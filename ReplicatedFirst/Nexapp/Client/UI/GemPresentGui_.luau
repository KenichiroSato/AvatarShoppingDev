--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)

local ROTATE_DEG_PER_SEC = 72  -- 5秒で1周

--- @class GemPresentGui_ : BaseGui_
local GemPresentGui_ = {}
GemPresentGui_.__index = GemPresentGui_
setmetatable(GemPresentGui_, BaseGui_)
GemPresentGui_.instance = nil

----------------------------------------------------------------------------------------------------
function GemPresentGui_.GetInstance()
	return GemPresentGui_.instance
end

--========================
-- private
--========================

local function Init(self, gui: ScreenGui)
	self:WaitForLoaded(gui)

	local frame = gui:WaitForChild("Frame") :: Frame
	local backImage = frame:WaitForChild("BackImage") :: ImageLabel

	-- BackImage 常時回転
	RunService.Heartbeat:Connect(function(dt)
		backImage.Rotation = backImage.Rotation + ROTATE_DEG_PER_SEC * dt
	end)
end

--========================
-- public
--========================

function GemPresentGui_.new(...)
	local self = setmetatable(BaseGui_.new(...), GemPresentGui_)
	Init(self, ...)
	GemPresentGui_.instance = self
	return self
end

return GemPresentGui_
