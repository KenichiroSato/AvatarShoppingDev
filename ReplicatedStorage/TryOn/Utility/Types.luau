--!strict

--[[
	Types - This module holds type information for the various data structures returned by
	AvatarEditorService:GetItemDetails(), :SearchCatalog(), etc.
--]]

export type ItemDetails = {
	CreatorHasVerifiedBadge: boolean,
	CreatorName: string,
	CreatorTargetId: number,
	CreatorType: string,
	Description: string,
	FavoriteCount: number,
	IsPurchasable: boolean?,
	IsOffSale: boolean?,
	Id: number,
	ItemRestrictions: { string },
	ItemStatus: { string },
	ItemType: string,
	Name: string,
	Owned: boolean,
	Price: number?,
	LowestPrice: number?,
	LowestResalePrice: number?,
	PriceStatus: string?,
	ProductId: number,
	PurchaseCount: number,
	SaleLocation: string,
}

export type AssetDetails = ItemDetails & {
	ItemType: "Asset",
	AssetType: string,
}

export type BundledItemDetails = {
	Id: number,
	Name: string,
	Owned: boolean,
	Type: string,
}

export type BundleDetails = ItemDetails & {
	ItemType: "Bundle",
	BundleType: string,
	BundledItems: { BundledItemDetails },
}

export type CatalogPage = { AssetDetails | BundleDetails }

export type BulkItem = {
	Id: string,
	Type: Enum.MarketplaceProductType,
}

export type BulkPurchaseResultItem = {
	id: string,
	status: Enum.MarketplaceItemPurchaseStatus,
	type: Enum.MarketplaceProductType,
}

export type BulkPurchaseResult = {
	Items: { BulkPurchaseResultItem },
	RobuxSpent: number,
}

export type HumanoidDescriptionAccessory = {
	AccessoryType: Enum.AccessoryType,
	AssetId: number,
	IsLayered: boolean?,
	Order: number?,
	Puffiness: number?,
}

return {}
