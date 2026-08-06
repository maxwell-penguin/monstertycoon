local Constants = {}

Constants.PLOT_MAX_PLAYERS = 10
Constants.VIAL_PICKUP_RADIUS = 15 -- TODO: temporarily widened from 8 for testing tolerance; dial back down once SlotPositioner spacing is confirmed comfortable
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

Constants.HALL_UPGRADE_COSTS = {
	[1] = 0,
	[2] = 50000,
	[3] = 5000000,
	[4] = 500000000,
	[5] = 50000000000,
}

Constants.HALL_SLOT_COUNTS = {
	[1] = 9,
	[2] = 15,
	[3] = 24,
	[4] = 36,
	[5] = 48,
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
	{ emotion = "Rage", duration = 480, multiplier = 4 },
	{ emotion = "Void", duration = 360, multiplier = 5 },
	{ emotion = "Joy", duration = 600, multiplier = 3 },
	{ emotion = "Dread", duration = 360, multiplier = 5 },
	{ emotion = "Sadness", duration = 480, multiplier = 3 },
	{ emotion = "Nostalgia", duration = 240, multiplier = 8 },
}

Constants.SPECIAL_BOOST_CHANCE = 0.15

Constants.SPECIAL_BOOSTS = {
	VoidStorm = { emotion = "All", multiplier = 2, duration = 180, displayName = "VOID STORM" },
	DoubleSurge = { multiplier = 3, duration = 300, displayName = "DOUBLE SURGE" },
	MysterySurge = { multiplier = 6, duration = 300, displayName = "??? SURGE" },
}

Constants.WATCHER_BOOST_MULTIPLIER = 50

Constants.EMOTION_COLORS = {
	Joy = Color3.fromRGB(250, 199, 80),
	Sadness = Color3.fromRGB(133, 183, 235),
	Rage = Color3.fromRGB(240, 149, 149),
	Dread = Color3.fromRGB(175, 169, 236),
	Nostalgia = Color3.fromRGB(237, 147, 177),
	Void = Color3.fromRGB(44, 44, 42),
	Static = Color3.fromRGB(151, 196, 89),
	Abyss = Color3.fromRGB(26, 33, 92),
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
	{ seconds = 2700, reward = "coins", amount = 10000 },
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
	AutoMerge = 0,
	VoidPass = 0,
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
}

-- Shared (not an EventStation-local) because the client-built Event Station panel
-- needs the same names/costs to render BUY buttons -- same reasoning as
-- GAMEPASS_IDS/PRODUCT_IDS above.
Constants.EVENT_MONSTERS = {
	{ name = "Glitchling", emotion = "Static", rarity = "Rare", tokenCost = 1 },
	{ name = "Voidborn", emotion = "Void", rarity = "Epic", tokenCost = 3 },
	{ name = "Prismatic", emotion = "Any", rarity = "Legendary", tokenCost = 8 },
	{ name = "Corrupted", emotion = "Any", rarity = "Legendary", tokenCost = 8 },
	{ name = "Hollow", emotion = "Sadness", rarity = "Epic", tokenCost = 3 },
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
