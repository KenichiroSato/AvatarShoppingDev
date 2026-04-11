--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)
local PlayerData = require(ReplicatedFirst.Nexapp.Common.System.PlayerData)
local SystemDataModule_ = require(ReplicatedFirst.Nexsys.Client.SystemDataModule_)


--- @class ShopGui_ : BaseGui_
local GemGui_ = {}
GemGui_.__index = GemGui_
setmetatable(GemGui_, BaseGui_)
GemGui_.instance = nil

local gemText: TextLabel
local perSecText: TextLabel

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- GetInstance
--- @return ShopGui_
function GemGui_.GetInstance()
	return GemGui_.instance
end

--========================
-- private method
--========================

local function Init(self, gui : ScreenGui)
	print("GemGui_ Init")
	self:WaitForLoaded(gui)
	print("GemGui_ Init after WaitForLoaded")
	self:WaitForSaveDataLoaded()
	print("GemGui_ Init after WaitForSaveDataLoaded")
	local frame = gui:WaitForChild("Frame")
	gemText = frame:WaitForChild("GemLabel") :: TextLabel
	--perSecText = frame:WaitForChild("PerSecLabel") ::TextLabel
	
	self:SetUpdate(true)
end

--========================
-- public method
--========================

function GemGui_.new(...)
	local self = setmetatable(BaseGui_.new(...), GemGui_)
	Init(self, ...)
	GemGui_.instance = self
	return self
end

function GemGui_:onUpdate(dt: number)
	gemText.Text = "  " .. PlayerData:GetGem()
	--perSecText.Text = "$" .. PlayerData:GetCoinPerSec() .. "/s"
end

return GemGui_
