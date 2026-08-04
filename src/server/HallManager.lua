local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Constants = require(ReplicatedStorage.Constants)
local Types = require(ReplicatedStorage.Types)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local Economy = require(script.Parent.Economy)
local MonsterData = require(script.Parent.MonsterData)

local HallManager = {}

local playerSlots: { [number]: { Types.MonsterSlot } } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateHallRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_HALL) :: RemoteEvent

local function buildEmptySlots(count: number): { Types.MonsterSlot }
	local slots = {}
	for i = 1, count do
		slots[i] = { slotIndex = i, monster = nil, isActive = false }
	end
	return slots
end

function HallManager.InitHall(player: Player)
	local userId = player.UserId
	local data = PlayerManager.GetData(userId)
	local hallTier = (data and data.hallTier) or 1
	local slotCount = Constants.HALL_SLOT_COUNTS[hallTier] or Constants.HALL_BASE_SLOTS

	local slots = buildEmptySlots(slotCount)
	playerSlots[userId] = slots

	updateHallRemote:FireClient(player, slots)
end

function HallManager.ClearHall(player: Player)
	playerSlots[player.UserId] = nil
end

function HallManager.GetSlots(player: Player): { Types.MonsterSlot }
	return playerSlots[player.UserId] or {}
end

-- monsterName is a temporary stand-in for a real monster instance id until
-- WarehouseManager (Phase 8) exists to look up owned monster instances.
function HallManager.SlotMonster(player: Player, slotIndex: number, monsterName: string): boolean
	local slots = playerSlots[player.UserId]
	if not slots then
		return false
	end

	if typeof(slotIndex) ~= "number" or slotIndex ~= math.floor(slotIndex) or slotIndex < 1 or slotIndex > #slots then
		return false
	end

	if typeof(monsterName) ~= "string" then
		return false
	end

	local monsterDef = MonsterData[monsterName]
	if not monsterDef then
		return false
	end

	local monster: Types.Monster = {
		id = HttpService:GenerateGUID(false),
		name = monsterDef.name,
		emotion = monsterDef.emotion,
		rarity = monsterDef.rarity,
		level = monsterDef.level,
		stars = 0,
		outputMultiplier = monsterDef.baseOutput,
	}

	slots[slotIndex].monster = monster
	slots[slotIndex].isActive = true

	updateHallRemote:FireClient(player, slots)

	return true
end

function HallManager.UnslotMonster(player: Player, slotIndex: number): boolean
	local slots = playerSlots[player.UserId]
	if not slots then
		return false
	end

	if typeof(slotIndex) ~= "number" or slotIndex ~= math.floor(slotIndex) or slotIndex < 1 or slotIndex > #slots then
		return false
	end

	local slot = slots[slotIndex]
	if not slot.monster then
		return false
	end

	slot.monster = nil
	slot.isActive = false

	updateHallRemote:FireClient(player, slots)

	return true
end

function HallManager.UpgradeHall(player: Player): boolean
	local userId = player.UserId
	local slots = playerSlots[userId]
	if not slots then
		return false
	end

	local data = PlayerManager.GetData(userId)
	if not data then
		return false
	end

	local currentTier = data.hallTier
	local cost = Economy.GetUpgradeCost("hall", currentTier)
	if cost == math.huge then
		return false
	end

	if not PlayerManager.DecrementCoins(userId, cost) then
		return false
	end

	local newTier = currentTier + 1
	local newSlotCount = Constants.HALL_SLOT_COUNTS[newTier] or #slots

	for i = #slots + 1, newSlotCount do
		slots[i] = { slotIndex = i, monster = nil, isActive = false }
	end

	PlayerManager.SetData(userId, "hallTier", newTier)

	updateHallRemote:FireClient(player, slots)

	return true
end

function HallManager.GetActiveMonsters(player: Player): { Types.MonsterSlot }
	local slots = playerSlots[player.UserId]
	if not slots then
		return {}
	end

	local active = {}
	for _, slot in slots do
		if slot.isActive and slot.monster then
			table.insert(active, slot)
		end
	end

	return active
end

return HallManager
