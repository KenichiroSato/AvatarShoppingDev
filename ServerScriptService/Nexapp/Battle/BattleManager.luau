local Players = game:GetService("Players")
local NpcManager = require(script.Parent:WaitForChild("NpcManager"))
local TrickHandler = require(script.Parent.TrickHandler)
--local ArenaBuilder = require(script.Parent.ArenaBuilder)
local PodiumHandler = require(script.Parent.PodiumHandler)
--local HouseBaseManager = require(script.Parent.Parent:WaitForChild("House"):WaitForChild("HouseBaseManager"))
local WandAssigner = require(script.Parent.WandAssigner)
local Define = require(game:GetService("ReplicatedFirst").Nexapp.Common.Define)

local BattleManager = {}

local MAX_PARTICIPANTS = 8
local DEFAULT_WALK_SPEED = 16

local battleParticipants = {
	npcs = {},
	players = {}
}
local hitCounts = {}
local BattleStatus = {
	Idle = "Idle",
	Preparing = "Preparing",
	Transitioning = "Transitioning",
	Countdown = "Countdown",
	Active = "Active",
	Ending = "Ending"
}

local currentBattleStatus = BattleStatus.Idle
local playerAddedConnection: RBXScriptConnection?
local playerRemovingConnection: RBXScriptConnection?

local function GetRemoteEvent(eventName: string): RemoteEvent
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteEventFolder = ReplicatedStorage:FindFirstChild("RemoteEvent")
	if not remoteEventFolder then
		remoteEventFolder = Instance.new("Folder")
		remoteEventFolder.Name = "RemoteEvent"
		remoteEventFolder.Parent = ReplicatedStorage
	end

	local remoteEvent = remoteEventFolder:FindFirstChild(eventName)
	if not remoteEvent then
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = eventName
		remoteEvent.Parent = remoteEventFolder
	end
	return remoteEvent
end

local function BarrierCharacter(targetCharacter: Model, duration: number?): Model?
	local ServerStorage = game:GetService("ServerStorage")
	local barrierTemplate = ServerStorage:FindFirstChild("BarrierModel")
	if not barrierTemplate then return nil end
	
	local barrier = barrierTemplate:Clone()
	barrier.Parent = targetCharacter
	
	-- Position barrier at character's position
	local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	local barrierPart = barrier.PrimaryPart or barrier:FindFirstChildWhichIsA("BasePart")
	if targetHRP and barrierPart then
		barrierPart.CFrame = targetHRP.CFrame
		
		-- Weld barrier to character
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = targetHRP
		weld.Part1 = barrierPart
		weld.Parent = barrierPart
	end
	
	-- Auto-remove barrier after duration or default 10 seconds
	local lifeTime = duration or 10
	game.Debris:AddItem(barrier, lifeTime)
	
	return barrier
end

local function GrantBarrierToAllParticipants()
	for _, player in ipairs(battleParticipants.players) do
		BarrierCharacter(player, 3)
	end
	for _, npc in ipairs(battleParticipants.npcs) do
		BarrierCharacter(npc, 3)
	end
end

local function StunCharacter(targetCharacterName: string, stunDuration: number)
	-- Find target character
	local targetCharacter: Model?
	for _, char in ipairs(battleParticipants.players) do
		if char.Name == targetCharacterName then
			print("Found target player character: " .. targetCharacterName)
			targetCharacter = char
			break
		end
	end
	if not targetCharacter then
		for _, char in ipairs(battleParticipants.npcs) do
			if char.Name == targetCharacterName then
				targetCharacter = char
				break
			end
		end
	end

	-- Apply stun
	if targetCharacter then
		local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		if humanoid then
			print("Disabling movement for " .. targetCharacterName)
			humanoid.WalkSpeed = 0
			targetCharacter:SetAttribute("IsStunned", true)
			-- Attach barrier to character in separate thread
			task.spawn(BarrierCharacter, targetCharacter, stunDuration + 5)
			
			task.wait(stunDuration)
						
			humanoid.WalkSpeed = DEFAULT_WALK_SPEED
			targetCharacter:SetAttribute("IsStunned", nil)
		end
	end
end

