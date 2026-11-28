--!strict
-- CashDisplay: the number the cash counter shows, between server updates (CLAUDE.md, server authority; ADR 0022).
--
-- The client predicts cash by running the same simulation as the server. The counter follows that prediction: when
-- the shown number is within `easeShare` of the target, it eases there over `easeSeconds`; a bigger gap, such as a
-- purchase or a correction from the server, snaps at once. The server's number is always the truth.
--
-- Pure Luau. State owned: the shown number of one counter.
--
-- Usage:
--     local counter = CashDisplay.new()
--     local shown = CashDisplay.update(counter, predictedCash, dt, 0.01, 0.3)

export type Counter = { shown: number, started: boolean }

local CashDisplay = {}

--[[
	@return a counter that shows its first target at once
]]
function CashDisplay.new(): Counter
	return { shown = 0, started = false }
end

--[[
	Moves the shown number towards the target.
	@param counter the counter
	@param target the predicted cash now
	@param dt seconds since the last update
	@param easeShare a gap up to this share of the target eases (0.01 is 1%); a bigger one snaps
	@param easeSeconds how long an ease takes
	@return the number to show
]]
function CashDisplay.update(
	counter: Counter,
	target: number,
	dt: number,
	easeShare: number,
	easeSeconds: number
): number
	local gap = target - counter.shown
	if not counter.started or math.abs(gap) > easeShare * math.max(math.abs(target), 1) then
		counter.shown = target
		counter.started = true
	else
		counter.shown += gap * math.min(1, dt / easeSeconds)
	end
	return counter.shown
end

return CashDisplay
