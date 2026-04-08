--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)
local Define = require(ReplicatedFirst.Nexapp.Common.Define)

--- @class ShopGui_ : BaseGui_
local TimeGui_ = {}
TimeGui_.__index = TimeGui_
setmetatable(TimeGui_, BaseGui_)
TimeGui_.instance = nil

----------------------------------------------------------------------------------------------------
-- GetInstance
--- @return ShopGui_
function TimeGui_.GetInstance()
	return TimeGui_.instance
end

--========================
-- private method
--========================
local function Init(self, gui : ScreenGui)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
	local timeEvent = remoteEventFolder:WaitForChild("TimeUpdate")
	if not timeEvent:IsA("RemoteEvent") then return end

	local frame = gui:WaitForChild("Frame")
	local textLabel = frame:WaitForChild("TextLabel") :: TextLabel
	local joinButton = frame:WaitForChild("JoinButton") :: TextButton

	-- BattleJoinEventを待機取得
	local joinEvent
	task.spawn(function()
		joinEvent = remoteEventFolder:WaitForChild("BattleJoinEvent", 30)
	end)

	local hasJoined = false

	joinButton.MouseButton1Click:Connect(function()
		if hasJoined then return end
		if joinEvent and joinEvent:IsA("RemoteEvent") then
			joinEvent:FireServer()
			hasJoined = true
			joinButton.Text = "Joined!"
		end
	end)

	timeEvent.OnClientEvent:Connect(function(seconds: number, state: string?)
		if seconds == 0 then
			textLabel.Text = ""
			joinButton.Visible = false
		elseif state == "Break" then
			textLabel.Text = string.format("Next magic battle in %d", seconds)
			textLabel.Visible = true
			joinButton.Visible = true
			-- Break開始時にボタンをリセット
			if seconds == Define.INTERVAL_DURATION then
				hasJoined = false
				joinButton.Text = "Join"
			end
		else
			if hasJoined then
				local m = math.floor(seconds / 60)
				local s = seconds % 60
				textLabel.Text = string.format("%02d:%02d", m, s)
				textLabel.Visible = true
			else
				textLabel.Visible = false
			end
			joinButton.Visible = false
		end
	end)
end

--========================
-- public method
--========================

function TimeGui_.new(...)
	local self = setmetatable(BaseGui_.new(...), TimeGui_)
	Init(self, ...)
	TimeGui_.instance = self
	return self
end

return TimeGui_
