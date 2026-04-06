--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)

--- @class ShopGui_ : BaseGui_
local TimeUpGui_ = {}
TimeUpGui_.__index = TimeUpGui_
setmetatable(TimeUpGui_, BaseGui_)
TimeUpGui_.instance = nil

----------------------------------------------------------------------------------------------------
-- GetInstance
--- @return ShopGui_
function TimeUpGui_.GetInstance()
	return TimeUpGui_.instance
end

--========================
-- private method
--========================
local Define = require(game:GetService("ReplicatedFirst").Nexapp.Common.Define) -- Adjust path if necessary, likely ReplicatedFirst.Nexapp.Common.Define

local function Init(self, gui : ScreenGui)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
	local timeupEvent = remoteEventFolder:WaitForChild("TimeUpEvent")
	if not timeupEvent:IsA("RemoteEvent") then return end
	
	local frame = gui:WaitForChild("Frame")
	local imageLabel = frame:WaitForChild("ImageLabel") :: ImageLabel
	local blueLabel = frame:WaitForChild("BlueLabel") :: TextLabel
	local redLabel  = frame:WaitForChild("RedLabel")  :: TextLabel
	local drawLabel = frame:WaitForChild("DrawLabel") :: TextLabel
	blueLabel.Visible = false
	redLabel.Visible  = false
	drawLabel.Visible = false

	timeupEvent.OnClientEvent:Connect(function(winner: string)
		-- 勝利チームのラベルだけ表示
		blueLabel.Visible = (winner == "blue")
		redLabel.Visible  = (winner == "red")
		drawLabel.Visible = (winner == "draw")

		self:Show()
		self:PlaySEByName("EndGong")
		task.wait(Define.TIME_UP_DISPLAY_TIME)
		self:Hide()
		self:StopSEByName("EndGong")

		-- 次のバトルに向けてリセット
		blueLabel.Visible = false
		redLabel.Visible  = false
		drawLabel.Visible = false
	end)
end

--========================
-- public method
--========================

function TimeUpGui_.new(...)
	local self = setmetatable(BaseGui_.new(...), TimeUpGui_)
	Init(self, ...)
	TimeUpGui_.instance = self
	return self
end

return TimeUpGui_
