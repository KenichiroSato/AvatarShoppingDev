--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer
local MarketplaceService = game:GetService("MarketplaceService")
local SoundManager_ = require(ReplicatedFirst.Nexsys.Client.SoundManager_)
local UIManager_ = require(ReplicatedFirst.Nexsys.Client.UIManager_)
local PlayerData = require(ReplicatedFirst.Nexapp.Common.System.PlayerData)

local TeamSelectionGui_ = {}
TeamSelectionGui_.__index = TeamSelectionGui_

local USE_AVATAR_TICKET_DPO_ID = 3577494456

local screenGui: ScreenGui? = nil
local _connectionShow: RBXScriptConnection? = nil
local _connectionEnd: RBXScriptConnection? = nil
local _rouletteGui: ScreenGui? = nil
local _connectionRoulette: RBXScriptConnection? = nil
local _connectionHideRouletteButton: RBXScriptConnection? = nil

--========================
-- Private: アバタールーレット演出
--========================

-- ReplicatedStorage の TeamAvatarsCache または Workspace からキャラクターモデルを探す
local function FindCharacterModel(name: string): Model?
	-- まず Workspace の生きているキャラクターから探す
	local charInWorkspace = workspace:FindFirstChild(name)
	if charInWorkspace and charInWorkspace:IsA("Model") then
		return charInWorkspace :: Model
	end
	-- NPCはNpcFolder等に居る可能性
	local npcFolder = workspace:FindFirstChild("NpcFolder") or workspace:FindFirstChild("NPCs")
	if npcFolder then
		local npc = npcFolder:FindFirstChild(name)
		if npc and npc:IsA("Model") then
			return npc :: Model
		end
	end
	return nil
end

-- ViewportFrame にキャラクターモデルをクローンして上半身を映す
local function SetupRouletteViewport(viewportFrame: ViewportFrame, characterModel: Model)
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewportFrame

	local originalArchivable = characterModel.Archivable
	characterModel.Archivable = true
	local clone = characterModel:Clone()
	characterModel.Archivable = originalArchivable

	if not clone then return end

	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
			desc:Destroy()
		elseif desc:IsA("LayerCollector") or desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
			desc:Destroy()
		elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
			desc:Destroy()
		elseif desc:IsA("ClickDetector") or desc:IsA("ProximityPrompt") then
			desc:Destroy()
		end
	end
	clone:PivotTo(CFrame.new(0, 0, 0))
	clone.Parent = worldModel

	local camera = Instance.new("Camera")
	local hrp = clone:FindFirstChild("HumanoidRootPart")
	local targetY = 1.2
	if hrp and hrp:IsA("BasePart") then
		targetY = (hrp :: BasePart).Position.Y + 1.0
	end
	local targetPos = Vector3.new(0, targetY, 0)
	-- +Z側からカメラを向けると正面が映る（Robloxキャラは-Z向き）
	camera.CFrame = CFrame.lookAt(Vector3.new(0, targetY, -5.5), targetPos)
	camera.FieldOfView = 55
	viewportFrame.CurrentCamera = camera
	camera.Parent = viewportFrame
end

