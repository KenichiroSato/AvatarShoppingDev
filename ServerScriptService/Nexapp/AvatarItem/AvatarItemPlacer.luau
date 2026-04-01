local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local AssetService = game:GetService("AssetService")
local Items = require(script.Parent.Items)
local Constants = require(ReplicatedStorage.TryOn.Constants)

local AvatarItemPlacer = {}
AvatarItemPlacer.__index = AvatarItemPlacer

function AvatarItemPlacer.new()
	local self = setmetatable({}, AvatarItemPlacer)
	return self
end

function AvatarItemPlacer:PlaceItems()
	local index = 0
	for _, url in ipairs(Items) do
		-- URLから数字とモデル名を抽出する
		local idStr = string.match(url, "%d+")
		if idStr then
			local id = tonumber(idStr)
			local modelName = string.match(url, idStr .. "/([^/?#]+)") or idStr
			
			if string.find(url, "/catalog/") then
				local success, model = pcall(function()
					return InsertService:LoadAsset(id)
				end)

				if success and model then
					model.Name = modelName
					self:_setupModel(model, id, index, false)
					index = index + 1
					print("AvatarItemPlacer: Loaded and placed asset:", id)
				else
					warn("AvatarItemPlacer: Failed to load asset:", id, tostring(model))
				end
			elseif string.find(url, "/bundles/") then
				local success, bundleDetails = pcall(function()
					return AssetService:GetBundleDetailsAsync(id)
				end)
				print("bundleDetails", bundleDetails)
				if success and bundleDetails and bundleDetails.Items then
					local outfitId = nil
					-- "BodyParts" タイプの全身キャラクターバンドルの場合のみ、UserOutfitから構築する
					if bundleDetails.BundleType == "BodyParts" then
						for _, item in ipairs(bundleDetails.Items) do
							if item.Type == "UserOutfit" then
								outfitId = item.Id
								break
							end
						end
					end
					
					local model = nil
					if outfitId then
						local Players = game:GetService("Players")
						local s, desc = pcall(function()
							return Players:GetHumanoidDescriptionFromOutfitId(outfitId)
						end)
						if s and desc then
							model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
							model.Name = modelName
							
							-- Humanoid, BodyColors, Scriptを削除
							for _, desc in ipairs(model:GetDescendants()) do
								if desc:IsA("Humanoid") or desc:IsA("BodyColors") or desc:IsA("BaseScript") then
									desc:Destroy()
								end
							end
							
							-- HumanoidRootPartのPositionをHeadのPositionに合わせる
							local hrp = model:FindFirstChild("HumanoidRootPart")
							local head = model:FindFirstChild("Head")
							if hrp and head then
								hrp.CFrame = CFrame.new(head.Position) * (hrp.CFrame - hrp.CFrame.Position)
							end
						end
					end
					
					if not model then
						model = Instance.new("Model")
						model.Name = modelName
						
						for _, item in ipairs(bundleDetails.Items) do
							if item.Type == "Asset" then
								local s, m = pcall(function()
									return InsertService:LoadAsset(item.Id)
								end)
								if s and m then
									local targetFolder = m:FindFirstChild("R15ArtistIntent") or m:FindFirstChild("R15") or m:FindFirstChild("R15Fixed") or m:FindFirstChild("R6")
									
									if targetFolder then
										for _, child in ipairs(targetFolder:GetChildren()) do
											child.Parent = model
										end
									else
										for _, child in ipairs(m:GetChildren()) do
											child.Parent = model
										end
									end
									m:Destroy()
								end
							end
						end
						
						-- モデルが「頭(Head)」だけの場合、Humanoidを追加して名前を非表示にする
						local isOnlyHead = true
						for _, child in ipairs(model:GetChildren()) do
							if child:IsA("BasePart") and child.Name ~= "Head" and child.Name ~= "HumanoidRootPart" then
								if child.Transparency < 1 then
									isOnlyHead = false
								end
							end
						end
						
						if isOnlyHead then
							local humanoid = Instance.new("Humanoid")
							humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
							humanoid.RigType = Enum.HumanoidRigType.R15
							humanoid.Parent = model
						end

						-- フォールバック：頭部の位置補正を追加
						local headPart = model:FindFirstChild("Head", true)
						local upperTorso = model:FindFirstChild("UpperTorso", true)
						if headPart and upperTorso then
							local headAtt = headPart:FindFirstChild("NeckRigAttachment")
							local torsoAtt = upperTorso:FindFirstChild("NeckRigAttachment")
							if headAtt and torsoAtt then
								headPart.CFrame = upperTorso.CFrame * torsoAtt.CFrame * headAtt.CFrame:Inverse()
							end
						end
					end
					
					self:_setupModel(model, id, index, true)
					index = index + 1
					print("AvatarItemPlacer: Loaded and placed bundle:", id)
				else
					warn("AvatarItemPlacer: Failed to load bundle:", id)
				end
			else
				warn("AvatarItemPlacer: URL format not recognized:", url)
			end
		else
			warn("AvatarItemPlacer: Could not find ID in URL:", url)
		end
	end
end

function AvatarItemPlacer:_setupModel(model, id, index, isBundle)
	-- 全てのパーツを落下しないように（Anchored = true）設定、およびその他の最適化
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = true
		end
		if desc:IsA("WrapLayer") then
			desc:Destroy()
		end
	end
	
	model.Parent = workspace
	model:ScaleTo(1.5)
	
	if model.PrimaryPart or #model:GetDescendants() > 0 then
		local columns = 8--6
		local x = (index % columns) * 8--14
		local z = math.floor(index / columns) * 20
		model:PivotTo(CFrame.new(Vector3.new(x, 5, z)))
	end

	local cloneFolder = ReplicatedStorage:FindFirstChild("Clone")
	local daizaTemplate = cloneFolder and cloneFolder:FindFirstChild("Daiza")
	if daizaTemplate then
		local daiza = daizaTemplate:Clone()
		daiza.Anchored = true
		daiza.BrickColor = BrickColor.Random()
		
		local bboxCFrame, bboxSize = model:GetBoundingBox()
		local bottomY = bboxCFrame.Position.Y - (bboxSize.Y / 2)
		local daizaY = bottomY - (daiza.Size.Y / 2)
		
		-- Keep the original orientation of daizaTemplate but update its position
		daiza.CFrame = daizaTemplate.CFrame.Rotation + Vector3.new(bboxCFrame.Position.X, daizaY, bboxCFrame.Position.Z)
		daiza.Parent = model
	else
		warn("AvatarItemPlacer: Daiza not found in ReplicatedStorage/Clone")
	end

	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- タグの追加と属性の設定
	--CollectionService:AddTag(model, Constants.MANNEQUIN_TAG)
	if isBundle then
		model:SetAttribute(Constants.BUNDLE_IDS_ATTRIBUTE, tostring(id))
	else
		model:SetAttribute(Constants.ACCESSORY_IDS_ATTRIBUTE, tostring(id))
	end
	--model:AddTag("TryOn_")
end

return AvatarItemPlacer
