--!strict
-- Specs for SessionState: the allowed moves, refused moves that change nothing, and Ended as the last state.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local SessionState = require("../../../src/shared/Logic/SessionState")

local STATES: { SessionState.State } = { "Loading", "Playing", "Releasing", "Ended" }

describe("SessionState", function()
	it("starts in Loading", function()
		expect(SessionState.new().get()).toBe("Loading")
	end)

	it("follows the normal life of a session", function()
		local session = SessionState.new()
		expect(session.move("Playing")).toBe(true)
		expect(session.move("Releasing")).toBe(true)
		expect(session.move("Ended")).toBe(true)
		expect(session.get()).toBe("Ended")
	end)

	it("ends straight from Loading when a load fails", function()
		local session = SessionState.new()
		expect(session.move("Ended")).toBe(true)
	end)

	it("ends straight from Playing when another server takes the session", function()
		local session = SessionState.new()
		session.move("Playing")
		expect(session.move("Ended")).toBe(true)
	end)

	it("refuses a move that is not in the table and stays where it was", function()
		local session = SessionState.new()
		expect(session.move("Releasing")).toBe(false)
		expect(session.get()).toBe("Loading")
	end)

	it("never goes back to Playing", function()
		for _, from in { "Releasing", "Ended" } :: { SessionState.State } do
			expect(SessionState.canMove(from :: SessionState.State, "Playing")).toBe(false)
		end
	end)

	it("never leaves Ended", function()
		for _, to in STATES do
			expect(SessionState.canMove("Ended", to :: SessionState.State)).toBe(false)
		end
	end)

	it("never moves to the state it is already in", function()
		for _, state in STATES do
			expect(SessionState.canMove(state :: SessionState.State, state :: SessionState.State)).toBe(false)
		end
	end)
end)
