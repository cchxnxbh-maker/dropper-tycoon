--!strict
-- RemoteFolder: the only code that makes or finds RemoteEvent instances (plan section 3.4: no file outside
-- `Network/` creates a remote).
--
-- The server calls `create` once at startup: one RemoteEvent per entry in `Remotes.luau`, in a folder named
-- `Remotes` under ReplicatedStorage. Clients call `find`, which waits for them to replicate.
--
-- State owned: none. The caller owns the folder `create` returns and puts it in its Trove.
--
-- Usage:
--     local folder, events = RemoteFolder.create(ReplicatedStorage, Remotes)   -- server
--     local events = RemoteFolder.find(ReplicatedStorage, Remotes)             -- client

local FOLDER_NAME = "Remotes"
-- How long a client waits for the remotes to replicate before it reports a problem.
local FIND_TIMEOUT_SECONDS = 30

local RemoteFolder = {}

local function sortedNames(remotes: { [string]: any }): { string }
	local names = {}
	for name in remotes do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

--[[
	Makes the folder and one RemoteEvent per remote. Server only.
	@param parent where the folder goes, ReplicatedStorage in the game
	@param remotes the table from `Remotes.luau`
	@return the folder (not yet parented until every event is in it) and the events by name
	@error when called on a client, or when the folder already exists
]]
function RemoteFolder.create(parent: Instance, remotes: { [string]: any }): (Folder, { [string]: RemoteEvent })
	assert(game:GetService("RunService"):IsServer(), "RemoteFolder.create runs on the server only")
	assert(parent:FindFirstChild(FOLDER_NAME) == nil, "RemoteFolder.create: the Remotes folder already exists")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local events: { [string]: RemoteEvent } = {}
	for _, name in sortedNames(remotes) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		events[name] = event
	end
	-- Parent last, so a client never sees a half-filled folder.
	folder.Parent = parent
	return folder, events
end

--[[
	Waits for the folder and every RemoteEvent in it. Client side.
	@param parent where the server put the folder, ReplicatedStorage in the game
	@param remotes the table from `Remotes.luau`
	@return the events by name
	@error when the folder or an event has not arrived within the timeout
]]
function RemoteFolder.find(parent: Instance, remotes: { [string]: any }): { [string]: RemoteEvent }
	local folder = parent:WaitForChild(FOLDER_NAME, FIND_TIMEOUT_SECONDS)
	assert(folder, "RemoteFolder.find: the Remotes folder never arrived")
	local events: { [string]: RemoteEvent } = {}
	for _, name in sortedNames(remotes) do
		local event = folder:WaitForChild(name, FIND_TIMEOUT_SECONDS)
		assert(event and event:IsA("RemoteEvent"), `RemoteFolder.find: remote {name} never arrived`)
		events[name] = event :: RemoteEvent
	end
	return events
end

return RemoteFolder
