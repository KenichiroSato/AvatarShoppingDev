print("Server Start. ServerId:", game.JobId)
local startTime = tick()

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ServerScriptService = game:GetService("ServerScriptService")
-- 最初に初期化が必要
local GameDataProviderImpl = require(ReplicatedFirst.Nexapp.Common.System.GameDataProviderImpl)
local ServerRemoteEventHandler = require(ServerScriptService.Nexapp.System.ServerRemoteEventHandler)
local PlayerManager = require(ServerScriptService.Nexapp.Player.PlayerManager)
local ServerInstanceManager = require(ServerScriptService.Nexapp.System.ServerInstanceManager)
local AvatarItemPlacer = require(ServerScriptService.Nexapp.AvatarItem.AvatarItemPlacer)
local TimeManager = require(ServerScriptService.Nexapp.Battle.TimeManager)
local WandShopHandler = require(ServerScriptService.Nexapp.Shop.WandShopHandler)
local ProductPurchaseManager = require(ServerScriptService.Nexapp.System.ProductPurchaseManager)

print("Server ModuleLoad end. time:", tick() - startTime)


-- 初期化
ServerInstanceManager.Init()

ServerRemoteEventHandler.Init()
PlayerManager.Start()
ServerInstanceManager.Setup()
ProductPurchaseManager.Init()

local avatarItemPlacer = AvatarItemPlacer.new()
--avatarItemPlacer:PlaceItems()

TimeManager.Start()
WandShopHandler.Init()
