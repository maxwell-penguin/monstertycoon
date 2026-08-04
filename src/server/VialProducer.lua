local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Constants = require(ReplicatedStorage.Constants)
local Types = require(ReplicatedStorage.Types)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local HallManager = require(script.Parent.HallManager)
local SlotPositioner = require(script.Parent.SlotPositioner)
local BagManager = require(script.Parent.BagManager)

export type VialData = {
	vialId: string,
	playerId: number,
	rarity: string,
	emotion: string,
	monsterLevel: number,
	monsterStars: number,
	slotIndex: number,
	position: Vector3,
	spawnTime: number,
}

local VIAL_DROP_INTERVAL = 30
local MAX_XZ_OFFSET = 3
local Y_OFFSET = 1

local VialProducer = {}

local activeLoops: { [number]: boolean } = {}
local slotCooldowns: { [number]: { [number]: number } } = {}
local playerVials: { [number]: { [string]: VialData } } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local vialSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_SPAWNED) :: RemoteEvent
local vialRemovedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_REMOVED) :: RemoteEvent

function VialProducer.SpawnVial(player: Player, slot: Types.MonsterSlot): string
	local monster = slot.monster
	if not monster then
		return ""
	end

	local vialId = HttpService:GenerateGUID(false)
	local slotPosition = SlotPositioner.GetSlotWorldPosition(player, slot.slotIndex)

	local offsetX = (math.random() * 2 - 1) * MAX_XZ_OFFSET
	local offsetZ = (math.random() * 2 - 1) * MAX_XZ_OFFSET
	local position = slotPosition + Vector3.new(offsetX, Y_OFFSET, offsetZ)

	local vialData: VialData = {
		vialId = vialId,
		playerId = player.UserId,
		rarity = monster.rarity,
		emotion = monster.emotion,
		monsterLevel = monster.level,
		monsterStars = monster.stars,
		slotIndex = slot.slotIndex,
		position = position,
		spawnTime = os.time(),
	}

	local vials = playerVials[player.UserId]
	if not vials then
		vials = {}
		playerVials[player.UserId] = vials
	end
	vials[vialId] = vialData

	vialSpawnedRemote:FireClient(player, vialId, position, monster.rarity, monster.emotion)

	return vialId
end

function VialProducer.StartProduction(player: Player)
	local userId = player.UserId
	if activeLoops[userId] then
		return
	end

	activeLoops[userId] = true
	playerVials[userId] = playerVials[userId] or {}
	slotCooldowns[userId] = {}

	task.spawn(function()
		while activeLoops[userId] do
			RunService.Heartbeat:Wait()

			if not activeLoops[userId] then
				break
			end

			local now = os.clock()
			local cooldowns = slotCooldowns[userId]

			for _, slot in HallManager.GetActiveMonsters(player) do
				local lastDrop = cooldowns[slot.slotIndex]
				if not lastDrop or (now - lastDrop) >= VIAL_DROP_INTERVAL then
					cooldowns[slot.slotIndex] = now
					VialProducer.SpawnVial(player, slot)
				end
			end
		end
	end)
end

function VialProducer.StopProduction(player: Player)
	local userId = player.UserId
	activeLoops[userId] = nil
	slotCooldowns[userId] = nil
	playerVials[userId] = nil
end

function VialProducer.GetVialData(vialId: string): VialData?
	for _, vials in playerVials do
		local data = vials[vialId]
		if data then
			return data
		end
	end
	return nil
end

function VialProducer.CollectVial(player: Player, vialId: string): boolean
	local userId = player.UserId
	local vials = playerVials[userId]
	local vialData = vials and vials[vialId]

	if not vialData then
		warn(`[VialProducer] Rejected pickup from user {userId}: vial {vialId} not found`)
		return false
	end

	local character = player.Character
	if not character then
		warn(`[VialProducer] Rejected pickup from user {userId}: no character`)
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		warn(`[VialProducer] Rejected pickup from user {userId}: no HumanoidRootPart`)
		return false
	end

	local distance = (rootPart.Position - vialData.position).Magnitude
	if distance > Constants.VIAL_PICKUP_RADIUS then
		warn(`[VialProducer] Rejected pickup from user {userId}: out of range ({distance} studs)`)
		return false
	end

	vials[vialId] = nil

	vialRemovedRemote:FireClient(player, vialId)
	BagManager.AddVial(player, vialData)

	return true
end

function VialProducer.GetActiveVials(player: Player): { VialData }
	local vials = playerVials[player.UserId]
	if not vials then
		return {}
	end

	local result = {}
	for _, vialData in vials do
		table.insert(result, vialData)
	end

	return result
end

return VialProducer
