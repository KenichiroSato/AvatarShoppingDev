
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local NPC_FOLDER = ServerStorage.NPCs
local WANDS_FOLDER = ReplicatedStorage:FindFirstChild("Wands")

local NpcManager = {}
local Npc = require(script.Parent:WaitForChild("Npc"))

-- keep track of instantiated Npc objects so we can stop them later
local activeNpcInstances = {}

function NpcManager.StartBattle(npcNum: number): {Model}
	
	if typeof(npcNum) ~= "number" then
		npcNum = tonumber(npcNum) or 0
	end
	if npcNum <= 0 then
		return {}
	end

	local candidates = {}
	for _, child in ipairs(NPC_FOLDER:GetChildren()) do
		if child:IsA("Model") then
			table.insert(candidates, child)
		end
	end

	if #candidates == 0 then
		return {}
	end

	local rng = Random.new(tick())
	local Workspace = game:GetService("Workspace")
	local destParent = Workspace:FindFirstChild("NPCs")
	if not destParent then
		destParent = Instance.new("Folder")
		destParent.Name = "NPCs"
		destParent.Parent = Workspace
	end

	local clones = {}
	-- choose without replacement while possible, then with replacement if more requested
	local available = {}
	for i = 1, #candidates do
		available[i] = i
	end

	for i = 1, npcNum do
		local choice
		if #available > 0 then
			local pickIndex = rng:NextInteger(1, #available)
			local candIndex = table.remove(available, pickIndex)
			choice = candidates[candIndex]
		else
			choice = candidates[rng:NextInteger(1, #candidates)]
		end
		local clone = choice:Clone()
		clone:SetAttribute("TrickTargetNPC", true)
		clone.Parent = destParent
		
		-- Randomly select and attach a wand
		if WANDS_FOLDER then
			local wands = {}
			for _, child in ipairs(WANDS_FOLDER:GetChildren()) do
				if child:IsA("Tool") then
					table.insert(wands, child)
				end
			end
			
			if #wands > 0 then
				local selectedWand = wands[rng:NextInteger(1, #wands)]
				local wandClone = selectedWand:Clone()
				wandClone.Parent = clone
			end
		end
		
		-- instantiate OOP Npc and start its behavior
		local npcObj = Npc.new(clone)
		npcObj:Start()
		table.insert(activeNpcInstances, npcObj)
		table.insert(clones, clone)
	end

	return clones
end

function NpcManager.StopBattle()
	local Workspace = game:GetService("Workspace")
	local destParent = Workspace:FindFirstChild("NPCs")
	-- Stop all running Npc instances first
	for _, npcObj in ipairs(activeNpcInstances) do
		if npcObj and typeof(npcObj.Stop) == "function" then
			npcObj:Stop()
		end
	end
	activeNpcInstances = {}

	if destParent then
		destParent:Destroy()
	end
end

return NpcManager
