local CharacterImageSetter = {}

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local NpcData = require(ReplicatedFirst:WaitForChild("Exdata"):WaitForChild("NpcData"))

function CharacterImageSetter.SetImage(character : Model, imageLabel : ImageLabel)
	local player = Players:GetPlayerFromCharacter(character)
	local userId = player and player.UserId or 0
	CharacterImageSetter.SetImageByInfo(character.Name, userId, imageLabel)
end

function CharacterImageSetter.SetImageByInfo(name: string, userId: number?, imageLabel: ImageLabel)
	if userId and userId > 0 then
		-- It's a player
		local content, isReady = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		if isReady then
			imageLabel.Image = content
		else
			task.spawn(function()
				local contentRetry, isReadyRetry = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				if isReadyRetry then
					imageLabel.Image = contentRetry
				end
			end)
		end
	else
		-- It's likely an NPC
		local npcInfo = NpcData[name]
		if npcInfo and npcInfo.ImageId then
			imageLabel.Image = npcInfo.ImageId
		else
			-- Fallback check for fake NPCs if needed, or clear image
			imageLabel.Image = ""
		end
	end
end

return CharacterImageSetter
