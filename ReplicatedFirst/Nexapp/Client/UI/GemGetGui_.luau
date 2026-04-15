--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)
local PopUp_   = require(ReplicatedFirst.Nexsys.Client.PopUp_)

local GEM_FLY_COUNT        = 5
local GEM_FLY_IMAGE        = "rbxassetid://87050085594612"
local GEM_FLY_SIZE_SCALE   = 0.09   -- 画面短辺に対する初期サイズの割合
local GEM_SCATTER_R_SCALE  = 0.25  -- 散布半径（最大）の割合
local GEM_SCATTER_R_MIN    = 0.06  -- 散布半径（最小）の割合

--- @class GemGetGui_ : BaseGui_
local GemGetGui_ = {}
GemGetGui_.__index = GemGetGui_
setmetatable(GemGetGui_, BaseGui_)
GemGetGui_.instance = nil

----------------------------------------------------------------------------------------------------
function GemGetGui_.GetInstance()
	return GemGetGui_.instance
end

--========================
-- private method
--========================

local function Init(self, gui: ScreenGui)
	self:WaitForLoaded(gui)
	self:WaitForSaveDataLoaded()
	self:SetZoomShowHide(true, 0.5)

	local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
	local gemGetEvent = remoteEventFolder:WaitForChild("GemGetEvent")

	local frame = gui:WaitForChild("Frame") :: Frame
	local descLabel  = frame:WaitForChild("DescriptionLabel") :: TextLabel
	local countLabel = frame:WaitForChild("CountLabel") :: TextLabel
	local notifGemImage = frame:FindFirstChildOfClass("ImageLabel") :: ImageLabel

	-- GemGui の ImageLabel（飛んでいく先）を取得
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gemGuiImageLabel = PlayerGui
		:WaitForChild("GemGui")
		:WaitForChild("Frame")
		:WaitForChild("ImageLabel") :: ImageLabel

	-- PopUpGui を取得（PopUp_ の親として使用）
	local PopUpGui = PlayerGui:WaitForChild("PopUpGui")

	-- Gemアイコンが画面上に広がり、GemGuiへ収束するアニメーション（PopUp_ 使用）
	local function playGemFlyAnimation()
		local viewport = workspace.CurrentCamera.ViewportSize
		local shortSide = math.min(viewport.X, viewport.Y)
		local flySize     = math.floor(shortSide * GEM_FLY_SIZE_SCALE)
		local radiusMax   = math.floor(shortSide * GEM_SCATTER_R_SCALE)
		local radiusMin   = math.floor(shortSide * GEM_SCATTER_R_MIN)

		-- 開始位置: 通知バナーのGemアイコン中央
		local startCenter = notifGemImage
			and (notifGemImage.AbsolutePosition + notifGemImage.AbsoluteSize * 0.5)
			or Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
		-- 終了位置: GemGuiのImageLabel中央
		local targetCenter = gemGuiImageLabel.AbsolutePosition + gemGuiImageLabel.AbsoluteSize * 0.5

		-- PopUpGui内にGemのテンプレートフレームを動的生成
		-- （PopUp_.ExecuteRSCAnimation がこれをCloneして散布する）
		local gemTemplate = Instance.new("Frame")
		gemTemplate.Size = UDim2.fromOffset(flySize, flySize)
		gemTemplate.BackgroundTransparency = 1
		gemTemplate.Position = UDim2.fromOffset(
			startCenter.X - flySize / 2,
			startCenter.Y - flySize / 2
		)
		gemTemplate.Visible = false
		local gemImg = Instance.new("ImageLabel")
		gemImg.Image = GEM_FLY_IMAGE
		gemImg.Size = UDim2.fromScale(1, 1)
		gemImg.BackgroundTransparency = 1
		gemImg.Parent = gemTemplate
		gemTemplate.Parent = PopUpGui

		-- PopUp_ のScatterAnimで「広がって→収束」
		-- SHOW_TIME(0.7s)散布 → MOVE_TIME(1s)収束 = 合計 1.7s
		PopUp_.newBase("", gemTemplate, gemTemplate.Position, {
			IsScatterAnim     = true,
			ScatterAnimTargetPos = targetCenter,
			ScatterCount      = GEM_FLY_COUNT,
			ScatterRadiusMin  = radiusMin,
			ScatterRadiusMax  = radiusMax,
		})

		-- アニメ完了後にテンプレートを削除
		task.delay(2.0, function()
			if gemTemplate.Parent then
				gemTemplate:Destroy()
			end
		end)
	end

	--frame.Visible = false

	local showCoroutine: thread? = nil

	gemGetEvent.OnClientEvent:Connect(function(description: string, count: number, playSE: boolean)
		-- 前の表示があればキャンセル
		if showCoroutine then
			coroutine.close(showCoroutine)
			showCoroutine = nil
		end

		descLabel.Text  = description
		countLabel.Text = "+" .. tostring(count)
		descLabel.TextTransparency  = 0
		countLabel.TextTransparency = 0
		--frame.Visible = true
		self:Show()
		if playSE then
			local SoundManager_ = require(ReplicatedFirst.Nexsys.Client.SoundManager_)
			SoundManager_.PlaySEByName("Boxing Bell")
		end

		-- Gemアイコンがバナーからカウンターへ飛ぶ演出
		task.spawn(function()
			task.wait(0.5)
			playGemFlyAnimation()
		end)

		showCoroutine = coroutine.create(function()
			task.wait(2.5)
			--[[
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tD = TweenService:Create(descLabel,  tweenInfo, { TextTransparency = 1 })
			local tC = TweenService:Create(countLabel, tweenInfo, { TextTransparency = 1 })
			tD:Play()
			tC:Play()
			]]
			task.wait(0.5)
			--frame.Visible = false
			self:Hide()
			showCoroutine = nil
		end)
		coroutine.resume(showCoroutine)
	end)
end

--========================
-- public method
--========================

function GemGetGui_.new(...)
	local self = setmetatable(BaseGui_.new(...), GemGetGui_)
	Init(self, ...)
	GemGetGui_.instance = self
	return self
end

return GemGetGui_
