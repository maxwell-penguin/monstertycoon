local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local HabitatManager = require(script.Parent.HabitatManager)
local RateLimiter = require(script.Parent.RateLimiter)
local AntiCheat = require(script.Parent.AntiCheat)

local INSTANCE_ID_LENGTH = 8
local MAX_COORD = 60

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local purchaseHabitatRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PURCHASE_HABITAT) :: RemoteEvent
local placeHabitatRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLACE_HABITAT) :: RemoteEvent
local slotHabitatMonsterRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SLOT_HABITAT_MONSTER) :: RemoteEvent
local unslotHabitatMonsterRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UNSLOT_HABITAT_MONSTER) :: RemoteEvent

local purchaseLimiter = RateLimiter.CreateLimiter(5, 5)
local placeLimiter = RateLimiter.CreateLimiter(5, 5)
local slotLimiter = RateLimiter.CreateLimiter(5, 1)
local unslotLimiter = RateLimiter.CreateLimiter(5, 1)

local function isValidId(id: any): boolean
	return typeof(id) == "string" and #id == INSTANCE_ID_LENGTH and id:match("^%w+$") ~= nil
end

local function isValidBiomeType(biomeType: any): boolean
	if typeof(biomeType) ~= "string" then
		return false
	end
	for _, def in Constants.HABITAT_TYPES do
		if def.biomeType == biomeType then
			return true
		end
	end
	return false
end

local function isValidCoord(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and math.abs(value) <= MAX_COORD
end

purchaseHabitatRemote.OnServerEvent:Connect(function(player: Player, biomeType: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if not purchaseLimiter:Check(userId) then
		warn(`[HabitatRemotes] Purchase rate limit exceeded for user {userId}`)
		return
	end

	if not isValidBiomeType(biomeType) then
		return
	end

	HabitatManager.PurchaseHabitat(player, biomeType)
end)

placeHabitatRemote.OnServerEvent:Connect(function(player: Player, biomeType: any, x: any, z: any, rotationY: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if not placeLimiter:Check(userId) then
		warn(`[HabitatRemotes] Place rate limit exceeded for user {userId}`)
		return
	end

	if not isValidBiomeType(biomeType) then
		return
	end

	if not isValidCoord(x) or not isValidCoord(z) then
		return
	end

	if typeof(rotationY) ~= "number" or rotationY ~= rotationY then
		return
	end

	local success, reason = HabitatManager.PlaceHabitat(player, biomeType, x, z, rotationY)

	if not success and reason == "out_of_bounds" then
		AntiCheat.RecordViolation(player, "habitat_placement_out_of_bounds")
	end
end)

slotHabitatMonsterRemote.OnServerEvent:Connect(function(player: Player, habitatId: any, instanceId: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if not slotLimiter:Check(userId) then
		warn(`[HabitatRemotes] Slot rate limit exceeded for user {userId}`)
		return
	end

	if not isValidId(habitatId) or not isValidId(instanceId) then
		return
	end

	HabitatManager.SlotMonster(player, habitatId, instanceId)
end)

unslotHabitatMonsterRemote.OnServerEvent:Connect(function(player: Player, habitatId: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if not unslotLimiter:Check(userId) then
		warn(`[HabitatRemotes] Unslot rate limit exceeded for user {userId}`)
		return
	end

	if not isValidId(habitatId) then
		return
	end

	HabitatManager.UnslotMonster(player, habitatId)
end)
