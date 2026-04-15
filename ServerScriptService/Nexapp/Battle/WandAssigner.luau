--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local PlayerManager = require(ServerScriptService.Nexapp.Player.PlayerManager)

local WandAssigner = {}

-- Constant for the attribute name used to identify battle wands
local BATTLE_WAND_ATTRIBUTE = "BattleWand"

--- Wands フォルダから有効なToolリストを取得する
local function getValidWands(): {Tool}
	local wandsFolder = ReplicatedStorage:FindFirstChild("Wands")
	if not wandsFolder then
		warn("Wands folder not found in ReplicatedStorage")
		return {}
	end
	local validWands = {}
	for _, item in ipairs(wandsFolder:GetChildren()) do
		if item:IsA("Tool") then
			table.insert(validWands, item)
		end
	end
	return validWands
end

--- 指定した名前のWandをキャラクターに装備させる
local function equipWand(character: Model, wand: Tool)
	local cloned = wand:Clone()
	cloned:SetAttribute(BATTLE_WAND_ATTRIBUTE, true)
	cloned.Parent = character
end

----------------------------------------------------------------------------------------------------
--- SelectedWandをPlayerに、ランダムをNPCにアサインする
--- Playerのみ対象。AssignRandomWandsとの統合版として使用する
-- @param participants キャラクターModelのリスト（PlayerとNPC混在可）
function WandAssigner.AssignWands(participants: {Model})
	local validWands = getValidWands()
	if #validWands == 0 then
		warn("No wands (Tools) found in ReplicatedStorage/Wands")
		return
	end

	local rng = Random.new()

	for _, character in ipairs(participants) do
		local player = Players:GetPlayerFromCharacter(character)

		if player then
			-- Player: SelectedWandを使う
			local pd = PlayerManager.GetPlayerData(player)
			local selectedWandName = pd and pd:GetSelectedWand() or ""
			local wandTool: Tool? = nil

			if selectedWandName ~= "" then
				-- ReplicatedStorage.WandsからName一致のToolを探す
				local wandsFolder = ReplicatedStorage:FindFirstChild("Wands")
				if wandsFolder then
					wandTool = wandsFolder:FindFirstChild(selectedWandName) :: Tool?
				end
			end

			-- SelectedWandが未設定 or 見つからない場合はNormalWandを使用
			if not wandTool then
				local wandsFolder = ReplicatedStorage:FindFirstChild("Wands")
				if wandsFolder then
					wandTool = wandsFolder:FindFirstChild("NormalWand") :: Tool?
				end
				-- NormalWandも見つからない場合はランダム
				if not wandTool then
					wandTool = validWands[rng:NextInteger(1, #validWands)]
				end
			end

			equipWand(character, wandTool)
		else
			-- NPC: ランダムアサイン
			local randomWand = validWands[rng:NextInteger(1, #validWands)]
			equipWand(character, randomWand)
		end
	end
end

----------------------------------------------------------------------------------------------------
--- Assigns a random wand from ReplicatedStorage/Wands to each participant
-- @param participants List of character models
function WandAssigner.AssignRandomWands(participants: {Model})
	local validWands = getValidWands()
	if #validWands == 0 then
		warn("No wands (Tools) found in ReplicatedStorage/Wands")
		return
	end

	local rng = Random.new()

	for _, character in ipairs(participants) do
		local randomWand = validWands[rng:NextInteger(1, #validWands)]
		equipWand(character, randomWand)
	end
end

--- Removes assigned battle wands from participants
-- @param participants List of character models (players only)
function WandAssigner.RemoveWands(participants: {Model})
	for _, character in ipairs(participants) do
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			-- Remove from Backpack
			local backpack = player:FindFirstChild("Backpack")
			if backpack then
				for _, item in ipairs(backpack:GetChildren()) do
					if item:GetAttribute(BATTLE_WAND_ATTRIBUTE) == true then
						item:Destroy()
					end
				end
			end
			
			-- Remove from Character (equipped tool)
			if character then
				for _, item in ipairs(character:GetChildren()) do
					if item:IsA("Tool") and item:GetAttribute(BATTLE_WAND_ATTRIBUTE) == true then
						item:Destroy()
					end
				end
			end
		end
	end
end

return WandAssigner
