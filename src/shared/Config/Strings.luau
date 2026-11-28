--!strict
-- Strings: all player-facing text, grouped by system and then by key (plan section 5.1). Code never writes a sentence a
-- player sees; it reads one from here, so wording changes in one place and translation can come later.
-- Read it through `Config`, which validates and freezes it.
--
-- State owned: none. Read-only data.
--
-- Usage:
--     local Config = require("../Config")
--     player:Kick(Config.Strings.Net.kicked)

local Types = require("../Types/Config")

local Strings: Types.Strings = {
	Net = {
		-- Shown when the server disconnects a player for sending far too many bad or rapid requests.
		kicked = "You were disconnected for sending too many requests. Please rejoin.",
	},
	Data = {
		-- Shown when the save could not be loaded in time, usually because Roblox's data stores are having trouble.
		loadFailed = "Your progress could not be loaded right now. Nothing was lost. Please rejoin in a minute.",
		-- Shown when this server is older than the build that last saved the player. Rejoining finds a newer server.
		newerSave = "This server is out of date for your progress. Please rejoin to reach an updated server.",
		-- Shown when the save failed its check. It is kept safe, unchanged, for the developer to look at.
		invalidSave = "Your progress could not be loaded, but it is safe and unchanged. Please rejoin later.",
		-- Shown when the player joined another server, which now holds their progress.
		sessionTaken = "Your progress was opened on another server, so this one has let it go. Please rejoin.",
	},
}

return Strings
