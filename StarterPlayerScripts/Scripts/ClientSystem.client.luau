
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FadeController = require(ReplicatedFirst.Nexsys.Client.Event.FadeController_)
local Players = game:GetService("Players")
local remoteEventFolder = ReplicatedStorage:WaitForChild("RemoteEvent")
local fadeEvent = remoteEventFolder:WaitForChild("FadeEvent")
local teleportEvent = remoteEventFolder:WaitForChild("TeleportEvent")
local CameraManager_ = require(ReplicatedFirst.Nexsys.Client.CameraManager_)

local fadeController = FadeController.new()

fadeEvent.OnClientEvent:Connect(function(isOut: boolean, isWhite: boolean?)
    if isOut then
        fadeController:StartFadeOut(1, isWhite)
    else
        fadeController:StartFadeIn(1, isWhite)
    end
end)

teleportEvent.OnClientEvent:Connect(function()
    CameraManager_.AlignCameraToCharacter(Players.LocalPlayer.Character)
end)

-- Hide default Backpack UI
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
