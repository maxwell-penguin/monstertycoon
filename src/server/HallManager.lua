local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local Types = require(ReplicatedStorage.Types)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local Economy = require(script.Parent.Economy)
local WarehouseManager = require(script.Parent.WarehouseManager)
local BiomeData = require(script.Parent.BiomeData)

-- Module/file stays named HallManager (require path unchanged everywhere), but
-- monsters are no longer slotted onto physical pedestals -- slots are now a
-- roster cap and each slotted monster roams a biome based on its element.
local MonsterEnvironment = {}

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

function MonsterEnvironment.InitMonsterEnvironment(player: Player)
	local userId = player.UserId
	local data = PlayerManager.GetData(userId)
	local environmentTier = (data and data.environmentTier) or 1
	local slotCount = Constants.ENVIRONMENT_CAPACITY[environmentTier] or Constants.HALL_BASE_SLOTS

	local slots = buildEmptySlots(slotCount)
	playerSlots[userId] = slots

	updateHallRemote:FireClient(player, slots)
end

function MonsterEnvironment.ClearMonsterEnvironment(player: Player)
	playerSlots[player.UserId] = nil
end

function MonsterEnvironment.GetSlots(player: Player): { Types.MonsterSlot }
	return playerSlots[player.UserId] or {}
end

function MonsterEnvironment.SlotMonster(player: Player, slotIndex: number, instanceId: string): boolean
	local slots = playerSlots[player.UserId]
	if not slots then
		return false
	end

	if typeof(slotIndex) ~= "number" or slotIndex ~= math.floor(slotIndex) or slotIndex < 1 or slotIndex > #slots then
		return false
	end

	if typeof(instanceId) ~= "string" then
		return false
	end

	local monster = WarehouseManager.GetMonsterByInstanceId(player, instanceId)
	if not monster then
		return false
	end

	slots[slotIndex].monster = monster
	slots[slotIndex].isActive = true

	WarehouseManager.RemoveMonster(player, instanceId)

	updateHallRemote:FireClient(player, slots)

	return true
end

function MonsterEnvironment.UnslotMonster(player: Player, slotIndex: number): boolean
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

function MonsterEnvironment.UpgradeMonsterEnvironment(player: Player): boolean
	local userId = player.UserId
	local slots = playerSlots[userId]
	if not slots then
		return false
	end

	local data = PlayerManager.GetData(userId)
	if not data then
		return false
	end

	local currentTier = data.environmentTier
	local cost = Economy.GetUpgradeCost("environment", currentTier)
	if cost == math.huge then
		return false
	end

	if not PlayerManager.DecrementCoins(userId, cost) then
		return false
	end

	local newTier = currentTier + 1
	local newSlotCount = Constants.ENVIRONMENT_CAPACITY[newTier] or #slots

	for i = #slots + 1, newSlotCount do
		slots[i] = { slotIndex = i, monster = nil, isActive = false }
	end

	PlayerManager.SetData(userId, "environmentTier", newTier)

	updateHallRemote:FireClient(player, slots)

	return true
end

function MonsterEnvironment.GetActiveMonsters(player: Player): { Types.MonsterSlot }
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

-- Groups slotted monsters by which biome their element belongs to, e.g.
-- {Forest = {monster1, monster2}, Volcano = {monster3}} -- used by MonsterAI
-- to know which monsters roam which biome.
function MonsterEnvironment.GetMonstersByBiome(player: Player): { [string]: { Types.Monster } }
	local grouped: { [string]: { Types.Monster } } = {}

	for _, slot in MonsterEnvironment.GetActiveMonsters(player) do
		local monster = slot.monster :: Types.Monster
		local biomeName = BiomeData.GetBiomeForElement(monster.element)
		if biomeName then
			local list = grouped[biomeName]
			if not list then
				list = {}
				grouped[biomeName] = list
			end
			table.insert(list, monster)
		end
	end

	return grouped
end

export type RoamingMonster = { monster: Types.Monster, biomeName: string, slotIndex: number }

-- Flat array version of GetMonstersByBiome, one entry per slotted monster.
function MonsterEnvironment.GetRoamingMonsters(player: Player): { RoamingMonster }
	local roaming: { RoamingMonster } = {}

	for _, slot in MonsterEnvironment.GetActiveMonsters(player) do
		local monster = slot.monster :: Types.Monster
		local biomeName = BiomeData.GetBiomeForElement(monster.element)
		if biomeName then
			table.insert(roaming, { monster = monster, biomeName = biomeName, slotIndex = slot.slotIndex })
		end
	end

	return roaming
end

return MonsterEnvironment
