--!strict
-- RateLimiter: token buckets that decide whether one more request fits a remote's limit (plan sections 3.6 and 4.8).
--
-- A bucket holds up to `burst` tokens and refills at `perSecond` tokens a second. Each request takes one token; with
-- none left, the request is refused. So a player can send `burst` requests at once, then `perSecond` a second after
-- that. Time comes in as `now` (seconds on any steady clock), never read here, so tests drive it by hand.
--
-- Pure Luau: the server uses it in the request pipeline and the client uses it to stay under the limit itself.
--
-- State owned: none. Each bucket is a small table owned by whoever made it.
--
-- Usage:
--     local bucket = RateLimiter.new({ burst = 5, perSecond = 2 }, now)
--     if RateLimiter.take(bucket, now) then ... end

export type Rate = { burst: number, perSecond: number }
export type Bucket = { burst: number, perSecond: number, tokens: number, updated: number }

local RateLimiter = {}

--[[
	Makes a full bucket.
	@param rate `burst` the most tokens held (at least 1), `perSecond` the refill rate (above 0)
	@param now the current time in seconds
	@return the bucket, starting full
	@error when the rate is not positive
]]
function RateLimiter.new(rate: Rate, now: number): Bucket
	assert(rate.burst >= 1 and rate.perSecond > 0, "RateLimiter: burst must be at least 1 and perSecond above 0")
	return { burst = rate.burst, perSecond = rate.perSecond, tokens = rate.burst, updated = now }
end

--[[
	Refills the bucket for the time since it was last used, then takes one token if there is one.
	A `now` earlier than the last call (a clock that stepped back) adds nothing rather than draining the bucket.
	@param bucket the bucket to use
	@param now the current time in seconds
	@return true when the request fits the limit and a token was taken
]]
function RateLimiter.take(bucket: Bucket, now: number): boolean
	local elapsed = math.max(0, now - bucket.updated)
	bucket.tokens = math.min(bucket.burst, bucket.tokens + elapsed * bucket.perSecond)
	bucket.updated = math.max(bucket.updated, now)
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

return RateLimiter
