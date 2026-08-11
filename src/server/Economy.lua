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

local LEVEL_MULTIPLIERS = { 1, 4, 12, 30, 100 }
local STAR_MULTIPLIERS = { [0] = 1, [1] = 2, [2] = 4, [3] = 8 }
local WATCHER_ELEMENT = "Any"

local UPGRADE_COST_TABLES = {
	environment = Constants.ENVIRONMENT_UPGRADE_COSTS,
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

-- Resolves the live boost multiplier for a given player/element pair, covering a
-- personal boost (e.g. FTUE's first-login Thunder surge, checked first and never
-- affecting other players), standard boosts, Void Storm ("All"), Double Surge
-- (elements array), Mystery Surge (secret real element, server-only), the "Any"
-- wildcard element (always benefits from any active boost), and the server-wide
-- ServerBoost multiplier (applies regardless of element boost).
--
-- The "Any" branch is currently unreachable: the elemental roster has no monster
-- with element "Any" (the old The Watcher did). Kept so a future wildcard monster
-- works without re-deriving this, but it is dead as of the elemental pivot.
--
-- BoostState.GetMultiplierForElement already folds in serverMultiplier for the
-- standard-boost path, so that branch must NOT multiply it again here -- every
-- other branch bypasses GetMultiplierForElement and so must apply it explicitly,
-- including the "no element boost active" case (serverMultiplier still applies).
function Economy.GetBoostMultiplier(element: string, userId: number): number
	local serverMultiplier = BoostState.GetServerMultiplier()

	local personalBoost = BoostState.GetPersonalBoost(userId)
	if personalBoost and (element == WATCHER_ELEMENT or personalBoost.element == element) then
		return personalBoost.multiplier * serverMultiplier
	end

	local boost = BoostState.GetCurrentBoost()

	if not boost.isActive then
		return serverMultiplier
	end

	if element == WATCHER_ELEMENT then
		return boost.multiplier * serverMultiplier
	end

	if boost.element == "Mystery" then
		if BoostState.GetRealElement() == element then
			return boost.multiplier * serverMultiplier
		end
		return serverMultiplier
	end

	return BoostState.GetMultiplierForElement(element)
end

-- incomeMultiplier is resolved internally from PlayerData rather than accepted as a
-- parameter, mirroring GetBoostMultiplier -- replaces the Phase 3 hardcoded default=1.
function Economy.GetVialValue(rarity: string, element: string, userId: number, monsterLevel: number, monsterStars: number): number
	local baseValue = Constants.BASE_VIAL_VALUES[rarity]
	if not baseValue then
		return 1
	end

	local data = PlayerManager.GetData(userId)
	local incomeMultiplier = (data and data.incomeMultiplier) or 1

	local boostMultiplier = Economy.GetBoostMultiplier(element, userId)
	local levelMultiplier = LEVEL_MULTIPLIERS[monsterLevel] or 1
	local starMultiplier = STAR_MULTIPLIERS[monsterStars] or 1

	local value = baseValue * boostMultiplier * incomeMultiplier * levelMultiplier * starMultiplier

	return math.max(math.floor(value), 1)
end

function Economy.GetEarnRate(slots: { Types.MonsterSlot }, userId: number): number
	local total = 0

	for _, slot in slots do
		if slot.isActive and slot.monster then
			local monster = slot.monster
			local value = Economy.GetVialValue(monster.rarity, monster.element, userId, monster.level, monster.stars)
			total += value / 30
		end
	end

	return total
end

function Economy.ProcessSell(
	userId: number,
	vialCount: number,
	vialRarity: string,
	vialElement: string,
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

	local unitValue = Economy.GetVialValue(vialRarity, vialElement, userId, monsterLevel, monsterStars)
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

		local earnRate = Economy.GetEarnRate(updatedData.monsterSlots, userId)
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
