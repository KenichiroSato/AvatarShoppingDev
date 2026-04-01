
local ReplicatedStorage = game:GetService("ReplicatedStorage")-- 名前: WandLocalScript
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local fireTrickEvent = ReplicatedStorage:WaitForChild("RemoteEvent"):WaitForChild("FireTrickEvent")
local Players = game:GetService("Players")
local SingleTapDetector_ = require(ReplicatedFirst.Nexsys.Client.SingleTapDetector_)

local player = Players.LocalPlayer
local wand = script.Parent

local lastHitTimes: {[Player]: number} = {}
local WAND_COOLDOWN = 1 -- 秒
local canWandActivate = true

local singleTapDetector = SingleTapDetector_.new()

-- アニメーション設定
local function playWandAnimation()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local anim = ReplicatedStorage.Wands.ToolSlashAnim
		local track = animator:LoadAnimation(anim)
		track:Play()
	end
end

local function find3DLocationFromInput(touchLocation):Vector3

	-- 2. その点から3D空間へ向かう「細い光線(Ray)」を作る
	local camera = workspace.CurrentCamera
	local unitRay = camera:ScreenPointToRay(touchLocation.X, touchLocation.Y)
	local raycastParams = RaycastParams.new()
	-- 自分のキャラクターは無視する設定
	raycastParams.FilterDescendantsInstances = {game.Players.LocalPlayer.Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, raycastParams)

	if result then
		-- 何かに当たった場合、その場所のVector3を返す
		return result.Position
	else
		-- 何にも当たらなかった（空など）場合、遠くの地点を返す
		return unitRay.Origin + (unitRay.Direction * 500)
	end

end

singleTapDetector:Start(function(input)
	print("singleTapDetector start")
	local character = player.Character
	if character then
		local wand = character:FindFirstChildWhichIsA("Tool")
		if wand and wand:GetAttribute("BattleWand") then
			if not canWandActivate then return end
			canWandActivate = false

			playWandAnimation()
			local targetPos = find3DLocationFromInput(input.Position)
			print("sato singleTapDetector pos =", targetPos)

			fireTrickEvent:FireServer(targetPos, wand)
			task.delay(WAND_COOLDOWN, function()
				canWandActivate = true
			end)
		end
	end
end)

