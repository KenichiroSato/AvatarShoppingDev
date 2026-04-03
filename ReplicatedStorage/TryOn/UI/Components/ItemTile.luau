--!strict

--[[
	ItemTile - This function acts as a basic UI component, implementing an item 'tile'. The tile
	displays the item name, icon, and price, as well as buttons to try on or add the item to the cart.

	This is used both for the shop as well as the mannequin inspect UI.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.TryOn.Constants)
local Cart = require(ReplicatedStorage.TryOn.Libraries.Cart)
local ItemContainer = require(ReplicatedStorage.TryOn.Utility.ItemContainer)
local Types = require(ReplicatedStorage.TryOn.Utility.Types)

local ItemButton = require(ReplicatedStorage.TryOn.UI.Components.ItemButton)

local itemTileTemplate = ReplicatedStorage.TryOn.UI.Objects.ItemTileFrame
local limitedLabelTemplate = ReplicatedStorage.TryOn.UI.Objects.LimitedLabel
local limitedULabelTemplate = ReplicatedStorage.TryOn.UI.Objects.LimitedULabel
local remotes = ReplicatedStorage.TryOn.Remotes
local purchaseRemote = remotes.Purchase

local function ItemTile(itemDetails: Types.AssetDetails | Types.BundleDetails): Frame
	local productType = Enum.MarketplaceProductType[`Avatar{itemDetails.ItemType}`]
	local price = itemDetails.LowestPrice or itemDetails.Price

	local itemTile = itemTileTemplate:Clone()
	itemTile.NameLabel.Text = itemDetails.Name
	itemTile.PriceLabel.Text = itemDetails.PriceStatus or `{Constants.ROBUX_CHAR}{price}`

	local itemButton = ItemButton(itemDetails.Id, productType)
	itemButton.Parent = itemTile

	local addToCartButton = itemTile.ButtonsFrame.AddToCartButton
	local buyButton = itemTile.ButtonsFrame.BuyButton
	local isInCart = Cart.getItem(itemDetails.Id, productType) ~= nil

	addToCartButton.IconLabel.ImageTransparency = if isInCart then Constants.BUTTON_DISABLED_TRANSPARENCY else 0

	-- The ItemRestrictions table in itemDetails contains information about various restrictions
	-- on the item, such as whether it is limited or a collectible.
	if table.find(itemDetails.ItemRestrictions, Constants.ITEM_RESTRICTIONS.LIMITED) then
		local limitedLabel = limitedLabelTemplate:Clone() :: GuiObject
		limitedLabel.Parent = itemButton
	elseif
		table.find(itemDetails.ItemRestrictions, Constants.ITEM_RESTRICTIONS.LIMITED_U)
		or table.find(itemDetails.ItemRestrictions, Constants.ITEM_RESTRICTIONS.COLLECTIBLE)
	then
		local limitedULabel = limitedULabelTemplate:Clone() :: GuiObject
		limitedULabel.Parent = itemButton
	end

	local function onBuyButtonActivated()
		purchaseRemote:FireServer(itemDetails.Id, productType)
	end

	local function onAddToCartButtonActivated()
		Cart.addItemAsync(itemDetails.Id, productType)
	end

	local function onItemAdded(cartItem: ItemContainer.ContainedItem)
		if cartItem.id == itemDetails.Id and cartItem.type == productType then
			addToCartButton.IconLabel.ImageTransparency = Constants.BUTTON_DISABLED_TRANSPARENCY
		end
	end

	local function onItemRemoved(cartItem: ItemContainer.ContainedItem)
		if cartItem.id == itemDetails.Id and cartItem.type == productType then
			addToCartButton.IconLabel.ImageTransparency = 0
		end
	end

	buyButton.Activated:Connect(onBuyButtonActivated)
	addToCartButton.Activated:Connect(onAddToCartButtonActivated)
	-- Since these connections are being made on objects outside of itemTile, they won't be disconnected
	-- when itemTile is destroyed. To make sure we aren't leaking connections, we save and disconnect them
	-- manually when itemTile is destroyed.
	local itemAddedConnection = Cart.itemAdded:Connect(onItemAdded)
	local itemRemovedConnection = Cart.itemRemoved:Connect(onItemRemoved)

	itemTile.Destroying:Once(function()
		itemAddedConnection:Disconnect()
		itemRemovedConnection:Disconnect()
	end)

	return itemTile
end

return ItemTile
