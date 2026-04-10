local ArenaBuilder = {}

local ServerScriptService = game:GetService("ServerScriptService")
--local HouseBaseManager = require(ServerScriptService.Nexapp.House.HouseBaseManager)
--[[
function ArenaBuilder.BuildForPlayer(player: Player)
	local HouseBuilder = require(ServerScriptService.Nexapp.House.HouseBuilder)
	HouseBuilder.RebuildHouse(player)

	local ItemManager = require(ServerScriptService.Nexapp.House.ItemManager)
	ItemManager.ReloadFurnitures(player)
end
]]

--- NPC用の家を生成してBase位置に配置
--- ServerStorage/NpcHouses からランダムに1つ選んで Workspace/HouseBases/HouseBase に配置する
function ArenaBuilder.BuildForNPC(): Model?
	-- 1. NpcHousesフォルダを取得
	local ServerStorage = game:GetService("ServerStorage")
	local npcHouses = ServerStorage:FindFirstChild("NpcHouses")
	if not npcHouses then
		warn("[ArenaBuilder] ServerStorage/NpcHouses が見つかりません")
		return nil
	end

	-- 2. Modelのみを取り出してランダムに1つ選抜
	local models = {}
	for _, child in ipairs(npcHouses:GetChildren()) do
		if child:IsA("Model") then
			table.insert(models, child)
		end
	end
	if #models == 0 then
		warn("[ArenaBuilder] NpcHouses に Model がありません")
		return nil
	end
	local chosen = models[math.random(1, #models)]

	-- 3. HouseBaseを取得
	local houseBases = workspace:FindFirstChild("HouseBases")
	local houseBase  = houseBases and houseBases:FindFirstChild("HouseBase")
	if not houseBase then
		warn("[ArenaBuilder] Workspace/HouseBases/HouseBase が見つかりません")
		return nil
	end
	local basePart = houseBase.PrimaryPart or houseBase:FindFirstChildWhichIsA("BasePart")
	if not basePart then
		warn("[ArenaBuilder] HouseBaseにPrimaryPartがありません")
		return nil
	end

	-- 4. CloneしてHouseBases配下にPivotToで配置
	local clone = chosen:Clone()
	clone.Parent = houseBases
	clone:PivotTo(basePart.CFrame)

	print(string.format("[ArenaBuilder] '%s' を HouseBase に配置しました", chosen.Name))
	return clone
end

return ArenaBuilder
