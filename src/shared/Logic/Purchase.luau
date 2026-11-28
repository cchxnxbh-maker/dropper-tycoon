--!strict
-- Purchase: the rules for buying from a pad (plan section 3.6, ADR 0021, ADR 0023). PurchaseService asks these before
-- it spends anything, and the client uses the same functions to label the pads it can see.
--
-- A pad sells its machine until the machine is owned, then the machine's next level until the top level. A machine
-- can be bought when it exists, is not owned yet, and every machine it requires is owned. A level can be bought when
-- the machine is owned, has levels and is below the top. Either way the player must stand at the pad and have the
-- cash. The checks run in that order, so the reason given is the first that fails.
--
-- Pure Luau. State owned: none.
--
-- Usage:
--     local reason = Purchase.check({ id = id, owned = owned, levels = levels, cash = cash, buildables = defs,
--         rules = Config.Economy.levels, distance = 4, radius = 12 })
--     if reason == nil then ... end

local Levels = require("./Levels")
local Types = require("../Types/Config")

-- Why a purchase was refused. "notEnoughCash" is what an honest player sees; the others mean the client asked for
-- something it was never shown.
export type Reason = "unknown" | "owned" | "maxLevel" | "locked" | "tooFar" | "notEnoughCash"

-- What a pad sells now: the machine itself, or its next level.
export type Offer = { id: string, price: number, upgrade: boolean, level: number }

export type Request = {
	id: string,
	owned: { [string]: boolean },
	-- Saved levels by machine ID; a machine not listed is at level 1.
	levels: { [string]: number },
	cash: number,
	buildables: { [string]: Types.BuildableDef },
	rules: Levels.Rules,
	-- Distance across the ground from the character to the pad's centre.
	distance: number,
	-- Largest distance allowed, from `FactoryLayout.padRadius`.
	radius: number,
}

local Purchase = {}

Purchase.REASONS = table.freeze({ "unknown", "owned", "maxLevel", "locked", "tooFar", "notEnoughCash" })

local function unlocked(def: Types.BuildableDef, owned: { [string]: boolean }): boolean
	for _, required in def.requires do
		if not owned[required] then
			return false
		end
	end
	return true
end

--[[
	What one machine's pad sells now.
	@param id the machine
	@param owned the IDs the player owns
	@param levels saved levels by machine ID
	@param buildables the buildable registry
	@param rules `Economy.levels`
	@return the offer; nil when the pad shows nothing (unknown, locked, or owned with no level left to buy)
]]
function Purchase.offer(
	id: string,
	owned: { [string]: boolean },
	levels: { [string]: number },
	buildables: { [string]: Types.BuildableDef },
	rules: Levels.Rules
): Offer?
	local def = buildables[id]
	if def == nil then
		return nil
	elseif owned[id] then
		local level = Levels.of(levels, id)
		local price = Levels.price(def, level, rules)
		return if price then { id = id, price = price, upgrade = true, level = level + 1 } else nil
	elseif unlocked(def, owned) then
		return { id = id, price = def.price, upgrade = false, level = 1 }
	end
	return nil
end

--[[
	Everything the player's pads sell now: machines they can buy and levels of machines they own.
	@param owned the IDs the player owns
	@param levels saved levels by machine ID
	@param buildables the buildable registry
	@param ids every buildable ID, sorted
	@param rules `Economy.levels`
	@return one offer per pad to show, in the order of `ids`
]]
function Purchase.offers(
	owned: { [string]: boolean },
	levels: { [string]: number },
	buildables: { [string]: Types.BuildableDef },
	ids: { string },
	rules: Levels.Rules
): { Offer }
	local list: { Offer } = {}
	for _, id in ids do
		local offer = Purchase.offer(id, owned, levels, buildables, rules)
		if offer then
			table.insert(list, offer)
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
	local price: number
	if def == nil then
		return "unknown"
	elseif request.owned[request.id] then
		if def.levelPrice == nil then
			return "owned"
		end
		local next = Levels.price(def, Levels.of(request.levels, request.id), request.rules)
		if next == nil then
			return "maxLevel"
		end
		price = next
	elseif not unlocked(def, request.owned) then
		return "locked"
	else
		price = def.price
	end
	if request.distance > request.radius then
		return "tooFar"
	elseif request.cash < price then
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
