local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ComponentBase = require(ReplicatedFirst.Nexsys.Common.Component.ComponentBase)
local PlayerSaveTable = require(ReplicatedFirst.Nexapp.Common.System.PlayerSaveTable)

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

	-- TextLabel を取得
	local weaponStand = ins:FindFirstChild("WeaponStand")
	if not weaponStand then return end
	local buttonPart = weaponStand:FindFirstChild("ButtonPart")
	if not buttonPart then return end
	local surfaceGui = buttonPart:FindFirstChild("SurfaceGui")
	if not surfaceGui then return end
	local frame = surfaceGui:FindFirstChild("Frame")
	if not frame then return end
	local textLabel = frame:FindFirstChild("TextLabel") :: TextLabel
	if not textLabel then return end

	-- SaveData が読み込まれるまで待つ
	self:WaitForSaveDataLoaded()

	local PlayerData = require(ReplicatedFirst.Nexapp.Common.System.PlayerData)

	local function updateLabel()
		local owned = PlayerData:HasOwnedWand(wandName)
		local selected = PlayerData:GetSelectedWand()
		if not owned then
			textLabel.Text = "Buy"
		elseif selected == wandName then
			textLabel.Text = "Equipped"
		else
			textLabel.Text = "Equip"
		end
	end

	-- 初回更新
	updateLabel()

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
