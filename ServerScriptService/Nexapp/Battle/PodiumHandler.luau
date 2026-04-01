local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Debris = game:GetService("Debris")

-- Assuming Tricks is located at ReplicatedStorage.Script.Tricks based on BattleManager code
local Tricks = require(ReplicatedStorage:WaitForChild("Script"):WaitForChild("Tricks"))
local Define = require(ReplicatedFirst.Nexapp.Common.Define)

local PodiumHandler = {}

local activeObjects = {}

function PodiumHandler.Reset()
	for _, obj in ipairs(activeObjects) do
		if obj then
			obj:Destroy()
		end
	end
	activeObjects = {}
end

local function PlayAnimation(character: Model, animId: string)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)
	
	local animation = Instance.new("Animation")
	animation.AnimationId = animId
	
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track:Play()
end

local function PlayBgm(): Sound?
    local podium = workspace:FindFirstChild("1stPos", true)
    local SoundService = game:GetService("SoundService")
    local bgmFolder = SoundService:FindFirstChild("BGM")
    if bgmFolder then
        local sounds = bgmFolder:GetChildren()
        if #sounds > 0 then
            local rng = Random.new()
            local randomSound = sounds[rng:NextInteger(1, #sounds)]:Clone()
            if randomSound:IsA("Sound") then
                randomSound.Name = "TrickBGM"
                randomSound.Parent = podium
                randomSound.Looped = true
                randomSound.Volume = 2.0
                randomSound:Play()
				return randomSound
            else
                randomSound:Destroy()
            end
        end
    end
	return nil
end  

function PodiumHandler.Display(topRanking, battleParticipants)
	local podium = workspace:FindFirstChild("Podium", true)
	
	if podium then
		local positions = {
			{Part = podium:FindFirstChild("1stPos"), Dance = "DanceShowstopper"},
			{Part = podium:FindFirstChild("2ndPos"), Dance = "DanceFreeFlow"},
			{Part = podium:FindFirstChild("3rdPos"), Dance = "DanceBoogieBomb"}
		}
		
		for i = 1, 3 do
			if topRanking[i] then
				local winnerData = topRanking[i]
				local winnerModel
				
				if winnerData.IsNpc then
					for _, npc in ipairs(battleParticipants.npcs) do
						if npc.Name == winnerData.Name then
							winnerModel = npc
							break
						end
					end
				else
					local player = Players:GetPlayerByUserId(winnerData.UserId)
					if player then
						winnerModel = player.Character
					end
				end
				
				if winnerModel then
					winnerModel.Archivable = true
					local clone = winnerModel:Clone()
					local barrier = clone:FindFirstChild("BarrierModel")
					if barrier then
						barrier:Destroy()
					end
					local bgm = clone:FindFirstChild("TrickBGM", true)
					if bgm then
						bgm:Destroy()
					end
					winnerModel.Archivable = false
					
					local posData = positions[i]
					if posData and posData.Part and posData.Part:IsA("BasePart") then
						clone.Parent = workspace
						table.insert(activeObjects, clone)
						
						local hrp = clone:FindFirstChild("HumanoidRootPart") :: BasePart
						if hrp then
							hrp.CFrame = posData.Part.CFrame + Vector3.new(0, 0, 0)
							hrp.Anchored = false
							task.spawn(function()
								--task.wait(0.2)
								hrp.Anchored = true
							end)
						end
						
						-- Play Dance
						local animId = Tricks:GetAnimId(posData.Dance)
						if animId then
							PlayAnimation(clone, animId)
						end
						-- Debris:AddItem(clone, 30) -- Handled by Reset now
					else
						clone:Destroy()
					end
				end
			end
		end

        local bgm = PlayBgm()
		if bgm then
			table.insert(activeObjects, bgm)
		end
		
		-- Fire Cutscene Event
		local remoteEventFolder = ReplicatedStorage:FindFirstChild("RemoteEvent")
		if not remoteEventFolder then
			remoteEventFolder = Instance.new("Folder")
			remoteEventFolder.Name = "RemoteEvent"
			remoteEventFolder.Parent = ReplicatedStorage
		end
		
		local podiumCutsceneEvent = remoteEventFolder:FindFirstChild("PodiumCutscene")
		if not podiumCutsceneEvent then
			podiumCutsceneEvent = Instance.new("RemoteEvent")
			podiumCutsceneEvent.Name = "PodiumCutscene"
			podiumCutsceneEvent.Parent = remoteEventFolder
		end
		
		
		podiumCutsceneEvent:FireAllClients()
		-- task.wait(Define.PODIUM_CUTSCENE_TIME) -- Handled in BattleManager now
	end
end

return PodiumHandler
