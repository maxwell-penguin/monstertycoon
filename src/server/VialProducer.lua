local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Constants = require(ReplicatedStorage.Constants)
local Types = require(ReplicatedStorage.Types)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BoostState = require(ReplicatedStorage.BoostState)
local BagManager = require(script.Parent.BagManager)
local HabitatManager = require(script.Parent.HabitatManager)
local HabitatVisuals = require(script.Parent.HabitatVisuals)

export type VialData = {
	vialId: string,
	playerId: number,
	rarity: string,
	element: string,
	monsterLevel: number,
	monsterStars: number,
	slotIndex: number?,
	habitatId: string?,
	position: Vector3,
	spawnTime: number,
}

-- A single thing that can produce vials -- either a roaming slotted monster or
-- a placed Habitat -- normalized so callers and SpawnVial don't need to know
-- which source they came from.
export type ProductionSource = {
	monster: Types.Monster,
	position: Vector3,
	slotIndex: number?,
	habitatId: string?,
}

local VIAL_DROP_INTERVAL = 30
local MAX_XZ_OFFSET = 3
local Y_OFFSET = 1
local VIAL_DESPAWN_TIME = 300

local VialProducer = {}

local activeLoops: { [number]: boolean } = {}
local slotCooldowns: { [number]: { [string]: number } } = {}
local playerVials: { [number]: { [string]: VialData } } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local vialSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_SPAWNED) :: RemoteEvent
local vialRemovedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_REMOVED) :: RemoteEvent

function VialProducer.SpawnVial(player: Player, source: ProductionSource): string
	local monster = source.monster

	local vialId = HttpService:GenerateGUID(false)

	local offsetX = (math.random() * 2 - 1) * MAX_XZ_OFFSET
	local offsetZ = (math.random() * 2 - 1) * MAX_XZ_OFFSET
	local position = source.position + Vector3.new(offsetX, Y_OFFSET, offsetZ)

	local vialData: VialData = {
		vialId = vialId,
		playerId = player.UserId,
		rarity = monster.rarity,
		element = monster.element,
		monsterLevel = monster.level,
		monsterStars = monster.stars,
		slotIndex = source.slotIndex,
		habitatId = source.habitatId,
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
	slotCooldowns[userId] = {}
	playerVials[userId] = playerVials[userId] or {}

	-- Slotted-monster production is owned by MonsterAI.CheckVialProduction (it
	-- knows each monster's actual roaming position); this loop drives Habitat
	-- production and sweeps stale vials.
	task.spawn(function()
		while activeLoops[userId] do
			-- Cooldowns here are 30s (production) and 300s (despawn) -- Heartbeat
			-- (60/sec) reran this full GetActiveMonsters+iteration+table-alloc
			-- pass 60x more often than needed, for every plot owner simultaneously,
			-- which was the main source of server stutter. 1s polling is plenty.
			task.wait(1)

			if not activeLoops[userId] then
				break
			end

			-- Slotted monsters are produced for by MonsterAI.CheckVialProduction
			-- (it tracks each roaming monster's live position). Habitats have no
			-- roaming model, so their production still runs here.
			local now = os.clock()
			local cooldowns = slotCooldowns[userId]

			for _, active in HabitatManager.GetActiveMonsters(player) do
				local cooldownKey = "habitat_" .. active.habitatId
				local lastDrop = cooldowns[cooldownKey]
				if not lastDrop or (now - lastDrop) >= VIAL_DROP_INTERVAL then
					local habitat = HabitatManager.GetHabitat(player, active.habitatId)
					local position = habitat and HabitatVisuals.GetGroundWorldPosition(player, habitat)
					if position then
						cooldowns[cooldownKey] = now
						VialProducer.SpawnVial(player, {
							monster = active.monster,
							position = position,
							habitatId = active.habitatId,
						})
					end
				end
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
