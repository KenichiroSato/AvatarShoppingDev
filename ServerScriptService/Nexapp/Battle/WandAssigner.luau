--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local WandAssigner = {}

-- Constant for the attribute name used to identify battle wands
local BATTLE_WAND_ATTRIBUTE = "BattleWand"

--- Assigns a random wand from ReplicatedStorage/Wands to each player in the list
-- @param participants List of character models (players only)
function WandAssigner.AssignRandomWands(participants: {Model})
	local wandsFolder = ReplicatedStorage:FindFirstChild("Wands")
	if not wandsFolder then
		warn("Wands folder not found in ReplicatedStorage")
		return
	end
	
	local wands = wandsFolder:GetChildren()
	local validWands = {}
	for _, item in ipairs(wands) do
		if item:IsA("Tool") then
			table.insert(validWands, item)
		end
	end

	if #validWands == 0 then
		warn("No wands (Tools) found in ReplicatedStorage/Wands")
		return
	end
	
	local rng = Random.new()
	
	for _, character in ipairs(participants) do
		local player = Players:GetPlayerFromCharacter(character)
		local backpack = if player then player:FindFirstChild("Backpack") else nil
		if player and backpack then
			local randomWand = validWands[rng:NextInteger(1, #validWands)]
			local clonedWand = randomWand:Clone()
			clonedWand:SetAttribute(BATTLE_WAND_ATTRIBUTE, true)
			clonedWand.Parent = character -- Equip by parenting to Character
		end
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
