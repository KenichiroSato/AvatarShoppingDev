--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)

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
	self:SetFlyInShowHide(true, 0.5, BaseGui_.FlyMoveDir.Right)

	local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
	local gemGetEvent = remoteEventFolder:WaitForChild("GemGetEvent")

	local frame = gui:WaitForChild("Frame") :: Frame
	local descLabel  = frame:WaitForChild("DescriptionLabel") :: TextLabel
	local countLabel = frame:WaitForChild("CountLabel") :: TextLabel

	--frame.Visible = false

	local showCoroutine: thread? = nil

	gemGetEvent.OnClientEvent:Connect(function(description: string, count: number)
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
