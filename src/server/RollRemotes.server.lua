local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local RollManager = require(script.Parent.RollManager)
local CrateManager = require(script.Parent.CrateManager)

local ROLL_RATE_LIMIT_WINDOW = 1
local CRATE_RATE_LIMIT_WINDOW = 1
local CRATE_RATE_LIMIT_COUNT = 5

local VALID_BATCH_COUNTS = { [1] = true, [5] = true, [10] = true }
local GUID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local rollEggRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.ROLL_EGG) :: RemoteEvent
local openCrateRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.OPEN_CRATE) :: RemoteEvent

local lastRollTime: { [number]: number } = {}
local crateRequestTimes: { [number]: { number } } = {}

local function isValidGuid(value: any): boolean
	return typeof(value) == "string" and value:match(GUID_PATTERN) ~= nil
end

local function isCrateRateLimited(userId: number): boolean
	local now = os.clock()
	local times = crateRequestTimes[userId]
	if not times then
		times = {}
		crateRequestTimes[userId] = times
	end

	local i = 1
	while i <= #times do
		if now - times[i] >= CRATE_RATE_LIMIT_WINDOW then
			table.remove(times, i)
		else
			i += 1
		end
	end

	if #times >= CRATE_RATE_LIMIT_COUNT then
		return true
	end

	table.insert(times, now)
	return false
end

rollEggRemote.OnServerEvent:Connect(function(player: Player, count: any)
	if typeof(count) ~= "number" or not VALID_BATCH_COUNTS[count] then
		return
	end

	local userId = player.UserId
	local now = os.clock()
	local last = lastRollTime[userId]
	if last and (now - last) < ROLL_RATE_LIMIT_WINDOW then
		warn(`[RollRemotes] Roll rate limit exceeded for user {userId}`)
		return
	end
	lastRollTime[userId] = now

	RollManager.PerformBatchRoll(player, count)
end)

openCrateRemote.OnServerEvent:Connect(function(player: Player, crateId: any)
	if not isValidGuid(crateId) then
		return
	end

	if isCrateRateLimited(player.UserId) then
		warn(`[RollRemotes] Crate open rate limit exceeded for user {player.UserId}`)
		return
	end

	CrateManager.ClaimCrate(player, crateId)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastRollTime[player.UserId] = nil
	crateRequestTimes[player.UserId] = nil
end)
