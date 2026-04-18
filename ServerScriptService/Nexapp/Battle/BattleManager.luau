local Players = game:GetService("Players")
local NpcManager = require(script.Parent:WaitForChild("NpcManager"))
local TrickHandler = require(script.Parent.TrickHandler)
local PodiumHandler = require(script.Parent.PodiumHandler)
local WandAssigner = require(script.Parent.WandAssigner)
local Define = require(game:GetService("ReplicatedFirst").Nexapp.Common.Define)
local PlayerManager = require(game:GetService("ServerScriptService").Nexapp.Player.PlayerManager)

local BattleManager = {}

-- ===================== 定数 =====================
local MIN_PARTICIPANTS       = 8
local MIN_NPCS               = 2
local DEFAULT_WALK_SPEED     = 16
local TEAM_SELECTION_TIMEOUT = 15   -- チーム選択タイムアウト (秒)

-- ===================== 状態変数 =====================
local battleParticipants = { npcs = {}, players = {} }
local hitCounts = {}

local teams = {
	blue = { avatar = nil :: Model?, avatarCache = nil :: Model?, members = {} :: { Model }, hitCount = 0 },
	red  = { avatar = nil :: Model?, avatarCache = nil :: Model?, members = {} :: { Model }, hitCount = 0 },
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
local playerRemovingConnection: RBXScriptConnection?
local joinedPlayers: { [Player]: boolean } = {}  -- 「参加する」ボタンを押したプレイヤーのセット
local chosenAvatars: { Model } = {} -- "Choose my Avatar"チケットで立候補したアバター

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

-- BattleJoinEvent等のリスナを設定する
local eventsSetupDone = false
local function SetupEvents()
	if eventsSetupDone then return end
	eventsSetupDone = true
	
	-- リモートイベントの事前生成
	GetRemoteEvent("HideChooseMyAvatarEvent")
	
	local joinEv = GetRemoteEvent("BattleJoinEvent")
	joinEv.OnServerEvent:Connect(function(player: Player)
		-- バトルがアクティブ中は受付けない
		if currentBattleStatus ~= BattleStatus.Idle then return end
		joinedPlayers[player] = true
		print("[Join] " .. player.Name .. " joined the next battle")
	end)

	local chooseEv = GetRemoteEvent("OnChooseMyAvatarEvent")
	chooseEv.OnServerEvent:Connect(function(player: Player)
		if currentBattleStatus ~= BattleStatus.Preparing and currentBattleStatus ~= BattleStatus.Idle and currentBattleStatus ~= BattleStatus.TeamSelection then 
			-- TeamSelection フェーズ（ルーレット中など）も含まれるようにする
			-- 厳密には、ExecuteTeamSelectionPhase()中だが、currentBattleStatusはTeamSelectionになっているか？
			-- 実際はExecuteTeamSelectionPhase内でTransitioningからTeamSelection等に変わるかもしれない。
			-- ひとまず、選ばれる数が2未満かチェックする。
		end
		
		if #chosenAvatars >= 2 then
			return -- 既に2人選ばれている
		end
		
		-- playerが参加者にいるか確認
		local character = player.Character
		if not character then return end
		
		local inParticipants = false
		for _, c in ipairs(battleParticipants.players) do
			if c == character then inParticipants = true break end
		end
		if not inParticipants then return end
		
		-- チケットチェック
		local gp = PlayerManager.GetGamePlayer(player)
		if not gp then return end
		local pd = gp:GetPlayerData()
		if not pd then return end
		
		local tickets = pd:GetChooseAvatarTicket()
		if tickets > 0 then
			-- 重複立候補チェック
			for _, c in ipairs(chosenAvatars) do
				if c == character then return end
			end
			
			pd:SetChooseAvatarTicket(tickets - 1)
			table.insert(chosenAvatars, character)
			print("[ChooseMyAvatar] " .. player.Name .. " used a ticket! Remaining: " .. (tickets - 1))
			
			if #chosenAvatars >= 2 then
				FireParticipants(GetRemoteEvent("HideChooseMyAvatarEvent"))
			end
		end
	end)
end

-- ===================== Remote Fire =====================

-- バトル参加者のプレイヤーにのみ FireClient するユーティリティ
local function FireParticipants(event: RemoteEvent, ...)
	for _, character in ipairs(battleParticipants.players) do
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			event:FireClient(player, ...)
		end
	end
end

local function FireBattlePhaseUpdate(targetPlayer: Player?)
	local ev = GetRemoteEvent("BattlePhaseUpdate")
	if targetPlayer then
		ev:FireClient(targetPlayer, currentBattleStatus)
	else
		FireParticipants(ev, currentBattleStatus)
	end
end

local function UpdateBattleStatus(newStatus: string)
	currentBattleStatus = newStatus
	FireBattlePhaseUpdate()
end

local function FireBattleStatus(isActive: boolean)
	FireParticipants(GetRemoteEvent("BattleStatus"), isActive)
end

local function FireFadeEvent(isOut: boolean, isWhite: boolean?)
	FireParticipants(GetRemoteEvent("FadeEvent"), isOut, isWhite)
end

local function FireTimeUpEvent(winner: string)
	FireParticipants(GetRemoteEvent("TimeUpEvent"), winner)
end

local function FireHintEvent(message: string, duration: number)
	FireParticipants(GetRemoteEvent("HintEvent"), message, duration)
end

local function FireCountDownEvent()
	FireParticipants(GetRemoteEvent("CountDownEvent"))
end

-- Gem獲得通知を特定プレイヤーに送る
local function FireGemGetEvent(player: Player, description: string, count: number, playSeName: string)
	print("[GemGetEvent] " .. player.Name .. " got " .. count .. " gems")
	GetRemoteEvent("GemGetEvent"):FireClient(player, description, count, playSeName)
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

local function IsParticipant(name: string): boolean
	return participantTeam[name] ~= nil
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
			task.spawn(BarrierCharacter, targetCharacter, stunDuration + 3)
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

-- ===================== 整列 =====================

-- チームメンバーをPositionPart（長方形）の長辺方向に一列に並べ、互いに向き合わせる
local function LineUpTeam(teamName: string, positionPart: BasePart, lookAtPosition: Vector3)
	local members = teams[teamName].members
	if #members == 0 then return end

	-- Partのサイズ・CFrameを取得
	local partCFrame  = positionPart.CFrame
	local partSizeX   = positionPart.Size.X  -- 長辺（横方向）
	local partSizeZ   = positionPart.Size.Z  -- 短辺（奥行き）
	local partSizeY   = positionPart.Size.Y  -- 高さ（板の厚み）

	-- 長辺の方向（PartのRightVector）に沿って並べる
	local rightVec = partCFrame.RightVector
	local center   = partCFrame.Position

	-- メンバー数に応じた間隔を計算（端に余白を持たせる）
	local count   = #members
	local margin  = 12  -- 両端の最小余白(studs) ← 中央寄りに調整
	local usable  = partSizeX - margin * 2
	local spacing = if count > 1 then usable / (count - 1) else 0

	-- Partの上面（Y + partSizeY/2 + キャラ高さの半分）に乗せる
	local yOffset = partSizeY / 2 + 3  -- 3 studs = キャラ重心分

	-- 向かい合う方向を計算（lookAtPositionの水平方向）
	local dirToOpponent = (Vector3.new(lookAtPosition.X, center.Y, lookAtPosition.Z) - Vector3.new(center.X, center.Y, center.Z)).Unit
	local lookCFrame    = CFrame.new(Vector3.zero, dirToOpponent)

	for i, character in ipairs(members) do
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then continue end

		-- 先頭から末尾への offset
		local t = if count > 1 then (i - 1) / (count - 1) else 0.5
		local offset = rightVec * (-usable / 2 + t * usable)
		local pos    = center + offset + Vector3.new(0, yOffset, 0)

		-- CFrame: posに移動 + 相手陣地の方向を向く
		local cf = CFrame.new(pos) * CFrame.fromMatrix(Vector3.zero, lookCFrame.RightVector, lookCFrame.UpVector)

		-- HRPをアンカーしてから配置（他の処理とかぶるが整列時は必ず]
		hrp.Anchored = false  -- 一瞬アンアンカーしてPivotToを正常動作させる
		character:PivotTo(cf)
		hrp.Anchored = true
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			GetRemoteEvent("TeleportEvent"):FireClient(player)
		end
	end
