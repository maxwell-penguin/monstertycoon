local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local NumberFormatter = require(ReplicatedStorage.NumberFormatter)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BoostState = require(ReplicatedStorage.BoostState)
local Types = require(ReplicatedStorage.Types)
local PlayerManager = require(script.Parent.PlayerManager)
local GlobalBoostMilestone = require(script.Parent.GlobalBoostMilestone)
local TownManager = require(script.Parent.TownManager)

local Economy = {}

local MAX_VIALS_PER_DEPOSIT = 100
local DEFAULT_INCOME_MULTIPLIER = 1

local LEVEL_MULTIPLIERS = { 1, 4, 12, 30, 100 }
local STAR_MULTIPLIERS = { [0] = 1, [1] = 2, [2] = 4, [3] = 8 }
local WATCHER_EMOTION = "Any"

local UPGRADE_COST_TABLES = {
	hall = Constants.HALL_UPGRADE_COSTS,
	warehouse = Constants.WAREHOUSE_UPGRADE_COSTS,
	plot = Constants.PLOT_UPGRADE_COSTS,
}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateCoinsRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_COINS) :: RemoteEvent
local updateEarnRateRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_EARN_RATE) :: RemoteEvent

function Economy.GetRollCost(lifetimeRolls: number): number
	for _, threshold in Constants.ROLL_COST_THRESHOLDS do
		if lifetimeRolls < threshold.maxRolls then
			return math.max(threshold.cost, 500)
		end
	end
	return 500
end

-- Resolves the live boost multiplier for a given monster emotion, covering standard
-- boosts, Void Storm ("All"), Double Surge (emotions array), Mystery Surge (secret
-- real emotion, server-only), and The Watcher ("Any" always benefits from any boost).
function Economy.GetBoostMultiplier(emotion: string): number
	local boost = BoostState.GetCurrentBoost()
	if not boost.isActive then
		return 1
	end

	if emotion == WATCHER_EMOTION then
		return boost.multiplier
	end

	if boost.emotion == "Mystery" then
		if BoostState.GetRealEmotion() == emotion then
			return boost.multiplier
		end
		return 1
	end

	return BoostState.GetMultiplierForEmotion(emotion)
end

function Economy.GetVialValue(
	rarity: string,
	emotion: string,
	incomeMultiplier: number,
	monsterLevel: number,
	monsterStars: number
): number
	local baseValue = Constants.BASE_VIAL_VALUES[rarity]
	if not baseValue then
		return 1
	end

	local boostMultiplier = Economy.GetBoostMultiplier(emotion)
	local levelMultiplier = LEVEL_MULTIPLIERS[monsterLevel] or 1
	local starMultiplier = STAR_MULTIPLIERS[monsterStars] or 1

	local value = baseValue * boostMultiplier * incomeMultiplier * levelMultiplier * starMultiplier

	return math.max(math.floor(value), 1)
end

function Economy.GetEarnRate(slots: { Types.MonsterSlot }, incomeMultiplier: number): number
	local total = 0

	for _, slot in slots do
		if slot.isActive and slot.monster then
			local monster = slot.monster
			local value = Economy.GetVialValue(monster.rarity, monster.emotion, incomeMultiplier, monster.level, monster.stars)
			total += value / 30
		end
	end

	return total
end

function Economy.ProcessSell(
	userId: number,
	vialCount: number,
	vialRarity: string,
	vialEmotion: string,
	monsterLevel: number,
	monsterStars: number
): (boolean, number)
	local data = PlayerManager.GetData(userId)
	if not data then
		warn(`[Economy] ProcessSell failed: no data loaded for user {userId}`)
		return false, 0
	end

	if
		typeof(vialCount) ~= "number"
		or vialCount ~= math.floor(vialCount)
		or vialCount <= 0
		or vialCount > MAX_VIALS_PER_DEPOSIT
	then
		warn(`[Economy] Sanity fail: user {userId} attempted to sell vialCount {tostring(vialCount)}`)
		return false, 0
	end

	local unitValue = Economy.GetVialValue(vialRarity, vialEmotion, DEFAULT_INCOME_MULTIPLIER, monsterLevel, monsterStars)
	local totalValue = unitValue * vialCount

	if not PlayerManager.IncrementCoins(userId, totalValue) then
		return false, 0
	end

	GlobalBoostMilestone.IncrementGlobalEarnings(totalValue)

	local player = Players:GetPlayerByUserId(userId)
	if player then
		TownManager.AddXP(player, Constants.XP_REWARDS.vialSell * vialCount)
	end

	local updatedData = PlayerManager.GetData(userId)

	if player and updatedData then
		updateCoinsRemote:FireClient(player, updatedData.coins)

		local earnRate = Economy.GetEarnRate(updatedData.monsterSlots, DEFAULT_INCOME_MULTIPLIER)
		updateEarnRateRemote:FireClient(player, earnRate)
	end

	return true, totalValue
end

function Economy.GetUpgradeCost(upgradeType: string, currentTier: number): number
	if upgradeType == "bag" then
		local nextTier = Constants.BAG_TIERS[currentTier + 1]
		if not nextTier then
			return math.huge
		end
		return nextTier.cost
	end

	local costTable = UPGRADE_COST_TABLES[upgradeType]
	if not costTable then
		return math.huge
	end

	local cost = costTable[currentTier + 1]
	if not cost then
		return math.huge
	end

	return cost
end

function Economy.FormatCoins(amount: number): string
	return NumberFormatter.Format(amount)
end

return Economy
