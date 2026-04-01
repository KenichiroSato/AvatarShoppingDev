local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Define = {}

-- サーバーへのRemoteEvent
Define.CommonServerEvent = {
	StartDashMode = 10,
	EndDashMode = 11,
	AreaStreamingRequest = 20,
	ModelPersitantRequest = 22,
}

Define.PopUpType = {
	Coin = "Coin",
}

Define.LOGIN_BONUS_MAX_DAY = 30
Define.LOGIN_BONUS_INTERVAL_TIME = 60 * 60 * 24

Define.PODIUM_CUTSCENE_TIME = 10
Define.TIME_UP_DISPLAY_TIME = 3

return Define