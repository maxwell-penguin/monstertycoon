local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BoostState = require(ReplicatedStorage.BoostState)
local PlayerManager = require(script.Parent.PlayerManager)
local PlotManager = require(script.Parent.PlotManager)
local RollManager = require(script.Parent.RollManager)
local CrateManager = require(script.Parent.CrateManager)

local EVENT_INTERVAL = 600
local EVENT_WEIGHTS = {
	{ name = "CrateRace", weight = 0.50 },
	{ name = "ShardHunt", weight = 0.35 },
	{ name = "VoidStorm", weight = 0.15 },
}

local CRATE_RACE_DURATION = 60
local CRATE_RACE_CLAIM_RADIUS = 15
local CRATE_RACE_NEUTRAL_POSITION = Vector3.new(0, 5, 0)
local CRATE_RACE_SPAWN_HEIGHT = Vector3.new(0, 20, 0)

local SHARD_HUNT_DURATION = 120
local SHARD_COUNT = 20
local SHARD_CLAIM_RADIUS = 8
local SHARD_GROUND_Y = 3
local NEUTRAL_ZONE_RADIUS = 30
local SHARD_PLOT_EDGE_MARGIN = 5
local SHARD_FULL_TOKEN_THRESHOLD = 10
local SHARD_HALF_TOKEN_THRESHOLD = 5

local VOID_STORM_DURATION = 180
local VOID_STORM_MULTIPLIER = 3.0

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local worldEventStartRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.WORLD_EVENT_START) :: RemoteEvent
local worldEventEndRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.WORLD_EVENT_END) :: RemoteEvent
local worldEventCountdownRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.WORLD_EVENT_COUNTDOWN) :: RemoteEvent
local crateSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.CRATE_SPAWNED) :: RemoteEvent
local shardSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SHARD_SPAWNED) :: RemoteEvent
local shardCollectedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SHARD_COLLECTED) :: RemoteEvent
local sessionRewardRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SESSION_REWARD) :: RemoteEvent

export type EventCrate = {
	crateId: string,
	position: Vector3,
	claimed: boolean,
	eventType: string,
}

export type Shard = {
	shardId: string,
	position: Vector3,
	claimed: boolean,
}

local EventManager = {}

local isEventRunning = false
local eventCrate: EventCrate? = nil
local crateRaceToken = 0

local activeShards: { [string]: Shard } = {}
local shardHuntCounts: { [number]: number } = {}

local serverLuckExpiry = 0

local function broadcastAll(remote: RemoteEvent, payload: any)
	for _, player in Players:GetPlayers() do
		remote:FireClient(player, payload)
	end
end

