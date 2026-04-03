--!strict

local Constants = {
	-- Tags
	MANNEQUIN_TAG = "Mannequin",
	UI_BUTTON_TAG = "UIButton",
	INSPECT_PROMPT_TAG = "InspectPrompt",
	-- Attributes
	BUNDLE_IDS_ATTRIBUTE = "bundleIds",
	ACCESSORY_IDS_ATTRIBUTE = "accessoryIds",
	SKIN_COLOR_ATTRIBUTE = "skinColor",
	POSE_ANIMATION_ATTRIBUTE = "poseAnimation",
	BODY_DEPTH_SCALE_ATTRIBUTE = "bodyDepthScale",
	BODY_HEIGHT_SCALE_ATTRIBUTE = "bodyHeightScale",
	BODY_PROPORTION_SCALE_ATTRIBUTE = "bodyProportionScale",
	BODY_TYPE_SCALE_ATTRIBUTE = "bodyTypeScale",
	BODY_WIDTH_SCALE_ATTRIBUTE = "bodyWidthScale",
	HEAD_SCALE_ATTRIBUTE = "headScale",
	-- Amount of items to load per catalog page
	PAGE_SIZE = 30,
	-- UI constants
	ROBUX_CHAR = utf8.char(0xe002),
	BUTTON_DISABLED_TRANSPARENCY = 0.5,
	ITEM_TILE_SIZE = Vector2.new(100, 200),
	ITEM_TILE_PADDING = 4,
	ITEM_RESTRICTIONS = {
		LIMITED = "Limited",
		LIMITED_U = "LimitedUnique",
		COLLECTIBLE = "Collectible",
	},
	-- Amount of the page that needs to be scrolled through before loading the next one
	SCROLL_LOAD_FACTOR = 0.9,
	-- Factor to offset the character by onscreen when shop/inspect UI is open
	CAMERA_OFFSET = 0.65,
}

return Constants
