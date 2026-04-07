--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)

--- @class ShopGui_ : BaseGui_
local RankingGui_ = {}
RankingGui_.__index = RankingGui_
setmetatable(RankingGui_, BaseGui_)
RankingGui_.instance = nil

----------------------------------------------------------------------------------------------------
-- GetInstance
--- @return ShopGui_
function RankingGui_.GetInstance()
	return RankingGui_.instance
end

--========================
-- private method
--========================
local CharacterImageSetter = require(ReplicatedFirst:WaitForChild("Nexapp"):WaitForChild("Common"):WaitForChild("System"):WaitForChild("CharacterImageSetter"))

-- TeamSelectionGui_と共通のViewportセットアップロジック
local function SetupViewport(viewportFrame: ViewportFrame, characterModel: Model)
	-- 前回のコンテンツをクリア
	for _, child in ipairs(viewportFrame:GetChildren()) do
		if not child:IsA("Camera") and not child:IsA("UIAspectRatioConstraint") and not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	local existingCam = viewportFrame:FindFirstChildOfClass("Camera")
	if existingCam then existingCam:Destroy() end

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
		end
	end
	clone.Parent = worldModel
	clone:PivotTo(CFrame.new(0, 0, 0))

	local targetPos = Vector3.new(0, 1.5, 0)
	local hrp = clone:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		targetPos = Vector3.new(0, hrp.Position.Y + 1.5, 0)
	end

	local camera = Instance.new("Camera")
	local cameraPos = targetPos + Vector3.new(0, 0, -3.5)
	camera.CFrame = CFrame.lookAt(cameraPos, targetPos)
	camera.FieldOfView = 60
	viewportFrame.CurrentCamera = camera
	camera.Parent = viewportFrame
end

-- ランキングスロットにViewportFrame or ImageLabelでキャラクターを表示
local function SetupRankingSlot(imageFrame: ImageLabel, name: string, userId: number?, originalDesc: HumanoidDescription?)
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")

	-- キャラクターモデルを取得
	local character: Model? = nil
	if userId and userId > 0 then
		-- オンラインプレイヤー
		local player = Players:GetPlayerByUserId(userId)
		if player then
			character = player.Character
		end
	else
		-- NPC: Workspace.NPCs フォルダから名前で探す
		local npcFolder = Workspace:FindFirstChild("NPCs")
		if npcFolder then
			character = npcFolder:FindFirstChild(name) :: Model?
		end
	end

	-- 既存のViewportFrameを再利用 or 新規作成
	local vp = imageFrame:FindFirstChildOfClass("ViewportFrame")
	if not vp then
		vp = Instance.new("ViewportFrame") :: ViewportFrame
		vp.Name = "RankingViewport"
		vp.Size = UDim2.new(1, 0, 1, 0)
		vp.Position = UDim2.new(0, 0, 0, 0)
		vp.BackgroundTransparency = 1
		vp.ZIndex = imageFrame.ZIndex + 1
		vp.Parent = imageFrame
	end

	if character then
		vp.Visible = true
		imageFrame.Image = ""
		SetupViewport(vp, character)

		-- プレイヤーかつ元の外見データがある場合、着替え前の外見をViewport内のクローンに適用する
		if originalDesc and userId and userId > 0 then
			task.spawn(function()
				local worldModel = vp:FindFirstChildOfClass("WorldModel")
				if not worldModel then return end
				local cloneInWorld = worldModel:FindFirstChildOfClass("Model")
				if not cloneInWorld then return end
				local humanoid = cloneInWorld:FindFirstChildOfClass("Humanoid")
				if humanoid then
					pcall(function()
						humanoid:ApplyDescription(originalDesc)
					end)
				end
			end)
		end
	else
		-- モデル未取得の場合はImageLabelにフォールバック
		vp.Visible = false
		CharacterImageSetter.SetImageByInfo(name, userId, imageFrame)
	end
end

--========================
-- private method
--========================
local function Init(self, gui : ScreenGui)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local rankingEvent = ReplicatedStorage:WaitForChild("RemoteEvent"):WaitForChild("RankingUpdate") :: RemoteEvent
	local frame = gui:WaitForChild("Frame") :: Frame
	frame.Visible = false
	
	local scoreFrame = frame:WaitForChild("Frame") :: Frame
	local blueLabel = scoreFrame:WaitForChild("BlueLabel") :: TextLabel
	local redLabel  = scoreFrame:WaitForChild("RedLabel")  :: TextLabel

	local battleStatusEvent = ReplicatedStorage:WaitForChild("RemoteEvent"):WaitForChild("BattleStatus") :: RemoteEvent
	battleStatusEvent.OnClientEvent:Connect(function(isActive: boolean)
		if not isActive then
			frame.Visible = false
			return
		end
	end)
	
	rankingEvent.OnClientEvent:Connect(function(rankingData, teamScores)
		local maxScore = rankingData[1]
		if maxScore == 0 then
			frame.Visible = false
			return
		end
		frame.Visible = true

		-- チームスコアとアバターを表示
		if teamScores then
			blueLabel.Text = tostring(teamScores.blue)
			redLabel.Text  = tostring(teamScores.red)

			-- Viewportにアバターをセットアップ
			local blueVP = scoreFrame:FindFirstChild("BlueViewportFrame") :: ViewportFrame?
			local redVP  = scoreFrame:FindFirstChild("RedViewportFrame")  :: ViewportFrame?
			if blueVP and teamScores.blueAvatar then
				SetupViewport(blueVP, teamScores.blueAvatar)
			end
			if redVP and teamScores.redAvatar then
				SetupViewport(redVP, teamScores.redAvatar)
			end
		end

		for i = 1, 6 do
			local imageFrame = frame:FindFirstChild("Image" .. i) :: ImageLabel?
			if not imageFrame then continue end
			
			local data = rankingData[i]
			if data then
				imageFrame.Visible = true
				
				local scoreText = imageFrame:FindFirstChild("ScoreText" .. i) :: TextLabel?
				if scoreText then
					scoreText.Text = tostring(data.Score)
				end
				
				local rankText = imageFrame:FindFirstChild("RankText" .. i) :: TextLabel?
				if rankText then
					rankText.Text = "#" .. i
				end
				
				SetupRankingSlot(imageFrame, data.Name, data.UserId, data.OriginalDesc)
				
				local uiStroke = imageFrame:FindFirstChildOfClass("UIStroke")
				if uiStroke and data.Team then
					if data.Team == "blue" then
						uiStroke.Color = Color3.fromRGB(0, 120, 255)
					elseif data.Team == "red" then
						uiStroke.Color = Color3.fromRGB(255, 50, 50)
					end
				end
			else
				imageFrame.Visible = false
			end
		end
	end)
end

--========================
-- public method
--========================

function RankingGui_.new(...)
	local self = setmetatable(BaseGui_.new(...), RankingGui_)
	Init(self, ...)
	RankingGui_.instance = self
	return self
end

return RankingGui_
