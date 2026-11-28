--!strict
-- Purchase: the rules for buying a machine (plan section 3.6, ADR 0021). PurchaseService asks these before it spends
-- anything, and the client uses `available` to know nothing it could not already see.
--
-- A machine can be bought when it exists, is not owned yet, every machine it requires is owned, the player stands at
-- its pad and has the cash. The checks run in that order, so the reason given is the first that fails.
--
-- Pure Luau. State owned: none.
--
-- Usage:
--     local reason = Purchase.check({ id = id, owned = owned, cash = cash, buildables = defs, distance = 4,
--         radius = 12 })
--     if reason == nil then ... end

local Types = require("../Types/Config")

-- Why a purchase was refused. "notEnoughCash" is what an honest player sees; the others mean the client asked for
-- something it was never shown.
export type Reason = "unknown" | "owned" | "locked" | "tooFar" | "notEnoughCash"

export type Request = {
	id: string,
	owned: { [string]: boolean },
	cash: number,
	buildables: { [string]: Types.BuildableDef },
	-- Distance across the ground from the character to the pad's centre.
	distance: number,
	-- Largest distance allowed, from `FactoryLayout.padRadius`.
	radius: number,
}

local Purchase = {}

Purchase.REASONS = table.freeze({ "unknown", "owned", "locked", "tooFar", "notEnoughCash" })

local function unlocked(def: Types.BuildableDef, owned: { [string]: boolean }): boolean
	for _, required in def.requires do
		if not owned[required] then
			return false
		end
	end
	return true
end

--[[
	The machines whose pads should show: not owned, with every requirement owned.
	@param owned the IDs the player owns
	@param buildables the buildable registry
	@param ids every buildable ID, sorted
	@return the available IDs, in the order of `ids`
]]
function Purchase.available(
	owned: { [string]: boolean },
	buildables: { [string]: Types.BuildableDef },
	ids: { string }
): { string }
	local list: { string } = {}
	for _, id in ids do
		local def = buildables[id]
		if not owned[id] and unlocked(def, owned) then
			table.insert(list, id)
		end
	end
	return list
end

--[[
	Checks one purchase request.
	@param request what is asked, what the player owns and has, and how far they stand from the pad
	@return nil when the purchase may go ahead; otherwise the first reason it may not
]]
function Purchase.check(request: Request): Reason?
	local def = request.buildables[request.id]
	if def == nil then
		return "unknown"
	elseif request.owned[request.id] then
		return "owned"
	elseif not unlocked(def, request.owned) then
		return "locked"
	elseif request.distance > request.radius then
		return "tooFar"
	elseif request.cash < def.price then
		return "notEnoughCash"
	end
	return nil
end

--[[
	The IDs of a registry, sorted, so code that walks it never depends on hash order.
	@param buildables the buildable registry
	@return every ID, sorted
]]
function Purchase.sortedIds(buildables: { [string]: Types.BuildableDef }): { string }
	local ids: { string } = {}
	for id in buildables do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return Purchase