end

-- 両チームをそれぞれのPositionPartに整列させてフリーズする
local function LineUpAndFreezeTeams()
	local battlefield = workspace:FindFirstChild("BattleField")
	if not battlefield then
		warn("[LineUp] BattleField not found in Workspace")
		return
	end

	local redPart  = battlefield:FindFirstChild("RedPosition")  :: BasePart?
	local bluePart = battlefield:FindFirstChild("BluePosition") :: BasePart?

	if not redPart or not bluePart then
		warn("[LineUp] RedPosition or BluePosition not found in BattleField")
		return
	end

	-- 赤チーム → 青Partの方向を向く / 青チーム → 赤Partの方向を向く
	LineUpTeam("red",  redPart,  bluePart.Position)
	LineUpTeam("blue", bluePart, redPart.Position)

	-- 全参加者をフリーズ（HRP Anchored + WalkSpeed 0）
	FreezeParticipants()
	print("[LineUp] Teams lined up and frozen.")
end

-- ===================== テレポート =====================
local function TeleportParticipants()
	local spawnFolder = workspace:FindFirstChild("SpawnPositions", true)
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

	local numSpawns = #spawnCFrames
	for idx, model in ipairs(allParticipants) do
		if model and numSpawns > 0 then
			local spawnIndex = ((idx - 1) % numSpawns) + 1
			model:PivotTo(spawnCFrames[spawnIndex])
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
		local teamName = participantTeam[name]
		table.insert(rankingData, { Name = name, Score = count, IsNpc = isNpc, UserId = userId, Team = teamName })
	end

	table.sort(rankingData, function(a, b) return a.Score > b.Score end)

	local topRanking = {}
	for i = 1, math.min(8, #rankingData) do
		table.insert(topRanking, rankingData[i])
	end

	local teamScores = {
		blue       = teams.blue.hitCount,
		red        = teams.red.hitCount,
		blueAvatar = teams.blue.avatarCache,
		redAvatar  = teams.red.avatarCache,
	}
	FireParticipants(GetRemoteEvent("RankingUpdate"), topRanking, teamScores)
	return topRanking
end

-- ===================== チーム選択フェーズ =====================

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

	-- NPCはこれまで通り自動ランダム選択で即時割り当て (ただし必ず両チームに1人はNPCを配置)
	local npcs = {}
	for _, character in ipairs(participants) do
		if not IsPlayerCharacter(character) then
			table.insert(npcs, character)
		end
	end
	
	if #npcs > 0 then
		local rng = Random.new()
		-- シャッフル
		for i = #npcs, 2, -1 do
			local j = rng:NextInteger(1, i)
			npcs[i], npcs[j] = npcs[j], npcs[i]
		end
		
		for i, character in ipairs(npcs) do
			local chosenTeam = "blue"
			if i == 1 then
				chosenTeam = "blue"
			elseif i == 2 then
				chosenTeam = "red"
			else
				chosenTeam = if rng:NextInteger(1, 2) == 1 then "blue" else "red"
			end
			
			assigned[character] = true
			selectedCount += 1
			AssignToTeam(character, chosenTeam)
			teamMemberIndex[chosenTeam] += 1
		end
	end

	-- クライアントへUI表示を要求
	local showTeamSelectionEvent = GetRemoteEvent("ShowTeamSelectionEvent")
	FireParticipants(showTeamSelectionEvent, teams.blue.avatarCache, teams.red.avatarCache, TEAM_SELECTION_TIMEOUT)

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
	FireParticipants(GetRemoteEvent("TeamSelectionEndEvent"))

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

-- チームアバターをランダムに2人選出してチームに設定する
local function SelectTeamAvatars(allParticipants: { Model })
	local rng = Random.new()
	
	-- 重複登録（同じ人が2回以上リストに入っているバグ）を防ぐ
	local pool = {}
	local seen = {}
	for _, m in ipairs(allParticipants) do 
		if m and not seen[m] then
			seen[m] = true
			table.insert(pool, m) 
		end
	end

	-- Shuffle
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	-- chosenAvatars を優先
	local selected = {}
	for _, avatar in ipairs(chosenAvatars) do
		-- pool 内に見つかれば selected に入れる
		for i, p in ipairs(pool) do
			if p == avatar then
				table.insert(selected, p)
				table.remove(pool, i)
				break
			end
		end
		if #selected >= 2 then break end
	end
	
	-- 残りを pool から補充
	while #selected < 2 and #pool > 0 do
		table.insert(selected, pool[1])
		table.remove(pool, 1)
	end

	teams.blue.avatar = selected[1]
	-- 万が一参加者が1人しかいない場合は、同じ人を選ばずにnilにする
	teams.red.avatar  = selected[2]

	local bName = teams.blue.avatar and teams.blue.avatar.Name or "None"
	local rName = teams.red.avatar and teams.red.avatar.Name or "None"
	print("[TeamSelect] Blue avatar=" .. bName .. " / Red avatar=" .. rName)
end

local function CacheTeamAvatars()
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("TeamAvatarsCache")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TeamAvatarsCache"
		folder.Parent = game:GetService("ReplicatedStorage")
	end
	folder:ClearAllChildren()

	for _, teamName in ipairs({"blue", "red"}) do
		local avatar = teams[teamName].avatar
		if avatar then
			local oldArch = avatar.Archivable
			avatar.Archivable = true
			local clone = avatar:Clone()
			avatar.Archivable = oldArch
			if clone then
				-- スクリプト等を削除して軽量化
				for _, desc in ipairs(clone:GetDescendants()) do
					if desc:IsA("Script") or desc:IsA("LocalScript") then
						desc.Disabled = true
						desc:Destroy()
					end
				end
				clone.Parent = folder
				teams[teamName].avatarCache = clone
			else
				warn("[BattleManager] Failed to clone avatar for TeamAvatarsCache: " .. avatar.Name)
			end
		end
	end
end

-- チーム選択フェーズ全体を実行する
local function ExecuteTeamSelectionPhase()
	local allParticipants = GetAllParticipants()

	chosenAvatars = {} -- リセット

	-- アバタールーレット演出（5秒間に先行開始）
	-- 全参加者のデータをクライアントに送信し、ViewportFrameで流れるルーレットUIを表示する
	local participantData = {}
	for _, char in ipairs(allParticipants) do
		local isNpc = not IsPlayerCharacter(char)
		local userId = 0
		local player = Players:FindFirstChild(char.Name)
		if player then userId = player.UserId end
		table.insert(participantData, { Name = char.Name, IsNpc = isNpc, UserId = userId })
	end
	
	-- ルーレットイベント送信後、一定時間受け付け
	FireParticipants(GetRemoteEvent("ShowAvatarRouletteEvent"), participantData)
	task.wait(5) -- ルーレット演出の時間

	-- 1. チームアバター選出
	SelectTeamAvatars(allParticipants)
	CacheTeamAvatars()

	-- 3. アバターを含めた全員が UI でチームを選択
	RunTeamSelectionPhase(allParticipants)
end

-- ===================== チーム外見統一 =====================

-- チームアバターの HumanoidDescription を取得する
local function GetTeamAvatarHumanoidDescription(avatar: Model): HumanoidDescription?
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local success, desc = pcall(function()
			return humanoid:GetAppliedDescription()
		end)
		if success and desc then return desc end
	end

	return nil
end

-- 各チームメンバーの見た目をチームアバターに揃える
local function ApplyTeamAppearance()
	local avatarDescriptions = {}

	-- 1. 全員が着替え始める前に、まず全チームアバターの服のデータ(Description)を安全に取得して保存しておく
	for _, teamName in ipairs({"blue", "red"}) do
		local avatar = teams[teamName].avatar
		if avatar then
			local desc = GetTeamAvatarHumanoidDescription(avatar)
			if desc then
				avatarDescriptions[teamName] = desc
			else
				warn("[Appearance] Could not get HumanoidDescription for avatar: " .. avatar.Name)
			end
		end
	end

	-- 2. 保存しておいたアバターデータをもとに、各チームのメンバーを一斉に着替えさせる
	for teamName, desc in pairs(avatarDescriptions) do
		local team = teams[teamName]
		local avatar = team.avatar
		
		-- チームアバター自身を除外した全メンバーにのみ着替えを適用する
		-- (アバター本人の服を自分自身にApplyDescriptionするとRobloxのキャッシュ仕様によりスキップされ、脱がされたまま裸になるため)
		local targets = {}
		for _, member in ipairs(team.members) do
			if member ~= avatar then
				table.insert(targets, member)
			end
		end

		for _, character in ipairs(targets) do
			task.spawn(function()
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid then return end

				-- 一旦今着ているアバターアイテムをすべて脱がせる
				humanoid:RemoveAccessories()
				for _, child in ipairs(character:GetChildren()) do
					if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("CharacterMesh") then
						child:Destroy()
					end
				end

				-- 通信エラー等を防ぐため、成功するまで最大3回リトライする
				local maxRetries = 3
				local success = false
				local err = ""
				for i = 1, maxRetries do
					success, err = pcall(function()
						humanoid:ApplyDescription(desc)
					end)
					if success then 
						print("[Appearance] Applied description for " .. character.Name)
						break
					end
					warn("[Appearance] Retry " .. i .. " failed for " .. character.Name .. ": " .. tostring(err))
					task.wait(1)
				end

				if not success then
					warn("[Appearance] ApplyDescription utterly failed for " .. character.Name)
				end
			end)
		end

		print("[Appearance] Applied " .. avatar.Name .. "'s look to " .. #targets .. " members (" .. teamName .. " team)")
	end
end

-- バトル開始前に全参加者の HumanoidDescription を保存する
local function SaveParticipantDescriptions()
	originalDescriptions = {}
	for _, character in ipairs(GetAllParticipants()) do
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

-- バトル終了後に全参加者の外見を元に戻す
local function RestoreParticipantDescriptions()
	local allParts = GetAllParticipants()
	for _, character in ipairs(allParts) do
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
	print("[Appearance] Restored original appearances for " .. #allParts .. " participants")
end

local currentArenaModel: Model? = nil  -- BuildForNPCで配置したModelを保持

local function BuildArena()
	local ArenaBuilder = require(script.Parent.ArenaBuilder)
	currentArenaModel = ArenaBuilder.BuildForNPC()
end

local function DestroyArena()
	if currentArenaModel and currentArenaModel.Parent then
		currentArenaModel:Destroy()
		print("[ArenaBuilder] Arena model destroyed.")
	end
	currentArenaModel = nil
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
	FireParticipants(rouletteEvent, allData, selData)
end

-- ===================== BattleManager Public API =====================

function BattleManager.IsSameTeam(nameA: string, nameB: string): boolean
	return IsSameTeam(nameA, nameB)
end

function BattleManager.GetParticipantTeam(name: string): string?
	return GetParticipantTeam(name)
end

function BattleManager.IsParticipant(name: string): boolean
	return IsParticipant(name)
end

function BattleManager.GetParticipants()
	return battleParticipants
end

function BattleManager.GetHitCounts()
	return hitCounts
end

function BattleManager.Start()
	print("BattleManager.Start")
	UpdateBattleStatus(BattleStatus.Preparing)
	PodiumHandler.Reset()

	-- RemoteEventの事前生成 (クライアントのWaitForChild漏れを防ぐ)
	GetRemoteEvent("ShowTeamSelectionEvent")
	GetRemoteEvent("OnTeamSelectedEvent")
	GetRemoteEvent("TeamSelectionEndEvent")
	GetRemoteEvent("ShowAvatarRouletteEvent")
	GetRemoteEvent("HintEvent")
	GetRemoteEvent("GemGetEvent")

	-- 状態リセット
	battleParticipants.players = {}
	battleParticipants.npcs    = {}
	hitCounts = {}
	teams.blue = { avatar = nil, avatarCache = nil, members = {}, hitCount = 0 }
	teams.red  = { avatar = nil, avatarCache = nil, members = {}, hitCount = 0 }
	participantTeam = {}

	-- 1. 「参加する」ボタンを押したプレイヤーのみ収集
	for player, _ in pairs(joinedPlayers) do
		if player.Character then
			table.insert(battleParticipants.players, player.Character)
			hitCounts[player.Character.Name] = 0
		end
	end
	joinedPlayers = {} -- 次のバトルに向けてリセット

	-- 2. NPC補充 (最低MIN_PARTICIPANTS人、かつ最低MIN_NPCS人確保)
	local npcNum = math.max(MIN_NPCS, MIN_PARTICIPANTS - #battleParticipants.players)
	local npcClones = NpcManager.StartBattle(npcNum)
	battleParticipants.npcs = npcClones
	for _, npc in ipairs(npcClones) do
		hitCounts[npc.Name] = 0
	end

	-- 3. フェードアウト & テレポート
	UpdateBattleStatus(BattleStatus.Transitioning)
	FireFadeEvent(true, true)
	task.wait(2)
	TeleportParticipants()
	task.wait(0.5)

	-- 4. フェードイン
	FireFadeEvent(false, true)

	-- 5. チーム選択フェーズ（アンフリーズしてから実施）
	UpdateBattleStatus(BattleStatus.TeamSelection)
	ExecuteTeamSelectionPhase()

	-- 5.5 チームメンバーの見た目をリーダーに統一
	-- (適用前に全員の元の外見を保存)
	SaveParticipantDescriptions()
	ApplyTeamAppearance()
	task.wait(1) -- 外見適用の完了を待つ

	-- 5.6 チームごとに一列整列 & フリーズ（カウントダウン終了まで固定）
	LineUpAndFreezeTeams()
	task.wait(0.5) -- 整列アニメ余韻

		-- 5.7 バトル開始メッセージを参加者に表示（3秒）
	FireHintEvent("Cast a spell and make them dance!", 3)
	task.wait(3)

	BuildArena()

	-- 6. カウントダウン（フリーズ済み）
	UpdateBattleStatus(BattleStatus.Countdown)
	FireCountDownEvent()
	task.wait(4) -- 3, 2, 1, GO

	-- 7. アンフリーズしてバトルスタート
	UnfreezeParticipants(GetAllParticipants())
	TrickHandler.StartBattle(BattleManager.OnHit, BattleManager.IsSameTeam, BattleManager.IsParticipant)
	FireBattleStatus(true)
	UpdateBattleStatus(BattleStatus.Active)

	--GrantBarrierToAllParticipants()
	local allParticipants = {}
	for _, p in ipairs(battleParticipants.players) do table.insert(allParticipants, p) end
	for _, n in ipairs(battleParticipants.npcs)    do table.insert(allParticipants, n) end
	WandAssigner.AssignWands(allParticipants)

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
	task.spawn(StunCharacter, targetCharacterName, 6)

	-- シューターがプレイヤーならGem付与 + UI通知
	local shooterPlayer = Players:FindFirstChild(shooterCharacterName)
	if shooterPlayer then
		local pd = PlayerManager.GetPlayerData(shooterPlayer)
		if pd then
			pd:AddGem(Define.GEM_HIT_REWARD)
			FireGemGetEvent(shooterPlayer, "Hit!", Define.GEM_HIT_REWARD, "Bell")
		end
	end
end

function BattleManager.Stop()
	UpdateBattleStatus(BattleStatus.Ending)
	TrickHandler.FinishBattle()

	-- チーム勝敗判定
	local winner: string
	if teams.blue.hitCount == teams.red.hitCount then
		winner = "draw"
	elseif teams.blue.hitCount > teams.red.hitCount then
		winner = "blue"
	else
		winner = "red"
	end
	print("[Result] " .. winner .. " (blue=" .. teams.blue.hitCount .. " / red=" .. teams.red.hitCount .. ")")

	FireTimeUpEvent(winner)  -- winnerを一緯に送信

	-- 勝利チームのプレイヤーにGemボーナス
	if winner ~= "draw" then
		for _, character in ipairs(teams[winner].members) do
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				local pd = PlayerManager.GetPlayerData(player)
				if pd then
					task.spawn(function()
						task.wait(2)
						pd:AddGem(Define.GEM_WIN_BONUS)
						FireGemGetEvent(player, "Win Bonus", Define.GEM_WIN_BONUS, "Fanfare")
					end)
				end
			end
		end
	end

	-- 参加者の見た目をバトル前の状態に戻す
	RestoreParticipantDescriptions()

	task.wait(1)

	FireFadeEvent(true, true)
	task.wait(Define.TIME_UP_DISPLAY_TIME)

	FreezeParticipants()


	local topRanking = UpdateRanking()

	FireParticipants(GetRemoteEvent("TeamBattleResult"), winner, teams.blue.hitCount, teams.red.hitCount)

	PodiumHandler.Display(topRanking, battleParticipants)
	WandAssigner.RemoveWands(battleParticipants.players)

	FireFadeEvent(false, true)
	task.wait(Define.PODIUM_CUTSCENE_TIME - 1)

	FireBattleStatus(false)
	UnfreezeParticipants(battleParticipants.players)
	TeleportToLobby()

	-- 状態リセット
	DestroyArena()  -- 配置したNPC用アリーナを削除
	NpcManager.StopBattle()
	battleParticipants.npcs    = {}
	battleParticipants.players = {}
	hitCounts = {}
	teams.blue = { avatar = nil, avatarCache = nil, members = {}, hitCount = 0 }
	teams.red  = { avatar = nil, avatarCache = nil, members = {}, hitCount = 0 }
	participantTeam = {}
	originalDescriptions = {}
	UpdateBattleStatus(BattleStatus.Idle)
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

playerRemovingConnection = Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- モジュール読み込み時に即座実行し、イベントを事前生成
SetupEvents()

return BattleManager
