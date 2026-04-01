--!strict
-- ShopListGui_: Nexapp UIシステムに準拠したショップリストGUIモジュール
-- Workspace.Shopsの各フォルダのRoofをViewportFrameで表示し、Partにテレポートするボタンリスト

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")

local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)

local player = Players.LocalPlayer
local shopsFolder = workspace:WaitForChild("Shops")

--- @class ShopListGui_ : BaseGui_
local ShopListGui_ = {}
ShopListGui_.__index = ShopListGui_
setmetatable(ShopListGui_, BaseGui_)
ShopListGui_.instance = nil

-- Constants
local ITEM_SIZE = 60
local ITEM_PADDING = 4
local BAR_HEIGHT = ITEM_SIZE + 30

----------------------------------------------------------------------------------------------------
-- Helper: clone a model into a ViewportFrame
local function cloneModelToViewport(model: Model, viewportFrame: ViewportFrame)
	local vpCamera = Instance.new("Camera")
	vpCamera.Parent = viewportFrame
	viewportFrame.CurrentCamera = vpCamera

	local cloned = model:Clone()
	cloned.Parent = viewportFrame

	-- BoundingBoxから全体のサイズを取得
	local cf, size = cloned:GetBoundingBox()
	
	-- 位置はBoundingBoxの中心ではなく、Pivot（PrimaryPart等）の中心を基準にする
	local centerPos = cloned:GetPivot().Position

	local maxDim = math.max(size.X, size.Y, size.Z)
	if maxDim == 0 then maxDim = 1 end
	local fov = math.rad(vpCamera.FieldOfView)
	
	-- 真正面から写すため、距離係数を1.5 -> 2.0程度に増やして引き気味に
	local distance: number = (maxDim / 2) / math.tan(fov / 2) * 2.0
	
	-- modelにdistance属性があればそれを使用する
	local attr = cloned:GetAttribute("distance")
	if type(attr) == "number" then
		distance = attr
	end

	-- CFrameの正面(LookVector)を利用して、モデルの中心から正面方向にカメラを配置
	vpCamera.CFrame = CFrame.lookAt(
		centerPos + (cf.LookVector * distance),
		centerPos -- ターゲットをPivotの中心座標に設定
	)
end

