local ArenaBuilder = {}

local ServerScriptService = game:GetService("ServerScriptService")
local HouseBaseManager = require(ServerScriptService.Nexapp.House.HouseBaseManager)

function ArenaBuilder.BuildForPlayer(player: Player)
	local HouseBuilder = require(ServerScriptService.Nexapp.House.HouseBuilder)
	HouseBuilder.RebuildHouse(player)

	local ItemManager = require(ServerScriptService.Nexapp.House.ItemManager)
	ItemManager.ReloadFurnitures(player)
end

--- NPC用の家を生成してBase位置に配置
function ArenaBuilder.BuildForNPC(character: Model): Model?
	print("ArenaBuilder.BuildForNPC called:"..character.Name)
	local ServerStorage = game:GetService("ServerStorage")
	local housesFolder = ServerStorage:FindFirstChild("NPCHouses") :: Folder?
	if not housesFolder then
		return nil
	end

	-- Find a Model whose name contains the character's name
	local characterName = character.Name
	local matchingHouse = nil
	for _, child in ipairs(housesFolder:GetChildren()) do
		if child:IsA("Model") and string.find(child.Name, characterName) then
			matchingHouse = child
			break
		end
	end

	-- If no matching house found, return nil
	if not matchingHouse then
		return nil
	end

	local clone = matchingHouse:Clone()
	
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("Seat") then
			descendant:Destroy()
		end
	end

	local basePart = HouseBaseManager.GetBaseForModel(character)
	if basePart then
		clone.Parent = basePart
		clone:SetPrimaryPartCFrame(basePart.CFrame)
	end
	return clone
end

return ArenaBuilder
