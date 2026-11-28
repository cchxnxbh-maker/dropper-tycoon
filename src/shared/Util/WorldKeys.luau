--!strict
-- WorldKeys: the CollectionService tags and attribute names that link world models to code (CLAUDE.md, dependencies
-- and communication). Server and client both read the names from here, so a typo cannot split them.
--
-- Attributes on a model are a display of state the server owns, never the state itself.
--
-- State owned: none.
--
-- Usage:
--     CollectionService:AddTag(model, WorldKeys.Tags.Plot)
--     model:SetAttribute(WorldKeys.Attributes.OwnerUserId, player.UserId)

local WorldKeys = table.freeze({
	Tags = table.freeze({
		-- Every plot model. Attributes: PlotIndex, OwnerUserId, OwnerName.
		Plot = "Plot",
		-- Every buildable model. Attribute: BuildableId.
		Buildable = "Buildable",
		-- Every purchase pad. Attribute: BuildableId. A pad exists only while its machine can be bought.
		PurchasePad = "PurchasePad",
	}),
	Attributes = table.freeze({
		-- The plot's number, 1 to `Config.Plots.count`.
		PlotIndex = "PlotIndex",
		-- The owner's user ID, or 0 while the plot is free.
		OwnerUserId = "OwnerUserId",
		-- The owner's display name, or "" while the plot is free.
		OwnerName = "OwnerName",
		BuildableId = "BuildableId",
	}),
	-- Names of the parts inside a plot model that code looks for.
	PlotParts = table.freeze({
		Base = "Base",
		Spawn = "Spawn",
		Sign = "Sign",
		-- Folder of the owner's bought machines, one model each.
		Machines = "Machines",
		-- Folder of the pads for machines the owner can buy next.
		Pads = "Pads",
	}),
})

return WorldKeys
