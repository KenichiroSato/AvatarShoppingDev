local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local SoundService = game:GetService("SoundService")

local trickSoundEvent = ReplicatedStorage:WaitForChild("RemoteEvent"):WaitForChild("TrickSoundEvent")
local BGMManager_ = require(ReplicatedFirst.Nexsys.Client.BGMManager_)

local function ChooseBgm(): string
	local bgmFolder = SoundService:WaitForChild("BGM")
	local sounds = bgmFolder:GetChildren()
	local soundList = {}
	for _, sound in ipairs(sounds) do
		if sound:IsA("Sound") then
			table.insert(soundList, sound.Name)
		end
	end
	
	if #soundList > 0 then
		local index = math.random(1, #soundList)
		return soundList[index]
	end
	return "MarioTomato" -- Fallback
end

trickSoundEvent.OnClientEvent:Connect(function(isPlay, soundName)
    print("ClientSoundHandler: " .. tostring(isPlay) .. " " .. tostring(soundName))
	if isPlay then
		BGMManager_.PlayBGMByName(ChooseBgm())
	else
		BGMManager_.StopBGM()
	end
end)
