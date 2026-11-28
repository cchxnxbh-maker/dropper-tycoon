--!strict
-- Types/Config: the shape of every config file (plan section 5.1). A missing or misspelled field in a config file fails
-- type analysis against these; ranges and cross-file rules are checked by `Config/Schema.luau`.
--
-- State owned: none. Types only.
--
-- Usage:
--     local Types = require("../Types/Config")
--     local Tuning: Types.Tuning = { Timing = { simRate = 10, maxCatchUpSteps = 5 } }

local Log = require("../Util/Log")

export type LogLevel = Log.Level

export type Build = {
	-- Semantic version shown in the settings screen and on every log line, such as "0.3.0".
	version: string,
	-- Place ID of the Dev experience's place. In Studio, only this place may use real data stores.
	devPlaceId: number,
}

export type Flags = {
	-- Feature switches by name. A risky feature ships switched off and is switched on in a later publish.
	Features: { [string]: boolean },
	-- Log levels: the default, and per-tag overrides by system name.
	Log: { default: LogLevel, tags: { [string]: LogLevel } },
}

export type Tuning = {
	Timing: {
		simRate: number,
		maxCatchUpSteps: number,
	},
	Network: {
		maxStringLength: number,
		maxTableDepth: number,
		maxTableEntries: number,
		strikeWindowSeconds: number,
		kickAfterStrikes: number,
		clientRateShare: number,
	},
}

-- Player-facing text: system name, then key, then the text.
export type Strings = { [string]: { [string]: string } }

-- Everything the loader returns. Registries map an entry's ID (its file name) to its definition.
export type Config = {
	Build: Build,
	Flags: Flags,
	Tuning: Tuning,
	Strings: Strings,
	Buildables: { [string]: any },
}

return {}
