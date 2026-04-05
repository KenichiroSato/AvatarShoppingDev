local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Define = require(ReplicatedFirst.Nexapp.Common.Define)

local TimeManager = {}

local function GetRemoteEvent()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteEventFolder = ReplicatedStorage:FindFirstChild("RemoteEvent")
	if not remoteEventFolder then
		remoteEventFolder = Instance.new("Folder")
		remoteEventFolder.Name = "RemoteEvent"
		remoteEventFolder.Parent = ReplicatedStorage
	end
	
	local remoteEvent = remoteEventFolder:FindFirstChild("TimeUpdate")
	if not remoteEvent then
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = "TimeUpdate"
		remoteEvent.Parent = remoteEventFolder
	end
	return remoteEvent
end

function TimeManager.Start()
	print("TimeManager started")
	local parent = script.Parent
	if not parent then return end
	local BattleManager = require(parent:WaitForChild("BattleManager"))
	local remoteEvent = GetRemoteEvent()
	
	task.spawn(function()
		while true do
			-- 30 seconds count
			for i = Define.INTERVAL_DURATION, 0, -1 do
				remoteEvent:FireAllClients(i, "Break")
				task.wait(1)
			end
			
			BattleManager.Start()
			
			-- 3 minutes count
			for i = 120, 0, -1 do
				remoteEvent:FireAllClients(i, "Battle")
				task.wait(1)
			end
			
			BattleManager.Stop()
		end
	end)
end

return TimeManager
