local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local EventManager = require(script.Parent.EventManager)
local EventStation = require(script.Parent.EventStation)
local CrateManager = require(script.Parent.CrateManager)
local PlayerManager = require(script.Parent.PlayerManager)

local SHARD_RATE_LIMIT_WINDOW = 1
local SHARD_RATE_LIMIT_COUNT = 10

local CRATE_RATE_LIMIT_WINDOW = 1
local CRATE_RATE_LIMIT_COUNT = 5

local STATION_RATE_LIMIT_WINDOW = 10
local STATION_RATE_LIMIT_COUNT = 3

local GUID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local shardCollectedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SHARD_COLLECTED) :: RemoteEvent
local openCrateRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.OPEN_CRATE) :: RemoteEvent
local eventStationPurchaseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.EVENT_STATION_PURCHASE) :: RemoteEvent
local playerDataLoadedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLAYER_DATA_LOADED) :: RemoteEvent

local shardRequestTimes: { [number]: { number } } = {}
local crateRequestTimes: { [number]: { number } } = {}
local stationRequestTimes: { [number]: { number } } = {}

local function isValidGuid(value: any): boolean
	return typeof(value) == "string" and value:match(GUID_PATTERN) ~= nil
end

local function isRateLimited(store: { [number]: { number } }, userId: number, window: number, count: number): boolean
	local now = os.clock()
	local times = store[userId]
	if not times then
		times = {}
		store[userId] = times
	end

	local i = 1
	while i <= #times do
		if now - times[i] >= window then
			table.remove(times, i)
		else
			i += 1
		end
	end

	if #times >= count then
		return true
	end

	table.insert(times, now)
	return false
end

shardCollectedRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local shardId = payload.shardId
	if not isValidGuid(shardId) then
		return
	end

	if isRateLimited(shardRequestTimes, player.UserId, SHARD_RATE_LIMIT_WINDOW, SHARD_RATE_LIMIT_COUNT) then
		warn(`[EventRemotes] Shard collection rate limit exceeded for user {player.UserId}`)
		return
	end

	EventManager.ClaimShard(player, shardId)
end)

-- Routes OPEN_CRATE to the shared event crate (Crate Race) or a personal crate
-- (CrateManager), based on which crate table the id actually belongs to. This is
-- the sole OPEN_CRATE listener -- RollRemotes.server.lua's old unconditional
-- CrateManager-only handler was removed so the two don't double-process the same
-- request.
openCrateRemote.OnServerEvent:Connect(function(player: Player, crateId: any)
	if not isValidGuid(crateId) then
		return
	end

	if isRateLimited(crateRequestTimes, player.UserId, CRATE_RATE_LIMIT_WINDOW, CRATE_RATE_LIMIT_COUNT) then
		warn(`[EventRemotes] Crate open rate limit exceeded for user {player.UserId}`)
		return
	end

	if EventManager.IsEventCrate(crateId) then
		EventManager.ClaimEventCrate(player, crateId)
	else
		CrateManager.ClaimCrate(player, crateId)
	end
end)

eventStationPurchaseRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local monsterName = payload.monsterName
	if typeof(monsterName) ~= "string" then
		return
	end

	if isRateLimited(stationRequestTimes, player.UserId, STATION_RATE_LIMIT_WINDOW, STATION_RATE_LIMIT_COUNT) then
		warn(`[EventRemotes] Event Station purchase rate limit exceeded for user {player.UserId}`)
		return
	end

	local success = EventStation.PurchaseEventMonster(player, monsterName)
	if success then
		-- Nothing else pushes the eventTokens deduction (or the new warehouse
		-- monster count -- WarehouseManager.AddMonster already handles that part
		-- via UPDATE_WAREHOUSE) to the client on its own, so re-sync the full
		-- snapshot the same way MonetizationManager does after granting something.
		local data = PlayerManager.GetData(player.UserId)
		if data then
			playerDataLoadedRemote:FireClient(player, data)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	shardRequestTimes[player.UserId] = nil
	crateRequestTimes[player.UserId] = nil
	stationRequestTimes[player.UserId] = nil
end)
