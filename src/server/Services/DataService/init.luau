--!strict
-- DataService: the only door to saved player data (plan section 4.7, ADRs 0003 and 0019).
--
-- Wraps ProfileStore, which gives session locking, autosave and safe saving on leave and on shutdown. When a player
-- joins, their save is read, migrated to the current schema on a copy (`SaveLoad`) and checked (`SaveSchema`). Only a
-- valid save is used. A save from a newer build is left alone and the player is asked to rejoin; a save that fails
-- its check is copied to a quarantine store, never overwritten, and the player is asked to rejoin.
--
-- Other services read a frozen snapshot with `get` and change data only through `mutate`, which works on a copy and
-- keeps the change only if the result still passes the schema. Each piece of saved state is changed only by its owner
-- (CLAUDE.md, state ownership); DataService itself owns `meta`.
--
-- Store choice: real servers use the real store. Studio uses the real store only on the Dev place
-- (`Config.Build.devPlaceId`), and only when "Enable Studio Access to API Services" is on; otherwise ProfileStore's
-- mock store, which forgets everything when the playtest stops. Live saves are never touched from Studio.
--
-- State owned: every player's profile and session state (Loading, Playing, Releasing, Ended).
--
-- Usage, in Main:
--     DataService.init()
--     DataService.start()
-- From an owning service:
--     DataService.mutate(player, "purchase", function(data) table.insert(data.owned, id) end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Freeze = require(ReplicatedStorage.Shared.Util.Freeze)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Migrations = require(script.Parent.Parent.Migrations)
local ProfileStoreModule = require(script.Parent.Parent.Vendor.ProfileStore)
local Quarantine = require(script.Quarantine)
local SaveLoad = require(ReplicatedStorage.Shared.Logic.SaveLoad)
local SaveSchema = require(ReplicatedStorage.Shared.Logic.SaveSchema)
local SessionState = require(ReplicatedStorage.Shared.Logic.SessionState)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

-- The vendored module is not typed on its own return value; its exported types describe it.
local ProfileStore = (ProfileStoreModule :: any) :: ProfileStoreModule.ProfileStoreModule

type Profile = ProfileStoreModule.Profile<any>
-- The two calls this service makes on a store. The real store and its `.Mock` both have them.
type SessionStore = {
	StartSessionAsync: (self: any, key: string, params: { Cancel: () -> boolean }) -> Profile?,
}
type Session = {
	machine: SessionState.Machine,
	profile: Profile?,
	snapshot: SaveSchema.SaveData?,
	trove: typeof(Trove.new()),
}

export type Snapshot = SaveSchema.SaveData
export type StoreKind = "real" | "mock"

local TAG = "Data"
-- Data store names are permanent: renaming one loses every save in it, so they are fixed here, not tuned in Config.
-- The quarantine store is named in `Quarantine.luau`.
local STORE_NAME = "PlayerData"

local DataService = {}

--[[
	Fires once a player's save is loaded and valid and their session is Playing. Carries the player.
]]
DataService.profileLoaded = Signal.new() :: Signal.Signal<Player>

--[[
	Fires when a Playing session is about to stop: the player left, the server is shutting down, or another server
	took the session. Carries the player. Owners that keep state in memory write it with `mutate` right away, without
	yielding (it is refused when another server took the session, since this server may no longer write).
]]
DataService.profileReleasing = Signal.new() :: Signal.Signal<Player>

local trove = Trove.new()
local sessions: { [Player]: Session } = {}
local store: SessionStore
local storeKind: StoreKind = "mock"

local function profileKey(player: Player): string
	return `Player_{player.UserId}`
end

local function kick(player: Player, message: string)
	if player.Parent == Players then
		player:Kick(message)
	end
end

-- Moves a session to Ended and forgets it. Safe to call more than once.
local function finish(player: Player, session: Session)
	session.machine.move("Ended")
	session.trove:Destroy()
	if sessions[player] == session then
		sessions[player] = nil
	end
end

-- Stamps the session facts that DataService owns. Runs once per load, on data that has just passed its check.
local function stampJoin(data: any, now: number)
	data.meta.joins += 1
	if data.meta.firstJoin == 0 then
		data.meta.firstJoin = now
	end
	data.meta.lastJoin = now
end

-- Ends a Playing session: tells the owners, then lets ProfileStore write the last save and release the lock.
local function release(player: Player, session: Session)
	if not session.machine.move("Releasing") then
		return
	end
	DataService.profileReleasing:Fire(player)
	local profile = session.profile
	if profile then
		profile:EndSession()
	end
	finish(player, session)
end

local function load(player: Player)
	local session: Session = { machine = SessionState.new(), profile = nil, snapshot = nil, trove = Trove.new() }
	sessions[player] = session

	local profile = store:StartSessionAsync(profileKey(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		-- The player left while loading, or the store could not be reached for two minutes.
		finish(player, session)
		if player.Parent == Players then
			Log.error(TAG, "could not load the save", { userId = player.UserId })
			kick(player, Config.Strings.Data.loadFailed)
		end
		return
	end
	if player.Parent ~= Players then
		profile:EndSession()
		finish(player, session)
		return
	end

	local result = SaveLoad.prepare(profile.Data, Migrations, SaveSchema)
	if result.kind == "newer" then
		Log.warn(TAG, "save is from a newer build; refused", { userId = player.UserId, version = result.version })
		profile:EndSession()
		finish(player, session)
		kick(player, Config.Strings.Data.newerSave)
		return
	elseif result.kind == "invalid" then
		Quarantine.keep(player.UserId, profile.Data, result.problems, storeKind == "real")
		profile:EndSession()
		finish(player, session)
		kick(player, Config.Strings.Data.invalidSave)
		return
	end

	local data = result.data
	stampJoin(data, os.time())
	profile.Data = data
	profile:AddUserId(player.UserId)
	session.profile = profile
	session.trove:Add(profile.OnSessionEnd:Connect(function()
		-- Reached after our own release too, when the session is already Ended and forgotten. When another server
		-- took the session, this server may no longer write, so the session ends before the owners hear of it.
		if session.machine.get() == "Playing" then
			Log.warn(TAG, "another server took the session", { userId = player.UserId })
			finish(player, session)
			DataService.profileReleasing:Fire(player)
			kick(player, Config.Strings.Data.sessionTaken)
		end
	end))
	session.machine.move("Playing")
	Log.info(TAG, "save loaded", {
		userId = player.UserId,
		joins = data.meta.joins,
		fromVersion = result.fromVersion,
		store = if storeKind == "mock" then "mock" else ProfileStore.DataStoreState,
	})
	DataService.profileLoaded:Fire(player)
end

local function onRemoving(player: Player)
	local session = sessions[player]
	if session and session.machine.get() == "Playing" then
		release(player, session)
	end
	-- A session still Loading ends itself: its Cancel check sees the player has gone.
end

--[[
	Opens the data store and checks the migration chain. Call once, before `start`.
	@error when the migrations do not form one chain from version 0 to `SaveSchema.CURRENT_VERSION`
]]
function DataService.init()
	local problems = SaveLoad.checkChain(Migrations, SaveSchema.CURRENT_VERSION)
	if #problems > 0 then
		error(`DataService: the save migrations are broken:\n{table.concat(problems, "\n")}`, 0)
	end
	local real = ProfileStore.New(STORE_NAME)
	if RunService:IsStudio() and game.PlaceId ~= Config.Build.devPlaceId then
		store = (real.Mock :: any) :: SessionStore
		storeKind = "mock"
		Log.info(TAG, "Studio on a place other than Dev: saves use the mock store and are forgotten on stop")
	else
		store = (real :: any) :: SessionStore
		storeKind = "real"
	end
end

--[[
	Loads the save of every player already here and of everyone who joins, and releases it when they leave.
]]
function DataService.start()
	trove:Connect(Players.PlayerAdded, function(player)
		task.spawn(load, player)
	end)
	trove:Connect(Players.PlayerRemoving, onRemoving)
	for _, player in Players:GetPlayers() do
		if sessions[player] == nil then
			task.spawn(load, player)
		end
	end
	-- Shutdown: ProfileStore's own close handler writes and releases every profile. Players leaving fire
	-- PlayerRemoving first, so owners still hear profileReleasing.
end

-- The session, when its data may be read: Playing, or Releasing while the owners write their last changes.
local function readable(player: Player): (Session?, Profile?)
	local session = sessions[player]
	if session == nil or session.profile == nil then
		return nil, nil
	end
	local state = session.machine.get()
	if state ~= "Playing" and state ~= "Releasing" then
		return nil, nil
	end
	return session, session.profile
end

--[[
	The player's session state.
	@return Loading, Playing or Releasing; nil when the player has no session on this server (never joined, or Ended)
]]
function DataService.getState(player: Player): SessionState.State?
	local session = sessions[player]
	return if session then session.machine.get() else nil
end

--[[
	Whether the player's save is loaded and their requests may be handled. ServerNet's session gate.
	@return true only while Playing
]]
function DataService.isPlaying(player: Player): boolean
	return DataService.getState(player) == "Playing"
end

--[[
	A frozen copy of the player's saved data. Writing to it throws. The copy is made once per change and reused.
	@return the snapshot; nil unless the session is Playing (or Releasing, inside a profileReleasing listener)
]]
function DataService.get(player: Player): Snapshot?
	local session, profile = readable(player)
	if session == nil or profile == nil then
		return nil
	end
	if session.snapshot == nil then
		session.snapshot = Freeze.deep(SaveLoad.deepCopy(profile.Data))
	end
	return session.snapshot
end

--[[
	Changes the player's saved data, all or nothing. `change` edits a private copy; the copy replaces the save only if
	`change` returns without error and the result still passes `SaveSchema`. Only the service that owns a field may
	change it (CLAUDE.md, state ownership).
	@param player the player whose save changes
	@param reason a short word for the log, such as "purchase"
	@param change edits the copy in place; must not yield
	@return true when the change was kept; false when the session is not Playing (or Releasing), `change` threw, or the
	result was invalid. The last two are server bugs and are logged as errors.
]]
function DataService.mutate(player: Player, reason: string, change: (data: any) -> ()): boolean
	local session, profile = readable(player)
	if session == nil or profile == nil or not profile:IsActive() then
		Log.warn(TAG, "change refused: no active session", { userId = player.UserId, reason = reason })
		return false
	end
	local draft = SaveLoad.deepCopy(profile.Data)
	-- `change` returns nothing; the cast lets pcall hand back its error message.
	local ok, err = pcall(change :: (any) -> any, draft)
	if not ok then
		Log.error(TAG, "change refused: it threw", { userId = player.UserId, reason = reason, error = err })
		return false
	end
	local problems = SaveSchema.validate(draft)
	if #problems > 0 then
		Log.error(TAG, "change refused: the save would be invalid", {
			userId = player.UserId,
			reason = reason,
			first = problems[1],
		})
		return false
	end
	profile.Data = draft
	session.snapshot = nil
	return true
end

--[[
	Which store saves go to on this server.
	@return "real" for the experience's data store (Studio falls back to memory without API access), "mock" otherwise
]]
function DataService.storeKind(): StoreKind
	return storeKind
end

return DataService
