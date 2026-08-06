-- RollTable itself is safe to require from the client (TownClient uses GetProbabilities/
-- FormatProbabilities for a dev console printout), but MonsterData lives in
-- ServerScriptService and never replicates to clients. Load it lazily, only inside
-- RollMonsterOfRarity, so merely requiring this module doesn't hang a client script
-- waiting on a child that will never appear.
local MonsterData: { [string]: any }? = nil

local function getMonsterData(): { [string]: any }
	if not MonsterData then
		local ServerScriptService = game:GetService("ServerScriptService")
		MonsterData = require(ServerScriptService:WaitForChild("MonsterData")) :: any
	end
	return MonsterData :: { [string]: any }
end

-- Same lazy-load reasoning as MonsterData above: EventManager is server-only, and
-- RollRarity must stay safely requirable from the client.
local EventManager: any = nil

local function getEventManager(): any
	if not EventManager then
		local ServerScriptService = game:GetService("ServerScriptService")
		EventManager = require(ServerScriptService:WaitForChild("EventManager")) :: any
	end
	return EventManager
end

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

local LEGENDARY_INDEX = 5

function RollTable.RollRarity(townLevel: number): string
	local probabilities = RollTable.GetProbabilities(townLevel)
	local roll = math.random()
	local cumulative = 0
	local rarity = RollTable.RARITY_ORDER[#RollTable.RARITY_ORDER]

	for _, r in RollTable.RARITY_ORDER do
		cumulative += probabilities[r]
		if roll <= cumulative then
			rarity = r
			break
		end
	end

	-- Server-only; on a client this pcall just fails closed (no bump) since
	-- EventManager never replicates there.
	local ok, isLucky = pcall(function()
		return getEventManager().IsServerLuckActive()
	end)

	if ok and isLucky then
		local index = table.find(RollTable.RARITY_ORDER, rarity)
		-- Bumps one tier, capped at Legendary: only bumps if below Legendary, and
		-- never touches an already-Legendary-or-Mythic roll (no downgrading).
		if index and index < LEGENDARY_INDEX then
			rarity = RollTable.RARITY_ORDER[index + 1]
		end
	end

	return rarity
end

function RollTable.RollMonsterOfRarity(rarity: string): string
	local matches = {}
	for name, def in getMonsterData() do
		if def.rarity == rarity and not def.isEventExclusive then
			table.insert(matches, name)
		end
	end

	if #matches == 0 then
		return "Embret"
	end

	return matches[math.random(1, #matches)]
end

function RollTable.RollMonster(townLevel: number): (string, string)
	local rarity = RollTable.RollRarity(townLevel)
	local monsterName = RollTable.RollMonsterOfRarity(rarity)
	return monsterName, rarity
end

function RollTable.FormatProbabilities(probabilities: { [string]: number }): string
	local parts = {}
	for _, rarity in RollTable.RARITY_ORDER do
		local percent = (probabilities[rarity] or 0) * 100
		table.insert(parts, string.format("%s: %.1f%%", rarity, percent))
	end
	return table.concat(parts, " | ")
end

return RollTable
