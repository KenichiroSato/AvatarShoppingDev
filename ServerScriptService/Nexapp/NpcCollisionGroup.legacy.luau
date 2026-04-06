-- ServerScriptService/RegisterNPCollisionGroup.server.lua
local PhysicsService = game:GetService("PhysicsService")
local Rep = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local PARTICIPANTS_GROUP = "PARTICIPANTS"

-- CollisionGroup を作成（すでにあってもOK）
pcall(function()
	PhysicsService:CreateCollisionGroup(PARTICIPANTS_GROUP)
end)

-- グループ内のメンバー同士は衝突しない
PhysicsService:CollisionGroupSetCollidable(PARTICIPANTS_GROUP, PARTICIPANTS_GROUP, false)

-- Model 内のすべての Part をグループに入れる
local function registerModelToParticipantsGroup(model: Model)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(inst, PARTICIPANTS_GROUP)
		end
	end
end

-- ReplicatedStorage.NPCs のモデルを登録
for _, inst in ipairs(ServerStorage.NPCs:GetChildren()) do
	if inst:IsA("Model") then
		registerModelToParticipantsGroup(inst)

		-- 後から追加される Part（Tool / Accessory 対策）
		inst.DescendantAdded:Connect(function(desc)
			if desc:IsA("BasePart") then
				PhysicsService:SetPartCollisionGroup(desc, PARTICIPANTS_GROUP)
			end
		end)
	end
end

-- Workspace.NPCs のクローンされたNPCを登録
local function registerWorkspaceNPCs()
	local workspaceNpcFolder = workspace:FindFirstChild("NPCs")
	if workspaceNpcFolder then
		for _, inst in ipairs(workspaceNpcFolder:GetChildren()) do
			if inst:IsA("Model") then
				registerModelToParticipantsGroup(inst)

				-- 後から追加される Part（Tool / Accessory 対策）
				inst.DescendantAdded:Connect(function(desc)
					if desc:IsA("BasePart") then
						PhysicsService:SetPartCollisionGroup(desc, PARTICIPANTS_GROUP)
					end
				end)
			end
		end
	end
end

-- プレイヤーのキャラクターをグループに登録
local function registerPlayerCharacter(player: Player)
	local character = player.Character
	if character then
		registerModelToParticipantsGroup(character)

		-- 後から追加される Part（Tool / Accessory 対策）
		character.DescendantAdded:Connect(function(desc)
			if desc:IsA("BasePart") then
				PhysicsService:SetPartCollisionGroup(desc, PARTICIPANTS_GROUP)
			end
		end)
	end
end

-- 現在のプレイヤーを登録
for _, player in ipairs(Players:GetPlayers()) do
	registerPlayerCharacter(player)
end

-- 新しいプレイヤーが参加したときに登録
Players.PlayerAdded:Connect(registerPlayerCharacter)

-- キャラクターがリスポーンしたときに再登録
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		registerPlayerCharacter(player)
	end)
end)

-- NPCs フォルダが作成されたら登録
workspace.ChildAdded:Connect(function(child)
	if child.Name == "NPCs" then
		registerWorkspaceNPCs()
	end
end)

-- 初期化時に workspace.NPCs が既に存在したら登録
registerWorkspaceNPCs()