-- Helper: shop name → alphabetical LayoutOrder (先頭4文字のバイト値で算出)
local function nameToOrder(name: string): number
	local order = 0
	for i = 1, math.min(#name, 4) do
		order = order * 256 + string.byte(name, i)
	end
	return order
end

----------------------------------------------------------------------------------------------------
-- Helper: create one shop item button
local function createShopItem(scrollFrame: Frame, shopFolder: Folder, _index: number)
	local roofModel = shopFolder:FindFirstChild("Roof") :: Model
	local teleportPart = shopFolder:FindFirstChild("Floor") :: BasePart
	if not roofModel or not teleportPart then return end

	-- Outer button
	local itemButton = Instance.new("TextButton")
	itemButton.Name = shopFolder.Name .. "_Item"
	itemButton.Size = UDim2.new(0, ITEM_SIZE, 1, -16)
	itemButton.BackgroundColor3 = Color3.fromRGB(25, 28, 50)
	itemButton.BackgroundTransparency = 0.1
	itemButton.BorderSizePixel = 0
	itemButton.Text = ""
	itemButton.LayoutOrder = nameToOrder(shopFolder.Name)
	itemButton.AutoButtonColor = false
	itemButton.Parent = scrollFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = itemButton

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(60, 70, 120)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = itemButton

	-- ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Viewport"
	vp.Size = UDim2.new(1, -4, 0, ITEM_SIZE - 4)
	vp.Position = UDim2.new(0, 2, 0, 2)
	vp.BackgroundColor3 = Color3.fromRGB(30, 33, 58)
	vp.BackgroundTransparency = 0
	vp.BorderSizePixel = 0
	vp.LightColor = Color3.fromRGB(220, 220, 255)
	vp.Ambient = Color3.fromRGB(180, 180, 220)
	vp.Parent = itemButton

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 8)
	vpCorner.Parent = vp

	cloneModelToViewport(roofModel, vp)

	-- Shop name label
	local label = Instance.new("TextLabel")
	label.Name = "ShopLabel"
	label.Size = UDim2.new(1, -4, 0, 20)
	label.Position = UDim2.new(0, 2, 0, ITEM_SIZE - 2)
	label.BackgroundTransparency = 1
	label.Text = shopFolder.Name
	label.TextColor3 = Color3.fromRGB(220, 225, 255)
	label.TextSize = 9
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = itemButton

	-- Hover effects
	itemButton.MouseEnter:Connect(function()
		stroke.Color = Color3.fromRGB(120, 150, 255)
		stroke.Thickness = 2
		itemButton.BackgroundColor3 = Color3.fromRGB(35, 40, 75)
	end)
	itemButton.MouseLeave:Connect(function()
		stroke.Color = Color3.fromRGB(60, 70, 120)
		stroke.Thickness = 1.5
		itemButton.BackgroundColor3 = Color3.fromRGB(25, 28, 50)
	end)

	-- Teleport on click
	itemButton.Activated:Connect(function()
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
			if hrp then
				-- 円の正面外側にテレポート（LookVectorで正面方向へオフセット）
				local forward = teleportPart.CFrame.LookVector
				local radius = teleportPart.Size.Z / 2
				local destPos = teleportPart.Position + forward * (radius + 5) + Vector3.new(0, 3, 0)
				-- 円の中心を向かせる
				hrp.CFrame = CFrame.lookAt(destPos, teleportPart.Position + Vector3.new(0, destPos.Y - teleportPart.Position.Y, 0))
				local CameraManager_ = require(ReplicatedFirst.Nexsys.Client.CameraManager_)
				CameraManager_.AlignCameraToCharacter(Players.LocalPlayer.Character)
			end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Build UI: create TopBar and shop items inside the ScreenGui
local function buildUI(gui: ScreenGui)
	-- Top bar frame
	local topFrame = Instance.new("Frame")
	topFrame.Name = "TopBar"
	topFrame.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
	topFrame.Position = UDim2.new(0, 0, 0, 0)
	topFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	topFrame.BackgroundTransparency = 1
	topFrame.BorderSizePixel = 0
	topFrame.Parent = gui

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 20)),
	})
	gradient.Parent = topFrame

	local borderLine = Instance.new("Frame")
	borderLine.Name = "BorderLine"
	borderLine.Size = UDim2.new(1, 0, 0, 2)
	borderLine.Position = UDim2.new(0, 0, 1, -2)
	borderLine.BackgroundTransparency = 1
	borderLine.BorderSizePixel = 0
	borderLine.Parent = topFrame

	-- Center frame for centered layout
	local scrollFrame = Instance.new("Frame")
	scrollFrame.Name = "ScrollFrame"
	scrollFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollFrame.Position = UDim2.new(0, 0, 0, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.Parent = topFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, ITEM_PADDING)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Parent = scrollFrame

	-- アイテム追加の共通処理
	local addedNames: {[string]: boolean} = {}
	local itemIndex = 0

	local function tryAddShop(shop: Instance)
		if not shop:IsA("Folder") then return end
		if addedNames[shop.Name] then return end  -- 重複防止
		addedNames[shop.Name] = true
		itemIndex += 1
		createShopItem(scrollFrame, shop :: Folder, itemIndex)
	end

	-- 既にロード済みの子を処理
	for _, shop in ipairs(shopsFolder:GetChildren()) do
		tryAddShop(shop)
	end

	-- ストリーミングで後から届く子を動的に追加
	shopsFolder.ChildAdded:Connect(function(shop)
		tryAddShop(shop)
	end)

	-- (centering handled by UIListLayout HorizontalAlignment)
end

----------------------------------------------------------------------------------------------------
-- Private Init
local function Init(self: any, gui: ScreenGui)
	print("ShopListGui_ Init")
	self:WaitForSaveDataLoaded()
	task.wait(1)
	buildUI(gui)
	print("ShopListGui_ Init done")
end

----------------------------------------------------------------------------------------------------
-- GetInstance
function ShopListGui_.GetInstance()
	return ShopListGui_.instance
end

----------------------------------------------------------------------------------------------------
-- constructor
function ShopListGui_.new(...: any)
	local self = setmetatable(BaseGui_.new(...), ShopListGui_)
	Init(self, ...)
	ShopListGui_.instance = self
	return self
end

return ShopListGui_
