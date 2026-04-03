--!strict

--[[
	Inspector - This script handles inspecting items on mannequins. A ProximityPrompt is
	created in each mannequin, which when triggered opens up the inspect menu.
--]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.TryOn.Constants)
local ItemDetailsCache = require(ReplicatedStorage.TryOn.Libraries.ItemDetailsCache)
local ModalManager = require(ReplicatedStorage.TryOn.Libraries.ModalManager)
local TryOn = require(ReplicatedStorage.TryOn.Libraries.TryOn)
local stringOfNumbersToArray = require(ReplicatedStorage.TryOn.Utility.stringOfNumbersToArray)

local ResponsiveGrid = require(ReplicatedStorage.TryOn.UI.Components.ResponsiveGrid)
local ItemTile = require(ReplicatedStorage.TryOn.UI.Components.ItemTile)
local CartButton = require(ReplicatedStorage.TryOn.UI.Components.CartButton)
local LoadingDisplay = require(ReplicatedStorage.TryOn.UI.Components.LoadingDisplay)

local player = Players.LocalPlayer :: Player
local playerGui = player.PlayerGui
local shoppingGui = playerGui:WaitForChild("ShoppingGui")
local inspectFrame = shoppingGui:WaitForChild("InspectFrame")
local topBar = inspectFrame:WaitForChild("TopBar")
local closeButton = topBar:WaitForChild("CloseButton")
local tryOnButton = topBar:WaitForChild("TryOnButton")
local buyAllButton = topBar:WaitForChild("BuyAllButton")
local itemsFrame: ScrollingFrame
local loadingDisplay: Frame

local inspectPromptTemplate = script.InspectPrompt

local remotes = ReplicatedStorage.TryOn.Remotes
local bulkPurchaseRemote = remotes.BulkPurchase

local inspectPrompts: { [Instance]: ProximityPrompt } = {}
local inspectingItems: { { id: number, type: Enum.MarketplaceProductType } } = {}
local isLoading = false

local function setLoading(loading: boolean)
	isLoading = loading
	loadingDisplay.Visible = loading
end

local function clearItemTiles()
	for _, child in itemsFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function inspectAsync(mannequin: Instance)
	if isLoading then
		return
	end

	-- Get the bundle and accessory ID strings from the mannequin
	local accessoryIdsString = mannequin:GetAttribute(Constants.ACCESSORY_IDS_ATTRIBUTE)
	local bundleIdsString = mannequin:GetAttribute(Constants.BUNDLE_IDS_ATTRIBUTE)

	-- Convert the accessory and bundle ID strings into arrays
	local accessoryIds = stringOfNumbersToArray(accessoryIdsString)
	--local bundleIds = stringOfNumbersToArray(bundleIdsString)

	-- Update the current inspecting items list
	table.clear(inspectingItems)
	for _, accessoryId in accessoryIds do
		table.insert(inspectingItems, { id = accessoryId, type = Enum.MarketplaceProductType.AvatarAsset })
	end
	--[[
	for _, bundleId in bundleIds do
		table.insert(inspectingItems, { id = bundleId, type = Enum.MarketplaceProductType.AvatarBundle })
	end
	]]

	clearItemTiles()
	ModalManager.push(inspectFrame)
	setLoading(true)

	-- Create tiles for each of the accessories and bundles on the mannequin
	for _, accessoryId in accessoryIds do
		local assetDetails = ItemDetailsCache.getAssetDetailsAsync(accessoryId)
		if not assetDetails then
			continue
		end

		local itemTile = ItemTile(assetDetails)
		itemTile.Parent = itemsFrame
	end
--[[
	for _, bundleId in bundleIds do
		local bundleDetails = ItemDetailsCache.getBundleDetailsAsync(bundleId)
		if not bundleDetails then
			continue
		end

		local itemTile = ItemTile(bundleDetails)
		itemTile.Parent = itemsFrame
	end
]]
	setLoading(false)
end

local function onMannequinAdded(mannequin: Instance)
	local base = mannequin:FindFirstChild("Base")
	assert(base, `{mannequin:GetFullName()} is missing Base`)

	-- Create a new ProximityPrompt in the mannequin, calling the inspect function when it is triggered
	local inspectPrompt = inspectPromptTemplate:Clone() :: ProximityPrompt
	inspectPrompt:AddTag(Constants.INSPECT_PROMPT_TAG)
	inspectPrompt.Parent = base

	inspectPrompt.Triggered:Connect(function(_: Player)
		-- Since this prompt is created locally, we don't need to check which player triggered it
		inspectAsync(mannequin)
	end)

	inspectPrompts[mannequin] = inspectPrompt
end

local function onMannequinRemoved(mannequin: Instance)
	-- Destroy the mannequin's ProximityPrompt
	if inspectPrompts[mannequin] then
		inspectPrompts[mannequin]:Destroy()
		inspectPrompts[mannequin] = nil
	end
end

local function onCloseButtonActivated()
	ModalManager.pop(inspectFrame)
end

local function onTryOnButtonActivated()
	TryOn.setItemsAsync(inspectingItems)
end

local function onBuyAllButtonActivated()
	-- We need to convert the list of items to the format expected by MarketplaceService:PromptBulkPurchase()
	local bulkPurchaseItems = {}
	for _, item in inspectingItems do
		table.insert(bulkPurchaseItems, {
			Id = tostring(item.id),
			Type = item.type,
		})
	end

	-- Since PromptBulkPurchase can't be used on the client, we send the list of items to the server
	bulkPurchaseRemote:FireServer(bulkPurchaseItems)
end

local function initialize()
	closeButton.Activated:Connect(onCloseButtonActivated)
	tryOnButton.Activated:Connect(onTryOnButtonActivated)
	buyAllButton.Activated:Connect(onBuyAllButtonActivated)
	-- Mannequins are all tagged with Constants.MANNEQUIN_TAG, so we can use CollectionService to
	-- easily keep track of them
	CollectionService:GetInstanceAddedSignal(Constants.MANNEQUIN_TAG):Connect(onMannequinAdded)
	CollectionService:GetInstanceRemovedSignal(Constants.MANNEQUIN_TAG):Connect(onMannequinRemoved)

	-- Initialize items frame
	itemsFrame = ResponsiveGrid(Constants.ITEM_TILE_SIZE, Constants.ITEM_TILE_PADDING)
	itemsFrame.LayoutOrder = 1
	itemsFrame.Parent = inspectFrame

	-- Initialize cart button
	local cartButton = CartButton()
	cartButton.LayoutOrder = 3
	cartButton.Parent = topBar

	-- Initialize loading display
	loadingDisplay = LoadingDisplay()
	loadingDisplay.Parent = inspectFrame
	
	for _, mannequin in CollectionService:GetTagged(Constants.MANNEQUIN_TAG) do
		onMannequinAdded(mannequin)
	end
end

initialize()
