local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Define = require(ReplicatedFirst.Nexapp.Common.Define)
local PlayerData = require(ReplicatedFirst.Nexapp.Common.System.PlayerData)
local PlayerSaveTable = require(ReplicatedFirst.Nexapp.Common.System.PlayerSaveTable)
local InstanceManager = require(ReplicatedFirst.Nexsys.Common.InstanceManager)
local GameUtil = require(ReplicatedFirst.Nexapp.Common.System.GameUtil)
local ComponentManager = require(ReplicatedFirst.Nexapp.Common.System.ComponentManager)
local ConfigData = require(ReplicatedFirst.Exdata.ConfigData)
local WandData = require(ReplicatedFirst.Exdata.WandData)

local ServerScriptService = game:GetService("ServerScriptService")
local BasePlayer = require(ServerScriptService.Nexsys.Player.BasePlayer)
local LoginBonus = require(ServerScriptService.Nexapp.System.LoginBonus)
local StayBonus = require(ServerScriptService.Nexapp.System.StayBonus)
local OrderedSaveDataManager = require(ServerScriptService.Nexsys.OrderedSaveDataManager)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local applyItemsToDescriptionAsync = require(ReplicatedStorage.TryOn.Utility.applyItemsToDescriptionAsync)

--local SaveDataLoadedEvent = ReplicatedStorage:WaitForChild("BindableEvent"):WaitForChild("SaveDataLoadedEvent")

--- @class GamePlayer : BasePlayer
local GamePlayer = {}
GamePlayer.__index = GamePlayer
setmetatable(GamePlayer, BasePlayer)
----------------------------------------------------------------------------------------------------
--
function GamePlayer.new(player: Player)
	local self = setmetatable(BasePlayer.new(player), GamePlayer)
	GamePlayer.Init(self, player)
	return self
end

function GamePlayer:Init(player: Player)

	self.playerData = PlayerData.new(player)
	self.saveLoadStartTime = tick()
	self:LoadSaveData()

	--self:SetRespawnPoint(workspace.Map.SpawnLocation)

	self.startTime = os.time()

	local loginBonus = LoginBonus.new(self)
	self.loginBonus = loginBonus
	---@type StayBonus
	self.stayBonus = StayBonus.new(self)
	
	player.Chatted:Connect(function(message, recipient)
		local DebugCommand = require(ServerScriptService.Nexapp.Debug.DebugCommand)
		DebugCommand.Process(player, message, recipient)
	end)

	-- Robuxゲームパス購入完了コールバック
	self._gamePassPurchaseConn = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchasedPlayer, gamePassId, wasPurchased)
		if purchasedPlayer ~= player then return end
		if not wasPurchased then return end
		if not self._pendingPassWand then return end
		if self._pendingPassWand.passId ~= gamePassId then return end

		local pendingWandName = self._pendingPassWand.wandName
		self._pendingPassWand = nil

		local pd = self.playerData
		if pd then
			pd:AddOwnedWand(pendingWandName)
			pd:SetSelectedWand(pendingWandName)
			self:Announce("WandPurchased")
			print("GamePlayer: Robux game pass purchased wand", pendingWandName, "by", self:GetName())
		end
	end)

end
----------------------------------------------------------------------------------------------------
-- Terminate
function GamePlayer:onTerminate(player : Player)
	self:RecordPlayTime()

	if self._gamePassPurchaseConn then
		self._gamePassPurchaseConn:Disconnect()
		self._gamePassPurchaseConn = nil
	end

	if RunService:IsStudio() then
		-- 終了が遅くなるのでスキップ
		warn("GamePlayer:Terminate skipped on studio", player)
		return
	end

	self:TerminateSaveData()
end
----------------------------------------------------------------------------------------------------
-- onCharacterAdded
function GamePlayer:onCharacterAdded(_chara: Model)
	-- print("GamePlayer:onCharacterAdded", self.Player)
	-- _chara:AddTag("ModelComp")

	InstanceManager.CreateComponentInstance(_chara)
	self:SetCollisionGroup("Character")

end
----------------------------------------------------------------------------------------------------
-- onCharacterAppearanceLoaded
function GamePlayer:onCharacterAppearanceLoaded(_char: Model) end
----------------------------------------------------------------------------------------------------
--- @param saveDataIns PlayerSaveData
function GamePlayer:onSaveDataLoaded(saveDataIns)
	local loadTime = tick() - self.saveLoadStartTime
	print("onSaveDataLoaded", self:GetName(), loadTime)
	local player = self:GetPlayer()
	self.playerData:SetSaveDataIns(saveDataIns)

	-- パラメータ初期化
	self:SetCoin(self.playerData:GetCoin())

	self.playerData:SetLastLoginTime(os.time())
	self.playerData:ClearStayBonusClaimedList()
	
