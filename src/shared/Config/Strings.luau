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
	Plot = {
		-- On the sign of a plot nobody has claimed yet.
		freeSign = "Free plot",
		-- On the sign of another player's plot. {name} is their display name.
		ownerSign = "{name}'s factory",
		-- On the sign of the player's own plot, as only they see it.
		yourSign = "Your factory",
		-- Under the owner line on every sign. {number} is the plot's number, 1 to 6.
		number = "Plot {number}",
		-- Shown when every plot is taken. Max Players should prevent this; it is the safety net.
		serverFull = "This server has no free plot. Please rejoin to find another server.",
	},
	-- Machine names, shown on purchase pads. Each buildable's key is its ID with a lowercase first letter.
	Buildables = {
		starterConveyor = "Conveyor",
		basicCollector = "Collector",
		coalDropper = "Coal Dropper",
		copperDropper = "Copper Dropper",
		washer = "Washer",
		ironDropper = "Iron Dropper",
		fastConveyor = "Fast Conveyor",
		silverDropper = "Silver Dropper",
		polisher = "Polisher",
		goldDropper = "Gold Dropper",
		bigCollector = "Big Collector",
		diamondDropper = "Diamond Dropper",
	},
	Purchase = {
		-- Under a machine's name on its pad. {price} is the formatted price.
		price = "${price}",
		-- On the pad of a free machine.
		free = "Free",
		-- Shown briefly when the player steps on a pad they cannot afford yet.
		notEnoughCash = "Not enough cash yet",
	},
	Hud = {
		-- The cash counter. {cash} is the formatted amount.
		cash = "${cash}",
		-- Under the cash counter. {rate} is the formatted cash per second.
		rate = "+${rate}/s",
	},
	DevPanel = {
		-- Heading of the developer panel, seen only in Studio and by the allowed accounts.
		title = "Dev panel",
		-- The saved test counter. {value} is its current value.
		counter = "Test counter: {value}",
		-- The button that adds one to the test counter.
		addCounter = "Add 1",
		-- The button that adds test cash. {amount} is how much.
		giveCash = "Give ${amount}",
		-- The button that sells back every machine and sets cash to zero, to test the start again.
		resetFactory = "Reset factory",
	},
}

return Strings
