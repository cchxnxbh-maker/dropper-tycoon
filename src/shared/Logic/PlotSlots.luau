--!strict
-- PlotSlots: which player holds which plot (plan section 3.4, task 10). PlotService keeps one of these and is the
-- only owner of plot assignment; this module is just the bookkeeping, kept pure so Lune tests it.
--
-- A claim always gets the lowest free plot number, so a server that empties and refills gives out plot 1 first.
-- Keys are any value that names a player, such as a user ID.
--
-- State owned: none. Each slots object is owned by whoever made it.
--
-- Usage:
--     local slots = PlotSlots.new(6)
--     local index = slots.claim(player.UserId) -- 1, or nil when every plot is taken
--     slots.release(player.UserId)

export type Slots<K> = {
	-- Gives the key the lowest free plot, or the plot it already holds. Returns nil when every plot is taken.
	claim: (key: K) -> number?,
	-- Frees the key's plot. Returns the plot it held, or nil when it held none.
	release: (key: K) -> number?,
	-- The plot the key holds, or nil.
	indexOf: (key: K) -> number?,
	-- The key holding a plot, or nil when it is free.
	holderOf: (index: number) -> K?,
	-- How many plots are free.
	freeCount: () -> number,
}

local PlotSlots = {}

--[[
	Makes an empty set of plots.
	@param count how many plots there are, at least 1
	@return the slots, all free
	@error when count is not a whole number of at least 1
]]
function PlotSlots.new<K>(count: number): Slots<K>
	assert(count >= 1 and count % 1 == 0, "PlotSlots: count must be a whole number of at least 1")
	local holders: { [number]: K } = {}
	local indexByKey: { [K]: number } = {}
	local free = count

	local slots = {}

	function slots.claim(key: K): number?
		local held = indexByKey[key]
		if held then
			return held
		end
		for index = 1, count do
			if holders[index] == nil then
				holders[index] = key
				indexByKey[key] = index
				free -= 1
				return index
			end
		end
		return nil
	end

	function slots.release(key: K): number?
		local held = indexByKey[key]
		if held == nil then
			return nil
		end
		holders[held] = nil
		indexByKey[key] = nil
		free += 1
		return held
	end

	function slots.indexOf(key: K): number?
		return indexByKey[key]
	end

	function slots.holderOf(index: number): K?
		return holders[index]
	end

	function slots.freeCount(): number
		return free
	end

	return slots
end

return PlotSlots