end
----------------------------------------------------------------------------------------------------
--
function GamePlayer:OnPlayerDied(player: Player)
	BasePlayer.OnPlayerDied(self, player)
	if not Players.CharacterAutoLoads then
		self:SpawnCharacterAsync()
	end
end
----------------------------------------------------------------------------------------------------
-- RecordPlayTime
function GamePlayer:RecordPlayTime()
	local curPlayTime = os.time() - self.startTime
	local totalPlayTime = self.playerData:GetPlayTime() + curPlayTime
	self.playerData:SetPlayTime(totalPlayTime)
end
----------------------------------------------------------------------------------------------------
-- Update
function GamePlayer:Update(dt)
	BasePlayer.Update(self, dt)
	
end
----------------------------------------------------------------------------------------------------
-- OnHeartbeat
function GamePlayer:OnHeartbeat(dt)
end
----------------------------------------------------------------------------------------------------
-- ローディングスクリーンが開けてClientでゲーム開始した
function GamePlayer:OnClientGameStarted()
	print("OnClientGameStarted")
	self.isClientGameStarted = true

	--self:LogFunnelStepEvent(LogDefine.StartDetailFunnel_A.StartButtonPushed)
end
----------------------------------------------------------------------------------------------------
-- GetPlayerData
function GamePlayer:GetPlayerData()
	return self.playerData
end

----------------------------------------------------------------------------------------------------
-- 以下コンテンツ実装系
----------------------------------------------------------------------------------------------------
-- SetCoin
function GamePlayer:SetCoin(val: number)
	self.playerData:SetCoin(val)
end
-- GetCoin
function GamePlayer:GetCoin()
	return self.playerData:GetCoin()
end
-- AddCoin
function GamePlayer:AddCoin(val: number)
	local newVal = self:GetCoin() + val
	self:SetCoin(newVal)
	--[[
	if val > 0 then
		self:PlaySEByName("CoinGet")

		local coinText = GameUtil.GetCoinText(val)
		self:PlayGamePopup("+"..coinText, Define.PopUpType.Coin)
	end
	]]
end
-- SubCoin
function GamePlayer:SubCoin(val: number) : boolean
	local curVal = self:GetCoin()
	if curVal < val then
		return false
	end
	local newVal = curVal - val
	self:SetCoin(newVal)
	return true
end

-- 試着関連
function GamePlayer:ApplyTryOn(assetIds: {number}, bundleIds: {number}?)
	print("GamePlayer ApplyTryOn", assetIds, bundleIds)
	task.spawn(function()
		local player = self.Player
		if not player.Character then
			return
		end
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		--GetAppliedDescriptionは現在のアバターの状態のDescriptionを返す
		local originalDescription = humanoid:GetAppliedDescription()
		--GetHumanoidDescriptionFromUserIdはロブロックス上に保存されている、プレーヤのアバターのDescriptionを返す
		--local originalDescription = Players:GetHumanoidDescriptionFromUserId(player.CharacterAppearanceId)
		print("originalDescription=", originalDescription.BackAccessory)
		local newDescription = originalDescription:Clone()
		
		bundleIds = bundleIds or {}
		applyItemsToDescriptionAsync(newDescription, assetIds, bundleIds, true)
		print("newDescription=", originalDescription.BackAccessory)
		humanoid:ApplyDescription(newDescription, Enum.AssetTypeVerification.Always)


		--wait(5.0)
		--humanoid:ApplyDescription(originalDescription, Enum.AssetTypeVerification.Always)
	end)
end

function GamePlayer:BulkPurchase(keys: {number}, bundleKeys: {number}?)
	local _keys: {number} = keys or {}
	local _bundleKeys: {number} = bundleKeys or {}
	
	local totalItems = #_keys + #_bundleKeys
	if totalItems == 1 then
		if #_keys == 1 then
			MarketplaceService:PromptPurchase(self:GetPlayer(), _keys[1])
		elseif #_bundleKeys == 1 then
			MarketplaceService:PromptBundlePurchase(self:GetPlayer(), _bundleKeys[1])
		end
	elseif totalItems > 1 then
		local items = {}
		for _, dataKey in _keys do
			table.insert(items, { Type = Enum.MarketplaceProductType.AvatarAsset, Id = tostring(dataKey) })
		end
		for _, dataKey in _bundleKeys do
			table.insert(items, { Type = Enum.MarketplaceProductType.AvatarBundle, Id = tostring(dataKey) })
		end
		MarketplaceService:PromptBulkPurchase(self.Player, items, {})
	end
