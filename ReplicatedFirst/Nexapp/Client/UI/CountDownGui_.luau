--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)

--- @class CountDownGui_ : BaseGui_
local CountDownGui_ = {}
CountDownGui_.__index = CountDownGui_
setmetatable(CountDownGui_, BaseGui_)
CountDownGui_.instance = nil

----------------------------------------------------------------------------------------------------
-- GetInstance
--- @return CountDownGui_
function CountDownGui_.GetInstance()
	return CountDownGui_.instance
end

--========================
-- private method
--========================
local function Init(self, gui : ScreenGui)
	local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
	local countDownEvent = remoteEventFolder:WaitForChild("CountDownEvent")
	if not countDownEvent:IsA("RemoteEvent") then return end
	
	local frame = gui:WaitForChild("Frame") :: Frame
	local textLabel = frame:WaitForChild("TextLabel") :: TextLabel
	--frame.Visible = false
	
	countDownEvent.OnClientEvent:Connect(function()
		self:Show()
		
		textLabel.Text = "Tap where you want to shoot"
		task.wait(3)

		self:PlaySEByName("CountDown") -- Assuming a sound exists or logic to play it
		
		textLabel.Text = "3"
		task.wait(1)
		textLabel.Text = "2"
		task.wait(1)
		textLabel.Text = "1"
		task.wait(1)
		textLabel.Text = "GO!"
		self:PlaySEByName("StartGong") -- Assuming sound
		task.wait(1)
		
		self:Hide()
	end)
end

--========================
-- public method
--========================

function CountDownGui_.new(...)
	local self = setmetatable(BaseGui_.new(...), CountDownGui_)
	Init(self, ...)
	CountDownGui_.instance = self
	return self
end

return CountDownGui_
