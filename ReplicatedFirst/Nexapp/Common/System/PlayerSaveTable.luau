local data = {}

data.Keys = {
	PlayTime = "PlayTime",
	LastLoginTime = "LastLoginTime",
	StayBonusClaimedList = "StayBonusClaimedList",
	Coin = "Coin",
	Gem = "Gem",
	LoginBonusGotDay = "LoginBonusGotDay",
	LastLoginBonusTime = "LastLoginBonusTime",
	WornAssets = "WornAssets",
	WornBundles = "WornBundles",
	OwnedWands = "OwnedWands",
	SelectedWand = "SelectedWand",
	ChooseAvatarTicket = "ChooseAvatarTicket",
}

data.Template = {
	[data.Keys.PlayTime] = 0,
	
	[data.Keys.LastLoginTime] = 0,
	[data.Keys.StayBonusClaimedList] = {
		-- [Level] = true,
	},
	[data.Keys.Coin] = 100,
	[data.Keys.Gem] = 0,
	[data.Keys.LoginBonusGotDay] = 0,
	[data.Keys.LastLoginBonusTime] = 0,
	[data.Keys.WornAssets] = {},
	[data.Keys.WornBundles] = {},
	[data.Keys.OwnedWands] = {},
	[data.Keys.SelectedWand] = "",
	[data.Keys.ChooseAvatarTicket] = 0,
}

return data