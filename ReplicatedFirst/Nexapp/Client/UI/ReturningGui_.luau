--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)

--- @class ShopGui_ : BaseGui_
local ReturningGui_ = {}
ReturningGui_.__index = ReturningGui_
setmetatable(ReturningGui_, BaseGui_)
ReturningGui_.instance = nil

local dotCount = 0

----------------------------------------------------------------------------------------------------
-- GetInstance
--- @return ShopGui_
function ReturningGui_.GetInstance()
	return ReturningGui_.instance
end

--========================
-- private method
--========================
local function Init(self, gui : ScreenGui)
	
	self.LoadingText = self:FindDescendant("TextLabel") :: TextLabel
	self.originalText = self.LoadingText.Text
	
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
	local timeEvent = remoteEventFolder:WaitForChild("ReturningHomeEvent")
	timeEvent.OnClientEvent:Connect(function()
		self:Show()
	end)

end

function ReturningGui_:OnShow()
	task.spawn(function()
		while self.LoadingText.Visible do
			dotCount = dotCount + 1
			if dotCount >= 5 then
				dotCount = 0
			end
			self.LoadingText.Text = self.originalText .. string.rep(".", dotCount)
			task.wait(1)
		end
		self.LoadingText.Text = self.originalText
	end)

end


--========================
-- public method
--========================

function ReturningGui_.new(...)
	local self = setmetatable(BaseGui_.new(...), ReturningGui_)
	Init(self, ...)
	ReturningGui_.instance = self
	return self
end

return ReturningGui_
