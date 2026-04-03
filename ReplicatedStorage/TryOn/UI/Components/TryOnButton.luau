--!strict

--[[
	TryOnButton - This function acts as a simple UI component, implementing the Try On button
	which as displayed for each of the items the player is currently trying on.

	When activated, an ActionsMenu component is created, allowing the player to take the item
	off, buy it, or add it to their cart.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cart = require(ReplicatedStorage.TryOn.Libraries.Cart)
local TryOn = require(ReplicatedStorage.TryOn.Libraries.TryOn)
local getItemIcon = require(ReplicatedStorage.TryOn.Utility.getItemIcon)

local ActionsMenu = require(ReplicatedStorage.TryOn.UI.Components.ActionsMenu)

local player = Players.LocalPlayer :: Player
local playerGui = player.PlayerGui
local remotes = ReplicatedStorage.TryOn.Remotes
local purchaseRemote = remotes.Purchase

local tryOnButtonTemplate = ReplicatedStorage.TryOn.UI.Objects.TryOnButton

local function TryOnButton(itemId: number, itemType: Enum.MarketplaceProductType): ImageButton
	local icon = getItemIcon(itemId, itemType)

	local tryOnButton = tryOnButtonTemplate:Clone()
	tryOnButton.Image = icon

	local function onActivated()
		-- We only want to show purchase options if the item is not an initially worn item
		local itemData = TryOn.getItem(itemId, itemType)
		local isInitialItem = itemData and itemData.data and itemData.data.isInitialItem

		-- These are the default actions to take with an item
		local actions = {
			{
				name = "Take off",
				callback = function()
					TryOn.removeItem(itemId, itemType)
				end,
			}
		}

		if not isInitialItem then
			table.insert(actions, {
				name = "Buy",
				callback = function()
					purchaseRemote:FireServer(itemId, itemType)
				end,
			})
			--[[
			-- If the item isn't in the cart, we'll add another action to add it
			local isInCart = Cart.getItem(itemId, itemType) ~= nil
			if not isInCart then
				table.insert(actions, {
					name = "Add to cart",
					callback = function()
						Cart.addItemAsync(itemId, itemType)
					end,
				})
			end
			]]
		end

		-- Create a new ActionsMenu component with our list of actions
		local actionsMenu = ActionsMenu(tryOnButton, actions)
		actionsMenu.Parent = playerGui
	end

	tryOnButton.Activated:Connect(onActivated)

	return tryOnButton
end

return TryOnButton
