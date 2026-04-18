local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ComponentBase = require(ReplicatedFirst.Nexsys.Common.Component.ComponentBase)
local PlayerData = require(ReplicatedFirst.Nexapp.Common.System.PlayerData)

local USE_AVATAR_TICKET_DPO_ID = 3577494456

--- @class TicketShop_ : ComponentBase
local TicketShop_ = {}
TicketShop_.__index = TicketShop_
setmetatable(TicketShop_, ComponentBase)

function TicketShop_.new(...)
	local self = setmetatable(ComponentBase.new(...), TicketShop_)
	TicketShop_.Init(self, ...)
	return self
end

function TicketShop_:Init(ins : Model)
	print("TicketShop Init", ins.Name)
	self:WaitForSaveDataLoaded()

	-- UI要素を取得
	local weaponStand = ins:FindFirstChild("WeaponStand")
	if not weaponStand then return end
	
	-- TicketShopにはRobuxPartのみある想定
	local robuxPart = weaponStand:FindFirstChild("RobuxPart")
	if not robuxPart then return end
	
	local robuxSurfaceGui = robuxPart:FindFirstChildOfClass("SurfaceGui")
	if not robuxSurfaceGui then return end
	
	-- Frame構成が存在するか（WandShopの構造参考）
	local frame = robuxSurfaceGui:FindFirstChild("Frame")
	if frame then
		-- さらに子のFrameがある場合（WandShop側は Frame -> Frame -> RobuxTextLabel の構造）
		local innerFrame = frame:FindFirstChild("Frame")
		local targetFrame = innerFrame or frame
		
		local robuxButton = frame:FindFirstChild("RobuxButton", true) :: GuiButton
		local robuxTextLabel = targetFrame:FindFirstChild("RobuxTextLabel", true) :: TextLabel

		-- RobuxTextLabelに開発者製品のRobux価格を非同期で表示
		if robuxTextLabel then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(USE_AVATAR_TICKET_DPO_ID, Enum.InfoType.Product)
				end)
				if ok and info and info.PriceInRobux then
					robuxTextLabel.Text = tostring(info.PriceInRobux)
				else
					warn("TicketShop_: failed to get product price for id", USE_AVATAR_TICKET_DPO_ID)
				end
			end)
		end

		if robuxButton then
			-- RobuxButton クリックで直接プロンプトを開く
			robuxButton.Activated:Connect(function()
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, USE_AVATAR_TICKET_DPO_ID)
			end)
		end
	else
		-- ルートに直接直置きされている場合
		local robuxButton = robuxSurfaceGui:FindFirstChild("RobuxButton", true) :: GuiButton
		local robuxTextLabel = robuxSurfaceGui:FindFirstChild("RobuxTextLabel", true) :: TextLabel
		
		if robuxTextLabel then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(USE_AVATAR_TICKET_DPO_ID, Enum.InfoType.Product)
				end)
				if ok and info and info.PriceInRobux then
					robuxTextLabel.Text = tostring(info.PriceInRobux)
				end
			end)
		end
		if robuxButton then
			robuxButton.Activated:Connect(function()
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, USE_AVATAR_TICKET_DPO_ID)
			end)
		end
	end
end

function TicketShop_:onTerminate()
end

return TicketShop_
