local Constants = {}

Constants.PLOT_MAX_PLAYERS = 10
Constants.VIAL_PICKUP_RADIUS = 8
Constants.DROPBOX_RADIUS = 10
Constants.WAREHOUSE_BASE_CAPACITY = 30
Constants.HALL_BASE_SLOTS = 9
Constants.OFFLINE_PRODUCTION_RATE = 0.25
Constants.OFFLINE_PRODUCTION_CAP_HOURS = 4
Constants.AUTO_MERGE_COST = 0 -- Robux gamepass feature; no coin cost

Constants.BASE_VIAL_VALUES = {
	Common = 10,
	Uncommon = 75,
	Rare = 500,
	Epic = 4000,
	Legendary = 30000,
	Mythic = 250000,
}

Constants.ROLL_COST_THRESHOLDS = {
	{ maxRolls = 20, cost = 500 },
	{ maxRolls = 50, cost = 1500 },
	{ maxRolls = 100, cost = 4000 },
	{ maxRolls = 200, cost = 10000 },
	{ maxRolls = 500, cost = 30000 },
	{ maxRolls = math.huge, cost = 80000 },
}

Constants.ENVIRONMENT_UPGRADE_COSTS = {
	[1] = 0,
	[2] = 50000,
	[3] = 5000000,
	[4] = 500000000,
	[5] = 50000000000,
}

Constants.ENVIRONMENT_CAPACITY = {
	[1] = 9,
	[2] = 15,
	[3] = 24,
	[4] = 36,
	[5] = 48,
}

-- Max monsters roaming each biome at once, independent of environment tier --
-- caps how many of a player's slotted monsters can be assigned to any one
-- biome (via GetMonstersByBiome), not the total roster size.
Constants.BIOME_CAPACITY_LIMITS = {
	Forest = 12,
	Waterfall = 10,
	Volcano = 8,
	Pond = 6,
}

Constants.WAREHOUSE_UPGRADE_COSTS = {
	[1] = 0,
	[2] = 10000,
	[3] = 1000000,
	[4] = 100000000,
	[5] = 10000000000,
}

Constants.WAREHOUSE_CAPACITY = {
	[1] = 30,
	[2] = 50,
	[3] = 80,
	[4] = 120,
	[5] = 180,
}

Constants.PLOT_UPGRADE_COSTS = {
	[1] = 0,
	[2] = 75000,
	[3] = 7500000,
	[4] = 750000000,
	[5] = 75000000000,
}

Constants.PLOT_SIZES = {
	[1] = { width = 60, depth = 80 },
	[2] = { width = 80, depth = 100 },
	[3] = { width = 100, depth = 120 },
	[4] = { width = 120, depth = 140 },
	[5] = { width = 140, depth = 160 },
}

Constants.BAG_TIERS = {
	{ name = "Starter", capacity = 10, cost = 0, robux = false },
	{ name = "Satchel", capacity = 25, cost = 500, robux = false },
	{ name = "Backpack", capacity = 50, cost = 3000, robux = false },
	{ name = "Vault Pack", capacity = 100, cost = 15000, robux = false },
	{ name = "Void Carrier", capacity = 250, cost = 0, robux = true, robuxCost = 199 },
	{ name = "Infinite Bag", capacity = math.huge, cost = 0, robux = true, robuxCost = 499 },
}

Constants.NUMBER_SUFFIXES = { "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc" }

Constants.CRATE_COOLDOWNS = {
	[1] = 90,
	[2] = 80,
	[3] = 70,
	[4] = 55,
	[5] = 30,
}

Constants.BOOST_ROTATION = {
	{ element = "Fire", duration = 480, multiplier = 4 },
	{ element = "Water", duration = 360, multiplier = 5 },
	{ element = "Nature", duration = 600, multiplier = 3 },
	{ element = "Void", duration = 360, multiplier = 5 },
	{ element = "Wind", duration = 480, multiplier = 3 },
	{ element = "Thunder", duration = 240, multiplier = 8 },
}

Constants.SPECIAL_BOOST_CHANCE = 0.15

Constants.SPECIAL_BOOSTS = {
	VoidStorm = { element = "All", multiplier = 2, duration = 180, displayName = "VOID STORM" },
	DoubleSurge = { multiplier = 3, duration = 300, displayName = "DOUBLE SURGE" },
	MysterySurge = { multiplier = 6, duration = 300, displayName = "??? SURGE" },
}

