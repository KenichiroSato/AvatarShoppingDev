--!strict
local TrickHandler = {}

-- ServerScriptService 内 Script
local replicatedStorage = game:GetService("ReplicatedStorage")
local Tricks = require(replicatedStorage:WaitForChild("Script"):WaitForChild("Tricks")) 
local players = game:GetService("Players")
local fireTrickEvent = replicatedStorage:WaitForChild("RemoteEvent"):WaitForChild("FireTrickEvent")
local fireTrickFromNpcEvent = replicatedStorage:WaitForChild("BindableEvent"):WaitForChild("fireTrickFromNpcEvent")
local generalMessageEvent = replicatedStorage.RemoteEvent.GeneralMessageEvent
local trickSoundEvent = replicatedStorage:WaitForChild("RemoteEvent"):FindFirstChild("TrickSoundEvent") :: RemoteEvent
local ServerScriptService = game:GetService("ServerScriptService")
local LocalizationService = game:GetService("LocalizationService")

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local onHitCallback: ((string, string) -> ())? = nil
local isSameTeamCallback: ((string, string) -> boolean)? = nil
local isBattleActive = false

-- プレイヤーの状態を記録
local characterState = {}

--プレイヤーの状態と値を登録
local function setCharacterState(characterId: string, time, value)
	if not characterState[characterId] then
		characterState[characterId] = {}
	end
	if not characterState[characterId] then
		characterState[characterId] = {}
	end
	characterState[characterId]["Time"] = time
	characterState[characterId]["Value"] = value
	print(characterState)
end

--プレイヤーの状態における値を取得
local function getCharacterState(characterId: string)
	if characterState[characterId] then
		if characterState[characterId] then
			return characterState[characterId].Value
		end 
	end
	print("not found characterState")
	return nil
end

--プレイヤーの状態登録時の時間を取得
local function getCharacterStateTime(characterId: string)
	if characterState[characterId] then
		if characterState[characterId] then
			return characterState[characterId].Time
		end 
	end
	print("not found characterStateTime")
	return nil
end

--プレイヤーの状態を削除
local function removeCharacterState(characterId: string)
	characterState[characterId] = nil
end

