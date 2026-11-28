--!strict
-- Specs for Net and Remotes: definitions are named, checked and frozen, and bad definitions fail at load.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local Net = require("../../../src/shared/Network/Net")
local Remotes = require("../../../src/shared/Network/Remotes")
local Validate = require("../../../src/shared/Logic/Validate")

local function request(example: any): Net.ToServer
	return Net.toServer({
		payload = Validate.record({ id = Validate.string({ maxLength = 10 }) }),
		rate = { burst = 2, perSecond = 1 },
		example = example,
	})
end

describe("Net.define", function()
	it("names each remote after its key and freezes it", function()
		expect(Remotes.RequestTestPing.name).toBe("RequestTestPing")
		expect(Remotes.TestPong.direction).toBe("toClient")
		expect(table.isfrozen(Remotes)).toBe(true)
		expect(table.isfrozen(Remotes.RequestTestPing)).toBe(true)
	end)

	it("refuses an example that fails its own rule", function()
		expect(function()
			Net.define({ RequestThing = request({ id = 5 }) })
		end).toThrow("the example fails its own rule")
	end)

	it("refuses a rate that is not positive", function()
		local bad = Net.toServer({ payload = Validate.boolean(), rate = { burst = 0, perSecond = 1 }, example = true })
		expect(function()
			Net.define({ RequestThing = bad })
		end).toThrow("rate needs burst >= 1")
	end)

	it("refuses a name that is not PascalCase", function()
		expect(function()
			Net.define({ requestThing = request({ id = "a" }) })
		end).toThrow("must be PascalCase")
	end)
end)

describe("toServer check", function()
	local remote = Net.define({ RequestThing = request({ id = "a" }) }).RequestThing

	it("runs the shape limits before the remote's rule", function()
		expect((remote.check({ id = "a" }))).toBe(true)
		local _, reason = remote.check({ id = 0 / 0 })
		expect(reason).toBe("payload.id: NaN")
		_, reason = remote.check({ id = "much too long" })
		expect(reason).toBe("payload.id: must be at most 10 characters, got 13")
	end)

	it("never accepts the tampering marker", function()
		expect((remote.check(Net.REJECTED))).toBe(false)
	end)
end)
