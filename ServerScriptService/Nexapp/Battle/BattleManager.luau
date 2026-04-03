local Players = game:GetService("Players")
local NpcManager = require(script.Parent:WaitForChild("NpcManager"))
local TrickHandler = require(script.Parent.TrickHandler)
local PodiumHandler = require(script.Parent.PodiumHandler)
local WandAssigner = require(script.Parent.WandAssigner)
local Define = require(game:GetService("ReplicatedFirst").Nexapp.Common.Define)

local BattleManager = {}

-- ===================== 定数 =====================
local MAX_PARTICIPANTS       = 8
local DEFAULT_WALK_SPEED     = 16
local TEAM_SELECTION_TIMEOUT = 15   -- チーム選択タイムアウト (秒)

-- ===================== 状態変数 =====================
local battleParticipants = { npcs = {}, players = {} }
local hitCounts = {}

local teams = {
	blue = { leader = nil :: Model?, members = {} :: { Model }, hitCount = 0 },
	red  = { leader = nil :: Model?, members = {} :: { Model }, hitCount = 0 },
}
local participantTeam: { [string]: string } = {}  -- [characterName] = "blue" | "red"
local originalDescriptions: { [string]: HumanoidDescription } = {}  -- バトル前の外見を保存

local BattleStatus = {
	Idle          = "Idle",
	Preparing     = "Preparing",
	Transitioning = "Transitioning",
	TeamSelection = "TeamSelection",
	Countdown     = "Countdown",
	Active        = "Active",
	Ending        = "Ending",
}
local currentBattleStatus = BattleStatus.Idle
local playerAddedConnection: RBXScriptConnection?
local playerRemovingConnection: RBXScriptConnection?

-- ===================== RemoteEvent =====================
local function GetRemoteEvent(eventName: string): RemoteEvent
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local folder = ReplicatedStorage:FindFirstChild("RemoteEvent")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RemoteEvent"
		folder.Parent = ReplicatedStorage
	end
	local event = folder:FindFirstChild(eventName)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = eventName
		event.Parent = folder
	end
	return event
end

-- ===================== Remote Fire =====================
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

-- ===================== 参加者ユーティリティ =====================
local function GetAllParticipants(): { Model }
	local all = {}
	for _, p in ipairs(battleParticipants.players) do table.insert(all, p) end
	for _, n in ipairs(battleParticipants.npcs) do table.insert(all, n) end
	return all
end

local function IsPlayerCharacter(character: Model): boolean
	return Players:GetPlayerFromCharacter(character) ~= nil
end

-- ===================== チーム管理 =====================
local function AssignToTeam(character: Model, teamName: string)
	participantTeam[character.Name] = teamName
	table.insert(teams[teamName].members, character)
end

local function RemoveFromTeam(character: Model)
	local team = participantTeam[character.Name]
	if team then
		for i, m in ipairs(teams[team].members) do
			if m == character then
				table.remove(teams[team].members, i)
				break
			end
		end
		participantTeam[character.Name] = nil
	end
end

local function IsSameTeam(nameA: string, nameB: string): boolean
	local teamA = participantTeam[nameA]
	local teamB = participantTeam[nameB]
	return teamA ~= nil and teamB ~= nil and teamA == teamB
end

local function GetParticipantTeam(name: string): string?
	return participantTeam[name]
end

-- ===================== キャラクター操作 =====================
local function BarrierCharacter(targetCharacter: Model, duration: number?): Model?
	local ServerStorage = game:GetService("ServerStorage")
	local barrierTemplate = ServerStorage:FindFirstChild("BarrierModel")
	if not barrierTemplate then return nil end

	local barrier = barrierTemplate:Clone()
	barrier.Parent = targetCharacter

	local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	local barrierPart = barrier.PrimaryPart or barrier:FindFirstChildWhichIsA("BasePart")
	if targetHRP and barrierPart then
		barrierPart.CFrame = targetHRP.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = targetHRP
		weld.Part1 = barrierPart
		weld.Parent = barrierPart
	end

	game.Debris:AddItem(barrier, duration or 10)
	return barrier
