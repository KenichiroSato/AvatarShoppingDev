local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local BasePlayerData = require(ReplicatedFirst.Nexsys.Common.BasePlayerData)
local PlayerSaveTable = require(ReplicatedFirst.Nexapp.Common.System.PlayerSaveTable)
local PlayerSyncParamsTable = require(ReplicatedFirst.Nexapp.Common.System.PlayerSyncParamsTable)
local Define = require(ReplicatedFirst.Nexapp.Common.Define)

--- @class PlayerData : BasePlayerData
local PlayerData = {}
PlayerData.__index = PlayerData
setmetatable(PlayerData, BasePlayerData)

----------------------------------------------------------------------------------------------------
--
function PlayerData.new(...)
	local self = setmetatable(BasePlayerData.new(...), PlayerData)
	PlayerData.Init(self, ...)
	if RunService:IsClient() then
		BasePlayerData.SetInstance(self)
	end
	return self
end

function PlayerData:Init(player: Player)
	self.player = player
	if RunService:IsServer() then
		self:CreateSyncParam(PlayerSyncParamsTable.Template)
	end
	-- ClientはReplicaが使えるタイミングで明示的に StartOnClient を呼ぶ
end
----------------------------------------------------------------------------------------------------
-- 
function PlayerData:StartOnClient()
	self:CreateSyncParam(PlayerSyncParamsTable.Template)
	self:CreateSaveReplicaParams(PlayerSaveTable.Template)
	task.spawn(function()
		local SystemDataModule_ = require(ReplicatedFirst.Nexsys.Client.SystemDataModule_)
		SystemDataModule_.WaitUntilSaveDataLoaded()
		self:StartListenToSaveDataChanged()
	end)
end
----------------------------------------------------------------------------------------------------
-- Destroy
function PlayerData:Destroy()
	BasePlayerData.Destroy(self)
	if self.syncParamIns then
		self.syncParamIns:Destroy()
	end
end

----------------------------------------------------------------------------------------------------
-- SyncTable系
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- SetPlayerLoginTime
function PlayerData:SetPlayerLoginTime()
	self:SetAttribute("PlayerLoginTime", os.time())
end
----------------------------------------------------------------------------------------------------
-- GetPlayerLoginTime
function PlayerData:GetPlayerLoginTime()
	return self:GetAttribute("PlayerLoginTime")
end
----------------------------------------------------------------------------------------------------
-- 
function PlayerData:GetPlayerSessionPlayTime()
	local loginTime = self:GetLastLoginTime()
	local now = os.time()
	local diff = now - loginTime
	return diff
end

----------------------------------------------------------------------------------------------------
--- IsDevMode
function PlayerData:IsDevMode() : boolean?
	return self:GetAttribute("DevMode")
end
----------------------------------------------------------------------------------------------------
--- SetDevMode
function PlayerData:SetDevMode(val : boolean)
	self:SetAttribute("DevMode", val)
end
----------------------------------------------------------------------------------------------------
-- GetDashMode
function PlayerData:IsDashMode()
	return self:GetSyncParamKey(PlayerSyncParamsTable.Keys.DashMode)
end
--
function PlayerData:SetDashMode(val)
	self:SetSyncParamKey(PlayerSyncParamsTable.Keys.DashMode, val)
end

----------------------------------------------------------------------------------------------------
-- セーブ系IF
----------------------------------------------------------------------------------------------------
-- GetPlayTime
function PlayerData:GetPlayTime()
	return self:GetSaveDataKey(PlayerSaveTable.Keys.PlayTime) or 0
end
-- SetPlayTime
function PlayerData:SetPlayTime(val: number)
	self:SetSaveDataKey(PlayerSaveTable.Keys.PlayTime, val)
end
----------------------------------------------------------------------------------------------------
-- 
function PlayerData:GetLastLoginTime()
	return self:GetSaveDataKey(PlayerSaveTable.Keys.LastLoginTime)
end
-- 
function PlayerData:SetLastLoginTime(val: number)
	self:SetSaveDataKey(PlayerSaveTable.Keys.LastLoginTime, val)
end
----------------------------------------------------------------------------------------------------
-- SetStayBonusClaimed
function PlayerData:SetStayBonusClaimed(level)
	self:SetSaveDataKey2(PlayerSaveTable.Keys.StayBonusClaimedList, level, true)
end
----------------------------------------------------------------------------------------------------
-- ClearStayBonusClaimedList
function PlayerData:ClearStayBonusClaimedList()
	self:SetSaveDataKey(PlayerSaveTable.Keys.StayBonusClaimedList, {})
