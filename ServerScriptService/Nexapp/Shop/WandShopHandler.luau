local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ServerScriptService = game:GetService("ServerScriptService")

local WandData = require(ReplicatedFirst.Exdata.WandData)
local PlayerManager = require(ServerScriptService.Nexapp.Player.PlayerManager)

local WandShopHandler = {}

----------------------------------------------------------------------------------------------------
local function Announce(player: Player, message: string)
	local gp = PlayerManager.GetGamePlayer(player)
	if gp then
		gp:Announce(message)
	end
end

----------------------------------------------------------------------------------------------------
-- WandDataをName文字列で検索する
local function findWandDataByName(wandName: string)
	for _, data in pairs(WandData) do
		if data.Name == wandName then
			return data
		end
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- 個々のWandShopにClickDetectorを接続する
local function setupWandShop(wandShop: Model)
	-- WeaponStand以外のModelがWandモデル
	local wandName: string? = nil
	for _, child in ipairs(wandShop:GetChildren()) do
		if child:IsA("Model") and child.Name ~= "WeaponStand" then
			wandName = child.Name
			break
		end
	end

	if not wandName then
		warn("WandShopHandler: wand model not found in", wandShop:GetFullName())
		return
	end

	local weaponStand = wandShop:FindFirstChild("WeaponStand")
	if not weaponStand then return end
	local buttonPart = weaponStand:FindFirstChild("ButtonPart")
	if not buttonPart then return end
	local clickDetector = buttonPart:FindFirstChild("BuyClickDetector")
	if not clickDetector then return end

	clickDetector.MouseClick:Connect(function(player: Player)
		local data = findWandDataByName(wandName)
		if not data then
			warn("WandShopHandler: WandData not found for name =", wandName)
			return
		end

		local pd = PlayerManager.GetPlayerData(player)
		if not pd then
			warn("WandShopHandler: PlayerData not found for", player.Name)
			return
		end

		-- 既に所持済みの場合はSelectedWandの切り替えのみ
		if pd:HasOwnedWand(wandName) then
			pd:SetSelectedWand(wandName)
			Announce(player, "WandEquipped")
			return
		end

		-- Gem残高チェック
		local currentGem = pd:GetGem()
		local price = data.GemPrice
		if currentGem < price then
			warn("WandShopHandler: not enough gems.", player.Name, "has", currentGem, "/ needs", price)
			Announce(player, "NotEnoughGems")
			return
		end

		-- 購入処理
		pd:SetGem(currentGem - price)
		pd:AddOwnedWand(wandName)
		pd:SetSelectedWand(wandName)

		Announce(player, "WandPurchased")

		print("WandShopHandler: purchased", wandName, "by", player.Name)
	end)
end

----------------------------------------------------------------------------------------------------
-- Init: Shop.Wands以下の全WandShopにイベントを設定する
function WandShopHandler.Init()
	local wandsFolder = workspace:WaitForChild("Shop"):WaitForChild("Wands")
	for _, child in ipairs(wandsFolder:GetChildren()) do
		if child:IsA("Model") and child.Name == "WandShop" then
			setupWandShop(child)
		end
	end
end

return WandShopHandler