end

----------------------------------------------------------------------------------------------------
-- BuyWand : クライアントからの購入リクエスト処理 (RCS_BuyWand)
function GamePlayer:BuyWand(wandName: string)
	local pd = self.playerData
	if not pd then return end

	local data = nil
	for _, d in pairs(WandData) do
		if d.Name == wandName then
			data = d
			break
		end
	end
	if not data then
		warn("GamePlayer:BuyWand: WandData not found for", wandName)
		return
	end

	-- 既に所持済みの場合は装備のみ
	if pd:HasOwnedWand(wandName) then
		pd:SetSelectedWand(wandName)
		self:Announce("WandEquipped")
		return
	end

	-- Gem残高チェック
	local currentGem = pd:GetGem()
	local price = data.GemPrice
	if currentGem < price then
		warn("GamePlayer:BuyWand: not enough gems.", self:GetName(), "has", currentGem, "/ needs", price)
		self:Announce("NotEnoughGems")
		return
	end

	-- 購入処理
	pd:SetGem(currentGem - price)
	pd:AddOwnedWand(wandName)
	pd:SetSelectedWand(wandName)
	self:Announce("WandPurchased")

	print("GamePlayer:BuyWand: purchased", wandName, "by", self:GetName())
end

----------------------------------------------------------------------------------------------------
-- BuyWandRobux : Robuxゲームパスによる購入リクエスト処理 (RCS_BuyWandRobux)
function GamePlayer:BuyWandRobux(wandName: string)
	local pd = self.playerData
	if not pd then return end

	local data = nil
	for _, d in pairs(WandData) do
		if d.Name == wandName then
			data = d
			break
		end
	end
	if not data then
		warn("GamePlayer:BuyWandRobux: WandData not found for", wandName)
		return
	end

	-- 既にWandを所持済みの場合は装備のみ
	if pd:HasOwnedWand(wandName) then
		pd:SetSelectedWand(wandName)
		self:Announce("WandEquipped")
		return
	end

	-- ゲームパス自体をすでに所持している場合は直接付与（複数WandがPassIdを共有するケース対応）
	if self:HasGamePassAsync(data.PassId) then
		pd:AddOwnedWand(wandName)
		pd:SetSelectedWand(wandName)
		self:Announce("WandPurchased")
		print("GamePlayer: game pass already owned, granted wand", wandName, "by", self:GetName())
		return
	end

	-- ゲームパス購入プロンプトを表示（完了はPromptGamePassPurchaseFinishedで受け取る）
	self._pendingPassWand = {passId = data.PassId, wandName = wandName}
	MarketplaceService:PromptGamePassPurchase(self:GetPlayer(), data.PassId)
end

----------------------------------------------------------------------------------------------------
-- 以下コンテンツコールバック系実装
----------------------------------------------------------------------------------------------------
-- OnDashChanged
function GamePlayer:OnDashChanged()
	-- print("OnDashChanged")
	self.playerData:SetDashMode(not self.playerData:IsDashMode())
end

----------------------------------------------------------------------------------------------------
-- OnLoginBonusClaimed
function GamePlayer:OnLoginBonusClaimed()
	-- print("OnLoginBonusClaimed")

	local result = self.loginBonus:OnGetLoginBonus()
	return result
end
----------------------------------------------------------------------------------------------------
-- OnTimeBonusClaim
function GamePlayer:OnTimeBonusClaim(level)
	-- print("OnTimeBonusClaim", self:GetName())

	return self.stayBonus:OnClaim(level)
end
----------------------------------------------------------------------------------------------------
-- OnInviteFriendsSent : 友達招待を送ったときに500Gemプレゼント（セッション内1回）
function GamePlayer:OnInviteFriendsSent()
	if self._hasReceivedInviteGemReward then return end
	self._hasReceivedInviteGemReward = true

	local pd = self.playerData
	if not pd then return end

	local GEM_AMOUNT = 500
	pd:AddGem(GEM_AMOUNT)

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local gemGetEvent = ReplicatedStorage.RemoteEvent:FindFirstChild("GemGetEvent")
	if gemGetEvent then
		gemGetEvent:FireClient(self:GetPlayer(), "友達を招待！", GEM_AMOUNT, "Bell")
	end

	print("GamePlayer:OnInviteFriendsSent: gave", GEM_AMOUNT, "gems to", self:GetName())
end
----------------------------------------------------------------------------------------------------

return GamePlayer
