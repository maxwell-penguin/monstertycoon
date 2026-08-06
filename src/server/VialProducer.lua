local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Constants = require(ReplicatedStorage.Constants)
local Types = require(ReplicatedStorage.Types)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BoostState = require(ReplicatedStorage.BoostState)
local SlotPositioner = require(script.Parent.SlotPositioner)
local BagManager = require(script.Parent.BagManager)

export type VialData = {
	vialId: string,
	playerId: number,
	rarity: string,
	element: string,
	monsterLevel: number,
	monsterStars: number,
	slotIndex: number,
	position: Vector3,
	spawnTime: number,
}

local MAX_XZ_OFFSET = 3
local Y_OFFSET = 1
local VIAL_DESPAWN_TIME = 300

local VialProducer = {}

local activeLoops: { [number]: boolean } = {}
local playerVials: { [number]: { [string]: VialData } } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local vialSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_SPAWNED) :: RemoteEvent
local vialRemovedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_REMOVED) :: RemoteEvent

function VialProducer.SpawnVial(player: Player, slot: Types.MonsterSlot, worldPosition: Vector3?): string
	local monster = slot.monster
	if not monster then
		return ""
	end

	local vialId = HttpService:GenerateGUID(false)

	local position: Vector3
	if worldPosition then
		position = worldPosition
	else
		local slotPosition = SlotPositioner.GetSlotWorldPosition(player, slot.slotIndex)
		local offsetX = (math.random() * 2 - 1) * MAX_XZ_OFFSET
		local offsetZ = (math.random() * 2 - 1) * MAX_XZ_OFFSET
		position = slotPosition + Vector3.new(offsetX, Y_OFFSET, offsetZ)
	end

	local vialData: VialData = {
		vialId = vialId,
		playerId = player.UserId,
		rarity = monster.rarity,
		element = monster.element,
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

	-- Visual intensity only; actual sale value is resolved fresh (and correctly,
	-- including Mystery Surge's hidden element) by Economy at sell time.
	local boostMultiplier = BoostState.GetMultiplierForElement(monster.element)
	vialSpawnedRemote:FireClient(player, vialId, position, monster.rarity, monster.element, boostMultiplier)

	return vialId
end

function VialProducer.StartProduction(player: Player)
	local userId = player.UserId
	if activeLoops[userId] then
		return
	end

	activeLoops[userId] = true
	playerVials[userId] = playerVials[userId] or {}

	-- Production itself is now owned by MonsterAI.CheckVialProduction (it knows
	-- each monster's actual roaming position); this loop only sweeps stale vials.
	task.spawn(function()
		while activeLoops[userId] do
			RunService.Heartbeat:Wait()

			if not activeLoops[userId] then
				break
			end

			local vials = playerVials[userId]
			if vials then
				local nowTime = os.time()
				local staleVialIds = {}
				for vialId, vialData in vials do
					if nowTime - vialData.spawnTime > VIAL_DESPAWN_TIME then
						table.insert(staleVialIds, vialId)
					end
				end
				for _, vialId in staleVialIds do
					VialProducer.DespawnVial(vialId)
				end
			end
		end
	end)
end

function VialProducer.StopProduction(player: Player)
	local userId = player.UserId
	activeLoops[userId] = nil
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

function VialProducer.DespawnVial(vialId: string)
	for userId, vials in playerVials do
		if vials[vialId] then
			vials[vialId] = nil

			local player = Players:GetPlayerByUserId(userId)
			if player then
				vialRemovedRemote:FireClient(player, vialId)
			end

			return
		end
	end
end

-- Reason string lets VialRemotes.server.lua tell an AntiCheat-worthy position
-- mismatch apart from a harmless bag-full rejection.
function VialProducer.CollectVial(player: Player, vialId: string): (boolean, string)
	local userId = player.UserId
	local vials = playerVials[userId]
	local vialData = vials and vials[vialId]

	if not vialData then
		warn(`[VialProducer] Rejected pickup from user {userId}: vial {vialId} not found`)
		return false, "not_found"
	end

	local character = player.Character
	if not character then
		warn(`[VialProducer] Rejected pickup from user {userId}: no character`)
		return false, "no_character"
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		warn(`[VialProducer] Rejected pickup from user {userId}: no HumanoidRootPart`)
		return false, "no_character"
	end

	local distance = (rootPart.Position - vialData.position).Magnitude
	if distance > Constants.VIAL_PICKUP_RADIUS then
		warn(`[VialProducer] Rejected pickup from user {userId}: out of range ({distance} studs)`)
		return false, "out_of_range"
	end

	-- Only remove the vial from the ground once the bag actually accepts it; if the
	-- bag is full the vial stays collectible until space opens up or it despawns.
	local added = BagManager.AddVial(player, vialData)
	if not added then
		return false, "bag_full"
	end

	vials[vialId] = nil
	vialRemovedRemote:FireClient(player, vialId)

	return true, ""
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
