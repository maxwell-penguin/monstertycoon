local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local DropboxManager = require(script.Parent.DropboxManager)

local RATE_LIMIT_WINDOW = 2

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local depositBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.DEPOSIT_BAG) :: RemoteEvent

local lastDeposit: { [number]: number } = {}

depositBagRemote.OnServerEvent:Connect(function(player: Player)
	local userId = player.UserId
	local now = os.clock()
	local last = lastDeposit[userId]

	if last and (now - last) < RATE_LIMIT_WINDOW then
		warn(`[DropboxRemotes] Rate limit exceeded for user {userId}`)
		return
	end

	lastDeposit[userId] = now

	DropboxManager.ProcessDeposit(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastDeposit[player.UserId] = nil
end)
