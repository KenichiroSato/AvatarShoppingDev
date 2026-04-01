local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Define = require(ReplicatedFirst.Nexapp.Common.Define)
local camera = workspace.CurrentCamera

local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
local podiumCutsceneEvent = remoteEventFolder:WaitForChild("PodiumCutscene")

local function PlayCutscene()
	local podium = workspace:FindFirstChild("1stPos", true)
	if not podium then return end
		
	camera.CameraType = Enum.CameraType.Scriptable
	
	-- Start Position: High up and back
	local startCFrame = CFrame.new(podium.Position + Vector3.new(25, 15, 0), podium.Position)
	camera.CFrame = startCFrame
	
	-- End Position: Closer look
	local endCFrame = CFrame.new(podium.Position + Vector3.new(12, 5, 0), podium.Position)
	
	local tweenInfo = TweenInfo.new(
		5, -- Duration
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	
	local tween = TweenService:Create(camera, tweenInfo, {CFrame = endCFrame})
	tween:Play()
	
	-- Clean up after 5 seconds
	task.delay(Define.PODIUM_CUTSCENE_TIME, function()
		camera.CameraType = Enum.CameraType.Custom
	end)
end

podiumCutsceneEvent.OnClientEvent:Connect(PlayCutscene)
