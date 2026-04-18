local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerManager = require(ServerScriptService.Nexapp.Player.PlayerManager)

local ProductPurchaseManager = {}

local CHOOSE_AVATAR_TICKET_DPO_ID = 3577494456

function ProductPurchaseManager.ProcessReceipt(receiptInfo)
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	
	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		-- プレイヤーが退室してしまった場合は保留にする
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	local gp = PlayerManager.GetGamePlayer(player)
	if not gp then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- チケット購入
	if productId == CHOOSE_AVATAR_TICKET_DPO_ID then
		local pd = gp:GetPlayerData()
		if pd then
			local currentTickets = pd:GetChooseAvatarTicket()
			pd:SetChooseAvatarTicket(currentTickets + 1)
			print("ProductPurchaseManager: Player " .. player.Name .. " bought ChooseAvatarTicket. Now has: " .. tostring(currentTickets + 1))
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	warn("ProductPurchaseManager: Unknown product ID or failed to grant: " .. tostring(productId))
	-- 不明な製品等はそのまま未処理として扱うか、処理済みにするかは運用次第だが、一旦NotProcessedYet
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ProductPurchaseManager.Init()
	MarketplaceService.ProcessReceipt = ProductPurchaseManager.ProcessReceipt
	print("ProductPurchaseManager Initialized.")
end

return ProductPurchaseManager