---------------------------------------------------------------
--魔法の効果をターゲットプレイヤーに適用する関数
---------------------------------------------------------------
local function applyTrickEffect(character: Model, trickName: string)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")

	local animationId = Tricks:GetAnimId(trickName) :: string
	local animation = Instance.new("Animation")
	local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator
	local oldTrack = getCharacterState(character.Name)
	animation.AnimationId = animationId
	local track = animator:LoadAnimation(animation)
	local currentTime = tick()

	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	
	-- Stop old sound if exists
	if hrp then
		local oldSound = hrp:FindFirstChild("TrickBGM")
		if oldSound then
			oldSound:Destroy()
		end
	end
	
	--5秒以内に連続でかけられたとき魔法を上書き
	if oldTrack and oldTrack.IsPlaying then
		oldTrack:Stop()
		oldTrack:Destroy()
	end

	track:Play()
	
	-- Play random BGM
	if hrp then
		local SoundService = game:GetService("SoundService")
		local bgmFolder = SoundService:FindFirstChild("BGM")
		if bgmFolder then
			local sounds = bgmFolder:GetChildren()
			if #sounds > 0 then
				local rng = Random.new()
				local randomSound = sounds[rng:NextInteger(1, #sounds)]:Clone()
				if randomSound:IsA("Sound") then
					randomSound.Name = "TrickBGM"
					randomSound.Parent = hrp
					randomSound.Looped = true
					randomSound.Volume = 2.0
					randomSound:Play()
				else
					randomSound:Destroy()
				end
			end
		end
	end
	
	setCharacterState(character.Name,currentTime, track)
	task.delay(10, function()
		if getCharacterStateTime(character.Name) == currentTime then--最後にかけられた魔法から5秒後に終了
			track:Stop()
			track:Destroy()
			
			-- Stop sound
			if hrp then
				local sound = hrp:FindFirstChild("TrickBGM")
				if sound then
					sound:Destroy()
				end
			end
			
			removeCharacterState(character.Name)
		end
	end)
end

--魔法弾モデル、発射音の選択関数
local function getProjectile(wand: Tool, character: Model)
	local projectileModel = replicatedStorage.Model.Projectile.ProjectileBallBase:Clone()
	local sparcles = {"NormalSparcle"} -- ProfileManager:GetSelectedSparcles(player)
	for _, sparcle in sparcles do
		local emitter = projectileModel:FindFirstChild(sparcle):: ParticleEmitter
		if emitter then
			emitter.Enabled = true
		end
	end
	local fireSound =  game:GetService("SoundService").TrickShootSound:Clone()
	return projectileModel, fireSound
end

local PROJECTILE_SPEED = 200
local PROJECTILE_LIFETIME =3

--魔法弾の生成関数
local function setProjectile(wand: Tool, character: Model)
	local handle = wand:WaitForChild("Handle") :: Part
	local origin = handle.CFrame.Position--出現元座標

	--弾丸、発射音生成
	local projectile, fireSound = getProjectile(wand, character)
	projectile.CFrame = CFrame.new(origin)

	--発射音の再生
	fireSound.Parent = handle
	fireSound:Play()
	fireSound.Ended:Connect(function()
		fireSound:Destroy()
	end)

	projectile.Parent = workspace
	game.Debris:AddItem(projectile, PROJECTILE_LIFETIME)--弾丸を3秒後に削除
	return projectile, origin
end

local function GetTrickName(): string
	local danceTricks = {}

	for name, data in pairs(Tricks) do
		if type(data) == "table" and data.TrickType == "Dance" then
			table.insert(danceTricks, name)
		end
	end

	if #danceTricks > 0 then
		local randomIndex = math.random(1, #danceTricks)
		return danceTricks[randomIndex]
	end

	return "DancePonPon"
end

---------------------------------------------------------------
--魔法弾の生成関数
---------------------------------------------------------------
local TweenService = game:GetService("TweenService")

local function ShowBeam(projectile: BasePart, origin: Vector3, targetVisualPos: Vector3)
	-- 見た目の処理 (Tweenで飛ばす)
	local distance = (targetVisualPos - origin).Magnitude
	local travelTime = distance / PROJECTILE_SPEED -- 速度に合わせて到達時間を計算

	-- Beam表示
	local attachment0 = Instance.new("Attachment")
	local attachment1 = Instance.new("Attachment")
	attachment0.Parent = workspace.Terrain
	attachment0.WorldPosition = origin
	attachment1.Parent = workspace.Terrain
	attachment1.WorldPosition = targetVisualPos

	local beam = Instance.new("Beam")
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.FaceCamera = true
	beam.Width0 = 0.9
	beam.Width1 = 0.9
	beam.Color = ColorSequence.new(Color3.new(1, 1, 0.4)) -- 淡い黄色
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0)
	beam.Parent = workspace

	game:GetService("Debris"):AddItem(attachment0, 0.5)
	game:GetService("Debris"):AddItem(attachment1, 0.5)
	game:GetService("Debris"):AddItem(beam, 0.5)
	
	-- Tween設定
	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = TweenService:Create(projectile, tweenInfo, {CFrame = CFrame.new(targetVisualPos)})
	
	tween:Play()
	tween.Completed:Connect(function()
		if projectile and projectile.Parent then
			task.wait(0.2)
			projectile:Destroy()
		end
	end)
end



local function fireProjectile(character: Model,targetPosition: Vector3, wand: Tool)
	if not isBattleActive then return end
	if not character then return end
	local trickName = GetTrickName()--wand:GetAttribute("TrickName")
	local shooterName = character.Name

	--弾丸生成
	local projectile, origin = setProjectile(wand, character)
	local direction = (targetPosition - origin).Unit--移動する方向
	
	-- Raycast 設定
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	-- 発射者のキャラと弾本体は当たり判定から除外
	rayParams.FilterDescendantsInstances = { character, projectile }
	
	-- 即座にRaycastを実行
	local maxDistance = PROJECTILE_SPEED * PROJECTILE_LIFETIME
	local result = workspace:Raycast(origin, direction * maxDistance, rayParams)
	
	local targetVisualPos = result and result.Position or origin + direction * maxDistance -- デフォルトは最大距離
	ShowBeam(projectile, origin, targetVisualPos)
	if result then		
		local function applyTrick(characterModel: Model)
			-- 同チームへのヒットは無効
			if isSameTeamCallback and isSameTeamCallback(shooterName, characterModel.Name) then
				print("[TrickHandler] Same team hit ignored: " .. shooterName .. " → " .. characterModel.Name)
				return
			end
			applyTrickEffect(characterModel, trickName)
			-- コールバック関数でヒット情報を通知
			if onHitCallback then
				onHitCallback(shooterName, characterModel.Name)
			end
		end

		-- ヒット相手のキャラクターを特定
		local hit = result.Instance

		--NPCにヒットした場合
		if hit:FindFirstAncestorOfClass("Model") then
			local characterModel = hit:FindFirstAncestorOfClass("Model")
			if characterModel and characterModel:GetAttribute("TrickTargetNPC") == true then
				applyTrick(characterModel)
			end
		end

		--プレイヤーにヒットした場合
		local hitModel = hit and hit:FindFirstAncestorOfClass("Model")
		local targetPlayer = hitModel and game.Players:GetPlayerFromCharacter(hitModel)
		if targetPlayer then
			local chara = targetPlayer.Character
			if chara then
				applyTrick(chara)
			end
		end
	end
	

end


function TrickHandler.StartBattle(hitCallback: (string, string) -> (), sameTeamCallback: ((string, string) -> boolean)?)
	isBattleActive = true
	onHitCallback = hitCallback
	isSameTeamCallback = sameTeamCallback
end

function TrickHandler.FinishBattle()
	isBattleActive = false
	onHitCallback = nil
	isSameTeamCallback = nil
end

fireTrickEvent.OnServerEvent:Connect(function(player: Player,targetPosition: Vector3, wand: Tool)
	local character = player.Character
	if not character then return end
	if character:GetAttribute("IsStunned") then return end
	fireProjectile(character,targetPosition, wand)
end)

fireTrickFromNpcEvent.Event:Connect(function(character: Model,targetPosition: Vector3, wand: Tool)
	if character:GetAttribute("IsStunned") then return end
	fireProjectile(character,targetPosition, wand)
end)

-- プレイヤーが退出した場合、そのプレイヤーの状態を削除
players.PlayerRemoving:Connect(function(player)
	local chara = player.Character
	if chara then
		characterState[chara.Name] = nil
	end
end)

return TrickHandler
