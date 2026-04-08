--!strict
--- OOP-style NPC module
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local fireTrickFromNpcEvent = ReplicatedStorage:WaitForChild("BindableEvent"):WaitForChild("fireTrickFromNpcEvent") :: BindableEvent

local Npc = {}
Npc.__index = Npc

-- ===== 設定 =====
local DETECT_RADIUS = 20000
local REPTHINK_INTERVAL = 0.1
local WAYPOINT_SPACING = 4
local AGENT_RADIUS = 2
local AGENT_HEIGHT = 5
local CAN_JUMP = true
local RANDOM_RADIUS = 10 -- studs
local MIN_WAYPOINT_ADVANCE = 6

-- コンストラクタ: model を渡してインスタンス化
function Npc.new(model: Model)
	local self = setmetatable({}, Npc)
	self.model = model
	self.humanoid = model:WaitForChild("Humanoid") :: Humanoid
	self.hrp = model:WaitForChild("HumanoidRootPart") :: BasePart
	self.hrp.Anchored = false
	self.wand = model:FindFirstChildWhichIsA("Tool") :: Tool?
	self._running = false
	self._task = nil
	return self
end

-- ターゲット選定 (local functions to reduce per-instance overhead)
local function PickRandomTarget(self): BasePart?
	-- Select a random Part named "Floor" under workspace/HouseBases
	local houseBases = workspace:FindFirstChild("HouseBases") :: Instance?
	if not houseBases then
		return nil
	end

	local floors: {BasePart} = {}
	for _, desc in ipairs(houseBases:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name == "Floor" then
			table.insert(floors, desc)
		end
	end

	if #floors == 0 then
		return nil
	end

	local rng = Random.new(tick())
	return floors[rng:NextInteger(1, #floors)]
end

local function ComputePath(self, goalPos: Vector3)
	local path = PathfindingService:CreatePath({
		AgentRadius = AGENT_RADIUS,
		AgentHeight = AGENT_HEIGHT,
		AgentCanJump = CAN_JUMP,
		WaypointSpacing = WAYPOINT_SPACING,
	})
	path:ComputeAsync(self.hrp.Position, goalPos)
	return path
end

local function RandomizeGoalPos(self, pos: Vector3): Vector3
	local angle = math.random() * math.pi * 2
	local r = math.random() * RANDOM_RADIUS
	local offset = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
	return pos + offset
end

local BattleManager
local function FindTarget(self)
	if not BattleManager then
		BattleManager = require(script.Parent:WaitForChild("BattleManager") :: ModuleScript)
	end

	local participants = BattleManager.GetParticipants()
	local myPos = self.hrp.Position
	local closestTarget = nil
	local minDist = 80 -- Sight range (studs)

	local candidates = {}
	for _, p in ipairs(participants.players) do table.insert(candidates, p) end
	for _, n in ipairs(participants.npcs) do table.insert(candidates, n) end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {self.model}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	for _, target in ipairs(candidates) do
		if target == self.model then continue end
		if target:FindFirstChild("BarrierModel") then continue end -- Skip targets with barrier
		local targetHrp = target:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not targetHrp then continue end

		-- 同チームはターゲットにしない
		local myTeam     = BattleManager.GetParticipantTeam(self.model.Name)
		local targetTeam = BattleManager.GetParticipantTeam(target.Name)
		if myTeam and targetTeam and myTeam == targetTeam then continue end

		local dist = (targetHrp.Position - myPos).Magnitude
		if dist < minDist then
			-- Visibility Check
			local origin = myPos
			local myHead = self.model:FindFirstChild("Head") :: BasePart?
			if myHead then
				origin = myHead.Position
			end
			
			local targetHeadPos = targetHrp.Position
			local targetHead = target:FindFirstChild("Head") :: BasePart?
			if targetHead then
				targetHeadPos = targetHead.Position
			end
			
			local direction = targetHeadPos - origin

			local result = workspace:Raycast(origin, direction, rayParams)
			if result and result.Instance:IsDescendantOf(target) then
				minDist = dist
				closestTarget = target
			end
		end
	end

	return closestTarget
end

local function TryShoot(self)
	if not self.wand then return end
	if self.model:GetAttribute("IsStunned") then return end
	
	local target = FindTarget(self)
	if not target then return end
	
	local targetHrp = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetHrp then return end

	local hitCounts = BattleManager.GetHitCounts()
	local participants = BattleManager.GetParticipants()
	
	local totalPlayerScore = 0
	local playerCount = 0
	for _, player in ipairs(participants.players) do
		local score = hitCounts[player.Name] or 0
		totalPlayerScore += score
		playerCount += 1
	end
	
	local averageScore = if playerCount > 0 then totalPlayerScore / playerCount else 0

	local myName = self.model.Name
	local myScore = hitCounts[myName] or 0
	
	local diff = math.max(0, averageScore - myScore)

	-- Chance increases as diff increases (NPC is losing)
	-- Base chance when diff is 0 depends on the NPC's randomized _fireRateBase
	-- Max chance is 1/6 (~17%)
	local baseChance = self._fireRateBase or 30
	local randMax = math.max(6, baseChance - math.floor(diff*5))
	local rand = math.random(1, randMax)
	if rand == 1 then
		-- 精度パラメータに基づきspreadに乗数をかける。高い精度ほどspreadが小さい
		local accuracyLevel = self._accuracyLevel or 5
		local spreadMultiplier = (11 - accuracyLevel) * 0.2
		
		-- spread が大きいほど外れる（精度低）
		local spread = (3 / (diff + 1)) * spreadMultiplier
		
		local offset = Vector3.new(
			(math.random() - 0.5) * spread * 10,
			(math.random() - 0.5) * spread,
			(math.random() - 0.5) * spread * 10
		)
		
		fireTrickFromNpcEvent:Fire(self.model, targetHrp.Position + offset, self.wand)
	end
end

local function RunLoop(self)
	while self._running and self.model.Parent do
		local targetEntity = PickRandomTarget(self)
		if not targetEntity then
			task.wait(0.5)
			continue
		end

		local target: BasePart?
		if targetEntity:IsA("BasePart") then
			target = targetEntity :: BasePart
		elseif targetEntity:IsA("Model") then
			target = targetEntity:FindFirstChild("HumanoidRootPart") or targetEntity.PrimaryPart or targetEntity:FindFirstChildWhichIsA("BasePart")
		end
		if not target then
			task.wait(0.3)
			continue
		end

		local goalPos = RandomizeGoalPos(self, target.Position)
		local path = ComputePath(self, goalPos)

		if path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			local minsteps = math.min(MIN_WAYPOINT_ADVANCE, #waypoints)
			local steps = math.random(minsteps, #waypoints)
			local ok = true

			for i = 1, steps do
				local wp = waypoints[i]
				if wp.Action == Enum.PathWaypointAction.Jump then
					self.humanoid.Jump = true
				end

				self.humanoid:MoveTo(wp.Position)
				TryShoot(self)
				local reached = self.humanoid.MoveToFinished:Wait()
				if not reached then
					ok = false
					break
				end
			end

			if not ok then
				task.wait(0.2)
			end
		else
			task.wait(0.2)
		end

		task.wait(REPTHINK_INTERVAL)
	end
end

function Npc:Start()
	if self._running then return end
	self._running = true
	
	-- TryShootの精度を決めるランダムなパラメータ: 1(最低) ~ 10(最高)
	self._accuracyLevel = math.random(1, 10)
	
	-- TryShootの頻度を決めるランダムなパラメータ: ベースの確率分母 (小さいほど頻度が高い)
	self._fireRateBase = math.random(1, 20)
	
	self._task = task.spawn(function()
		RunLoop(self)
	end)
end

function Npc:Stop()
	self._running = false
end

return Npc
