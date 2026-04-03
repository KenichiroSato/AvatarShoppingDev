--!strict

--[[
	TryOn - This script handles the main Try On UI, creating buttons to represent each of
	the items the player is currently trying on.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local TryOn = require(ReplicatedStorage.TryOn.Libraries.TryOn)
local ItemContainer = require(ReplicatedStorage.TryOn.Utility.ItemContainer)

local TryOnButton = require(ReplicatedStorage.TryOn.UI.Components.TryOnButton)

local player = Players.LocalPlayer :: Player
local playerGui = player.PlayerGui
local shoppingGui = playerGui:WaitForChild("ShoppingGui")
local tryOnFrame = shoppingGui:WaitForChild("TryOnFrame")

local tryOnButtons: { [string]: ImageButton } = {}

local function onItemAdded(item: ItemContainer.ContainedItem)
	-- Make sure we're not making a duplicate button somehow
	if tryOnButtons[item.key] then
		return
	end

	local tryOnButton = TryOnButton(item.id, item.type)
	tryOnButton.Parent = tryOnFrame

	tryOnButtons[item.key] = tryOnButton
end

local function onItemRemoved(item: ItemContainer.ContainedItem)
	if tryOnButtons[item.key] then
		tryOnButtons[item.key]:Destroy()
		tryOnButtons[item.key] = nil
	end
end

local resetToInitialItemsAsync: (() -> ())?  -- will be set in initialize()

local function setupResetButton()
	local resetGui = playerGui:WaitForChild("ResetAvatarGui")
	local button = resetGui:WaitForChild("ResetAvatarButton")

	button.Activated:Connect(function()
		if resetToInitialItemsAsync then
			task.spawn(resetToInitialItemsAsync)
		end
	end)
end

local function initialize()
	TryOn.itemAdded:Connect(onItemAdded)
	TryOn.itemRemoved:Connect(onItemRemoved)

	-- バトル参加中はリセットボタンと試着リストを非表示
	local battleStatusEvent = ReplicatedStorage:WaitForChild("RemoteEvent"):WaitForChild("BattleStatus") :: RemoteEvent
	battleStatusEvent.OnClientEvent:Connect(function(isActive: boolean)
		local resetGui = playerGui:FindFirstChild("ResetAvatarGui") :: ScreenGui?
		if resetGui then
			resetGui.Enabled = not isActive
		end
		tryOnFrame.Visible = not isActive
	end)

	for _, item in TryOn.getItems() do
		onItemAdded(item)
	end

	setupResetButton()
	
	-- Populate TryOn list with initially worn items
	task.spawn(function()
		local SystemDataModule_ = require(ReplicatedFirst.Nexsys.Client.SystemDataModule_)
		SystemDataModule_.WaitUntilSaveDataLoaded()
		local BasePlayerData = require(ReplicatedFirst.Nexsys.Common.BasePlayerData)
		local playerData = BasePlayerData.Get()

		local savedAssets = playerData:GetWornAssets()
		local savedBundles = playerData:GetWornBundles()

		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local description = humanoid:GetAppliedDescription()
		
		local baseAssets = {}
		for _, acc in description:GetAccessories(true) do
			baseAssets[acc.AssetId] = true
		end
		if description.Shirt > 0 then baseAssets[description.Shirt] = true end
		if description.Pants > 0 then baseAssets[description.Pants] = true end
		if description.GraphicTShirt > 0 then baseAssets[description.GraphicTShirt] = true end
		if description.Face > 0 then baseAssets[description.Face] = true end

		-- Build the initial items list for both first load and reset
		local function buildInitialItems(): ({ { id: number, isInitialItem: boolean } }, { number })
			local initialAssets = {}
			local initialBundles = {}
			if #savedAssets > 0 or #savedBundles > 0 then
				for _, assetId in ipairs(savedAssets) do
					local isInitial = baseAssets[assetId] == true
					table.insert(initialAssets, { id = assetId, isInitialItem = isInitial })
				end
				for _, bundleId in ipairs(savedBundles) do
					table.insert(initialBundles, bundleId)
				end
			else
				-- Accessories
				for _, acc in description:GetAccessories(true) do
					table.insert(initialAssets, { id = acc.AssetId, isInitialItem = true })
				end
				-- Clothing & Face
				if description.Shirt > 0 then table.insert(initialAssets, { id = description.Shirt, isInitialItem = true }) end
				if description.Pants > 0 then table.insert(initialAssets, { id = description.Pants, isInitialItem = true }) end
				if description.GraphicTShirt > 0 then table.insert(initialAssets, { id = description.GraphicTShirt, isInitialItem = true }) end
				if description.Face > 0 then table.insert(initialAssets, { id = description.Face, isInitialItem = true }) end
			end
			return initialAssets, initialBundles
		end

		-- Apply initial items on first load
		local initialAssets, initialBundles = buildInitialItems()
		if #initialAssets > 0 then
			TryOn.addItemsBatchAsync(initialAssets)
		end
		for _, bundleId in ipairs(initialBundles) do
			TryOn.addItemAsync(bundleId, Enum.MarketplaceProductType.AvatarBundle)
		end

		-- Set up reset function: clears all items and re-applies the player's
		-- original Roblox avatar (GetAppliedDescription at game start, before savedAssets/savedBundles)
		resetToInitialItemsAsync = function()
			TryOn.setItemsAsync({})
			local resetAssets = {}
			for _, acc in description:GetAccessories(true) do
				table.insert(resetAssets, { id = acc.AssetId, isInitialItem = true })
			end
			if description.Shirt > 0 then table.insert(resetAssets, { id = description.Shirt, isInitialItem = true }) end
			if description.Pants > 0 then table.insert(resetAssets, { id = description.Pants, isInitialItem = true }) end
			if description.GraphicTShirt > 0 then table.insert(resetAssets, { id = description.GraphicTShirt, isInitialItem = true }) end
			if description.Face > 0 then table.insert(resetAssets, { id = description.Face, isInitialItem = true }) end
			if #resetAssets > 0 then
				TryOn.addItemsBatchAsync(resetAssets)
			end
		end
	end)
end

initialize()
