--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)
local RemoteSender_ = require(ReplicatedFirst.Nexsys.Client.RemoteSender_)

local ROTATE_DEG_PER_SEC = 72  -- 5秒で1周

--- @class InviteFriendsGui_ : BaseGui_
local InviteFriendsGui_ = {}
InviteFriendsGui_.__index = InviteFriendsGui_
setmetatable(InviteFriendsGui_, BaseGui_)
InviteFriendsGui_.instance = nil

----------------------------------------------------------------------------------------------------
function InviteFriendsGui_.GetInstance()
	return InviteFriendsGui_.instance
end

--========================
-- private
--========================

local function Init(self, gui: ScreenGui)
	self:WaitForLoaded(gui)
	self:WaitForSaveDataLoaded()

	local frame = gui:WaitForChild("Frame") :: Frame
	local backImage = frame:WaitForChild("BackImage") :: ImageLabel
	local inviteButton = frame:WaitForChild("InviteButton") :: TextButton
	local localPlayer = Players.LocalPlayer

	-- BackImage 常時回転
	RunService.Heartbeat:Connect(function(dt)
		backImage.Rotation = backImage.Rotation + ROTATE_DEG_PER_SEC * dt
	end)

	-- バトル中は非表示
	local battlePhaseEvent = ReplicatedStorage:WaitForChild("RemoteEvent"):WaitForChild("BattlePhaseUpdate") :: RemoteEvent
	battlePhaseEvent.OnClientEvent:Connect(function(phase: string)
		local hideUI = phase == "Transitioning" or phase == "TeamSelection" or phase == "Countdown" or phase == "Active"
		gui.Enabled = not hideUI
	end)

	-- セッション内に一度だけ報酬を受け取れる
	local hasReceivedReward = false

	-- 招待ダイアログが閉じたときに、送信済みなら報酬リクエスト
	SocialService.GameInvitePromptClosed:Connect(function(player, recipientIds)
		print("Invite closed:", #recipientIds)
		if player ~= localPlayer then return end
		if hasReceivedReward then return end
		--#recipientIds取れないので常時付与
		--if recipientIds and #recipientIds > 0 then
			hasReceivedReward = true
			RemoteSender_.SendEvent("RCS_OnInviteFriendsSent")
		--end
	end)

	-- InviteButton押下でネイティブ招待UI（友達リスト付き）を表示
	inviteButton.Activated:Connect(function()
		local ok, canInvite = pcall(function()
			return SocialService:CanSendGameInviteAsync(localPlayer)
		end)
		if ok and canInvite then
			pcall(function()
				SocialService:PromptGameInvite(localPlayer)
			end)
		end
	end)
end

--========================
-- public
--========================

function InviteFriendsGui_.new(...)
	local self = setmetatable(BaseGui_.new(...), InviteFriendsGui_)
	Init(self, ...)
	InviteFriendsGui_.instance = self
	return self
end

return InviteFriendsGui_
