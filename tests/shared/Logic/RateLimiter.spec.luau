--!strict
-- Specs for RateLimiter: the burst, the refill rate, the cap on stored tokens and a clock that steps back.

local testkit = require("../../../tools/testkit")
local describe, it, expect = testkit.describe, testkit.it, testkit.expect

local RateLimiter = require("../../../src/shared/Logic/RateLimiter")

-- How many of `count` requests at time `now` the bucket lets through.
local function takeMany(bucket: RateLimiter.Bucket, count: number, now: number): number
	local taken = 0
	for _ = 1, count do
		if RateLimiter.take(bucket, now) then
			taken += 1
		end
	end
	return taken
end

describe("RateLimiter", function()
	it("lets the burst through at once, then refuses", function()
		local bucket = RateLimiter.new({ burst = 5, perSecond = 2 }, 0)
		expect(takeMany(bucket, 100, 0)).toBe(5)
	end)

	it("refills at perSecond", function()
		local bucket = RateLimiter.new({ burst = 5, perSecond = 2 }, 0)
		takeMany(bucket, 5, 0)
		expect(takeMany(bucket, 10, 0.4)).toBe(0)
		expect(takeMany(bucket, 10, 0.5)).toBe(1)
		expect(takeMany(bucket, 10, 1.5)).toBe(2)
	end)

	it("never stores more than the burst", function()
		local bucket = RateLimiter.new({ burst = 3, perSecond = 2 }, 0)
		expect(takeMany(bucket, 100, 1000)).toBe(3)
	end)

	it("allows exactly the limit over a long run of spam", function()
		local bucket = RateLimiter.new({ burst = 5, perSecond = 2 }, 0)
		local taken = 0
		for frame = 0, 600 do
			taken += takeMany(bucket, 10, frame / 60)
		end
		-- 10 seconds of spam: the burst plus 2 a second.
		expect(taken).toBe(5 + 20)
	end)

	it("adds nothing when the clock steps back", function()
		local bucket = RateLimiter.new({ burst = 2, perSecond = 1 }, 10)
		takeMany(bucket, 2, 10)
		expect(takeMany(bucket, 5, 5)).toBe(0)
		expect(takeMany(bucket, 5, 11)).toBe(1)
	end)

	it("refuses a rate that is not positive", function()
		expect(function()
			RateLimiter.new({ burst = 0, perSecond = 1 }, 0)
		end).toThrow("burst must be at least 1")
	end)
end)
