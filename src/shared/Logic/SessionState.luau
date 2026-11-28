--!strict
-- SessionState: the life of one player's data session on this server, as a small state machine (plan sections 3.4
-- and 4.7, ADR 0019).
--
--     Loading --> Playing --> Releasing --> Ended
--        |           |                        ^
--        +-----------+------------------------+
--
-- Loading: the save is being read, migrated and checked. Playing: the save is ready and requests are accepted.
-- Releasing: the player is leaving and the last save is being written. Ended: nothing more happens for this session;
-- reached straight from Loading when a load fails, and from Playing when another server takes the session.
-- Only moves in `MOVES` are allowed; anything else is refused and leaves the state as it was.
--
-- Pure Luau: no Roblox APIs, so Lune tests it.
--
-- State owned: one state per machine.
--
-- Usage:
--     local session = SessionState.new()
--     session.move("Playing") -- true
--     session.get() -- "Playing"

export type State = "Loading" | "Playing" | "Releasing" | "Ended"

export type Machine = {
	get: () -> State,
	move: (to: State) -> boolean,
}

local SessionState = {}

-- Every allowed move: from a state to the states it may go to next.
SessionState.MOVES = table.freeze({
	Loading = table.freeze({ Playing = true, Ended = true }),
	Playing = table.freeze({ Releasing = true, Ended = true }),
	Releasing = table.freeze({ Ended = true }),
	Ended = table.freeze({}),
}) :: { [State]: { [State]: boolean } }

--[[
	Whether a session may move from one state to another.
	@param from the current state
	@param to the wanted state
	@return true when the move is in `MOVES`
]]
function SessionState.canMove(from: State, to: State): boolean
	local next = SessionState.MOVES[from]
	return next ~= nil and next[to] == true
end

--[[
	A new session machine, starting in Loading.
	@return the machine; `move` returns false and changes nothing when the move is not allowed
]]
function SessionState.new(): Machine
	local state: State = "Loading"
	local machine = {} :: Machine

	function machine.get(): State
		return state
	end

	function machine.move(to: State): boolean
		if not SessionState.canMove(state, to) then
			return false
		end
		state = to
		return true
	end

	return machine
end

return SessionState
