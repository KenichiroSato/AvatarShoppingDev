local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ComponentBase = require(ReplicatedFirst.Nexsys.Common.Component.ComponentBase)
local RemoteSender_ = require(ReplicatedFirst.Nexsys.Client.RemoteSender_)
local LocalizeModule_ = require(ReplicatedFirst.Nexsys.Client.LocalizeModule_)
local SoundManager_ = require(ReplicatedFirst.Nexsys.Client.SoundManager_)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.TryOn.Constants)
local TryOn = require(ReplicatedStorage.TryOn.Libraries.TryOn)
--- @class TryOn_ : ComponentBase
local TryOn_ = {}
TryOn_.__index = TryOn_
setmetatable(TryOn_, ComponentBase)

----------------------------------------------------------------------------------------------------
local function CreateKeyList(keystring: string): {number}
	--print("keystring=", keystring)
	--return {tonumber(keystring)}
	local list: {number} = {}

	-- string.splitはカンマがなくても、文字列全体を1つの要素として返します
	local splitItems = string.split(keystring, ",")

	for _, item in ipairs(splitItems) do
		-- 前後の空白を除去（" 123 " -> "123"）
		local cleanItem = string.gsub(item, "^%s*(.-)%s*$", "%1")

		-- 数値に変換
		local num = tonumber(cleanItem)

		-- 数値変換に成功した場合のみ追加
		if num then
			table.insert(list, num)
		end
	end

	return list
end
----------------------------------------------------------------------------------------------------
function TryOn_.new(...)
	local self = setmetatable(ComponentBase.new(...), TryOn_)
	TryOn_.Init(self, ...)
	return self
end

function TryOn_:Init(ins : Model)
	task.wait(1)
	
	-- FukidashiPartのクローンと配置
	local cloneFolder = ReplicatedStorage:WaitForChild("Clone")
	local fukidashiPartTemplate = cloneFolder:WaitForChild("FukidashiPart")
	local fukidashiPart = fukidashiPartTemplate:Clone()
	local insCFrame, insSize = ins:GetBoundingBox()
	local yOffset = (insSize.Y / 2) + (fukidashiPart.Size.Y / 2) + 1
	fukidashiPart.CFrame = insCFrame * CFrame.new(0, yOffset, 0)

	fukidashiPart.Parent = ins
	self._fukidashiPart = fukidashiPart
	
	local keystring = ins:GetAttribute(Constants.ACCESSORY_IDS_ATTRIBUTE) or ""
	local assetKeys = CreateKeyList(keystring)
	
	local bundleKeystring = ins:GetAttribute(Constants.BUNDLE_IDS_ATTRIBUTE) or ""
	local bundleKeys = CreateKeyList(bundleKeystring)

	-- ボタンの入力処理 (複数配置対応)
	for _, desc in ipairs(fukidashiPart:GetDescendants()) do
		if desc:IsA("GuiButton") then
			if desc.Name == "TryOnButton" then
				desc.Activated:Connect(function()
					if self._cooldownTry then
						return
					end
					self._cooldownTry = true
					task.delay(1, function()
						self._cooldownTry = false
					end)
					SoundManager_.PlaySEByName("ClickOK")
					RemoteSender_.SendEvent("ApplyTryOn", assetKeys, bundleKeys) 
					for _, assetId in assetKeys do
						TryOn.addItemAsync(assetId, Enum.MarketplaceProductType.AvatarAsset)
					end
					for _, bundleId in bundleKeys do
						TryOn.addItemAsync(bundleId, Enum.MarketplaceProductType.AvatarBundle)
					end
				end)
			elseif desc.Name == "BuyButton" then
				desc.Activated:Connect(function()
					if self._cooldownBuy then
						return
					end
					self._cooldownBuy = true
					task.delay(1, function()
						self._cooldownBuy = false
					end)
					SoundManager_.PlaySEByName("ClickOK")
					RemoteSender_.SendEvent("BulkPurchase", assetKeys, bundleKeys) 
				end)
			end
		end
	end

	-- イベント接続後に、ShopTeleporterなどPlayerGuiにある他のUIと重なった際に
	-- クリックを正しく手前で判定させるため、PlayerGuiに移動
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		local playerGui = localPlayer:WaitForChild("PlayerGui")
		for _, child in fukidashiPart:GetChildren() do
			if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
				child.Adornee = fukidashiPart
				child.Parent = playerGui
				
				-- 親(Part)が破棄されたらPlayerGuiに逃がしたGUIも破棄する
				fukidashiPart.AncestryChanged:Connect(function(_, newParent)
					if not newParent then
						child:Destroy()
					end
				end)
			end
		end
	end
end

function TryOn_:onTerminate()
	if self._fukidashiPart then
		self._fukidashiPart:Destroy()
		self._fukidashiPart = nil
	end
end


----------------------------------------------------------------------------------------------------

return TryOn_