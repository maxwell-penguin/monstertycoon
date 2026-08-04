local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local MergeManager = require(script.Parent.MergeManager)
local RateLimiter = require(script.Parent.RateLimiter)

local INSTANCE_ID_LENGTH = 8

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local mergeMonstersRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.MERGE_MONSTERS) :: RemoteEvent

local mergeLimiter = RateLimiter.CreateLimiter(3, 1)
local autoMergeLimiter = RateLimiter.CreateLimiter(1, 5)

local function isValidInstanceId(instanceId: any): boolean
	return typeof(instanceId) == "string" and #instanceId == INSTANCE_ID_LENGTH and instanceId:match("^%w+$") ~= nil
end

mergeMonstersRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if payload.autoMerge == true then
		if not autoMergeLimiter:Check(userId) then
			warn(`[MergeRemotes] Auto-merge rate limit exceeded for user {userId}`)
			return
		end

		MergeManager.AutoMerge(player)
		return
	end

	if not mergeLimiter:Check(userId) then
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
