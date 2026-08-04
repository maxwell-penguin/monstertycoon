local ServerScriptService = game:GetService("ServerScriptService")

-- RollTable is only ever required from server-side code (RollManager, CrateManager),
-- so reaching into ServerScriptService here is safe even though this module lives in shared/.
local MonsterData = require(ServerScriptService:WaitForChild("MonsterData"))

local RollTable = {}

RollTable.RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

local BASE_PROBABILITIES = {
	Common = 0.70,
	Uncommon = 0.18,
	Rare = 0.08,
	Epic = 0.03,
	Legendary = 0.008,
	Mythic = 0.002,
}

-- Legendary/Mythic keep their base 4:1 ratio while growing to fill the remainder
-- left after Common/Uncommon/Rare/Epic hit their town-level-50 targets.
local MAX_PROBABILITIES = {
	Common = 0.40,
	Uncommon = 0.13,
	Rare = 0.18,
	Epic = 0.11,
	Legendary = 0.144,
	Mythic = 0.036,
}

local MIN_TOWN_LEVEL = 1
local MAX_TOWN_LEVEL = 50

function RollTable.GetProbabilities(townLevel: number): { [string]: number }
	local clampedLevel = math.clamp(townLevel, MIN_TOWN_LEVEL, MAX_TOWN_LEVEL)
	local t = (clampedLevel - MIN_TOWN_LEVEL) / (MAX_TOWN_LEVEL - MIN_TOWN_LEVEL)

	local probabilities = {}
	local total = 0

	for _, rarity in RollTable.RARITY_ORDER do
		local base = BASE_PROBABILITIES[rarity]
		local max = MAX_PROBABILITIES[rarity]
		local value = base + (max - base) * t
		probabilities[rarity] = value
		total += value
	end

	for rarity, value in probabilities do
		probabilities[rarity] = value / total
	end

	return probabilities
end

function RollTable.RollRarity(townLevel: number): string
	local probabilities = RollTable.GetProbabilities(townLevel)
	local roll = math.random()
	local cumulative = 0

	for _, rarity in RollTable.RARITY_ORDER do
		cumulative += probabilities[rarity]
		if roll <= cumulative then
			return rarity
		end
	end

	return RollTable.RARITY_ORDER[#RollTable.RARITY_ORDER]
end

function RollTable.RollMonsterOfRarity(rarity: string): string
	local matches = {}
	for name, def in MonsterData do
		if def.rarity == rarity then
			table.insert(matches, name)
		end
	end

	if #matches == 0 then
		return "Weeper"
	end

	return matches[math.random(1, #matches)]
end

function RollTable.RollMonster(townLevel: number): (string, string)
	local rarity = RollTable.RollRarity(townLevel)
	local monsterName = RollTable.RollMonsterOfRarity(rarity)
	return monsterName, rarity
end

return RollTable
