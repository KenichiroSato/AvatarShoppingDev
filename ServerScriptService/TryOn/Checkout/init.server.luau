--!strict

--[[
	Checkout - This script handles the main checkout functionality. Since bulk purchases are only able
	to be prompted on the server, the client fires a RemoteEvent to let the server know when they want
	to make a purchase.

	We do some simple validation on the parameters passed from the client to ensure we are sending a
	proper prompt request.
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.TryOn.Utility.Types)
local RestrictedItems = require(ReplicatedStorage.TryOn.Libraries.RestrictedItems)
local validateSimpleTable = require(ServerScriptService.TryOn.Utility.TypeValidation.validateSimpleTable)
local validateNumber = require(ServerScriptService.TryOn.Utility.TypeValidation.validateNumber)
local validateEnum = require(ServerScriptService.TryOn.Utility.TypeValidation.validateEnum)
local validateBulkItem = require(script.validateBulkItem)

local remotes = ReplicatedStorage.TryOn.Remotes
local bulkPurchaseRemote = remotes.BulkPurchase
local purchaseRemote = remotes.Purchase

local GEM_PURCHASE_BONUS = 500

local function getRemoteEvent(name: string): RemoteEvent
	local folder = ReplicatedStorage:FindFirstChild("RemoteEvent")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RemoteEvent"
		folder.Parent = ReplicatedStorage
	end
	local event = folder:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	return event :: RemoteEvent
end

local function giveAvatarPurchaseBonus(player: Player)
local PlayerManager = require(ServerScriptService.Nexapp.Player.PlayerManager)
	local gp = PlayerManager.GetGamePlayer(player)
	if not gp then return end
	local pd = gp.playerData
	if not pd then return end
	pd:AddGem(GEM_PURCHASE_BONUS)
	getRemoteEvent("GemGetEvent"):FireClient(player, "Bonus with purchase", GEM_PURCHASE_BONUS, "Fanfare")
end

local function onPurchaseEvent(player: Player, itemId: number, itemType: Enum.MarketplaceProductType)
	print("onPurchaseEvent:", itemId, itemType)
	if not validateNumber(itemId) then
		return
	end

	if not validateEnum(itemType, Enum.MarketplaceProductType) then
		return
	end

	-- Make sure this item is not in the restricted items list. This list should be used to
	-- disable purchasing items using these remotes, e.g. in the case of giving out free
	-- UGC through a separate game mechanic.
	if RestrictedItems.isRestricted(itemId, itemType) then
		return
	end

	if itemType == Enum.MarketplaceProductType.AvatarBundle then
		MarketplaceService:PromptBundlePurchase(player, itemId)
	else
		MarketplaceService:PromptPurchase(player, itemId)
	end
end

local function onBulkPurchaseEvent(player: Player, bulkPurchaseItems: { Types.BulkItem })
	if not validateSimpleTable(bulkPurchaseItems, "number", validateBulkItem) then
		return
	end

	-- Make sure no items are in the restricted items list. This list should be used to
	-- disable purchasing items using these remotes, e.g. in the case of giving out free
	-- UGC through a separate game mechanic.
	for _, item in bulkPurchaseItems do
		if RestrictedItems.isRestricted(tonumber(item.Id) :: number, item.Type) then
			return
		end
	end

	local options = {}
	MarketplaceService:PromptBulkPurchase(player, bulkPurchaseItems, options)
end

purchaseRemote.OnServerEvent:Connect(onPurchaseEvent)
bulkPurchaseRemote.OnServerEvent:Connect(onBulkPurchaseEvent)

-- アバターアイテム単品購入ボーナス
MarketplaceService.PromptPurchaseFinished:Connect(function(player: Player, _assetId: number, wasPurchased: boolean)
	if not wasPurchased then return end
	giveAvatarPurchaseBonus(player)
end)

-- バンドル購入ボーナス
MarketplaceService.PromptBundlePurchaseFinished:Connect(function(player: Player, _bundleId: number, wasPurchased: boolean)
	if not wasPurchased then return end
	giveAvatarPurchaseBonus(player)
end)

-- カート一括購入ボーナス (クライアントから通知)
getRemoteEvent("AvatarBulkPurchaseBonusEvent").OnServerEvent:Connect(function(player: Player)
	giveAvatarPurchaseBonus(player)
end)
