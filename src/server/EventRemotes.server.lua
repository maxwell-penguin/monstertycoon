local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local EventManager = require(script.Parent.EventManager)
local EventStation = require(script.Parent.EventStation)
local CrateManager = require(script.Parent.CrateManager)
local PlayerManager = require(script.Parent.PlayerManager)
local RateLimiter = require(script.Parent.RateLimiter)
local AntiCheat = require(script.Parent.AntiCheat)

local GUID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local shardCollectedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SHARD_COLLECTED) :: RemoteEvent
local openCrateRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.OPEN_CRATE) :: RemoteEvent
local eventStationPurchaseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.EVENT_STATION_PURCHASE) :: RemoteEvent
local playerDataLoadedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLAYER_DATA_LOADED) :: RemoteEvent

local shardLimiter = RateLimiter.CreateLimiter(10, 1)
local crateLimiter = RateLimiter.CreateLimiter(5, 1)
local stationLimiter = RateLimiter.CreateLimiter(3, 10)

local function isValidGuid(value: any): boolean
	return typeof(value) == "string" and value:match(GUID_PATTERN) ~= nil
end

shardCollectedRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if typeof(payload) ~= "table" then
		return
	end

	local shardId = payload.shardId
	if not isValidGuid(shardId) then
		return
	end

	if not shardLimiter:Check(userId) then
		warn(`[EventRemotes] Shard collection rate limit exceeded for user {userId}`)
		return
	end

	local success, reason = EventManager.ClaimShard(player, shardId)
	if not success and reason == "out_of_range" then
		AntiCheat.RecordViolation(player, `position_mismatch: shard collection out of range`)
	end
end)

-- Routes OPEN_CRATE to the shared event crate (Crate Race) or a personal crate
-- (CrateManager), based on which crate table the id actually belongs to. This is
-- the sole OPEN_CRATE listener -- RollRemotes.server.lua's old unconditional
-- CrateManager-only handler was removed so the two don't double-process the same
-- request.
openCrateRemote.OnServerEvent:Connect(function(player: Player, crateId: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if not isValidGuid(crateId) then
		return
	end

	if not crateLimiter:Check(userId) then
		warn(`[EventRemotes] Crate open rate limit exceeded for user {userId}`)
		return
	end

	if EventManager.IsEventCrate(crateId) then
		EventManager.ClaimEventCrate(player, crateId)
	else
		CrateManager.ClaimCrate(player, crateId)
	end
end)

eventStationPurchaseRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if typeof(payload) ~= "table" then
		return
	end

	local monsterName = payload.monsterName
	if typeof(monsterName) ~= "string" then
		return
	end

	if not stationLimiter:Check(userId) then
		warn(`[EventRemotes] Event Station purchase rate limit exceeded for user {userId}`)
		return
	end

	local success = EventStation.PurchaseEventMonster(player, monsterName)
	if success then
		-- Nothing else pushes the eventTokens deduction (or the new warehouse
		-- monster count -- WarehouseManager.AddMonster already handles that part
		-- via UPDATE_WAREHOUSE) to the client on its own, so re-sync the full
		-- snapshot the same way MonetizationManager does after granting something.
		local data = PlayerManager.GetData(userId)
		if data then
			playerDataLoadedRemote:FireClient(player, data)
		end
	end
end)
