local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local RollManager = require(script.Parent.RollManager)
local RateLimiter = require(script.Parent.RateLimiter)

local VALID_BATCH_COUNTS = { [1] = true, [5] = true, [10] = true }

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local rollEggRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.ROLL_EGG) :: RemoteEvent

local rollLimiter = RateLimiter.CreateLimiter(1, 1)

rollEggRemote.OnServerEvent:Connect(function(player: Player, count: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if typeof(count) ~= "number" or not VALID_BATCH_COUNTS[count] then
		return
	end

	if not rollLimiter:Check(userId) then
		warn(`[RollRemotes] Roll rate limit exceeded for user {userId}`)
		return
	end

	RollManager.PerformBatchRoll(player, count)
end)