Constants.WATCHER_BOOST_MULTIPLIER = 50

Constants.ELEMENT_COLORS = {
	Fire = Color3.fromRGB(255, 100, 30),
	Magma = Color3.fromRGB(180, 50, 10),
	Water = Color3.fromRGB(60, 140, 220),
	Ice = Color3.fromRGB(180, 220, 255),
	Wind = Color3.fromRGB(200, 220, 240),
	Thunder = Color3.fromRGB(255, 220, 50),
	Nature = Color3.fromRGB(60, 160, 60),
	Poison = Color3.fromRGB(120, 200, 50),
	Void = Color3.fromRGB(80, 40, 120),
	Galaxy = Color3.fromRGB(100, 60, 180),
	Light = Color3.fromRGB(255, 240, 180),
	Radiance = Color3.fromRGB(255, 200, 80),
}

Constants.XP_REWARDS = {
	vialSell = 1, -- per vial sold
	eggOpen = 10, -- per egg opened (any rarity)
	eggRare = 25, -- bonus for Rare or above
	eggLegendary = 100, -- bonus for Legendary or above
	eggMythic = 500, -- bonus for Mythic
	sessionMilestone = 50, -- per session milestone reward claimed
	mergeEvolve = 5, -- per successful non-star merge (evolution)
	mergeStar = 20, -- per star added to a max-level monster
}

Constants.MAX_TOWN_LEVEL = 50

Constants.SESSION_REWARDS = {
	{ seconds = 60, reward = "coins", amount = 1000 },
	{ seconds = 120, reward = "egg", rarity = "Common" },
	{ seconds = 300, reward = "coins", amount = 5000, bonusLuck = true, luckDuration = 120 },
	{ seconds = 900, reward = "egg", rarity = "Uncommon" },
	{ seconds = 1800, reward = "bagVoucher" },
	{ seconds = 3600, reward = "egg", rarity = "Rare", bonusTownXP = true },
	{ seconds = 7200, reward = "egg", rarity = "Epic", chance = 0.3 },
}

-- Placeholder IDs (0) until filled in after publishing to Roblox. Shared (not a
-- MonetizationManager-local) because the client-built Shop Panel needs the same
-- numeric IDs to fire PROMPT_PURCHASE with.
Constants.GAMEPASS_IDS = {
	InfiniteBag = 0,
	VoidCarrier = 0,
	SpeedBoots = 0,
	BoostInsider = 0,
	ExtraPlot = 0,
	Income2x = 0,
	Income3x = 0,
	Income5x = 0,
	Income7x = 0,
	Income10x = 0,
	Magnet = 0,
}

Constants.PRODUCT_IDS = {
	LuckBoost = 0,
	MergeBoost = 0,
	ServerBoost = 0,
	RareEgg = 0,
	EpicEgg = 0,
	LegendaryEgg = 0,
	MythicEgg = 0,
	StarterPack = 0,
	VoidPack = 0,
	AutoPickup = 0,
}

-- Shared (not an EventStation-local) because the client-built Event Station panel
-- needs the same names/costs to render BUY buttons -- same reasoning as
-- GAMEPASS_IDS/PRODUCT_IDS above.
Constants.EVENT_MONSTERS = {
	{ name = "Glitchling", element = "Void", rarity = "Rare", tokenCost = 1 },
	{ name = "Galaxyborn", element = "Galaxy", rarity = "Epic", tokenCost = 3 },
	{ name = "Prismatic", element = "Radiance", rarity = "Legendary", tokenCost = 8 },
	{ name = "Corrupted", element = "Void", rarity = "Legendary", tokenCost = 8 },
	{ name = "Hollow", element = "Void", rarity = "Epic", tokenCost = 3 },
}

Constants.ANTICHEAT = {
	MAX_COINS_PER_SELL = 1e15,
	MAX_VIALS_PER_DEPOSIT = 100,
	MAX_STUD_TRAVEL_PER_SECOND = 60,
	STRIKES_BEFORE_KICK = 3,
	STRIKES_BEFORE_BAN = 5,
	STRIKE_DECAY_SECONDS = 300,
}

return Constants
