local RemoteEvents = {}

RemoteEvents.EVENTS = {
	-- Economy
	SELL_VIALS = "SellVials",
	UPDATE_COINS = "UpdateCoins",
	UPDATE_EARN_RATE = "UpdateEarnRate",

	-- Monsters
	SLOT_MONSTER = "SlotMonster",
	UNSLOT_MONSTER = "UnslotMonster",
	MERGE_MONSTERS = "MergeMonsters",
	MONSTER_PRODUCED = "MonsterProduced",
	UPDATE_HALL = "UpdateHall",
	UPDATE_WAREHOUSE = "UpdateWarehouse",

	-- Vials
	PICKUP_VIAL = "PickupVial",
	DEPOSIT_BAG = "DepositBag",
	UPDATE_BAG = "UpdateBag",
	VIAL_SPAWNED = "VialSpawned",
	VIAL_REMOVED = "VialRemoved",

	-- Eggs
	ROLL_EGG = "RollEgg",
	OPEN_CRATE = "OpenCrate",
	EGG_RESULT = "EggResult",
	CRATE_SPAWNED = "CrateSpawned",

	-- Boosts
	BOOST_STARTED = "BoostStarted",
	BOOST_ENDED = "BoostEnded",
	BOOST_WARNING = "BoostWarning",
	SERVER_BOOST_TRIGGERED = "ServerBoostTriggered",

	-- Plot
	UPGRADE_ENVIRONMENT = "UpgradeEnvironment",
	UPGRADE_WAREHOUSE = "UpgradeWarehouse",
	UPGRADE_BAG = "UpgradeBag",
	PLOT_UPDATED = "PlotUpdated",

	-- Session
	SESSION_REWARD = "SessionReward",
	PLAYER_DATA_LOADED = "PlayerDataLoaded",

	-- Town
	TOWN_UPDATED = "TownUpdated",

	-- Monetization
	SET_WALK_SPEED = "SetWalkSpeed",
	LUCK_BOOST_ACTIVE = "LuckBoostActive",
	PROMPT_PURCHASE = "PromptPurchase",
	SET_MAGNET = "SetMagnet",
	SET_AUTO_PICKUP = "SetAutoPickup",

	-- FTUE
	FTUE_STEP = "FtueStep",
	FTUE_PROGRESS = "FtueProgress",

	-- Events
	SHARD_SPAWNED = "ShardSpawned",
	SHARD_COLLECTED = "ShardCollected",
	EVENT_CRATE_SPAWNED = "EventCrateSpawned",
	EVENT_CRATE_CLAIMED = "EventCrateClaimed",
	GLOBAL_MILESTONE_HIT = "GlobalMilestoneHit",
	WORLD_EVENT_START = "WorldEventStart",
	WORLD_EVENT_END = "WorldEventEnd",
	WORLD_EVENT_COUNTDOWN = "WorldEventCountdown",
	EVENT_STATION_PURCHASE = "EventStationPurchase",

	-- Anti-cheat
	SANITY_FAIL = "SanityFail",

	-- Biomes
	BIOME_UNLOCK_PROMPT = "BiomeUnlockPrompt",
	BIOME_UNLOCKED = "BiomeUnlocked",
	UNLOCK_BIOME = "UnlockBiome",
}

RemoteEvents.FUNCTIONS = {
	GET_PLAYER_DATA = "GetPlayerData",
	VALIDATE_PURCHASE = "ValidatePurchase",
}

return RemoteEvents
