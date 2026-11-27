--!strict
-- Rng: seeded, reproducible randomness for the whole game (plan section 8.4, ADR 0016).
--
-- Every random draw comes from a named stream. Each stream is derived from the session seed and its name only, so the
-- same seed gives the same numbers in every stream no matter which order streams are created or used in. That is what
-- lets a repro bundle (seed plus accepted requests) replay a bug exactly.
--
-- The generator is xoshiro128** on 32-bit integers, seeded through SplitMix32 from an FNV-1a hash of the stream name.
-- It is pure Luau (`bit32` only), so Lune and Roblox produce identical sequences. `math.random` is banned by the linter.
--
-- State owned: the session seed and the cache of named streams.
--
-- Usage:
--     Rng.seed(sessionSeed)                 -- once, on the server, at startup (the seed is logged)
--     local loot = Rng.stream("Loot")
--     local roll = loot:nextInteger(1, 6)

local TWO_32 = 4294967296 -- const: 2^32, the 32-bit range
local TWO_53 = 9007199254740992 -- const: 2^53, the double's exact-integer range
local FNV_OFFSET = 2166136261 -- const: FNV-1a 32-bit offset basis
local FNV_PRIME = 16777619 -- const: FNV-1a 32-bit prime
local GOLDEN = 0x9E3779B9 -- const: SplitMix32 increment (golden ratio)

export type Generator = {
	nextU32: (self: Generator) -> number,
	nextNumber: (self: Generator) -> number,
	nextInteger: (self: Generator, min: number, max: number) -> number,
	pick: <T>(self: Generator, list: { T }) -> T,
	shuffle: <T>(self: Generator, list: { T }) -> (),
}

type State = { s0: number, s1: number, s2: number, s3: number }

local Rng = {}

local sessionSeed: number? = nil
local streams: { [string]: Generator } = {}

-- Low 32 bits of a * b. Splits b into 16-bit halves so every partial product stays exact in a double.
local function mul32(a: number, b: number): number
	local bLow = bit32.band(b, 0xFFFF) -- const: 16-bit halves
	local bHigh = bit32.rshift(b, 16) -- const: 16-bit halves
	return (a * bLow + bit32.band(a * bHigh, 0xFFFF) * 65536) % TWO_32 -- const: 16-bit halves
end

-- FNV-1a over the bytes of `text`, starting from `basis`.
local function hash(text: string, basis: number): number
	local h = basis
	for index = 1, #text do
		h = mul32(bit32.bxor(h, string.byte(text, index)), FNV_PRIME)
	end
	return h
end

-- SplitMix32: turns one 32-bit seed into a well-mixed sequence used to fill the generator state.
local function splitMix(seed: number): () -> number
	local current = seed
	return function(): number
		current = (current + GOLDEN) % TWO_32
		local z = current
		z = mul32(bit32.bxor(z, bit32.rshift(z, 16)), 0x85EBCA6B) -- const: SplitMix32 mixing step
		z = mul32(bit32.bxor(z, bit32.rshift(z, 13)), 0xC2B2AE35) -- const: SplitMix32 mixing step
		return bit32.bxor(z, bit32.rshift(z, 16)) -- const: SplitMix32 mixing step
	end
end

local Generator = {}
Generator.__index = Generator

-- xoshiro128**: one 32-bit output per call.
function Generator.nextU32(self: Generator): number
	local state = (self :: any) :: State
	local s0, s1, s2, s3 = state.s0, state.s1, state.s2, state.s3
	local result = mul32(bit32.lrotate(mul32(s1, 5), 7), 9) -- const: xoshiro128** scramble
	local t = bit32.lshift(s1, 9) -- const: xoshiro128** shift
	s2 = bit32.bxor(s2, s0)
	s3 = bit32.bxor(s3, s1)
	s1 = bit32.bxor(s1, s2)
	s0 = bit32.bxor(s0, s3)
	s2 = bit32.bxor(s2, t)
	s3 = bit32.lrotate(s3, 11) -- const: xoshiro128** rotation
	state.s0, state.s1, state.s2, state.s3 = s0, s1, s2, s3
	return result
end

-- A number in [0, 1) with 53 random bits, built from two draws.
function Generator.nextNumber(self: Generator): number
	local high = bit32.rshift(self:nextU32(), 5) -- const: keep 27 bits
	local low = bit32.rshift(self:nextU32(), 6) -- const: keep 26 bits
	return (high * 67108864 + low) / TWO_53 -- const: 2^26, shifts the high bits past the low 26
end

-- A whole number in [min, max], both ends included, with no modulo bias.
function Generator.nextInteger(self: Generator, min: number, max: number): number
	assert(min == math.floor(min) and max == math.floor(max), "Rng: nextInteger needs whole numbers")
	assert(max >= min, "Rng: nextInteger needs max >= min")
	local range = max - min + 1
	assert(range <= TWO_32, "Rng: nextInteger range is wider than 2^32")
	local limit = TWO_32 - TWO_32 % range
	local draw = self:nextU32()
	while draw >= limit do
		draw = self:nextU32()
	end
	return min + draw % range
end

-- One element of a non-empty array.
function Generator.pick<T>(self: Generator, list: { T }): T
	assert(#list > 0, "Rng: pick needs a non-empty array")
	return list[self:nextInteger(1, #list)]
end

-- Shuffles an array in place (Fisher-Yates).
function Generator.shuffle<T>(self: Generator, list: { T })
	for index = #list, 2, -1 do
		local other = self:nextInteger(1, index)
		list[index], list[other] = list[other], list[index]
	end
end

--[[
	Makes a standalone generator. Most code wants `Rng.stream` instead; this is for tests and tools.
	@param seed any whole number; only its low 32 bits are used
	@param name optional label mixed into the seed, so one seed can give independent generators
	@return a new generator
]]
function Rng.new(seed: number, name: string?): Generator
	assert(seed == math.floor(seed), "Rng: seed must be a whole number")
	local mixed = hash(name or "", bit32.bxor(FNV_OFFSET, seed % TWO_32))
	local fill = splitMix(mixed)
	local state: State = { s0 = fill(), s1 = fill(), s2 = fill(), s3 = fill() }
	if state.s0 == 0 and state.s1 == 0 and state.s2 == 0 and state.s3 == 0 then
		state.s0 = 1 -- xoshiro never leaves the all-zero state
	end
	return (setmetatable(state :: any, Generator) :: any) :: Generator
end

--[[
	Sets the session seed and forgets every stream made from an earlier seed. The server calls it once at startup.
	@param seed any whole number; only its low 32 bits are used
]]
function Rng.seed(seed: number)
	assert(seed == math.floor(seed), "Rng: seed must be a whole number")
	sessionSeed = seed % TWO_32
	table.clear(streams)
end

--[[
	The session seed, for logs and repro bundles.
	@return the seed, or nil before `Rng.seed` is called
]]
function Rng.sessionSeed(): number?
	return sessionSeed
end

--[[
	The named stream for this session. The same name always returns the same generator, which keeps its position.
	@param name the stream name, such as "Loot"
	@return the generator for that name
	@error when `Rng.seed` has not been called yet
]]
function Rng.stream(name: string): Generator
	local seed = sessionSeed
	if seed == nil then
		error("Rng: call Rng.seed before Rng.stream", 2)
	end
	local existing = streams[name]
	if existing then
		return existing
	end
	local created = Rng.new(seed, name)
	streams[name] = created
	return created
end

return Rng
