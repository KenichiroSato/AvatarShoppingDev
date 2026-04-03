--!strict

--[[
	Shop - This is the main shop display script, implementing searching and filtering item categories.
	Items are searched using AvatarEditorService:SearchCatalog(), with the creator name automatically
	set to the place creator's name. This allows the shop to be auto-populated with the place creator's
	items.
--]]

local AvatarEditorService = game:GetService("AvatarEditorService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.TryOn.Constants)
local Settings = require(ReplicatedStorage.TryOn.Settings)
local Types = require(ReplicatedStorage.TryOn.Utility.Types)
local Cart = require(ReplicatedStorage.TryOn.Libraries.Cart)
local ModalManager = require(ReplicatedStorage.TryOn.Libraries.ModalManager)
local RestrictedItems = require(ReplicatedStorage.TryOn.Libraries.RestrictedItems)
local ItemFilters = require(script.ItemFilters)
local SortingFilters = require(script.SortingFilters)
local ingestCatalogPage = require(script.ingestCatalogPage)
local disconnectAndClear = require(ReplicatedStorage.TryOn.Utility.disconnectAndClear)
local getCreatorNameAsync = require(ReplicatedStorage.TryOn.Utility.getCreatorNameAsync)

local ItemTile = require(ReplicatedStorage.TryOn.UI.Components.ItemTile)
local DropdownButton = require(ReplicatedStorage.TryOn.UI.Components.DropdownButton)
local ResponsiveGrid = require(ReplicatedStorage.TryOn.UI.Components.ResponsiveGrid)
local CartButton = require(ReplicatedStorage.TryOn.UI.Components.CartButton)
local LoadingDisplay = require(ReplicatedStorage.TryOn.UI.Components.LoadingDisplay)

local player = Players.LocalPlayer :: Player
local playerGui = player.PlayerGui
local shoppingGui = playerGui:WaitForChild("ShoppingGui")
local shopFrame = shoppingGui:WaitForChild("ShopFrame")
local topBar = shopFrame:WaitForChild("TopBar")
local searchFrame = topBar:WaitForChild("SearchFrame")
local searchBox = searchFrame:WaitForChild("SearchBox")
local closeButton = topBar:WaitForChild("CloseButton")
local shopButton = shoppingGui:WaitForChild("ShopButton")
local countLabel = shopButton:WaitForChild("CountLabel")
local itemFilterDropdown: GuiButton
local sortingFilterDropdown: GuiButton
local itemsFrame: ScrollingFrame
local loadingDisplay: Frame

local creatorName = Settings.DEFAULT_CREATOR_NAME
local searchParams = CatalogSearchParams.new()
local connections: { RBXScriptConnection } = {}
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

-- Clear all item tiles and create new ones for the items in the specified page
local function displayPage(catalogPage: Types.CatalogPage)
	for _, itemDetails in catalogPage do
		local itemType = Enum.MarketplaceProductType[`Avatar{itemDetails.ItemType}`]
		if RestrictedItems.isRestricted(itemDetails.Id, itemType) then
			continue
		end

		local itemTile = ItemTile(itemDetails)
		itemTile.Parent = itemsFrame
	end
end

local function shouldLoadNextPage(): boolean
	local bottomPosition = itemsFrame.AbsoluteWindowSize.Y * (2 - Constants.SCROLL_LOAD_FACTOR)
		+ itemsFrame.CanvasPosition.Y
	return bottomPosition >= itemsFrame.AbsoluteCanvasSize.Y
end

local function displayPagesAsync(catalogPages: CatalogPages)
	-- Clear the current item tiles and disconnect current connections
	clearItemTiles()
	disconnectAndClear(connections)

	-- Scroll back to the top
	itemsFrame.CanvasPosition = Vector2.zero

	-- Load the first page and add it to the page cache
	local firstPage = catalogPages:GetCurrentPage() :: Types.CatalogPage

	local function loadNextPageAsync()
		-- Don't increment the page if we're currently loading another one
		if isLoading then
			return
		end

		if catalogPages.IsFinished then
			return
		end

		setLoading(true)
		catalogPages:AdvanceToNextPageAsync()
		setLoading(false)

		-- Add all item details in the page to the item details cache
		local page = catalogPages:GetCurrentPage()
		ingestCatalogPage(page)
		displayPage(page)
	end

	table.insert(
		connections,
		itemsFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if shouldLoadNextPage() then
				loadNextPageAsync()
			end
		end)
	)

	ingestCatalogPage(firstPage)
	displayPage(firstPage)

	while shouldLoadNextPage() and not catalogPages.IsFinished do
		loadNextPageAsync()
	end