local function rollEventType(): string
	local roll = math.random()
	local cumulative = 0

	for _, entry in EVENT_WEIGHTS do
		cumulative += entry.weight
		if roll <= cumulative then
			return entry.name
		end
	end

	return EVENT_WEIGHTS[#EVENT_WEIGHTS].name
end

--============================================================
-- Server-wide luck (GlobalBoostMilestone "luck" reward)
--============================================================

function EventManager.GrantServerLuck(duration: number)
	serverLuckExpiry = os.time() + duration
end

function EventManager.IsServerLuckActive(): boolean
	return os.time() < serverLuckExpiry
end

--============================================================
-- Crate Race
--============================================================

function EventManager.IsEventCrate(crateId: string): boolean
	return eventCrate ~= nil and eventCrate.crateId == crateId
end

local function endCrateRace(winnerId: number?, winnerName: string?)
	crateRaceToken += 1

	-- Captured before clearing: RollManager.PerformPremiumRoll's EGG_RESULT fire
	-- (triggered by a win) doesn't carry isCrate/crateId, and only reaches the
	-- winner anyway -- broadcasting crateId here is what lets every player's
	-- client (winner and everyone who didn't claim it) actually remove the crate
	-- visual, instead of it being left behind forever.
	local crateId = eventCrate and eventCrate.crateId
	eventCrate = nil

	broadcastAll(worldEventEndRemote, { eventType = "CrateRace", winnerId = winnerId, winnerName = winnerName, crateId = crateId })

	isEventRunning = false
end

function EventManager.StartCrateRace()
	if isEventRunning then
		return
	end
	isEventRunning = true

	crateRaceToken += 1
	local token = crateRaceToken

	broadcastAll(worldEventStartRemote, { eventType = "CrateRace", duration = CRATE_RACE_DURATION })

	local crateId = HttpService:GenerateGUID(false)
	eventCrate = {
		crateId = crateId,
		position = CRATE_RACE_NEUTRAL_POSITION,
		claimed = false,
		eventType = "CrateRace",
	}

	for _, player in Players:GetPlayers() do
		crateSpawnedRemote:FireClient(player, crateId, CRATE_RACE_SPAWN_HEIGHT, CRATE_RACE_NEUTRAL_POSITION)
	end

	task.delay(CRATE_RACE_DURATION, function()
		if crateRaceToken ~= token then
			return
		end
		endCrateRace(nil, nil)
	end)
end

-- Called by EventRemotes.server.lua when an incoming OPEN_CRATE's crateId matches
-- the active event crate rather than a personal CrateManager crate.
function EventManager.ClaimEventCrate(player: Player, crateId: string): (boolean, string)
	if not eventCrate or eventCrate.crateId ~= crateId or eventCrate.claimed then
		return false, "not_found"
	end

	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if not rootPart then
		return false, "out_of_range"
	end

	local distance = (rootPart.Position - eventCrate.position).Magnitude
	if distance > CRATE_RACE_CLAIM_RADIUS then
		return false, "out_of_range"
	end

	eventCrate.claimed = true

	RollManager.PerformPremiumRoll(player, "Epic", true)

	endCrateRace(player.UserId, player.Name)

	return true, ""
end

--============================================================
-- Shard Hunt
--============================================================

local function randomPositionInPlot(player: Player): Vector3?
	local origin = PlotManager.GetPlotOrigin(player)
	if not origin then
		return nil
	end

	local data = PlayerManager.GetData(player.UserId)
	local environmentTier = (data and data.environmentTier) or 1
	local plotSize = Constants.PLOT_SIZES[environmentTier] or Constants.PLOT_SIZES[1]

	local offsetX = (math.random() * 2 - 1) * (plotSize.width / 2 - SHARD_PLOT_EDGE_MARGIN)
	local offsetZ = (math.random() * 2 - 1) * (plotSize.depth / 2 - SHARD_PLOT_EDGE_MARGIN)

	local originPosition = origin.Position
	return Vector3.new(originPosition.X + offsetX, SHARD_GROUND_Y, originPosition.Z + offsetZ)
end

local function randomPositionInNeutralZone(): Vector3
	local angle = math.random() * math.pi * 2
	local radius = math.random() * NEUTRAL_ZONE_RADIUS
	return Vector3.new(math.cos(angle) * radius, SHARD_GROUND_Y, math.sin(angle) * radius)
end

local function grantShardHuntRewards()
	local results: { [number]: number } = {}

	for _, player in Players:GetPlayers() do
		local count = shardHuntCounts[player.UserId] or 0
		results[player.UserId] = count

		local tokensEarned = 0
		if count >= SHARD_FULL_TOKEN_THRESHOLD then
			tokensEarned = 1
		elseif count >= SHARD_HALF_TOKEN_THRESHOLD then
			tokensEarned = 0.5
		end

		if tokensEarned > 0 then
			local userId = player.UserId
			local data = PlayerManager.GetData(userId)
			local currentTokens = (data and data.eventTokens) or 0
			PlayerManager.SetData(userId, "eventTokens", currentTokens + tokensEarned)

			sessionRewardRemote:FireClient(player, { type = "eventTokens", amount = tokensEarned })
		end
	end

	return results
end

local function endShardHunt()
	local results = grantShardHuntRewards()

	activeShards = {}
	shardHuntCounts = {}

	broadcastAll(worldEventEndRemote, { eventType = "ShardHunt", results = results })

	isEventRunning = false
end

function EventManager.StartShardHunt()
	if isEventRunning then
		return
	end
	isEventRunning = true

	broadcastAll(worldEventStartRemote, { eventType = "ShardHunt", duration = SHARD_HUNT_DURATION })

	activeShards = {}
	shardHuntCounts = {}

	local players = Players:GetPlayers()

	for _ = 1, SHARD_COUNT do
		local position: Vector3
		if #players > 0 then
			local player = players[math.random(1, #players)]
			position = randomPositionInPlot(player) or randomPositionInNeutralZone()
		else
			position = randomPositionInNeutralZone()
		end

		local shardId = HttpService:GenerateGUID(false)
		activeShards[shardId] = { shardId = shardId, position = position, claimed = false }

		for _, player in Players:GetPlayers() do
			shardSpawnedRemote:FireClient(player, shardId, position)
		end
	end

	task.delay(SHARD_HUNT_DURATION, endShardHunt)
end

-- Called by EventRemotes.server.lua after payload/rate-limit validation.
function EventManager.ClaimShard(player: Player, shardId: string): (boolean, string)
	local shard = activeShards[shardId]
	if not shard or shard.claimed then
		return false, "not_found"
	end

	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if not rootPart then
		return false, "out_of_range"
	end

	local distance = (rootPart.Position - shard.position).Magnitude
	if distance > SHARD_CLAIM_RADIUS then
		return false, "out_of_range"
	end

	shard.claimed = true

	local userId = player.UserId
	shardHuntCounts[userId] = (shardHuntCounts[userId] or 0) + 1

	broadcastAll(shardCollectedRemote, shardId)

	return true, ""
end

--============================================================
-- Void Storm (world event; distinct from BoostRotation's special boost of the
-- same name)
--============================================================

function EventManager.StartVoidStorm()
	if isEventRunning then
		return
	end
	isEventRunning = true

	broadcastAll(worldEventStartRemote, { eventType = "VoidStorm", duration = VOID_STORM_DURATION })

	BoostState.SetServerMultiplier(VOID_STORM_MULTIPLIER, VOID_STORM_DURATION)

	for _, player in Players:GetPlayers() do
		CrateManager.SpawnCrate(player)
	end

	task.delay(VOID_STORM_DURATION, function()
		broadcastAll(worldEventEndRemote, { eventType = "VoidStorm" })
		isEventRunning = false
	end)
end

--============================================================
-- Schedule
--============================================================

function EventManager.InitEvents()
	task.spawn(function()
		local nextEventTime = os.time() + EVENT_INTERVAL

		while true do
			task.wait(60)

			local secondsUntilNext = math.max(nextEventTime - os.time(), 0)
			broadcastAll(worldEventCountdownRemote, secondsUntilNext)

			if os.time() >= nextEventTime then
				nextEventTime = os.time() + EVENT_INTERVAL

				if not isEventRunning then
					local eventType = rollEventType()
					if eventType == "CrateRace" then
						task.spawn(EventManager.StartCrateRace)
					elseif eventType == "ShardHunt" then
						task.spawn(EventManager.StartShardHunt)
					else
						task.spawn(EventManager.StartVoidStorm)
					end
				end
			end
		end
	end)
end

return EventManager
