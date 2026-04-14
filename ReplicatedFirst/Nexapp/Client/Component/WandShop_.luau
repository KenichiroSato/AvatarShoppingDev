local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ComponentBase = require(ReplicatedFirst.Nexsys.Common.Component.ComponentBase)
local PlayerSaveTable = require(ReplicatedFirst.Nexapp.Common.System.PlayerSaveTable)
local WandData = require(ReplicatedFirst.Exdata.WandData)

--- @class WandShop_ : ComponentBase
local WandShop_ = {}
WandShop_.__index = WandShop_
setmetatable(WandShop_, ComponentBase)

----------------------------------------------------------------------------------------------------
function WandShop_.new(...)
	local self = setmetatable(ComponentBase.new(...), WandShop_)
	WandShop_.Init(self, ...)
	return self
end

function WandShop_:Init(ins : Model)
	print("WandShop Init", ins.Name)
	self:WaitForSaveDataLoaded()

	-- WeaponStand以外のModelがWandモデル
	local wandName: string? = nil
	for _, child in ipairs(ins:GetChildren()) do
		if child:IsA("Model") and child.Name ~= "WeaponStand" then
			wandName = child.Name
			break
		end
	end
	if not wandName then
		warn("WandShop_: wand model not found in", ins:GetFullName())
		return
	end

	-- UI要素を取得
	local weaponStand = ins:FindFirstChild("WeaponStand")
	if not weaponStand then return end
	local buttonPart = weaponStand:FindFirstChild("ButtonPart")
	if not buttonPart then return end
	local surfaceGui = buttonPart:FindFirstChild("SurfaceGui")
	if not surfaceGui then return end
	local frame = surfaceGui:FindFirstChild("Frame")
	if not frame then return end
	local textLabel = frame:FindFirstChild("GemTextLabel", true) :: TextLabel
	if not textLabel then return end
	local gemImageLabel = frame:FindFirstChild("GemImageLabel", true) :: ImageLabel
	local buyButton = frame:FindFirstChild("BuyButton") :: GuiButton
	if not buyButton then return end

	-- RobuxPart UI要素を取得
	local robuxPart = weaponStand:FindFirstChild("RobuxPart")
	local robuxSurfaceGui = robuxPart and robuxPart:FindFirstChildOfClass("SurfaceGui")
	local robuxButton = robuxPart and robuxPart:FindFirstChild("RobuxButton", true) :: GuiButton

	-- SaveData が読み込まれるまで待つ
	self:WaitForSaveDataLoaded()

	local PlayerData = require(ReplicatedFirst.Nexapp.Common.System.PlayerData)

	-- WandDataからGemPriceを取得
	local gemPrice: number? = nil
	for _, d in pairs(WandData) do
		if d.Name == wandName then
			gemPrice = d.GemPrice
			break
		end
	end

	local defaultLabelSize = textLabel.Size

	local function updateLabel()
		local owned = PlayerData:HasOwnedWand(wandName)
		local selected = PlayerData:GetSelectedWand()
		if not owned then
			textLabel.Text = gemPrice and tostring(gemPrice) or "Buy"
			textLabel.Size = defaultLabelSize
			if gemImageLabel then gemImageLabel.Visible = true end
			-- 未所持時はRobuxボタンを表示
			if robuxSurfaceGui then robuxSurfaceGui.Enabled = true end
		elseif selected == wandName then
			textLabel.Text = "Equipped"
			textLabel.Size = UDim2.new(0.9, 0, 1, 0)
			if gemImageLabel then gemImageLabel.Visible = false end
			-- 所持済み時はRobuxボタンを非表示
			if robuxSurfaceGui then robuxSurfaceGui.Enabled = false end
		else
			textLabel.Text = "Equip"
			textLabel.Size = UDim2.new(0.9, 0, 1, 0)
			if gemImageLabel then gemImageLabel.Visible = false end
			-- 所持済み時はRobuxボタンを非表示
			if robuxSurfaceGui then robuxSurfaceGui.Enabled = false end
		end
	end

	-- 初回更新
	updateLabel()

	-- BuyButton クリックでサーバーに購入リクエスト（Gem購入）
	buyButton.Activated:Connect(function()
		self:SendRemoteEventToServer("RCS_BuyWand", wandName)
	end)

	-- RobuxButton クリックでサーバーにRobux購入リクエスト
	if robuxButton then
		robuxButton.Activated:Connect(function()
			self:SendRemoteEventToServer("RCS_BuyWandRobux", wandName)
		end)
	end

	-- OwnedWands / SelectedWand の変化を監視
	self._ownedWandsCallback = PlayerData:ListenToSaveDataParam1Changed(
		PlayerSaveTable.Keys.OwnedWands,
		function() updateLabel() end
	)
	self._selectedWandCallback = PlayerData:ListenToSaveDataParam1Changed(
		PlayerSaveTable.Keys.SelectedWand,
		function() updateLabel() end
	)

	self._playerData = PlayerData
end

function WandShop_:onTerminate()
	if self._playerData then
		if self._ownedWandsCallback then
			self._playerData:UnlistenToSaveDataParam1Changed(PlayerSaveTable.Keys.OwnedWands, self._ownedWandsCallback)
		end
		if self._selectedWandCallback then
			self._playerData:UnlistenToSaveDataParam1Changed(PlayerSaveTable.Keys.SelectedWand, self._selectedWandCallback)
		end
	end
end

----------------------------------------------------------------------------------------------------

return WandShop_