end
----------------------------------------------------------------------------------------------------
-- GetStayBonusClaimedList
function PlayerData:GetStayBonusClaimedList()
	return self:GetSaveDataKey(PlayerSaveTable.Keys.StayBonusClaimedList)
end
----------------------------------------------------------------------------------------------------
-- GetCoin
function PlayerData:GetCoin()
	return self:GetSaveDataKey(PlayerSaveTable.Keys.Coin)
end
-- SetCoin
function PlayerData:SetCoin(val: number)
	self:SetSaveDataKey(PlayerSaveTable.Keys.Coin, val)
end
-- GetCoinText
function PlayerData:GetCoinText()
	local GameUtil = require(ReplicatedFirst.Nexapp.Common.System.GameUtil)
	return GameUtil.GetCoinText(self:GetCoin())
end
----------------------------------------------------------------------------------------------------
-- GetGem
function PlayerData:GetGem()
	return self:GetSaveDataKey(PlayerSaveTable.Keys.Gem) or 0
end
-- SetGem
function PlayerData:SetGem(val: number)
	self:SetSaveDataKey(PlayerSaveTable.Keys.Gem, val)
end
-- AddGem
function PlayerData:AddGem(val: number)
	self:SetGem((self:GetGem()) + val)
end

----------------------------------------------------------------------------------------------------
-- GetWornAssets
function PlayerData:GetWornAssets(): {number}
	return self:GetSaveDataKey(PlayerSaveTable.Keys.WornAssets) or {}
end
-- SetWornAssets
function PlayerData:SetWornAssets(val: {number})
	self:SetSaveDataKey(PlayerSaveTable.Keys.WornAssets, val)
end
----------------------------------------------------------------------------------------------------
-- GetWornBundles
function PlayerData:GetWornBundles(): {number}
	return self:GetSaveDataKey(PlayerSaveTable.Keys.WornBundles) or {}
end
-- SetWornBundles
function PlayerData:SetWornBundles(val: {number})
	self:SetSaveDataKey(PlayerSaveTable.Keys.WornBundles, val)
end

----------------------------------------------------------------------------------------------------
-- GetLoginBonusGotDay
function PlayerData:GetLoginBonusGotDay()
	return self:GetSaveDataKey(PlayerSaveTable.Keys.LoginBonusGotDay)
end
-- SetLoginBonusGotDay
function PlayerData:SetLoginBonusGotDay(day)
	self:SetSaveDataKey(PlayerSaveTable.Keys.LoginBonusGotDay, day)
end
-- GetLastLoginBonusTime
function PlayerData:GetLastLoginBonusTime()
	return self:GetSaveDataKey(PlayerSaveTable.Keys.LastLoginBonusTime)
end
-- SetLastLoginBonusTime
function PlayerData:SetLastLoginBonusTime(time)
	self:SetSaveDataKey(PlayerSaveTable.Keys.LastLoginBonusTime, time)
end
----------------------------------------------------------------------------------------------------
-- HasCanClaimLoginBonus
function PlayerData:HasCanClaimLoginBonus()
	local lastBonusTime = self:GetLastLoginBonusTime()
	if lastBonusTime == nil then
		return true
	end
	local gotDay = self:GetLoginBonusGotDay()
	if gotDay >= Define.LOGIN_BONUS_MAX_DAY then
		return false
	end

	-- 前回のログインボーナス受け取りから24時間以上経過しているか
	local currentTime = os.time()
	if (currentTime - lastBonusTime) >= Define.LOGIN_BONUS_INTERVAL_TIME then
		return true
	else
		return false
	end
end
----------------------------------------------------------------------------------------------------
-- 
function PlayerData:ListenToLoginBonusGotDayChanged(func)
	self:ListenToSaveDataParam1Changed(PlayerSaveTable.Keys.LoginBonusGotDay, func)
end
----------------------------------------------------------------------------------------------------
-- 
function PlayerData:ListenToMissionStatusListChanged(func)
	self:ListenToSaveDataParam1Changed(PlayerSaveTable.Keys.MissionStatusList, func)
end

----------------------------------------------------------------------------------------------------
-- Util系
----------------------------------------------------------------------------------------------------
-- 
function PlayerData:GetCurrentPlayTime()
	local curPlayTime = self:GetPlayerSessionPlayTime()
	local lastPlayTime = self:GetSaveDataKey(PlayerSaveTable.Keys.PlayTime) or 0
	return lastPlayTime + curPlayTime
end
----------------------------------------------------------------------------------------------------
-- Client用Singleton処理
----------------------------------------------------------------------------------------------------
if RunService:IsClient() then
	local ins = BasePlayerData.Get()
	if not ins then
		return PlayerData.new(game.Players.LocalPlayer)
	end
	return ins
else
	return PlayerData
end