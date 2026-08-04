local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local RollTable = require(ReplicatedStorage.RollTable)
local PlayerManager = require(script.Parent.PlayerManager)
local Economy = require(script.Parent.Economy)
local WarehouseManager = require(script.Parent.WarehouseManager)

local MAX_PREMIUM_ROLL_ATTEMPTS = 100
local VALID_BATCH_COUNTS = { [1] = true, [5] = true, [10] = true }

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local eggResultRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.EGG_RESULT) :: RemoteEvent

local RARITY_RANK = {}
for i, rarity in RollTable.RARITY_ORDER do
	RARITY_RANK[rarity] = i
end

local RollManager = {}

function RollManager.GetTownLevel(player: Player): number
	local data = PlayerManager.GetData(player.UserId)
	return (data and data.townLevel) or 1
end

function RollManager.GetRollCost(player: Player): number
	local data = PlayerManager.GetData(player.UserId)
	local lifetimeRolls = (data and data.lifetimeRolls) or 0
	return Economy.GetRollCost(lifetimeRolls)
end

function RollManager.PerformRoll(player: Player): (boolean, string, string, any)
	local userId = player.UserId
	local data = PlayerManager.GetData(userId)
	if not data then
		return false, "not_found", "", 0
	end

	local cost = RollManager.GetRollCost(player)
	if data.coins < cost then
		return false, "insufficient_coins", "", 0
	end

	if not PlayerManager.DecrementCoins(userId, cost) then
		return false, "insufficient_coins", "", 0
	end

	local townLevel = RollManager.GetTownLevel(player)
	local monsterName, rarity = RollTable.RollMonster(townLevel)

	local added, newInstanceId = WarehouseManager.AddMonster(player, monsterName)
	if not added then
		PlayerManager.IncrementCoins(userId, cost)
		eggResultRemote:FireClient(player, { success = false, reason = "full" })
		return false, "full", "", 0
	end

	PlayerManager.SetData(userId, "lifetimeRolls", data.lifetimeRolls + 1)

	eggResultRemote:FireClient(player, {
		success = true,
		monsterName = monsterName,
		rarity = rarity,
		newInstanceId = newInstanceId,
		coinsSpent = cost,
	})

	return true, monsterName, rarity, newInstanceId
end

function RollManager.PerformPremiumRoll(
	player: Player,
	minimumRarity: string,
	isPurchaseValid: boolean
): (boolean, string, string, string)
	if not isPurchaseValid then
		return false, "", "", ""
	end

	local minRank = RARITY_RANK[minimumRarity]
	if not minRank then
		return false, "", "", ""
	end

	local townLevel = RollManager.GetTownLevel(player)

	local rarity
	local attempts = 0
	repeat
		rarity = RollTable.RollRarity(townLevel)
		attempts += 1
	until RARITY_RANK[rarity] >= minRank or attempts >= MAX_PREMIUM_ROLL_ATTEMPTS

	if RARITY_RANK[rarity] < minRank then
		rarity = minimumRarity
	end

	local monsterName = RollTable.RollMonsterOfRarity(rarity)

	local added, newInstanceId = WarehouseManager.AddMonster(player, monsterName)
	if not added then
		eggResultRemote:FireClient(player, { success = false, reason = "full" })
		return false, "full", "", ""
	end

	eggResultRemote:FireClient(player, {
		success = true,
		monsterName = monsterName,
		rarity = rarity,
		newInstanceId = newInstanceId,
		isPremium = true,
	})

	return true, monsterName, rarity, newInstanceId
end

function RollManager.PerformBatchRoll(player: Player, count: number): { any }
	if not VALID_BATCH_COUNTS[count] then
		return {}
	end

	local results = {}

	for _ = 1, count do
		local success, monsterNameOrReason, rarity, newInstanceId = RollManager.PerformRoll(player)

		table.insert(results, {
			success = success,
			monsterName = monsterNameOrReason,
			rarity = rarity,
			newInstanceId = newInstanceId,
		})

		if not success then
			break
		end
	end

	return results
end

return RollManager
