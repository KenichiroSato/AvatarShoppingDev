--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

local UIManager_ = require(ReplicatedFirst.Nexsys.Client.UIManager_)

local TeamSelectionGui_ = {}
TeamSelectionGui_.__index = TeamSelectionGui_

local screenGui: ScreenGui? = nil
local _connectionShow: RBXScriptConnection? = nil
local _connectionEnd: RBXScriptConnection? = nil

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
	local targetPos = Vector3.new(0, 1.5, 0) -- デフォルトの注視点(胸〜顔)
	local hrp = clone:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		targetPos = Vector3.new(0, hrp.Position.Y + 1.5, 0)
	end
	
	-- Robloxアバターをいい感じに収めるための安定した距離 (大きすぎるエフェクトに引っ張られないよう固定上限つき)
	local distance = 6.5
	if size.Y > 10 then
		distance = size.Y * 1.2
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
	title.Text = "Which avatar's team will you join?"
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
	countdownTextSize.MaxTextSize = 30
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
				
				-- 選択後、UIを非表示にする
				if screenGui then
					screenGui:Destroy()
					screenGui = nil
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
end

return TeamSelectionGui_
