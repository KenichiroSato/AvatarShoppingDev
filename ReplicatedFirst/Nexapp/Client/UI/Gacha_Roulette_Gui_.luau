local ReplicatedFirst = game:GetService("ReplicatedFirst")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)
local Gacha_Appear_Gui_ = require(ReplicatedFirst.Nexapp.Client.UI.Gacha_Appear_Gui_)
local CharacterImageSetter = require(ReplicatedFirst:WaitForChild("Nexapp"):WaitForChild("Common"):WaitForChild("System"):WaitForChild("CharacterImageSetter"))

--- @class Gacha_Roulette_Gui_ : BaseGui_
local Gacha_Roulette_Gui_ = {}
Gacha_Roulette_Gui_.__index = Gacha_Roulette_Gui_
setmetatable(Gacha_Roulette_Gui_, BaseGui_)
Gacha_Roulette_Gui_.instance = nil

local ELEM_NUM = 16

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- GetInstance
--- @return Gacha_Roulette_Gui_
function Gacha_Roulette_Gui_.GetInstance()
	return Gacha_Roulette_Gui_.instance
end
----------------------------------------------------------------------------------------------------

function Gacha_Roulette_Gui_.new(...)
	local self = setmetatable(BaseGui_.new(...), Gacha_Roulette_Gui_)
	Gacha_Roulette_Gui_.Init(self, ...)
	Gacha_Roulette_Gui_.instance = self
	return self
end

function Gacha_Roulette_Gui_:Init(gui : ScreenGui)
	self:WaitForLoaded(gui)
	self:SetShowUpdate(true)
	self.frame = self:FindDescendantFrame("WindowBase")
	self.frameBasePos = self.frame.Position
	self.speed = 1
	self.rouletteTime = 4

	self.frame1 = self.frame["1"] :: Frame
	for i=6,ELEM_NUM do
		local frame = self.frame1:Clone()
		frame.Name = i
		frame.Parent = self.frame
		frame.LayoutOrder = i
		frame.Visible = true
	end
	self.loopFrame = self.frame["9"] :: Frame
	
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local rankingEvent = ReplicatedStorage:WaitForChild("RemoteEvent"):WaitForChild("ShowRoulette") :: RemoteEvent
	rankingEvent.OnClientEvent:Connect(function(allCharacters, selectedCharacters)
		self:Show(allCharacters, selectedCharacters)
	end)
	-- warn("Size", self.frame.Size, self.frame.AbsoluteSize)
	-- warn("pos", self.frame1.AbsolutePosition, self.loopFrame.AbsolutePosition)
end

----------------------------------------------------------------------------------------------------
-- onShow
function Gacha_Roulette_Gui_:OnShow(allCharacters, selectedCharacters)
	self.allCharacters = allCharacters
	self.selectedCharacters = selectedCharacters
	self.frame.Position = self.frameBasePos
	self:PlaySEByName("DrumRoll")
	self:setupList(allCharacters)
end
----------------------------------------------------------------------------------------------------
-- onHide
function Gacha_Roulette_Gui_:OnHide()
	self:StopSEByName("DrumRoll")
	-- Gacha_Appear_Gui_のonHideでHUD_を有効化
	-- HUD_.GetInstance():SetEnabled(true)
end
----------------------------------------------------------------------------------------------------
-- setupList
function Gacha_Roulette_Gui_:setupList(allCharacters)

	for i=1,ELEM_NUM do
		local elem : Frame = self.frame[tostring(i)]
		local charaIndex = (i-1) % #allCharacters + 1
		local imageLabel = elem:FindFirstChild("CharacterImage", true)
		CharacterImageSetter.SetImageByInfo(allCharacters[charaIndex].Name, allCharacters[charaIndex].UserId, imageLabel)
	end
end
----------------------------------------------------------------------------------------------------
-- onShowUpdate
function Gacha_Roulette_Gui_:onShowUpdate(dt)

	local move = self.speed * dt
	self.frame.Position = self.frame.Position - UDim2.fromScale(move, 0)
	if self.loopFrame.AbsolutePosition.X <= 0 then
		self.frame.Position = self.frameBasePos
	end

	if self:GetShowTime() > self.rouletteTime then
		self:Hide()
		Gacha_Appear_Gui_.GetInstance():Show(self.selectedCharacters)
	end
end
----------------------------------------------------------------------------------------------------




return Gacha_Roulette_Gui_