end

local function GrantBarrierToAllParticipants()
	for _, p in ipairs(battleParticipants.players) do BarrierCharacter(p, 3) end
	for _, n in ipairs(battleParticipants.npcs) do BarrierCharacter(n, 3) end
end

local function StunCharacter(targetCharacterName: string, stunDuration: number)
	local targetCharacter: Model?
	for _, char in ipairs(battleParticipants.players) do
		if char.Name == targetCharacterName then targetCharacter = char; break end
	end
	if not targetCharacter then
		for _, char in ipairs(battleParticipants.npcs) do
			if char.Name == targetCharacterName then targetCharacter = char; break end
		end
	end

	if targetCharacter then
		local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			targetCharacter:SetAttribute("IsStunned", true)
			task.spawn(BarrierCharacter, targetCharacter, stunDuration + 5)
			task.wait(stunDuration)
			humanoid.WalkSpeed = DEFAULT_WALK_SPEED
			targetCharacter:SetAttribute("IsStunned", nil)
		end
	end
end

local function FreezeParticipants(participants: { Model }?)
	local targets = participants
	if not targets then
		targets = GetAllParticipants()
	end
	for _, character in ipairs(targets) do
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if hrp then hrp.Anchored = true end
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop() end
			end
		end
		local barrier = character:FindFirstChild("BarrierModel")
		if barrier then barrier:Destroy() end
	end
end

local function UnfreezeParticipants(participants: { Model })
	for _, character in ipairs(participants) do
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if hrp then hrp.Anchored = false end
		if humanoid then
			humanoid.WalkSpeed = DEFAULT_WALK_SPEED
			humanoid.JumpPower = 50
		end
	end
end

-- ===================== テレポート =====================
local function TeleportParticipants()
	local spawnFolder = workspace:FindFirstChild("SpawnPositions")
	local spawnCFrames = {}
	if spawnFolder then
		for _, sp in ipairs(spawnFolder:GetChildren()) do
			if sp:IsA("Model") and sp.Name == "SpawnPosition" then
				local part = sp.PrimaryPart or sp:FindFirstChildWhichIsA("BasePart")
				if part then table.insert(spawnCFrames, part.CFrame) end
			end
		end
	end

	local allParticipants = GetAllParticipants()
	if #allParticipants == 0 then return end

	local rng = Random.new(tick())
	for i = #spawnCFrames, 2, -1 do
		local j = rng:NextInteger(1, i)
		spawnCFrames[i], spawnCFrames[j] = spawnCFrames[j], spawnCFrames[i]
	end

	for idx, model in ipairs(allParticipants) do
		if model and spawnCFrames[idx] then
			model:PivotTo(spawnCFrames[idx])
		end
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			GetRemoteEvent("TeleportEvent"):FireClient(player)
		end
	end
end

local function TeleportToLobby()
	local lobby = workspace:FindFirstChild("Lobby")
	local spawnLocation = if lobby then lobby:FindFirstChild("SpawnLocation") else nil
	if spawnLocation and spawnLocation:IsA("BasePart") then
		local rng = Random.new()
		for _, char in ipairs(battleParticipants.players) do
			if char and char.Parent then
				local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					char:PivotTo(spawnLocation.CFrame * CFrame.new(rng:NextNumber(-2, 2), 3, rng:NextNumber(-2, 2)))
				end
			end
		end
	end
end

