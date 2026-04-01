local data = {}

data.Keys = {
	PlayTime = "PlayTime",
	LastLoginTime = "LastLoginTime",
	StayBonusClaimedList = "StayBonusClaimedList",
	Coin = "Coin",
	LoginBonusGotDay = "LoginBonusGotDay",
	LastLoginBonusTime = "LastLoginBonusTime",
	WornAssets = "WornAssets",
	WornBundles = "WornBundles",
}

data.Template = {
	[data.Keys.PlayTime] = 0,
	
	[data.Keys.LastLoginTime] = 0,
	[data.Keys.StayBonusClaimedList] = {
		-- [Level] = true,
	},
	[data.Keys.Coin] = 100,
	[data.Keys.LoginBonusGotDay] = 0,
	[data.Keys.LastLoginBonusTime] = 0,
	[data.Keys.WornAssets] = {},
	[data.Keys.WornBundles] = {},
}

return data