-- アバタールーレット演出を表示する
local function ShowAvatarRoulette(participantData: { { Name: string, IsNpc: boolean, UserId: number } })
	-- 既存があれば破棄
	if _rouletteGui then
		_rouletteGui:Destroy()
		_rouletteGui = nil
	end

	local CARD_WIDTH   = 200  -- カードの幅 (px)
	local CARD_HEIGHT  = 240  -- カードの高さ (px)
	local CARD_PADDING = 16   -- カード間のすき間 (px)
	local CARD_STEP    = CARD_WIDTH + CARD_PADDING
	local ROULETTE_DURATION = 5  -- 秒
	local SLOW_START    = 3     -- 何秒後からスローダウンするか

	-- 参加者リストを3周分繰り返して長い列を作る
	local loopedData: { { Name: string, IsNpc: boolean, UserId: number } } = {}
	local repeatCount = math.max(3, math.ceil(24 / math.max(1, #participantData)))
	for _ = 1, repeatCount do
		for _, d in ipairs(participantData) do
			table.insert(loopedData, d)
		end
	end

	local totalCards    = #loopedData
	local totalWidth    = totalCards * CARD_STEP
	local screenWidth   = workspace.CurrentCamera.ViewportSize.X
	-- スクロール開始位置: 右端の外から始まる
	local startOffsetX  = screenWidth
	-- スクロール終了位置: リスト全体が画面左に流れきる手前で止める（中央付近で止まるように）
	local endOffsetX    = -(totalWidth - screenWidth / 2 - CARD_STEP * 5)

	-- ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "AvatarRouletteGui"
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	_rouletteGui = gui

	-- 背景フレーム
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(8, 8, 20)
	bg.BackgroundTransparency = 0.15
	bg.ZIndex = 200
	bg.Parent = gui

	-- キラキラグラデーション飾り（上部）
	local topGlow = Instance.new("Frame")
	topGlow.Size = UDim2.new(1, 0, 0, 6)
	topGlow.Position = UDim2.new(0, 0, 0, 0)
	topGlow.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
	topGlow.BorderSizePixel = 0
	topGlow.ZIndex = 205
	topGlow.Parent = bg

	-- タイトルテキスト
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 90)
	title.Position = UDim2.new(0, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = "Selecting Team Avatar..."
	title.TextColor3 = Color3.fromRGB(255, 230, 60)
	title.TextStrokeColor3 = Color3.fromRGB(20, 10, 0)
	title.TextStrokeTransparency = 0
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.ZIndex = 210
	title.Parent = bg
	local titleSizeConstraint = Instance.new("UITextSizeConstraint")
	titleSizeConstraint.MaxTextSize = 72
	titleSizeConstraint.Parent = title

	-- タイトルのパルスアニメ
	local titleTween = TweenService:Create(title,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ TextTransparency = 0.25 }
	)
	titleTween:Play()

	-- カードスクロール用コンテナ（ClipsDescendants でカードが端で消える）
	local clipFrame = Instance.new("Frame")
	clipFrame.Size = UDim2.new(1, 0, 0, CARD_HEIGHT + 40)
	clipFrame.Position = UDim2.new(0, 0, 0.5, -(CARD_HEIGHT + 40) / 2)
	clipFrame.BackgroundTransparency = 1
	clipFrame.ClipsDescendants = true
	clipFrame.ZIndex = 202
	clipFrame.Parent = bg

	-- スクロールする内部フレーム（全カードの親）
	local scrollFrame = Instance.new("Frame")
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.Size = UDim2.new(0, totalWidth, 1, 0)
	scrollFrame.Position = UDim2.new(0, startOffsetX, 0, 0)
	scrollFrame.ZIndex = 203
	scrollFrame.Parent = clipFrame

	-- 各カードを生成
	for i, data in ipairs(loopedData) do
		local cardX = (i - 1) * CARD_STEP
		local card = Instance.new("Frame")
		card.Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT)
		card.Position = UDim2.new(0, cardX, 0.5, -CARD_HEIGHT / 2)
		card.BackgroundColor3 = Color3.fromRGB(25, 25, 50)
		card.BackgroundTransparency = 0.05
		card.ZIndex = 204
		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 16)
		cardCorner.Parent = card

		-- カードのボーダーグロー
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(100, 100, 200)
		stroke.Thickness = 2
		stroke.Transparency = 0.4
		stroke.Parent = card

		-- ViewportFrame（上80%）
		local viewport = Instance.new("ViewportFrame")
		viewport.Size = UDim2.new(1, 0, 0, CARD_HEIGHT - 50)
		viewport.Position = UDim2.new(0, 0, 0, 0)
		viewport.BackgroundTransparency = 1
		viewport.ZIndex = 205

		local characterModel = FindCharacterModel(data.Name)
		if characterModel then
			SetupRouletteViewport(viewport, characterModel)
		else
			-- モデルが見つからない場合はシルエットアイコンを表示
			local fallback = Instance.new("TextLabel")
			fallback.Size = UDim2.new(1, 0, 1, 0)
			fallback.BackgroundTransparency = 1
			fallback.Text = "👤"
			fallback.TextScaled = true
			fallback.Font = Enum.Font.GothamBold
			fallback.TextColor3 = Color3.fromRGB(150, 150, 200)
			fallback.ZIndex = 206
			fallback.Parent = viewport
		end
		viewport.Parent = card

		-- 名前ラベル（下部）
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -8, 0, 40)
		nameLabel.Position = UDim2.new(0, 4, 1, -44)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = data.Name
		nameLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 30)
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		local nameConstraint = Instance.new("UITextSizeConstraint")
		nameConstraint.MaxTextSize = 22
		nameConstraint.Parent = nameLabel
		nameLabel.ZIndex = 206
		nameLabel.Parent = card

		card.Parent = scrollFrame
	end

	-- GUI を PlayerGui に追加
	local playerGui = Player:WaitForChild("PlayerGui")
	gui.Parent = playerGui

	-- 背景フェードイン
	bg.BackgroundTransparency = 1
	TweenService:Create(bg, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.15
	}):Play()

	-- ===== スクロールアニメーション =====
	SoundManager_.PlaySEByName("DrumRoll")

	-- "Use my Avatar" ボタンを追加
	local useBtn = Instance.new("TextButton")
	useBtn.Name = "UseMyAvatarBtn"
	useBtn.Size = UDim2.new(0, 240, 0, 60)
	useBtn.Position = UDim2.new(0.5, -120, 1, -100)
	useBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
	useBtn.TextColor3 = Color3.fromRGB(20, 10, 0)
	useBtn.Font = Enum.Font.FredokaOne
	useBtn.TextScaled = true
	useBtn.Text = "Use my Avatar\n(Ticket: " .. (PlayerData:GetUseAvatarTicket() or 0) .. ")"
	useBtn.ZIndex = 300
	useBtn.Parent = bg
	local useCorner = Instance.new("UICorner")
	useCorner.CornerRadius = UDim.new(0, 12)
	useCorner.Parent = useBtn

	-- 押した時の処理
	useBtn.MouseButton1Click:Connect(function()
		local tickets = PlayerData:GetUseAvatarTicket() or 0
		if tickets > 0 then
			-- 使用イベント送信
			local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
			local useEv = remoteEventFolder:FindFirstChild("OnUseMyAvatarEvent")
			if useEv and useEv:IsA("RemoteEvent") then
				useEv:FireServer()
			end
			useBtn.Visible = false
		else
			-- 購入ダイアログ表示
			MarketplaceService:PromptProductPurchase(Player, USE_AVATAR_TICKET_DPO_ID)
		end
	end)

	-- フェーズ1: 最初SLOW_START秒は高速でスクロール
	local phase1Distance = (endOffsetX - startOffsetX) * 0.7
	local phase1Tween = TweenService:Create(scrollFrame,
		TweenInfo.new(SLOW_START, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0, startOffsetX + phase1Distance, 0, 0) }
	)
	-- フェーズ2: 残り(ROULETTE_DURATION - SLOW_START)秒でゆっくり止まる
	local phase2Tween = TweenService:Create(scrollFrame,
		TweenInfo.new(ROULETTE_DURATION - SLOW_START, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, endOffsetX, 0, 0) }
	)

	phase1Tween:Play()
	phase1Tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			phase2Tween:Play()
		end
	end)

	-- 5秒後にフェードアウトして破棄
	task.delay(ROULETTE_DURATION, function()
		if not _rouletteGui then return end
		local fadeOut = TweenService:Create(bg,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		)
		-- title と cards も同時にフェード
		TweenService:Create(title, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(clipFrame, TweenInfo.new(0.5), { GroupTransparency = 1 }):Play()
		TweenService:Create(useBtn, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			if _rouletteGui then
				SoundManager_.StopSEByName("DrumRoll")
				_rouletteGui:Destroy()
				_rouletteGui = nil
			end
		end)
	end)
end

--========================
-- Private Method: Camera & Viewport
--========================
local function SetupViewport(viewportFrame: ViewportFrame, characterModel: Model)
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewportFrame

	-- 1. クローン失敗対策 (強制的にArchivableをtrueにする)
	local originalArchivable = characterModel.Archivable
	characterModel.Archivable = true
	local clone = characterModel:Clone()
	characterModel.Archivable = originalArchivable

	if not clone then
		warn("TeamSelectionGui_: Failed to clone characterModel")
		return
	end

	-- 2. スクリプトや悪影響を及ぼすUI・パーティクルを除去
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
			desc:Destroy()
		elseif desc:IsA("LayerCollector") or desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") or desc:IsA("UIComponent") then
			desc:Destroy()
		elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
			desc:Destroy()
		elseif desc:IsA("ClickDetector") or desc:IsA("ProximityPrompt") then
			desc:Destroy()
		end
	end
	clone.Parent = worldModel

	-- バウンディングボックスを取得して中心とサイズを把握
	local _, size = clone:GetBoundingBox()
	
	-- モデルを原点に移動し、回転を完全にリセットする (正面を向かせるため)
	clone:PivotTo(CFrame.new(0, 0, 0))

	local camera = Instance.new("Camera")

	-- バウンディングボックス(巨大なアクセサリーや見えないパーツ)に影響されないよう、
	-- 安定した固定のオフセットに頼るか、HumanoidRootPartのY位置を基準にします。
	local targetPos = Vector3.new(0, 1.2, 0) -- デフォルトの注視点(胸〜顔)
	local hrp = clone:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		targetPos = Vector3.new(0, hrp.Position.Y + 1.2, 0)
	end
	
	-- Robloxアバターをいい感じに収めるための安定した距離
	-- 異常に巨大な見えないパーツ(アクセサリー等)が含まれている場合に備えて、距離の上限を15スタッドに制限する
	local distance = 6.5
	if size.Y > 10 then
		distance = math.min(12, size.Y * 1.2)
	end

	-- 回転をリセットしたRobloxのキャラクターは通常 -Z 方向を向いている。
	-- したがって、+Z 側にカメラを置くことで確実に正面を捉えられる。
	local cameraPos = targetPos + Vector3.new(0, 0, -distance)
	
	camera.CFrame = CFrame.lookAt(cameraPos, targetPos)
	camera.FieldOfView = 60
	
	viewportFrame.CurrentCamera = camera
	camera.Parent = viewportFrame
end

--========================
-- Private Method: GUI構築
--========================
local function CreateGUI(blueAvatar: Model, redAvatar: Model, timeout: number)
	if screenGui then
		screenGui:Destroy()
	end

	local newScreenGui = Instance.new("ScreenGui")
	newScreenGui.Name = "TeamSelectionGui"
	newScreenGui.IgnoreGuiInset = true
	newScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	screenGui = newScreenGui

	-- 全体フレーム
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundTransparency = 0.5
	mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	mainFrame.ZIndex = 100
	mainFrame.Parent = newScreenGui

	-- タイトル
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 80)
	title.Position = UDim2.new(0, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Text = "Which avatar is better?"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeTransparency = 0
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne
	title.ZIndex = 110
	title.Parent = mainFrame
	
	local uiTextSize = Instance.new("UITextSizeConstraint")
	uiTextSize.MaxTextSize = 60
	uiTextSize.Parent = title

	-- カウントダウン
	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Size = UDim2.new(1, 0, 0, 80)
	countdownLabel.Position = UDim2.new(0, 0, 0, 130)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Text = tostring(timeout or 15)
	countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	countdownLabel.TextStrokeTransparency = 0
	countdownLabel.TextScaled = true
	countdownLabel.Font = Enum.Font.FredokaOne
	countdownLabel.ZIndex = 110
	countdownLabel.Parent = mainFrame
	
	local countdownTextSize = Instance.new("UITextSizeConstraint")
	countdownTextSize.MaxTextSize = 80
	countdownTextSize.Parent = countdownLabel

	local function CreateTeamPanel(teamName: string, color: Color3, posScaleX: number, avatarModel: Model)
		local panel = Instance.new("Frame")
		panel.Size = UDim2.new(0.35, 0, 0.6, 0)
		panel.Position = UDim2.new(posScaleX, 0, 0.55, 0)
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.BackgroundColor3 = color
		panel.BackgroundTransparency = 0.2
		panel.ZIndex = 101
		-- 角丸
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 20)
		corner.Parent = panel
		
		-- チームラベル
		local teamLabel = Instance.new("TextLabel")
		teamLabel.Size = UDim2.new(1, 0, 0, 40)
		teamLabel.Position = UDim2.new(0, 0, 0, 10)
		teamLabel.BackgroundTransparency = 1
		teamLabel.Text = string.upper(teamName) .. " TEAM"
		teamLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		teamLabel.Font = Enum.Font.FredokaOne
		teamLabel.TextScaled = true
		teamLabel.ZIndex = 102
		teamLabel.Parent = panel

		-- ViewportFrame
		local viewport = Instance.new("ViewportFrame")
		viewport.Size = UDim2.new(1, 0, 0.7, 0)
		viewport.Position = UDim2.new(0, 0, 0, 60)
		viewport.BackgroundTransparency = 1
		viewport.ZIndex = 102
		viewport.Parent = panel

		-- セットアップ
		if avatarModel then
			SetupViewport(viewport, avatarModel)
		end

		-- 選択ボタン
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.8, 0, 0.15, 0)
		btn.Position = UDim2.new(0.5, 0, 0.9, 0)
		btn.AnchorPoint = Vector2.new(0.5, 0.5)
		btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextColor3 = color
		btn.Text = "Join"
		btn.Font = Enum.Font.FredokaOne
		btn.TextScaled = true
		btn.Active = true
		btn.ZIndex = 110
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 10)
		btnCorner.Parent = btn
		btn.Parent = panel

		-- ボタンのアニメーション (UIManagerのホバーアニメ設定を流用)
		--UIManager_.SetupHoverAnim(btn)

		btn.MouseButton1Click:Connect(function()
			print("TeamSelectionGui: " .. teamName .. " selected")
			local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
			local selectEvent = remoteEventFolder:FindFirstChild("OnTeamSelectedEvent")
			if selectEvent and selectEvent:IsA("RemoteEvent") then
				selectEvent:FireServer(teamName)
				
				-- 選択後、他のUI要素を隠して待機メッセージを表示
				if mainFrame and title then
					for _, child in ipairs(mainFrame:GetChildren()) do
						if child:IsA("GuiObject") and child ~= title and child ~= countdownLabel then
							child.Visible = false
						end
					end
					title.Text = "Waiting for other players..."
				end
			end
		end)

		return panel
	end

	local bluePanel = CreateTeamPanel("blue", Color3.fromRGB(0, 120, 255), 0.28, blueAvatar)
	bluePanel.Parent = mainFrame

	local redPanel = CreateTeamPanel("red", Color3.fromRGB(255, 50, 50), 0.72, redAvatar)
	redPanel.Parent = mainFrame

	local targetScreenGui = screenGui
	if targetScreenGui then
		targetScreenGui.Parent = Player:WaitForChild("PlayerGui")
	end

	-- ポップアップアニメーション
	local uisBlue = Instance.new("UIScale")
	uisBlue.Parent = bluePanel
	uisBlue.Scale = 0
	
	local uisRed = Instance.new("UIScale")
	uisRed.Parent = redPanel
	uisRed.Scale = 0

	local twInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(uisBlue, twInfo, {Scale = 1}):Play()
	task.delay(0.1, function()
		TweenService:Create(uisRed, twInfo, {Scale = 1}):Play()
	end)

	if timeout and timeout > 0 then
		task.spawn(function()
			local t = timeout
			while t > 0 and screenGui == targetScreenGui do
				countdownLabel.Text = tostring(t)
				task.wait(1)
				t -= 1
			end
		end)
	end
