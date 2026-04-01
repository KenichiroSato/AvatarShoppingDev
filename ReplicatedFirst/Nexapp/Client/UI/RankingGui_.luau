--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)

--- @class ShopGui_ : BaseGui_
local RankingGui_ = {}
RankingGui_.__index = RankingGui_
setmetatable(RankingGui_, BaseGui_)
RankingGui_.instance = nil

----------------------------------------------------------------------------------------------------
-- GetInstance
--- @return ShopGui_
function RankingGui_.GetInstance()
	return RankingGui_.instance
end

--========================
-- private method
--========================
local CharacterImageSetter = require(ReplicatedFirst:WaitForChild("Nexapp"):WaitForChild("Common"):WaitForChild("System"):WaitForChild("CharacterImageSetter"))

--========================
-- private method
--========================
local function Init(self, gui : ScreenGui)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local rankingEvent = ReplicatedStorage:WaitForChild("RemoteEvent"):WaitForChild("RankingUpdate") :: RemoteEvent
	local frame = gui:WaitForChild("Frame") :: Frame
	frame.Visible = false
	
	local battleStatusEvent = ReplicatedStorage:WaitForChild("RemoteEvent"):WaitForChild("BattleStatus") :: RemoteEvent
	battleStatusEvent.OnClientEvent:Connect(function(isActive: boolean)
		if not isActive then
			frame.Visible = false
			return
		end
	end)
	
	rankingEvent.OnClientEvent:Connect(function(rankingData)
		local maxScore = rankingData[1]
		if maxScore == 0 then
			frame.Visible = false
			return
		end
		frame.Visible = true
		for i = 1, 8 do
			local imageFrame = frame:FindFirstChild("Image" .. i) :: ImageLabel?
			if not imageFrame then continue end
			
			local data = rankingData[i]
			if data then
				imageFrame.Visible = true
				
				local scoreText = imageFrame:FindFirstChild("ScoreText" .. i) :: TextLabel?
				if scoreText then
					scoreText.Text = tostring(data.Score)
				end
				
				local rankText = imageFrame:FindFirstChild("RankText" .. i) :: TextLabel?
				if rankText then
					rankText.Text = "#" .. i
				end
				
				CharacterImageSetter.SetImageByInfo(data.Name, data.UserId, imageFrame)
			else
				imageFrame.Visible = false
			end
		end
	end)
end

--========================
-- public method
--========================

function RankingGui_.new(...)
	local self = setmetatable(BaseGui_.new(...), RankingGui_)
	Init(self, ...)
	RankingGui_.instance = self
	return self
end

return RankingGui_
