local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local DropboxManager = require(script.Parent.DropboxManager)
local RateLimiter = require(script.Parent.RateLimiter)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local depositBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.DEPOSIT_BAG) :: RemoteEvent

local depositLimiter = RateLimiter.CreateLimiter(1, 2)

depositBagRemote.OnServerEvent:Connect(function(player: Player)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if not depositLimiter:Check(userId) then
		warn(`[DropboxRemotes] Rate limit exceeded for user {userId}`)
		return
	end

	DropboxManager.ProcessDeposit(player)
end)