end

--========================
-- Public Method
--========================
function TeamSelectionGui_.Setup()
	local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")

	local showEvent = remoteEventFolder:WaitForChild("ShowTeamSelectionEvent", 10)
	if showEvent and showEvent:IsA("RemoteEvent") then
		_connectionShow = showEvent.OnClientEvent:Connect(function(blueAvatar, redAvatar, timeout)
			print("TeamSelectionGui: Received ShowTeamSelectionEvent")
			-- ルーレット演出が表示中なら即座に消す
			if _rouletteGui then
				_rouletteGui:Destroy()
				_rouletteGui = nil
			end
			SoundManager_.PlaySEByName("TaDa")
			CreateGUI(blueAvatar, redAvatar, timeout)
		end)
	end
	
	local endEvent = remoteEventFolder:WaitForChild("TeamSelectionEndEvent", 10)
	if endEvent and endEvent:IsA("RemoteEvent") then
		_connectionEnd = endEvent.OnClientEvent:Connect(function()
			if screenGui then
				screenGui:Destroy()
				screenGui = nil
			end
		end)
	end

	-- アバタールーレット演出イベント
	local rouletteEvent = remoteEventFolder:WaitForChild("ShowAvatarRouletteEvent", 10)
	if rouletteEvent and rouletteEvent:IsA("RemoteEvent") then
		_connectionRoulette = rouletteEvent.OnClientEvent:Connect(function(participantData)
			print("TeamSelectionGui: Received ShowAvatarRouletteEvent, participants=", #participantData)
			ShowAvatarRoulette(participantData)
		end)
	end
	
	local hideUseEvent = remoteEventFolder:WaitForChild("HideUseMyAvatarEvent", 10)
	if hideUseEvent and hideUseEvent:IsA("RemoteEvent") then
		_connectionHideRouletteButton = hideUseEvent.OnClientEvent:Connect(function()
			if _rouletteGui then
				local btn = _rouletteGui:FindFirstChild("UseMyAvatarBtn", true)
				if btn and btn:IsA("GuiObject") then
					btn.Visible = false
				end
			end
		end)
	end
end

return TeamSelectionGui_
