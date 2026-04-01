local Workspace = game:GetService("Workspace")

-- Humanoidを最適化する関数
local function optimizeHumanoid(humanoid)
	-- 1. すべてのステート計算を無効化
	humanoid:SetStateEnabled(Enum.HumanoidStateType.All, false)

	-- 2. 不要な自動計算プロパティをオフにする
	humanoid.CanClimb = false
	humanoid.AutoJumpEnabled = false
	humanoid.AutomaticScalingEnabled = false

	-- 3. 名前やHPバーの表示計算を停止（置物なら不要）
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	-- 4. パーツを物理演算から切り離す (AnchoredをTrueにする)
	local character = humanoid.Parent
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				-- 置物なら衝突判定も不要な場合は以下を有効に（コメントアウト解除）
				-- part.CanCollide = false
				-- part.CanTouch = false
			end
		end
	end

	print("Optimized Humanoid: " .. humanoid:GetFullName())
end

-- 既にWorkspaceに存在するものを処理
for _, obj in ipairs(Workspace:GetDescendants()) do
	if obj:IsA("Humanoid") then
		optimizeHumanoid(obj)
	end
end

-- 今後追加されるものに対しても自動実行
Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Humanoid") then
		optimizeHumanoid(descendant)
	end
end)