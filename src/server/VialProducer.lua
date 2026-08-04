local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Constants = require(ReplicatedStorage.Constants)
local Types = require(ReplicatedStorage.Types)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BoostState = require(ReplicatedStorage.BoostState)
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
local VIAL_DESPAWN_TIME = 300

local VialProducer = {}

local activeLoops: { [number]: boolean } = {}
local slotCooldowns: { [number]: { [number]: number } } = {}
local playerVials: { [number]: { [string]: VialData } } = {}

-- Vials only ever existed as a client-rendered visual (VialClient.client.lua) with
-- the server tracking pure data, no Part -- server-side .Touched detection needs
-- an actual server Part to exist. These are invisible, non-colliding "trigger"
-- Parts positioned exactly where each client renders its own visual vial; they
-- exist purely to detect overlap server-side, not to be seen.
local playerVialTriggers: { [number]: { [string]: BasePart } } = {}

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

	-- Invisible, non-colliding trigger Part so the server can detect a touch
	-- directly instead of only trusting the client's PICKUP_VIAL fire. CanCollide
	-- stays false so it never blocks movement or interferes with the client's own
	-- visual vial Part; CanTouch (true by default) is what makes .Touched fire.
	local triggerPart = Instance.new("Part")
	triggerPart.Name = "VialTrigger_" .. vialId
	triggerPart.Size = Vector3.new(1.5, 1.5, 1.5)
	triggerPart.Shape = Enum.PartType.Ball
	triggerPart.Anchored = true
	triggerPart.CanCollide = false
	triggerPart.CanTouch = true
	triggerPart.Transparency = 1
	triggerPart.Position = position
	triggerPart.Parent = Workspace

	local triggers = playerVialTriggers[player.UserId]
	if not triggers then
		triggers = {}
		playerVialTriggers[player.UserId] = triggers
	end
	triggers[vialId] = triggerPart

	triggerPart.Touched:Connect(function(hitPart: BasePart)
		local character = hitPart:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end

		local touchingPlayer = Players:GetPlayerFromCharacter(character)
		if not touchingPlayer then
			return
		end

		-- No separate ownership check needed: CollectVial looks the vialId up in
		-- *this* player's own table, so a non-owner's touch simply finds nothing
		-- and is rejected as "not_found" -- there's no cross-player vial to leak.
		VialProducer.CollectVial(touchingPlayer, vialId)
	end)

	-- Visual intensity only; actual sale value is resolved fresh (and correctly,
	-- including Mystery Surge's hidden emotion) by Economy at sell time.
	local boostMultiplier = BoostState.GetMultiplierForEmotion(monster.emotion)
	vialSpawnedRemote:FireClient(player, vialId, position, monster.rarity, monster.emotion, boostMultiplier)

	return vialId
end

local function destroyVialTrigger(userId: number, vialId: string)
	local triggers = playerVialTriggers[userId]
	local triggerPart = triggers and triggers[vialId]
	if triggerPart then
		triggers[vialId] = nil
		triggerPart:Destroy()
	end
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

	local triggers = playerVialTriggers[userId]
	if triggers then
		for _, triggerPart in triggers do
			triggerPart:Destroy()
		end
		playerVialTriggers[userId] = nil
	end
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
			destroyVialTrigger(userId, vialId)

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
	destroyVialTrigger(userId, vialId)
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
