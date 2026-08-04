local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local MergeManager = require(script.Parent.MergeManager)

local INSTANCE_ID_LENGTH = 8
local MERGE_RATE_LIMIT_WINDOW = 1
local MERGE_RATE_LIMIT_COUNT = 3
local AUTO_MERGE_RATE_LIMIT_WINDOW = 5

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local mergeMonstersRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.MERGE_MONSTERS) :: RemoteEvent

local mergeRequestTimes: { [number]: { number } } = {}
local lastAutoMerge: { [number]: number } = {}

local function isValidInstanceId(instanceId: any): boolean
	return typeof(instanceId) == "string" and #instanceId == INSTANCE_ID_LENGTH and instanceId:match("^%w+$") ~= nil
end

local function isMergeRateLimited(userId: number): boolean
	local now = os.clock()
	local times = mergeRequestTimes[userId]
	if not times then
		times = {}
		mergeRequestTimes[userId] = times
	end

	local i = 1
	while i <= #times do
		if now - times[i] >= MERGE_RATE_LIMIT_WINDOW then
			table.remove(times, i)
		else
			i += 1
		end
	end

	if #times >= MERGE_RATE_LIMIT_COUNT then
		return true
	end

	table.insert(times, now)
	return false
end

local function isAutoMergeRateLimited(userId: number): boolean
	local now = os.clock()
	local last = lastAutoMerge[userId]
	if last and (now - last) < AUTO_MERGE_RATE_LIMIT_WINDOW then
		return true
	end

	lastAutoMerge[userId] = now
	return false
end

mergeMonstersRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local userId = player.UserId

	if payload.autoMerge == true then
		if isAutoMergeRateLimited(userId) then
			warn(`[MergeRemotes] Auto-merge rate limit exceeded for user {userId}`)
			return
		end

		MergeManager.AutoMerge(player)
		return
	end

	if isMergeRateLimited(userId) then
		warn(`[MergeRemotes] Merge rate limit exceeded for user {userId}`)
		return
	end

	local instanceIds = payload.instanceIds
	if typeof(instanceIds) ~= "table" or #instanceIds ~= 3 then
		return
	end

	for _, instanceId in instanceIds do
		if not isValidInstanceId(instanceId) then
			return
		end
	end

	MergeManager.ExecuteMerge(player, instanceIds)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	mergeRequestTimes[player.UserId] = nil
	lastAutoMerge[player.UserId] = nil
end)