local function TeleportPlayerToRandomSpawn(player: Player)
	local spawnFolder = workspace:FindFirstChild("SpawnPositions")
	if spawnFolder and player.Character then
		local spawns = spawnFolder:GetChildren()
		if #spawns > 0 then
			local rng = Random.new()
			local sp = spawns[rng:NextInteger(1, #spawns)]
			local part = sp.PrimaryPart or sp:FindFirstChildWhichIsA("BasePart")
			if part then player.Character:PivotTo(part.CFrame) end
		end
	end
end

-- ===================== ランキング =====================
local function UpdateRanking()
	local rankingData = {}
	for name, count in pairs(hitCounts) do
		local isNpc = true
		local userId = 0
		local player = Players:FindFirstChild(name)
		if player then
			isNpc = false
			userId = player.UserId
		end
		table.insert(rankingData, { Name = name, Score = count, IsNpc = isNpc, UserId = userId })
	end

	table.sort(rankingData, function(a, b) return a.Score > b.Score end)

	local topRanking = {}
	for i = 1, math.min(8, #rankingData) do
		table.insert(topRanking, rankingData[i])
	end

	GetRemoteEvent("RankingUpdate"):FireAllClients(topRanking)
	return topRanking
end

-- ===================== チーム選択フェーズ =====================

-- Fieldの両端CFrameを取得する
local function GetFieldEndCFrames(): (CFrame, CFrame)
	local battlefield = workspace:FindFirstChild("BattleField")
	local field = battlefield and battlefield:FindFirstChild("Field")

	local center = CFrame.new(0, 0, 0)
	local halfLen = 40

	if field then
		if field:IsA("BasePart") then
			center = field.CFrame
			-- X/Z の長い方を長辺とみなす
			local size = (field :: BasePart).Size
			halfLen = math.max(size.X, size.Z) / 2 - 5
		elseif field:IsA("Model") then
			local pivot, size = (field :: Model):GetBoundingBox()
			center = pivot
			halfLen = math.max(size.X, size.Z) / 2 - 5
		end
	end

	-- 青が-Z端、赤が+Z端
	local blueCFrame = center * CFrame.new(0, 0, -halfLen)
	local redCFrame  = center * CFrame.new(0, 0,  halfLen)
	return blueCFrame, redCFrame
end


-- 未選択者を人数が均等になるようチームに振り分ける
local function BalanceUndecided(undecided: { Model })
	for _, character in ipairs(undecided) do
		local teamName = if #teams.blue.members <= #teams.red.members then "blue" else "red"
		AssignToTeam(character, teamName)
		print("[TeamBalance] Timeout: auto-assigned " .. character.Name .. " → " .. teamName)
	end
end

-- メンバー（リーダー含む全員）が UI でチームを選択するフェーズ
local function RunTeamSelectionPhase(participants: { Model })
	local assigned: { [Model]: boolean } = {}
	local selectedCount = 0
	local totalParticipants = #participants
	local teamMemberIndex = { blue = 0, red = 0 }

	-- NPCはこれまで通り自動ランダム選択で即時割り当て
	for _, character in ipairs(participants) do
		if not IsPlayerCharacter(character) then
			local rng = Random.new()
			local chosenTeam = if rng:NextInteger(1, 2) == 1 then "blue" else "red"
			assigned[character] = true
			selectedCount += 1
			AssignToTeam(character, chosenTeam)
			teamMemberIndex[chosenTeam] += 1
		end
	end

	-- クライアントへUI表示を要求
	local showTeamSelectionEvent = GetRemoteEvent("ShowTeamSelectionEvent")
	showTeamSelectionEvent:FireAllClients(teams.blue.leader, teams.red.leader)

	-- クライアントからの選択受付イベント
	local teamSelectedEvent = GetRemoteEvent("OnTeamSelectedEvent")
	local connection = teamSelectedEvent.OnServerEvent:Connect(function(player, chosenTeam)
		if type(chosenTeam) ~= "string" then return end
		if chosenTeam ~= "blue" and chosenTeam ~= "red" then return end

		local character = player.Character
		-- participantsに含まれるか、まだ選択していないかチェック
		if character and not assigned[character] then
			local isParticipant = false
			for _, p in ipairs(participants) do
				if p == character then isParticipant = true; break end
			end
			if isParticipant then
				assigned[character] = true
				selectedCount += 1
				AssignToTeam(character, chosenTeam)
				teamMemberIndex[chosenTeam] += 1
				print("[TeamSelect] UI: " .. character.Name .. " → " .. chosenTeam)
			end
		end
	end)

	-- タイムアウト管理 (待機ポーリング)
	local startTime = tick()
	while selectedCount < totalParticipants and (tick() - startTime) < TEAM_SELECTION_TIMEOUT do
		task.wait(0.2)
	end

	local timedOut = (selectedCount < totalParticipants)
	connection:Disconnect()
	
	-- UI側にタイムアウトを知らせるイベントを通達(任意で利用)
	GetRemoteEvent("TeamSelectionEndEvent"):FireAllClients()

	-- タイムアウト時: 未選択者を均等割り振り
	if timedOut then
		print("[TeamSelect] Timeout! Balancing undecided members...")
		local undecided = {}
		for _, character in ipairs(participants) do
			if not assigned[character] then
				table.insert(undecided, character)
			end
		end
		BalanceUndecided(undecided)

		-- 未選択者も整列させる
		for _, character in ipairs(undecided) do
			local teamName = participantTeam[character.Name]
			if teamName then
				teamMemberIndex[teamName] += 1
			end
		end
	end

	-- 整列完了まで待つ
	task.wait(3)
	print("[TeamSelect] Done. Blue=" .. #teams.blue.members .. " / Red=" .. #teams.red.members)
end

-- リーダーを選出してチームに設定する (プレイヤーを優先)
local function SelectTeamLeaders(allParticipants: { Model })
	local rng = Random.new(tick())
	local playerPool = {}
	local npcPool = {}

	for _, m in ipairs(allParticipants) do
		if IsPlayerCharacter(m) then
			table.insert(playerPool, m)
		else
			table.insert(npcPool, m)
		end
	end

	-- それぞれをシャッフル
	local function Shuffle(pool)
		for i = #pool, 2, -1 do
			local j = rng:NextInteger(1, i)
			pool[i], pool[j] = pool[j], pool[i]
		end
	end

	Shuffle(playerPool)
	Shuffle(npcPool)

	-- プレイヤーを先頭に、NPCを後ろにしてプールを統合
	local pool = {}
	for _, m in ipairs(playerPool) do table.insert(pool, m) end
	for _, m in ipairs(npcPool) do table.insert(pool, m) end

	teams.blue.leader = pool[1]
	teams.red.leader  = pool[2]

	-- リーダー自身のチームを確定（members ではなく leader として扱う）
	participantTeam[pool[1].Name] = "blue"
	participantTeam[pool[2].Name] = "red"

	print("[TeamSelect] Blue leader=" .. pool[1].Name .. " / Red leader=" .. pool[2].Name)
end

-- チーム選択フェーズ全体を実行する
local function ExecuteTeamSelectionPhase()
	local allParticipants = GetAllParticipants()

	-- 1. リーダー選出
	SelectTeamLeaders(allParticipants)

	-- 2. Fieldの両端を計算してリーダーを配置
	local blueCF, redCF = GetFieldEndCFrames()
	if teams.blue.leader then
		local facingDir = redCF.Position
		local pos = blueCF.Position + Vector3.new(0, 1.5, 0)
		teams.blue.leader:PivotTo(CFrame.lookAt(pos, Vector3.new(facingDir.X, pos.Y, facingDir.Z)))
	end
	if teams.red.leader then
		local facingDir = blueCF.Position
		local pos = redCF.Position + Vector3.new(0, 1.5, 0)
		teams.red.leader:PivotTo(CFrame.lookAt(pos, Vector3.new(facingDir.X, pos.Y, facingDir.Z)))
	end

	-- 3. リーダーを含む全員が UI でチームを選択
	RunTeamSelectionPhase(allParticipants)
end

-- ===================== チーム外見統一 =====================

-- リーダーの HumanoidDescription を取得する
local function GetLeaderHumanoidDescription(leader: Model): HumanoidDescription?
	-- プレイヤーキャラなら UserId から取得（最も正確）
	local player = Players:GetPlayerFromCharacter(leader)
	if player then
		local success, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if success and desc then return desc end
	end

	-- NPC または取得失敗時: Humanoid の AppliedDescription から取得
	local humanoid = leader:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local success, desc = pcall(function()
			return humanoid:GetAppliedDescription()
		end)
		if success and desc then return desc end
	end

	return nil
end

-- 各チームメンバーの見た目をリーダーに揃える
local function ApplyTeamAppearance()
	for _, teamName in ipairs({"blue", "red"}) do
		local team = teams[teamName]
		local leader = team.leader
		if not leader then continue end

		local desc = GetLeaderHumanoidDescription(leader)
		if not desc then
			warn("[Appearance] Could not get HumanoidDescription for leader: " .. leader.Name)
			continue
		end

		-- リーダー本人 + 全メンバーに適用
		local targets = { leader }
		for _, member in ipairs(team.members) do
			table.insert(targets, member)
		end

		for _, character in ipairs(targets) do
			task.spawn(function()
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid then return end
				local success, err = pcall(function()
					humanoid:ApplyDescription(desc)
				end)
				if not success then
					warn("[Appearance] ApplyDescription failed for " .. character.Name .. ": " .. tostring(err))
				end
			end)
		end

		print("[Appearance] Applied " .. leader.Name .. "'s look to " .. #targets .. " members (" .. teamName .. " team)")
	end
end

-- バトル開始前に全プレイヤー参加者の HumanoidDescription を保存する
local function SaveParticipantDescriptions()
	originalDescriptions = {}
	for _, character in ipairs(battleParticipants.players) do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then continue end
		local success, desc = pcall(function()
			return humanoid:GetAppliedDescription()
		end)
		if success and desc then
			originalDescriptions[character.Name] = desc
			print("[Appearance] Saved description for " .. character.Name)
		end
	end
end

-- バトル終了後に全プレイヤー参加者の外見を元に戻す
local function RestoreParticipantDescriptions()
	for _, character in ipairs(battleParticipants.players) do
		local savedDesc = originalDescriptions[character.Name]
		if not savedDesc then continue end
		task.spawn(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			local success, err = pcall(function()
				humanoid:ApplyDescription(savedDesc)
			end)
			if not success then
				warn("[Appearance] Restore failed for " .. character.Name .. ": " .. tostring(err))
			end
		end)
	end
	print("[Appearance] Restored original appearances for " .. #battleParticipants.players .. " players")
end

-- ===================== ルーレット表示（既存機能）=====================
local function ShowRouletteOnClient(allParticipants: { Model }, selection: { Model })
	local rouletteEvent = GetRemoteEvent("ShowRoulette")

	local function CreateData(model: Model): {}
		local name = model.Name
		local isNpc = true
		local userId = 0
		local player = Players:FindFirstChild(name)
		if player then
			isNpc = false
			userId = player.UserId
		end
		return { Name = name, IsNpc = isNpc, UserId = userId }
	end

	local allData, selData = {}, {}
	for _, m in ipairs(allParticipants) do table.insert(allData, CreateData(m)) end
	for _, m in ipairs(selection) do table.insert(selData, CreateData(m)) end
	rouletteEvent:FireAllClients(allData, selData)
end

-- ===================== BattleManager Public API =====================

function BattleManager.IsSameTeam(nameA: string, nameB: string): boolean
	return IsSameTeam(nameA, nameB)
end

function BattleManager.GetParticipantTeam(name: string): string?
	return GetParticipantTeam(name)
end

function BattleManager.GetParticipants()
	return battleParticipants
end

function BattleManager.GetHitCounts()
	return hitCounts
end

function BattleManager.Start()
	print("BattleManager.Start")
	currentBattleStatus = BattleStatus.Preparing
	PodiumHandler.Reset()

	-- RemoteEventの事前生成 (クライアントのWaitForChild漏れを防ぐ)
	GetRemoteEvent("ShowTeamSelectionEvent")
	GetRemoteEvent("OnTeamSelectedEvent")
	GetRemoteEvent("TeamSelectionEndEvent")

	-- 状態リセット
	battleParticipants.players = {}
	battleParticipants.npcs    = {}
	hitCounts = {}
	teams.blue = { leader = nil, members = {}, hitCount = 0 }
	teams.red  = { leader = nil, members = {}, hitCount = 0 }
	participantTeam = {}

	-- 1. プレイヤーキャラ収集
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(battleParticipants.players, player.Character)
			hitCounts[player.Character.Name] = 0
		end
	end

	-- 2. NPC補充 (MAX_PARTICIPANTS に満たない分)
	local npcNum = math.max(0, MAX_PARTICIPANTS - #battleParticipants.players)
	local npcClones = NpcManager.StartBattle(npcNum)
	battleParticipants.npcs = npcClones
	for _, npc in ipairs(npcClones) do
		hitCounts[npc.Name] = 0
	end

	-- 3. フェードアウト & テレポート
	currentBattleStatus = BattleStatus.Transitioning
	FireFadeEvent(true, true)
	task.wait(2)
	TeleportParticipants()
	task.wait(0.5)
	FreezeParticipants()

	-- 4. フェードイン
	FireFadeEvent(false, true)
	task.wait(1)

	-- 5. チーム選択フェーズ（アンフリーズしてから実施）
	UnfreezeParticipants(GetAllParticipants())
	currentBattleStatus = BattleStatus.TeamSelection
	ExecuteTeamSelectionPhase()

	-- 5.5 チームメンバーの見た目をリーダーに統一
	-- (適用前に全員の元の外見を保存)
	SaveParticipantDescriptions()
	ApplyTeamAppearance()
	task.wait(1) -- 外見適用の完了を待つ

	-- 6. 全員フリーズしてカウントダウン
	FreezeParticipants()
	currentBattleStatus = BattleStatus.Countdown
	FireCountDownEvent()
	task.wait(4) -- 3, 2, 1, GO

	-- 7. バトルスタート
	UnfreezeParticipants(battleParticipants.players)
	UnfreezeParticipants(battleParticipants.npcs)
	TrickHandler.StartBattle(BattleManager.OnHit, BattleManager.IsSameTeam)
	FireBattleStatus(true)
	currentBattleStatus = BattleStatus.Active

	GrantBarrierToAllParticipants()
	WandAssigner.AssignRandomWands(battleParticipants.players)

	print("Battle started! Blue=" .. #teams.blue.members .. " / Red=" .. #teams.red.members)
	return battleParticipants
end

function BattleManager.OnHit(shooterCharacterName: string, targetCharacterName: string)
	-- 同チームへのヒットは無効
	if IsSameTeam(shooterCharacterName, targetCharacterName) then
		print("[Hit] Same team – ignored: " .. shooterCharacterName .. " → " .. targetCharacterName)
		return
	end

	-- 個人スコア更新
	if hitCounts[shooterCharacterName] then
		hitCounts[shooterCharacterName] = hitCounts[shooterCharacterName] + 1
	end

	-- チームスコア更新
	local shooterTeam = participantTeam[shooterCharacterName]
	if shooterTeam then
		teams[shooterTeam].hitCount = teams[shooterTeam].hitCount + 1
	end

	print("[Hit] " .. shooterCharacterName .. " → " .. targetCharacterName
		.. " (team=" .. (shooterTeam or "?")
		.. ", personal=" .. tostring(hitCounts[shooterCharacterName])
		.. ", blue=" .. teams.blue.hitCount .. ", red=" .. teams.red.hitCount .. ")")

	UpdateRanking()
	task.spawn(StunCharacter, targetCharacterName, 10)
end

function BattleManager.Stop()
	currentBattleStatus = BattleStatus.Ending
	TrickHandler.FinishBattle()

	FireTimeUpEvent()
	task.wait(1)

	FireFadeEvent(true, true)
	task.wait(Define.TIME_UP_DISPLAY_TIME)

	FreezeParticipants()

	local topRanking = UpdateRanking()

	-- チーム勝敗判定
	local winner = if teams.blue.hitCount >= teams.red.hitCount then "blue" else "red"
	print("[Result] " .. winner .. " wins! (blue=" .. teams.blue.hitCount .. " / red=" .. teams.red.hitCount .. ")")
	GetRemoteEvent("TeamBattleResult"):FireAllClients(winner, teams.blue.hitCount, teams.red.hitCount)

	PodiumHandler.Display(topRanking, battleParticipants)
	WandAssigner.RemoveWands(battleParticipants.players)

	FireFadeEvent(false, true)
	task.wait(Define.PODIUM_CUTSCENE_TIME - 1)

	FireBattleStatus(false)
	UnfreezeParticipants(battleParticipants.players)
	TeleportToLobby()

	-- 参加者の見た目をバトル前の状態に戻す
	RestoreParticipantDescriptions()

	-- 状態リセット
	NpcManager.StopBattle()
	battleParticipants.npcs    = {}
	battleParticipants.players = {}
	hitCounts = {}
	teams.blue = { leader = nil, members = {}, hitCount = 0 }
	teams.red  = { leader = nil, members = {}, hitCount = 0 }
	participantTeam = {}
	originalDescriptions = {}
	currentBattleStatus = BattleStatus.Idle
end

-- ===================== 途中参加・退出の監視 =====================
local function OnPlayerAdded(player: Player)
	print("BattleManager: Player joined: " .. player.Name .. ", status=" .. currentBattleStatus)

	player.CharacterAdded:Connect(function(character)
		if currentBattleStatus == BattleStatus.Idle or currentBattleStatus == BattleStatus.Ending then return end

		-- 既に参加済みかチェック
		for _, p in ipairs(battleParticipants.players) do
			if p == character then return end
		end

		-- NPCと交代
		if #battleParticipants.npcs > 0 then
			local npcToRemove = table.remove(battleParticipants.npcs, 1)
			if npcToRemove then
				print("Swapping NPC " .. npcToRemove.Name .. " for Player " .. player.Name)
				hitCounts[npcToRemove.Name] = nil
				RemoveFromTeam(npcToRemove)
				npcToRemove:Destroy()

				table.insert(battleParticipants.players, character)
				hitCounts[player.Name] = 0
				task.wait(0.5)

				if currentBattleStatus == BattleStatus.Preparing then
					print("Joined during Preparing – added to list")

				elseif currentBattleStatus == BattleStatus.Transitioning
					or currentBattleStatus == BattleStatus.Countdown then
					TeleportPlayerToRandomSpawn(player)
					FreezeParticipants({ character })

				elseif currentBattleStatus == BattleStatus.TeamSelection then
					TeleportPlayerToRandomSpawn(player)
					-- 人数が少ない方のチームに自動割り当て
					local teamName = if #teams.blue.members <= #teams.red.members then "blue" else "red"
					AssignToTeam(character, teamName)
					print("Joined during TeamSelection – auto-assigned to " .. teamName)

				elseif currentBattleStatus == BattleStatus.Active then
					TeleportPlayerToRandomSpawn(player)
					local teamName = if #teams.blue.members <= #teams.red.members then "blue" else "red"
					AssignToTeam(character, teamName)
					WandAssigner.AssignRandomWands({ character })
					BarrierCharacter(character, 3)
					GetRemoteEvent("TeleportEvent"):FireClient(player)
					print("Joined during Active – team=" .. teamName)
				end
			end
		end
	end)
end

local function OnPlayerRemoving(player: Player)
	for i, char in ipairs(battleParticipants.players) do
		if char.Name == player.Name then
			table.remove(battleParticipants.players, i)
			hitCounts[player.Name] = nil
			RemoveFromTeam(char)
			break
		end
	end
end

playerAddedConnection   = Players.PlayerAdded:Connect(OnPlayerAdded)
playerRemovingConnection = Players.PlayerRemoving:Connect(OnPlayerRemoving)

return BattleManager
