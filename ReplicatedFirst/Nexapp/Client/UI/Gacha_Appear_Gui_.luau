local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local BaseGui_ = require(ReplicatedFirst.Nexsys.Client.BaseGui_)
local promise = require(ReplicatedStorage.Packages.promise)
local CharacterImageSetter = require(ReplicatedFirst:WaitForChild("Nexapp"):WaitForChild("Common"):WaitForChild("System"):WaitForChild("CharacterImageSetter"))

--- @class Gacha_Appear_Gui_ : BaseGui_
local Gacha_Appear_Gui_ = {}
Gacha_Appear_Gui_.__index = Gacha_Appear_Gui_
setmetatable(Gacha_Appear_Gui_, BaseGui_)
Gacha_Appear_Gui_.instance = nil

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- GetInstance
--- @return Gacha_Appear_Gui_
function Gacha_Appear_Gui_.GetInstance()
	return Gacha_Appear_Gui_.instance
end
----------------------------------------------------------------------------------------------------

function Gacha_Appear_Gui_.new(...)
	local self = setmetatable(BaseGui_.new(...), Gacha_Appear_Gui_)
	Gacha_Appear_Gui_.Init(self, ...)
	Gacha_Appear_Gui_.instance = self
	return self
end

function Gacha_Appear_Gui_:Init(gui : ScreenGui)
	self:WaitForLoaded(gui)

	gui.Enabled = false
	self.WindowFrame = self:FindDescendant("WindowFrame")
	self.HouseFrame = self:FindDescendant("HouseOwners")
	self.tweens = {}
end
----------------------------------------------------------------------------------------------------
-- onShow
function Gacha_Appear_Gui_:OnShow(characters)
	self:_cancelTweens()

	self:setup(characters)

	self:PlaySEByName("TaDa")
	-- 5秒後に閉じる
	print("sato hide1")
	self.promise = promise.new(function(resolve, reject)
		task.wait(3)

		-- このタイミングでコンプリートチェック
		-- local isCompleted = PlayerData:IsProgressFlag(ProgressFlagData.Flag_GachaCompleted)
		-- if not isCompleted then
		-- 	local petTypeNum = PlayerData:GetOwnedPetTypeCount()
		-- 	if petTypeNum >= ConfigData.CompleteCharaNum then
		-- 		local Gacha_Complete_Gui_ = require(ReplicatedFirst.Nexapp.Client.UI.Gacha_Complete_Gui_)
		-- 		Gacha_Complete_Gui_.GetInstance():Show()
		-- 	end
		-- end

		self:Hide()
		resolve()
		print("sato hide2")
	end)
end
----------------------------------------------------------------------------------------------------
-- setup
function Gacha_Appear_Gui_:setup(characters)
	local frame = self.HouseFrame

	for i=1, #characters do
		local charaFrame = frame:FindFirstChild("Chara" .. i, true)
		if not charaFrame then
			warn("charaFrame not found", frame, i)
			continue
		end
		
		local data = characters[i]

		local charaImage = charaFrame:FindFirstChild("CharacterImage")
		local charaName = charaFrame:FindFirstChild("CharacterName", true)
		
		CharacterImageSetter.SetImageByInfo(data.Name, data.UserId, charaImage)
		charaName.Text = data.Name
	end
end
----------------------------------------------------------------------------------------------------
-- onHide
function Gacha_Appear_Gui_:OnHide()

	task.delay(0.5, function()
		self:_cancelTweens()
	end)
	-- self:_cancelTweens()

	-- なんか微妙かも onHideが最後までいかない感じになる
	if self.promise then
		self.promise:cancel()
		self.promise = nil
	end
end
----------------------------------------------------------------------------------------------------
--- _cancelTweens
function Gacha_Appear_Gui_:_cancelTweens()
	for _, tween in self.tweens do
		-- warn("cancel tween", tween)
		tween:Cancel()
	end
	self.tweens = {}
end


return Gacha_Appear_Gui_