end

local function searchAsync()
	-- Don't perform a search if we're currently searching/paging
	if isLoading then
		return
	end

	-- Perform the search using our search parameters
	setLoading(true)
	local catalogPages = AvatarEditorService:SearchCatalog(searchParams)
	setLoading(false)

	-- Display the returned pages
	displayPagesAsync(catalogPages)
end

local function onSearchBoxFocused()
	itemFilterDropdown.Visible = false
	sortingFilterDropdown.Visible = false
end

local function onSearchBoxFocusLost(enterPressed: boolean)
	itemFilterDropdown.Visible = true
	sortingFilterDropdown.Visible = true

	-- Update the search term, then perform a search if enter was pressed
	searchParams.SearchKeyword = searchBox.Text

	if enterPressed then
		searchAsync()
	end
end

local function onItemFilterChanged(filterName: string)
	-- Update the filtered asset/bundle types and then perform a search
	local filter = ItemFilters.filters[filterName]
	searchParams.AssetTypes = filter.assets
	searchParams.BundleTypes = filter.bundles

	searchAsync()
end

local function onSortingFilterChangedAsync(filterName: string)
	local filter = SortingFilters.filters[filterName]
	searchParams.SortType = filter

	searchAsync()
end

local function toggleShop()
	local isCurrentModal = ModalManager.getModal() == shopFrame

	if isCurrentModal then
		ModalManager.pop(shopFrame)
	else
		ModalManager.push(shopFrame)
	end
end

local function updateCount()
	local count = #Cart.getItems()
	countLabel.Text = tostring(count)
	countLabel.Visible = count > 0
end

local function onInputBegan(inputObject: InputObject, processed: boolean)
	if processed then
		return
	end

	if inputObject.KeyCode == Settings.SHOP_GAMEPAD_KEY_CODE then
		toggleShop()
	end
end

local function initialize()
	shopButton.Activated:Connect(toggleShop)
	closeButton.Activated:Connect(toggleShop)
	searchBox.Focused:Connect(onSearchBoxFocused)
	searchBox.FocusLost:Connect(onSearchBoxFocusLost)
	Cart.itemAdded:Connect(updateCount)
	Cart.itemRemoved:Connect(updateCount)
	UserInputService.InputBegan:Connect(onInputBegan)

	-- Initialize items frame
	itemsFrame = ResponsiveGrid(Constants.ITEM_TILE_SIZE, Constants.ITEM_TILE_PADDING)
	itemsFrame.LayoutOrder = 1
	itemsFrame.Parent = shopFrame

	-- Initialize filters dropdown
	local initialItemFilter = ItemFilters.list[1]
	itemFilterDropdown = DropdownButton(ItemFilters.list, initialItemFilter, onItemFilterChanged)
	itemFilterDropdown.LayoutOrder = 1
	itemFilterDropdown.Parent = topBar

	-- Initialize sorting dropdown
	local initialSortingFilter = SortingFilters.list[1]
	sortingFilterDropdown = DropdownButton(SortingFilters.list, initialSortingFilter, onSortingFilterChangedAsync)
	sortingFilterDropdown.LayoutOrder = 2
	sortingFilterDropdown.Parent = topBar

	-- Initialize cart button
	local cartButton = CartButton()
	cartButton.LayoutOrder = 3
	cartButton.Parent = topBar

	-- Initialize loading display
	loadingDisplay = LoadingDisplay()
	loadingDisplay.Parent = shopFrame

	-- Get place creator name
	if Settings.FETCH_CREATOR_NAME and game.CreatorId ~= 0 then
		local name = getCreatorNameAsync()
		if name then
			creatorName = name
		else
			warn(`Failed to get creator name, loading items from default creator: {creatorName}`)
		end
	else
		warn(`Place is not published, loading items from default creator: {creatorName}`)
	end

	-- Initialize search params
	searchParams.CreatorName = creatorName
	searchParams.Limit = Constants.PAGE_SIZE
	searchParams.IncludeOffSale = false
	searchParams.AssetTypes = ItemFilters.filters[initialItemFilter].assets
	searchParams.BundleTypes = ItemFilters.filters[initialItemFilter].bundles
	searchParams.SortType = SortingFilters.filters[initialSortingFilter]

	updateCount()

	-- Do initial search
	searchAsync()
end

initialize()
