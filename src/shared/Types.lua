export type Monster = {
	id: string,
	name: string,
	emotion: string,
	rarity: string,
	level: number,
	stars: number,
	outputMultiplier: number,
}

export type MonsterSlot = {
	slotIndex: number,
	monster: Monster?,
	isActive: boolean,
}

export type Bag = {
	tier: number,
	capacity: number,
	currentCount: number,
}

export type PlayerData = {
	coins: number,
	lifetimeRolls: number,
	townLevel: number,
	townXP: number,
	environmentTier: number,
	warehouseTier: number,
	bagTier: number,
	totalPlaytime: number,
	lastOnlineTime: number,
	monsterSlots: { MonsterSlot },
	warehouse: { [string]: Monster },
	sessionStartTime: number,
	ownedGamepasses: { [string]: boolean },
	incomeMultiplier: number,
	freeMerges: number,
	hasBoostInsider: boolean,
	ftueComplete: boolean,
	eventTokens: number,
	unlockedBiomes: { string },
}

export type Plot = {
	playerId: number,
	hallTier: number,
	warehouseTier: number,
	plotLevel: number,
}

export type BoostState = {
	emotion: string,
	emotions: { string }?,
	multiplier: number,
	startTime: number,
	endTime: number,
	isActive: boolean,
}

return nil
