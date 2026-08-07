local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Constants = require(ReplicatedStorage.Constants)
local Types = require(ReplicatedStorage.Types)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local Economy = require(script.Parent.Economy)
local MonsterData = require(script.Parent.MonsterData)

export type Warehouse = {
	monsters: { [string]: Types.Monster },
	capacity: number,
}

export type MergeableGroup = {
	monsterName: string,
	rarity: string,
	level: number,
	stars: number,
	instanceIds: { string },
}

local WarehouseManager = {}

local playerWarehouses: { [number]: Warehouse } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateWarehouseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_WAREHOUSE) :: RemoteEvent

local function generateInstanceId(): string
	return HttpService:GenerateGUID(false):sub(1, 8)
end

local function countMonsters(warehouse: Warehouse): number
	local count = 0
	for _ in warehouse.monsters do
		count += 1
	end
	return count
end

function WarehouseManager.InitWarehouse(player: Player)
	local userId = player.UserId
	local data = PlayerManager.GetData(userId)
	local warehouseTier = (data and data.warehouseTier) or 1
	local capacity = Constants.WAREHOUSE_CAPACITY[warehouseTier] or Constants.WAREHOUSE_BASE_CAPACITY

	local warehouse: Warehouse = {
		monsters = {},
		capacity = capacity,
	}

	playerWarehouses[userId] = warehouse

	updateWarehouseRemote:FireClient(player, warehouse)
end

function WarehouseManager.GetWarehouse(player: Player): Warehouse?
	return playerWarehouses[player.UserId]
end

function WarehouseManager.GetMonsterByInstanceId(player: Player, instanceId: string): Types.Monster?
	local warehouse = playerWarehouses[player.UserId]
	if not warehouse then
		return nil
	end

	return warehouse.monsters[instanceId]
end

function WarehouseManager.AddMonster(player: Player, monsterName: string, stars: number?): (boolean, string)
	local warehouse = playerWarehouses[player.UserId]
	if not warehouse then
		warn(`[Warehouse] AddMonster failed: no warehouse for {player.Name}`)
		return false, "not_found"
	end

	local monsterDef = MonsterData[monsterName]
	if not monsterDef then
		warn("[Warehouse] AddMonster failed: unknown monster " .. tostring(monsterName))
		return false, "invalid"
	end

	if countMonsters(warehouse) >= warehouse.capacity then
		warn(`[Warehouse] AddMonster failed: {player.Name} full at capacity {warehouse.capacity}`)
		return false, "full"
	end

	local instanceId = generateInstanceId()

	local monster: Types.Monster = {
		id = instanceId,
		name = monsterDef.name,
		element = monsterDef.element,
		rarity = monsterDef.rarity,
		level = monsterDef.level,
		stars = stars or 0,
		outputMultiplier = monsterDef.baseOutput,
	}

	warehouse.monsters[instanceId] = monster

	updateWarehouseRemote:FireClient(player, warehouse)

	return true, instanceId
end

function WarehouseManager.RemoveMonster(player: Player, instanceId: string): boolean
	local warehouse = playerWarehouses[player.UserId]
	if not warehouse then
		return false
	end

	if not warehouse.monsters[instanceId] then
		return false
	end

	warehouse.monsters[instanceId] = nil

	updateWarehouseRemote:FireClient(player, warehouse)

	return true
end

function WarehouseManager.GetMergeableGroups(player: Player): { MergeableGroup }
	local warehouse = playerWarehouses[player.UserId]
	if not warehouse then
		return {}
	end

	local groups: { [string]: MergeableGroup } = {}

	for instanceId, monster in warehouse.monsters do
		local key = `{monster.element}|{monster.rarity}|{monster.level}|{monster.stars}`
		local group = groups[key]

		if not group then
			group = {
				monsterName = monster.name,
				rarity = monster.rarity,
				level = monster.level,
				stars = monster.stars,
				instanceIds = {},
			}
			groups[key] = group
		end

		table.insert(group.instanceIds, instanceId)
	end

	local result = {}
	for _, group in groups do
		if #group.instanceIds >= 3 then
			table.insert(result, group)
		end
	end

	return result
end

function WarehouseManager.UpgradeWarehouse(player: Player): boolean
	local userId = player.UserId
	local warehouse = playerWarehouses[userId]
	if not warehouse then
		return false
	end

	local data = PlayerManager.GetData(userId)
	if not data then
		return false
	end

	local currentTier = data.warehouseTier
	local cost = Economy.GetUpgradeCost("warehouse", currentTier)
	if cost == math.huge then
		return false
	end

	if not PlayerManager.DecrementCoins(userId, cost) then
		return false
	end

	local newTier = currentTier + 1
	PlayerManager.SetData(userId, "warehouseTier", newTier)

	warehouse.capacity = Constants.WAREHOUSE_CAPACITY[newTier] or warehouse.capacity

	updateWarehouseRemote:FireClient(player, warehouse)

	return true
end

function WarehouseManager.GetCapacityInfo(player: Player): (number, number)
	local warehouse = playerWarehouses[player.UserId]
	if not warehouse then
		return 0, 0
	end

	return countMonsters(warehouse), warehouse.capacity
end

function WarehouseManager.ClearWarehouse(player: Player)
	playerWarehouses[player.UserId] = nil
end

function WarehouseManager.SaveWarehouseToPlayerData(player: Player)
	local warehouse = playerWarehouses[player.UserId]
	if not warehouse then
		return
	end

	PlayerManager.SetData(player.UserId, "warehouse", warehouse.monsters)
end

function WarehouseManager.LoadWarehouseFromPlayerData(player: Player)
	local warehouse = playerWarehouses[player.UserId]
	if not warehouse then
		return
	end

	local data = PlayerManager.GetData(player.UserId)
	if not data then
		return
	end

	-- Saved data is the one path monsters enter without going through AddMonster, so
	-- it's also the only path stale pre-pivot names (monsters since removed from
	-- MonsterData) can arrive by. They'd otherwise sit unmergeable forever, since
	-- MergeRules is keyed off the same names.
	local count = countMonsters(warehouse)
	local skippedForCapacity = 0

	for instanceId, monster in data.warehouse do
		local monsterName = typeof(monster) == "table" and monster.name or nil

		if not (typeof(monsterName) == "string" and MonsterData[monsterName]) then
			warn("[Warehouse] Skipped stale monster: " .. tostring(monsterName))
		elseif count >= warehouse.capacity then
			skippedForCapacity += 1
		else
			warehouse.monsters[instanceId] = monster
			count += 1
		end
	end

	if skippedForCapacity > 0 then
		warn(
			`[Warehouse] {player.Name}: {skippedForCapacity} saved monsters left unloaded, over capacity {warehouse.capacity}`
		)
	end

	updateWarehouseRemote:FireClient(player, warehouse)
end

return WarehouseManager
