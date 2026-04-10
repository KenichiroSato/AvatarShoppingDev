--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)

--- @class HintGui_ : BaseGui_
local HintGui_ = {}
HintGui_.__index = HintGui_
setmetatable(HintGui_, BaseGui_)
HintGui_.instance = nil

function HintGui_.GetInstance()
	return HintGui_.instance
end

local function Init(self, gui: ScreenGui)
	local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
	local hintEvent = remoteEventFolder:WaitForChild("HintEvent")
	if not hintEvent:IsA("RemoteEvent") then return end

	local frame = gui:WaitForChild("Frame") :: Frame
	local textLabel = frame:WaitForChild("TextLabel") :: TextLabel

	hintEvent.OnClientEvent:Connect(function(message: string, duration: number)
		textLabel.Text = message
		frame.Visible = true
		textLabel.TextTransparency = 0

		-- duration秒待ってフェードアウト
		task.wait(duration - 0.5)
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(textLabel, tweenInfo, { TextTransparency = 1 })
		tween:Play()
		task.wait(0.5)
		frame.Visible = false
	end)
end

function HintGui_.new(...)
	local self = setmetatable(BaseGui_.new(...), HintGui_)
	Init(self, ...)
	HintGui_.instance = self
	return self
end

return HintGui_
