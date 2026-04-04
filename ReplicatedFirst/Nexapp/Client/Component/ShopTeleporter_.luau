local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local ComponentBase = require(ReplicatedFirst.Nexsys.Common.Component.ComponentBase)

local player = Players.LocalPlayer

--- @class ShopTeleporter_ : ComponentBase
local ShopTeleporter_ = {}
ShopTeleporter_.__index = ShopTeleporter_
setmetatable(ShopTeleporter_, ComponentBase)

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

	-- 真正面から写すため、距離係数を2.0程度に増やして引き気味に
	local distance: number = (maxDim / 2) / math.tan(fov / 2) * 1.0
	print(cloned.Name .. " distance=", distance)
	
	-- modelにdistance属性があればそれを使用する
	local attr = cloned:GetAttribute("distance")
	if type(attr) == "number" then
		distance = attr
	end

	-- CFrameの正面(LookVector)を利用して、モデルの中心から正面方向にカメラを配置
	-- cf.LookVectorはBoundingBoxの向き。モデル自体の向きを使いたい場合はcloned:GetPivot().LookVector もあり得る。
	vpCamera.CFrame = CFrame.lookAt(
		centerPos + (cf.LookVector * distance),
		centerPos -- ターゲットをPivotの中心座標に設定
	)
end

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
function ShopTeleporter_.new(...)
	local self = setmetatable(ComponentBase.new(...), ShopTeleporter_)
	ShopTeleporter_.Init(self, ...)
	return self
end

function ShopTeleporter_:Init(ins : Folder)
	print("ShopTeleporter_.Init", ins.Name)
	self:WaitForSaveDataLoaded()
	task.wait(1)

	
	local floor = ins:FindFirstChild("Floor", true) :: BasePart
	local roof = ins:FindFirstChild("Roof") :: Model
	
	if not floor or not roof then
		warn("ShopTeleporter_: Missing Floor or Roof in", ins.Name)
		return
	end
	
	-- BillboardPartの作成と配置
	local billboardModel = Instance.new("Model")
	billboardModel.Name = "BillboardModel"
	billboardModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	billboardModel.Parent = ins

	local billboardPart = Instance.new("Part")
	billboardPart.Name = "BillboardPart"
	billboardPart.Size = Vector3.new(15, 15, 2) -- GUIと近いサイズにする
	billboardPart.Anchored = true
	billboardPart.CanCollide = false
	billboardPart.Transparency = 1
	-- Floorの上空50スタッドに配置
	billboardPart.Position = floor.Position + Vector3.new(0, 50, 0)
	billboardPart.Parent = billboardModel
	
	-- テレポート処理共通関数
	local function doTeleport()
		print("ShopTeleporter Teleported!", ins.Name)
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
			if hrp then
				-- 円の正面外側にテレポート（LookVectorで正面方向へオフセット）
				local forward = floor.CFrame.LookVector
				local radius = floor.Size.Z / 2
				local destPos = floor.Position + forward * (radius + 5) + Vector3.new(0, 3, 0)
				-- 円の中心を向かせる
				hrp.CFrame = CFrame.lookAt(destPos, floor.Position + Vector3.new(0, destPos.Y - floor.Position.Y, 0))
				local CameraManager_ = require(ReplicatedFirst.Nexsys.Client.CameraManager_)
				CameraManager_.AlignCameraToCharacter(char)
			end
		end
	end


	-- BillboardGuiの設定
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "ShopBillboard_" .. ins.Name
	-- スケールを使用して距離に応じて小さくなるように設定（15x15スタッド）
	local size = 40
	billboardGui.Size = UDim2.new(size, 0, size, 0)
	billboardGui.StudsOffset = Vector3.new(0, 0, 0)
	billboardGui.AlwaysOnTop = false -- =trueにするとRaycastがすり抜けてクリックできない場合があります
	billboardGui.LightInfluence = 0
	billboardGui.ResetOnSpawn = false -- リセット時に消えないようにする
	billboardGui.Active = true -- これがないと内部のボタンがクリック判定を吸ってくれない場合があります
	billboardGui.MaxDistance = 1000 -- クリック可能距離を制限or拡張
	-- Clickを反応させるため、ParentをPlayerGuiに設定し、AdorneeをbillboardPartに向ける
	billboardGui.Adornee = billboardPart
	billboardGui.Parent = player:WaitForChild("PlayerGui")
	
	-- 背景とボタンの作成
	local itemButton = Instance.new("TextButton")
	itemButton.Name = "TeleportButton"
	itemButton.Size = UDim2.new(1, 0, 1, 0)
	itemButton.BackgroundColor3 = Color3.fromRGB(40, 64, 242)
	itemButton.BackgroundTransparency = 0
	itemButton.BorderSizePixel = 0
	itemButton.Text = ""
	itemButton.AutoButtonColor = false
	itemButton.Active = true
	itemButton.ZIndex = 2
	itemButton.Parent = billboardGui

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
	vp.Size = UDim2.new(0.92, 0, 0.72, 0)
	vp.Position = UDim2.new(0.04, 0, 0.24, 0)
	vp.BackgroundColor3 = Color3.fromRGB(30, 33, 58)
	vp.BackgroundTransparency = 1
	vp.BorderSizePixel = 0
	vp.LightColor = Color3.fromRGB(220, 220, 255)
	vp.Ambient = Color3.fromRGB(180, 180, 220)
	vp.ZIndex = 3
	vp.Parent = itemButton

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 8)
	vpCorner.Parent = vp

	cloneModelToViewport(roof, vp)

	-- Shop name label
	local label = Instance.new("TextLabel")
	label.Name = "ShopLabel"
	label.Size = UDim2.new(0.92, 0, 0.20, 0)
	label.Position = UDim2.new(0.04, 0, 0.04, 0)
	label.BackgroundTransparency = 1
	label.Text = ins.Name
	label.TextColor3 = Color3.fromRGB(220, 225, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = 3
	label.Parent = itemButton

	-- Bottom right icon
	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "TeleportIcon"
	iconImage.Size = UDim2.new(0.35, 0, 0.35, 0)
	iconImage.Position = UDim2.new(0.96, 0, 0.96, 0)
	iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
	iconImage.BackgroundTransparency = 1
	iconImage.Image = "rbxassetid://124095905428296"
	iconImage.ZIndex = 4
	iconImage.Parent = itemButton

	-- Hover effects
	itemButton.MouseEnter:Connect(function()
		stroke.Color = Color3.fromRGB(120, 150, 255)
		stroke.Thickness = 2
		itemButton.BackgroundColor3 = Color3.fromRGB(35, 40, 75)
	end)
	itemButton.MouseLeave:Connect(function()
		stroke.Color = Color3.fromRGB(60, 70, 120)
		stroke.Thickness = 1.5
		itemButton.BackgroundColor3 = Color3.fromRGB(40, 64, 242)
	end)

	-- Teleport on click (GUIボタン経由)
	itemButton.Activated:Connect(doTeleport)

	-- バトル参加の状況に応じて非表示にする
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
	local updateEvent = remoteEventFolder:WaitForChild("BattlePhaseUpdate")
	if updateEvent and updateEvent:IsA("RemoteEvent") then
		updateEvent.OnClientEvent:Connect(function(phase)
			if phase == "Transitioning" or phase == "TeamSelection" or phase == "Countdown" or phase == "Active" then
				billboardGui.Enabled = false
			elseif phase == "Preparing" or phase == "Idle" or phase == "Ending" then
				billboardGui.Enabled = true
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------

return ShopTeleporter_