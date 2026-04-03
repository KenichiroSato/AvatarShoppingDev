--!strict

--[[
	ItemButton - This function acts as a simple UI component, implementing a UI button that displays
	an item icon. When clicked, it toggles whether the player is trying on the item or not. This is
	used in the main item tile component, as well as in the cart to allow users to easily try on items.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TryOn = require(ReplicatedStorage.TryOn.Libraries.TryOn)
local ItemContainer = require(ReplicatedStorage.TryOn.Utility.ItemContainer)
local getItemIcon = require(ReplicatedStorage.TryOn.Utility.getItemIcon)

local itemButtonTemplate = ReplicatedStorage.TryOn.UI.Objects.ItemButton

local function ItemButton(itemId: number, itemType: Enum.MarketplaceProductType): ImageButton
	local icon = getItemIcon(itemId, itemType)
	local isTryingOn = TryOn.getItem(itemId, itemType) ~= nil

	local itemButton = itemButtonTemplate:Clone()
	itemButton.Image = icon
	itemButton.TryOnFrame.Visible = isTryingOn

	local function onActivated()
		if TryOn.getItem(itemId, itemType) then
			TryOn.removeItem(itemId, itemType)
		else
			TryOn.addItemAsync(itemId, itemType)
		end
	end

	local function onItemAdded(tryOnItem: ItemContainer.ContainedItem)
		if tryOnItem.id == itemId and tryOnItem.type == itemType then
			itemButton.TryOnFrame.Visible = true
		end
	end

	local function onItemRemoved(tryOnItem: ItemContainer.ContainedItem)
		if tryOnItem.id == itemId and tryOnItem.type == itemType then
			itemButton.TryOnFrame.Visible = false
		end
	end

	itemButton.Activated:Connect(onActivated)
	local itemAddedConnection = TryOn.itemAdded:Connect(onItemAdded)
	local itemRemovedConnection = TryOn.itemRemoved:Connect(onItemRemoved)

	itemButton.Destroying:Once(function()
		itemAddedConnection:Disconnect()
		itemRemovedConnection:Disconnect()
	end)

	return itemButton
end

return ItemButton
