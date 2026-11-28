--!strict
-- PadController: the player's purchase pads (task 12, plan section 4.4, ADR 0023). Each pad on the player's own plot
-- gets a label with what it sells, the machine or its next level, and the price, worked out from the factory state
-- the server sent. Stepping on it asks the server to buy. Standing on a pad asks again every
-- `Config.Factory.padRetrySeconds`, so a machine is bought as soon as the cash is there, and staying on a level pad
-- keeps buying levels. The server decides; this only asks. Pads on other players' plots are hidden for this player.
--
-- Streaming-safe: pads are bound when a part tagged `PurchasePad` streams in and dropped when it leaves.
--
-- State owned: one label and touch connection per pad that is streamed in, and when each pad last asked.
--
-- Usage, in Main:
--     PadController.init()
--     PadController.start()

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbuseCases = require(Shared:WaitForChild("Network"):WaitForChild("AbuseCases"))
local ClientNet = require(script.Parent.Parent.Net.ClientNet)
local ClientStore = require(script.Parent.Parent.Net.ClientStore)
local Config = require(Shared:WaitForChild("Config"))
local NumberFormat = require(Shared:WaitForChild("Logic"):WaitForChild("NumberFormat"))
local Purchase = require(Shared:WaitForChild("Logic"):WaitForChild("Purchase"))
local PurchasePad = require(script.Parent.Parent.Views.PurchasePad)
local Remotes = require(Shared:WaitForChild("Network"):WaitForChild("Remotes"))
local Scheduler = require(Shared:WaitForChild("Util"):WaitForChild("Scheduler"))
local Text = require(Shared:WaitForChild("Util"):WaitForChild("Text"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local WorldKeys = require(Shared:WaitForChild("Util"):WaitForChild("WorldKeys"))

local PadController = {}

local trove = Trove.new()
local bound: { [Instance]: typeof(Trove.new()) } = {}
-- The player's own pads that are streamed in, with their machine IDs, for the standing-still check.
local ownPads: { [BasePart]: string } = {}
local views: { [BasePart]: PurchasePad.View } = {}
local lastAsked: { [string]: number } = {}

-- The plot model a pad belongs to: pads sit in the plot's Pads folder.
local function plotOf(pad: Instance): Instance?
	local folder = pad.Parent
	return if folder then folder.Parent else nil
end

local function nameOf(id: string): string
	local key = string.lower(string.sub(id, 1, 1)) .. string.sub(id, 2)
	return Config.Strings.Buildables[key] or id
end

-- What a pad's label says: the machine, or its next level, and the price, from the last factory state.
local function labelOf(id: string): (string, string)
	local strings = Config.Strings.Purchase
	local state = ClientStore.get("factory") :: ClientStore.Factory?
	local owned = if state then state.owned else {}
	local levels = if state then state.levels else {}
	local offer = Purchase.offer(id, owned, levels, Config.Buildables, Config.Economy.levels)
	local name = nameOf(id)
	if offer == nil then
		return name, ""
	end
	local price = if offer.price == 0
		then strings.free
		else Text.format(strings.price, { price = NumberFormat.cash(offer.price) })
	if offer.upgrade then
		name = Text.format(strings.upgrade, { name = name, level = tostring(offer.level) })
	end
	return name, price
end

local function relabel()
	for pad, id in ownPads do
		local view = views[pad]
		if view then
			view.set(labelOf(id))
		end
	end
end

local function ask(id: string)
	-- While the Studio abuse suite runs, the server counts every request it gets; a purchase would spoil the count.
	if Players.LocalPlayer:GetAttribute(AbuseCases.ATTRIBUTE) == true then
		return
	end
	local now = os.clock()
	if now - (lastAsked[id] or -math.huge) < Config.Factory.padRetrySeconds then
		return
	end
	lastAsked[id] = now
	ClientNet.send(Remotes.RequestPurchase, { buildableId = id })
end

-- Asks again for any pad the character is standing on.
local function retry()
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local half = Config.Factory.padSize / 2
	for pad, id in ownPads do
		local offset = pad.CFrame:PointToObjectSpace(root.Position)
		if math.abs(offset.X) <= half and math.abs(offset.Z) <= half then
			ask(id)
		end
	end
end

local function unbind(pad: Instance)
	if pad:IsA("BasePart") then
		ownPads[pad] = nil
		views[pad] = nil
	end
	local own = bound[pad]
	if own then
		own:Destroy()
		bound[pad] = nil
	end
end

local function bind(pad: Instance)
	unbind(pad)
	if not pad:IsA("BasePart") then
		return
	end
	local id = pad:GetAttribute(WorldKeys.Attributes.BuildableId)
	local def = if type(id) == "string" then Config.Buildables[id] else nil
	local plot = plotOf(pad)
	if def == nil or plot == nil then
		return
	end
	local own = Trove.new()
	bound[pad] = own
	if plot:GetAttribute(WorldKeys.Attributes.OwnerUserId) ~= Players.LocalPlayer.UserId then
		-- Someone else's pad. Changes made here stay on this client.
		pad.LocalTransparencyModifier = 1
		pad.CanTouch = false
		return
	end
	local name, price = labelOf(def.id)
	views[pad] = own:Add(PurchasePad.mount(pad, name, price), "destroy")
	ownPads[pad] = def.id
	own:Connect(pad.Touched, function(hit: BasePart)
		local character = Players.LocalPlayer.Character
		if character and hit:IsDescendantOf(character) then
			ask(def.id)
		end
	end)
end

--[[
	Nothing to prepare; here so Main treats every controller the same way.
]]
function PadController.init() end

--[[
	Binds every pad already streamed in, and each one that arrives later.
]]
function PadController.start()
	Scheduler.every("PadRetry", 1 / Config.Factory.padRetrySeconds, retry)
	trove:Add(ClientStore.changed("factory", relabel))
	trove:Connect(CollectionService:GetInstanceAddedSignal(WorldKeys.Tags.PurchasePad), bind)
	trove:Connect(CollectionService:GetInstanceRemovedSignal(WorldKeys.Tags.PurchasePad), unbind)
	for _, pad in CollectionService:GetTagged(WorldKeys.Tags.PurchasePad) do
		bind(pad)
	end
end

return PadController
