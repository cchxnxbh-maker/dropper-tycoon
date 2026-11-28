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
	Sync: {
		cashPerSecond: number,
		cashSaveSeconds: number,
		-- The cash counter: a predicted gap up to this share eases over `cashEaseSeconds`; a bigger one snaps.
		cashEaseShare: number,
		cashEaseSeconds: number,
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

export type Plots = {
	count: number,
	ringRadius: number,
	baseSize: number,
	baseThickness: number,
	spawnInset: number,
	spawnSize: number,
	padThickness: number,
	signWidth: number,
	signHeight: number,
	signThickness: number,
	signLift: number,
	colors: { base: string, spawn: string, sign: string },
}

-- A point on a plot's ground, in studs from the plot's pivot. Negative z is towards the plot's front edge, where the
-- spawn pad and sign are; x runs across the plot.
export type PlotPoint = { x: number, z: number }

-- One machine a player can buy (plan section 5.1). Its ID is its file name and is saved in player data, so it never
-- changes. Its player-facing name is `Strings.Buildables[<id with a lowercase first letter>]`.
export type BuildableDef = {
	id: string,
	-- The kind decides what the machine does: a file in `Logic/Kinds/`, such as "Dropper".
	kind: string,
	-- The tier it belongs to. Phase 1 has only tier 1.
	tier: number,
	-- Cash it costs. 0 makes it free, which is how the first machines teach the pads.
	price: number,
	-- Buildables the player must own before this one's pad appears.
	requires: { string },
	-- The production line it joins. Phase 1 has one line, "Main".
	line: string,
	-- Numbers the kind reads. Each kind's file lists its own and their ranges.
	params: { [string]: number },
	-- Where its purchase pad sits on the plot. After it is bought, the same pad sells its next level.
	pad: PlotPoint,
	-- Cash for level 2. Each level after costs `Economy.levels.priceGrowth` times the one before. Absent for a machine
	-- that has no levels; only kinds with a `perLevel` param can have them.
	levelPrice: number?,
}

-- Where the factory sits on every plot, and the sizes and colours of the grey-box parts (Phase 1).
export type Factory = {
	-- The production line: a conveyor through `path`, a list of corners joined by straight runs along x or z, with the
	-- collector just past the last corner. Machines say how far along it they sit.
	line: { path: { PlotPoint }, height: number, width: number },
	collectorSize: number,
	dropperSize: number,
	dropperLift: number,
	upgraderClearance: number,
	postSize: number,
	itemSize: number,
	padSize: number,
	padThickness: number,
	-- How far beyond a pad's edge a character may stand and still buy from it. Allows for lag.
	padReach: number,
	-- Seconds before standing on the same pad asks the server again.
	padRetrySeconds: number,
	-- Most box items one dropper may have on screen at once. Draw-side only; the server never counts parts.
	maxItemsPerDropper: number,
	colors: {
		conveyor: string,
		collector: string,
		dropper: string,
		upgrader: string,
		item: string,
		pad: string,
	},
}

-- Cash rules (ADR 0009). Every number is a starting value for the balance pass.
export type Economy = {
	-- Cash never goes above this in one rebirth cycle (ADR 0009).
	maxCash: number,
	-- What the dev panel's Give cash button adds.
	devCashGift: number,
	-- Machine levels (ADR 0023): a bought machine's pad sells its next level, up to `maxLevel`.
	levels: {
		maxLevel: number,
		-- Each level costs this many times the one before.
		priceGrowth: number,
	},
	-- What `lune run balance` holds a fresh factory to. Buying is simulated with no walking time.
	pacing: {
		-- Longest wait allowed between two purchases, machines and levels alike.
		maxWaitSeconds: number,
		-- Buying every machine (not every level) must take between these. The fun gate asks for 20 minutes of play.
		minTotalMinutes: number,
		maxTotalMinutes: number,
	},
}

-- Player-facing text: system name, then key, then the text.
export type Strings = { [string]: { [string]: string } }

-- Everything the loader returns. Registries map an entry's ID (its file name) to its definition.
export type Config = {
	Build: Build,
	Flags: Flags,
	Tuning: Tuning,
	Plots: Plots,
	Factory: Factory,
	Economy: Economy,
	Strings: Strings,
	Buildables: { [string]: BuildableDef },
}

return {}
