local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local RollManager = require(script.Parent.RollManager)

local ROLL_RATE_LIMIT_WINDOW = 1

local VALID_BATCH_COUNTS = { [1] = true, [5] = true, [10] = true }

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local rollEggRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.ROLL_EGG) :: RemoteEvent

local lastRollTime: { [number]: number } = {}

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

Players.PlayerRemoving:Connect(function(player: Player)
	lastRollTime[player.UserId] = nil
end)
