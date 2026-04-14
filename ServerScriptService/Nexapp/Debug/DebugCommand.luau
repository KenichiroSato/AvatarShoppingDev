local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local RecommendationService = game:GetService("RecommendationService")
local PlayerManager = require(ServerScriptService.Nexapp.Player.PlayerManager)
local PlayerSaveDataModule = require(ServerScriptService.Nexsys.Player.PlayerSaveDataModule)
local OrderedSaveDataManager = require(ServerScriptService.Nexsys.OrderedSaveDataManager)
local SystemDebugCommand = require(ServerScriptService.Nexsys.Debug.SystemDebugCommand)

--- @class DebugCommand : table
local DebugCommand = {}

local GROUP_ID = 35794055

function canDebugCommand(player: Player)
	if RunService:IsStudio() then
		return true
	end
	-- テストプレイ
	if player.UserId < 0 then
		return true
	end

	-- ランク
	local rank = player:GetRankInGroup(GROUP_ID)
	if rank >= 250 then
		return true
	end

	local role = player:GetRoleInGroup(GROUP_ID)
	if role == "管理者" or role == "所有者" or role == "E" or role == "D" or role == "P" then
	-- or player.Name == "keita0x12" then
		return true
	end
	return false
end

----------------------------------------------------------------------------------------------------
-- Process
function DebugCommand.Process(player: Player, message: string, _recipient)
	-- if not ServerStorage.DevConfig.EnableDebugCommand.Value then
	-- 	warn("DebugCommand is disabled")
	-- 	return
	-- end

	local gp = PlayerManager.GetGamePlayer(player)

	local beginIdx = string.find(message, "/dc")
	
	if beginIdx and beginIdx >= 1 then
		if not RunService:IsStudio() then
			-- 公開で使っている人は検知
			warn("DebugCommand Process : player", player.Name, player.UserId, message)
		else
			print("DebugCommand Process", message)
		end
		
		-- グループの特定権限のみ
		if not canDebugCommand(player) then
			warn("DebugCommand is not allowed, tryed.")
			warn("DebugCommand try message: player=", player.Name, player.UserId, message)
			return
		end
		
		local args = string.split(message, " ")
		local command = args[2]
		
		if command == "rs" or command == "resetsave" then
			print("reset save data")
			gp:ResetSaveData()
			return
		elseif command == "rsall" or command == "resetsaveall" then
			PlayerSaveDataModule:RemoveSaveDataAll()
			return
		elseif command == "dev" or command == "devmode" then
			gp.playerData:SetDevMode(not gp.playerData:IsDevMode())
			warn("DebugCommand: set devmode", gp.playerData:IsDevMode())
			return
		elseif command == "ac" or command == "addcoin" then
			local amount = tonumber(args[3])
			if amount then
				gp:AddCoin(amount)
			end
			return
		elseif command == "ag" or command == "addgem" then
			local amount = tonumber(args[3])
			if amount then
				gp.playerData:AddGem(amount)
			end
			return
		elseif command == "rsw" then
			gp.playerData:SetOwnedWands({})
			gp.playerData:SetSelectedWand("")
		end
		
		-- システム系
		SystemDebugCommand.Process(player, message, _recipient)
	end
end

return DebugCommand