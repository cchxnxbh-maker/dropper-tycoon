--!strict
-- ClientStore: the client's read-only copy of the player's state (plan section 3.4). Controllers read it and listen
-- for changes; only the network layer (`Net/StateSync.luau`) writes it, from what the server sends. Nothing here is
-- trusted by the server.
--
-- Phase 1 holds two entries: `cash` (from CashSync) and `factory` (from FactoryState). Path-based patches for the
-- whole save arrive when more state needs mirroring (ADR 0021).
--
-- State owned: the latest copy of each entry.
--
-- Usage:
--     local cash = ClientStore.get("cash")
--     ClientStore.changed("cash", function(value) ... end)

export type Factory = {
	owned: { [string]: boolean },
	-- Levels above 1, by machine ID (ADR 0023).
	levels: { [string]: number },
	starts: { [string]: number },
	tick: number,
	serverTime: number,
	incomeRate: number,
}

-- The last cash the server sent, and the server time it was sent at.
export type Cash = { cash: number, serverTime: number }

export type Key = "cash" | "factory"

local ClientStore = {}

local values: { [string]: any } = {}
local listeners: { [string]: { (value: any) -> () } } = {}

--[[
	The latest value of an entry.
	@param key "cash" (a `Cash`) or "factory" (a `Factory`)
	@return the value; nil until the server has sent it
]]
function ClientStore.get(key: Key): any
	return values[key]
end

--[[
	Calls `listener` with each new value of an entry, and at once with the current one if there is one.
	@param key the entry
	@param listener called with the new value
	@return a function that stops the calls
]]
function ClientStore.changed(key: Key, listener: (value: any) -> ()): () -> ()
	local list = listeners[key]
	if list == nil then
		list = {}
		listeners[key] = list
	end
	table.insert(list, listener)
	if values[key] ~= nil then
		task.spawn(listener, values[key])
	end
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

--[[
	Stores a new value and tells the listeners. Only `Net/StateSync.luau` calls this.
	@param key the entry
	@param value the new value, as the server sent it
]]
function ClientStore.write(key: Key, value: any)
	values[key] = value
	-- A copy, so a listener that stops itself does not skip the next one.
	local list: { (value: any) -> () } = table.clone(listeners[key] or {})
	for _, listener in list do
		task.spawn(listener, value)
	end
end

return ClientStore
