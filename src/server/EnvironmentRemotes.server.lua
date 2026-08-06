local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local HallManager = require(script.Parent.HallManager)
local MonsterAI = require(script.Parent.MonsterAI)
local RateLimiter = require(script.Parent.RateLimiter)

local INSTANCE_ID_LENGTH = 8

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local slotMonsterRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SLOT_MONSTER) :: RemoteEvent
local unslotMonsterRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UNSLOT_MONSTER) :: RemoteEvent
local upgradeEnvironmentRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPGRADE_ENVIRONMENT) :: RemoteEvent

local slotLimiter = RateLimiter.CreateLimiter(5, 1)
local unslotLimiter = RateLimiter.CreateLimiter(5, 1)
local upgradeLimiter = RateLimiter.CreateLimiter(3, 10)

local function isValidInstanceId(instanceId: any): boolean
	return typeof(instanceId) == "string"
		and #instanceId == INSTANCE_ID_LENGTH
		and instanceId:match("^%w+$") ~= nil
end

slotMonsterRemote.OnServerEvent:Connect(function(player: Player, slotIndex: any, instanceId: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if not slotLimiter:Check(userId) then
		warn(`[EnvironmentRemotes] Slot rate limit exceeded for user {userId}`)
		return
	end

	if typeof(slotIndex) ~= "number" then
		return
	end

	if not isValidInstanceId(instanceId) then
		return
	end

	if HallManager.SlotMonster(player, slotIndex, instanceId) then
		MonsterAI.UpdateRoster(player)
	end
end)

unslotMonsterRemote.OnServerEvent:Connect(function(player: Player, slotIndex: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if not unslotLimiter:Check(userId) then
		warn(`[EnvironmentRemotes] Unslot rate limit exceeded for user {userId}`)
		return
	end

	if typeof(slotIndex) ~= "number" then
		return
	end

	if HallManager.UnslotMonster(player, slotIndex) then
		MonsterAI.UpdateRoster(player)
	end
end)

upgradeEnvironmentRemote.OnServerEvent:Connect(function(player: Player)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if not upgradeLimiter:Check(userId) then
		warn(`[EnvironmentRemotes] Upgrade rate limit exceeded for user {userId}`)
		return
	end

	local success = HallManager.UpgradeMonsterEnvironment(player)
	upgradeEnvironmentRemote:FireClient(player, success)
end)
