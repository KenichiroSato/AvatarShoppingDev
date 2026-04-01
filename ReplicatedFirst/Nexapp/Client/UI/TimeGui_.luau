--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)

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
	
	timeEvent.OnClientEvent:Connect(function(seconds: number, state: string?)
		if seconds == 0 then
			textLabel.Text = ""
		elseif state == "Break" then
			textLabel.Text = string.format("break (%d)", seconds)
		else
			local m = math.floor(seconds / 60)
			local s = seconds % 60
			textLabel.Text = string.format("%02d:%02d", m, s)
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
