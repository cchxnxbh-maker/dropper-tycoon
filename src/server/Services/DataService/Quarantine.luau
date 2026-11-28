--!strict
-- Quarantine: keeps a copy of a save that failed its check, with the reasons, so it can be looked at and repaired by
-- hand (plan section 4.7, ADR 0019). Part of DataService; nothing else requires it.
--
-- The original save stays untouched in the player's own key. The copy goes to its own data store under
-- `<userId>_<unix time>`, tagged with the user ID so a data-deletion request covers it too.
--
-- State owned: none.
--
-- Usage, inside DataService:
--     Quarantine.keep(player.UserId, profile.Data, problems, storeKind == "real")

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local TAG = "Data"
-- Permanent, like the main store's name: renaming it would hide every quarantined save.
local STORE_NAME = "PlayerDataQuarantine"

local Quarantine = {}

--[[
	Logs every problem and, when saves are real, writes the copy. Yields while writing.
	@param userId the player's user ID
	@param raw the save exactly as loaded
	@param problems the reasons it failed, from `SaveLoad.prepare`
	@param write false with the mock store, where only the log lines are written
	@return true when the copy was written; false when `write` is false or the write failed (logged as an error)
]]
function Quarantine.keep(userId: number, raw: any, problems: { string }, write: boolean): boolean
	Log.error(TAG, "save failed its check; kept as it was and quarantined", {
		userId = userId,
		problems = #problems,
		first = problems[1],
	})
	for _, problem in problems do
		Log.warn(TAG, `quarantined save problem: {problem}`, { userId = userId })
	end
	if not write then
		return false
	end
	local ok, err = pcall(function()
		DataStoreService:GetDataStore(STORE_NAME):SetAsync(`{userId}_{os.time()}`, {
			build = Config.Build.version,
			problems = problems,
			data = raw,
		}, { userId })
	end)
	if not ok then
		Log.error(TAG, "could not write the quarantine copy", { userId = userId, error = err })
	end
	return ok
end

return Quarantine