local function TeleportParticipants()
	local spawnFolder = workspace:FindFirstChild("SpawnPositions")
	local spawnCFrames = {}
	if spawnFolder then
		for _, sp in ipairs(spawnFolder:GetChildren()) do
			if sp:IsA("Model") and sp.Name == "SpawnPosition" then
				local part = sp.PrimaryPart or sp:FindFirstChildWhichIsA("BasePart")
				if part then
					table.insert(spawnCFrames, part.CFrame)
				end
			end
		end
	end

	local totalParticipants = #battleParticipants.players + #battleParticipants.npcs
	if totalParticipants <= 0 then return end

	local rng = Random.new(tick())
	for i = #spawnCFrames, 2, -1 do
		local j = rng:NextInteger(1, i)
		spawnCFrames[i], spawnCFrames[j] = spawnCFrames[j], spawnCFrames[i]
	end

	-- assign first N spawn positions (guaranteed #spawnCFrames >= totalParticipants)
	for idx = 1, totalParticipants do
		local model
		if idx <= #battleParticipants.players then
			model = battleParticipants.players[idx]
		else
			model = battleParticipants.npcs[idx - #battleParticipants.players]
		end
		if model then
			model:PivotTo(spawnCFrames[idx])
		end
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			GetRemoteEvent("TeleportEvent"):FireClient(player)
		end
	end
end

local function ShowRouletteOnClient(allParticipants: { Model }, selection: { Model })
	local rouletteEvent = GetRemoteEvent("ShowRoulette")

	local allParticipantsData = {}
	local selectedData = {}

	local function CreateData(model: Model): {}
		local name = model.Name
		local isNpc = true
		local userId = 0
		local player = Players:FindFirstChild(name) -- Usually character name matches player name
		if player then
			isNpc = false
			userId = player.UserId
		end
		-- Identify if it's really an NPC if not found in Players
		if isNpc then
			local _foundNpc = false
			for _, npc in ipairs(battleParticipants.npcs) do
				if npc.Name == name then
					_foundNpc = true
					break
				end
			end
		end
		return {
			Name = name,
			IsNpc = isNpc,
			UserId = userId
		}
	end

	for _, model in ipairs(allParticipants) do
		table.insert(allParticipantsData, CreateData(model))
	end
	for _, model in ipairs(selection) do
		table.insert(selectedData, CreateData(model))
	end
	rouletteEvent:FireAllClients(allParticipantsData, selectedData)
end
--[[
local function BuildArena(num: number?)
	local count = num or 4
	local pool = {}
	for _, p in ipairs(battleParticipants.players) do
		table.insert(pool, p)
	end
	for _, n in ipairs(battleParticipants.npcs) do
		table.insert(pool, n)
	end
	if #pool == 0 then return end

	local rng = Random.new(tick())
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local selection = {}
	for i = 1, math.min(count, #pool) do
		table.insert(selection, pool[i])
	end

	ShowRouletteOnClient(pool, selection)
	task.wait(6)

	-- Assign bases for the selected participants
	HouseBaseManager.AssignBases(selection)

	-- Build arenas for each selection: players get player arenas, others get NPC arenas
	for _, model in ipairs(selection) do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			ArenaBuilder.BuildForPlayer(player)
		else
			ArenaBuilder.BuildForNPC(model)
		end
	end
end
]]

local function FreezeParticipants(participants: {Model}?)
	local targetParticipants = participants
	if not targetParticipants then
		targetParticipants = {}
		for _, p in ipairs(battleParticipants.players) do table.insert(targetParticipants, p) end
		for _, n in ipairs(battleParticipants.npcs) do table.insert(targetParticipants, n) end
	end

	for _, character in ipairs(targetParticipants) do
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		
		if hrp then
			hrp.Anchored = true
		end
		
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			
			local animator = humanoid:FindFirstChild("Animator") :: Animator?
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:Stop()
				end
			end
		end

		local barrier = character:FindFirstChild("BarrierModel")
		if barrier then
			barrier:Destroy()
		end
	end
end

local function UnfreezeParticipants(participants: {Model})
	for _, character in ipairs(participants) do
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		
		if hrp then
			hrp.Anchored = false
		end
		
		if humanoid then
			humanoid.WalkSpeed = DEFAULT_WALK_SPEED
			humanoid.JumpPower = 50 -- Default jump power
		end
	end
end



local function FireBattleStatus(isActive: boolean)
	GetRemoteEvent("BattleStatus"):FireAllClients(isActive)
end

local function FireFadeEvent(isOut: boolean, isWhite: boolean?)
	GetRemoteEvent("FadeEvent"):FireAllClients(isOut, isWhite)
end

local function FireTimeUpEvent()
	GetRemoteEvent("TimeUpEvent"):FireAllClients()
end

local function FireCountDownEvent()
	GetRemoteEvent("CountDownEvent"):FireAllClients()
end

function BattleManager.Start()
	print("BattleManager.Start")
	currentBattleStatus = BattleStatus.Preparing
	PodiumHandler.Reset()
	
	battleParticipants.players = {}
	battleParticipants.npcs = {}
	hitCounts = {}
	
	local playerCount = #Players:GetPlayers()
	local npcNum = MAX_PARTICIPANTS - playerCount
	npcNum = math.max(npcNum, 0)
	
	-- Collect player characters
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(battleParticipants.players, player.Character)
			hitCounts[player.Character.Name] = 0
		end
	end
	
	-- Clone NPCs
	local npcClones = NpcManager.StartBattle(npcNum)
	battleParticipants.npcs = npcClones
	

	--BuildArena(4)
	
	for _, npc in ipairs(npcClones) do
		hitCounts[npc.Name] = 0
	end

	currentBattleStatus = BattleStatus.Transitioning


	FireFadeEvent(true, true)
	task.wait(2) -- Fade time

	TeleportParticipants()
	task.wait(0.5) --テレポート後ちゃんと立つまで待つ

	-- Freeze participants during countdown
	FreezeParticipants()
	
	currentBattleStatus = BattleStatus.Countdown

	-- Battle Start Sequence
	-- White Fade Out
	
	-- Fade In
	FireFadeEvent(false, true)
	
	-- Countdown
	FireCountDownEvent()
	task.wait(4) -- 3, 2, 1, GO

	-- Unfreeze participants to start battle
	UnfreezeParticipants(battleParticipants.players)
	UnfreezeParticipants(battleParticipants.npcs)

	-- TrickHandler にコールバック関数を設定
	TrickHandler.StartBattle(BattleManager.OnHit)
	FireBattleStatus(true)
	
	currentBattleStatus = BattleStatus.Active
	
	GrantBarrierToAllParticipants()
	WandAssigner.AssignRandomWands(battleParticipants.players)
	
	print("participants=", battleParticipants)
	return battleParticipants
end

function BattleManager.GetParticipants()
	return battleParticipants
end

local function UpdateRanking()
	-- Calculate Ranking
	local rankingData = {}
	for name, count in pairs(hitCounts) do
		local isNpc = true
		local userId = 0
		local player = Players:FindFirstChild(name) -- Usually character name matches player name
		if player then
			isNpc = false
			userId = player.UserId
		end
		
		-- Identify if it's really an NPC if not found in Players
		if isNpc then
			local _foundNpc = false
			for _, npc in ipairs(battleParticipants.npcs) do
				if npc.Name == name then
					_foundNpc = true
					break
				end
			end
			-- optimization: if not in npcs list and not player, might be error or old char, but we just treat as NPC or ignore?
			-- Current logic trusts hitCounts keys.
		end

		table.insert(rankingData, {
			Name = name,
			Score = count,
			IsNpc = isNpc,
			UserId = userId
		})
	end

	table.sort(rankingData, function(a, b)
		return a.Score > b.Score
	end)

	-- Top 8
	local topRanking = {}
	for i = 1, math.min(8, #rankingData) do
		table.insert(topRanking, rankingData[i])
	end

	-- Broadcast
	GetRemoteEvent("RankingUpdate"):FireAllClients(topRanking)
	return topRanking
end



local function TeleportToLobby()
	local lobby = workspace:FindFirstChild("Lobby")
	local spawnLocation = if lobby then lobby:FindFirstChild("SpawnLocation") else nil
	
	if spawnLocation and spawnLocation:IsA("BasePart") then
		local rng = Random.new()
		for _, char in ipairs(battleParticipants.players) do
			if char and char.Parent then
				local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
				if hrp then
					local offsetX = rng:NextNumber(-2, 2)
					local offsetZ = rng:NextNumber(-2, 2)
					char:PivotTo(spawnLocation.CFrame * CFrame.new(offsetX, 3, offsetZ))
					print("sato Teleported player to lobby")
				end
			end
		end
	end
end

function BattleManager.Stop()
	currentBattleStatus = BattleStatus.Ending
	TrickHandler.FinishBattle()
	-- Time Up Sequence
	FireTimeUpEvent()
	task.wait(1)
	
	-- White Fade Out
	FireFadeEvent(true, true)
	task.wait(Define.TIME_UP_DISPLAY_TIME) -- Wait for fade out to complete before doing heavy work

	-- Freeze all participants (Players + NPCs)
	FreezeParticipants()

	local topRanking = UpdateRanking()
	PodiumHandler.Display(topRanking, battleParticipants)

	WandAssigner.RemoveWands(battleParticipants.players)

	-- Fade In
	FireFadeEvent(false, true)
	
	-- Wait for cutscene
	task.wait(Define.PODIUM_CUTSCENE_TIME -1 )
	FireBattleStatus(false)
	UnfreezeParticipants(battleParticipants.players) -- Only unfreeze players as NPCs are destroyed
	TeleportToLobby()

	NpcManager.StopBattle()
	--HouseBaseManager.DestroyAll()
	battleParticipants.npcs = {}
	battleParticipants.players = {}
	hitCounts = {}
	currentBattleStatus = BattleStatus.Idle
end

-- 途中参加・退出の監視
local function TeleportPlayerToRandomSpawn(player: Player)
	local spawnFolder = workspace:FindFirstChild("SpawnPositions")
	if spawnFolder and player.Character then
		local spawns = spawnFolder:GetChildren()
		if #spawns > 0 then
			local rng = Random.new()
			local sp = spawns[rng:NextInteger(1, #spawns)]
			local part = sp.PrimaryPart or sp:FindFirstChildWhichIsA("BasePart")
			if part then
				player.Character:PivotTo(part.CFrame)
			end
		end
	end
end

local function OnPlayerAdded(player: Player)
	print("BattleManager: Player joined: " .. player.Name .. ", currentBattleStatus=" .. currentBattleStatus) 
	
	player.CharacterAdded:Connect(function(character)
		print("BattleManager:CharacterAdded begins:".. currentBattleStatus )
		if currentBattleStatus == BattleStatus.Idle or currentBattleStatus == BattleStatus.Ending then
			return
		end
		
		-- Check if player is already participating
		for _, p in ipairs(battleParticipants.players) do
			if p == character then
				return
			end
		end

		-- NPCがいれば交代する
		print("BattleManager:CharacterAdded: #npc=", #battleParticipants.npcs)
		if #battleParticipants.npcs > 0 then
			local npcToRemove = table.remove(battleParticipants.npcs, 1)
			if npcToRemove then
				print("Swapping NPC " .. npcToRemove.Name .. " for Player " .. player.Name)
				hitCounts[npcToRemove.Name] = nil -- Clean up NPC score
				npcToRemove:Destroy()
				
				table.insert(battleParticipants.players, character)
				hitCounts[player.Name] = 0 -- Init player score
				
				task.wait(0.5) -- Wait for character load

				if currentBattleStatus == BattleStatus.Preparing then
					-- Just add to list, do nothing else as Start() will handle it
					print("Player joined during Preparing phase - simply added to list")
				elseif currentBattleStatus == BattleStatus.Countdown or currentBattleStatus == BattleStatus.Transitioning then
					-- Teleport and freeze
					TeleportPlayerToRandomSpawn(player)
					FreezeParticipants({character})
					print("Player joined during Countdown/Transition - teleported and frozen")
				elseif currentBattleStatus == BattleStatus.Active then
					-- Teleport and give wand
					TeleportPlayerToRandomSpawn(player)
					WandAssigner.AssignRandomWands({character})
					BarrierCharacter(character, 3) -- Grant barrier on late join
					GetRemoteEvent("TeleportEvent"):FireClient(player) -- Ensure camera/etc if needed
					print("Player joined during Active phase - teleported and equipped")
				end
			end
		end
	end)
end

local function OnPlayerRemoving(player: Player)
	-- バトル参加者から削除
	for i, char in ipairs(battleParticipants.players) do
		if char.Name == player.Name then
			table.remove(battleParticipants.players, i)
			hitCounts[player.Name] = nil
			break
		end
	end
end

playerAddedConnection = Players.PlayerAdded:Connect(OnPlayerAdded)
playerRemovingConnection = Players.PlayerRemoving:Connect(OnPlayerRemoving)


function BattleManager.OnHit(shooterCharacterName: string, targetCharacterName: string)
	if hitCounts[shooterCharacterName] then
		hitCounts[shooterCharacterName] = hitCounts[shooterCharacterName] + 1
		print(shooterCharacterName .. " hit " .. targetCharacterName .. " (total hits: " .. hitCounts[shooterCharacterName] .. ")")
	end

	UpdateRanking()

	StunCharacter(targetCharacterName, 10)
end

function BattleManager.GetHitCounts()
	return hitCounts
end

return BattleManager
