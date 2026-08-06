local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BiomeManager = require(script.Parent.BiomeManager)

local RATE_LIMIT_SECONDS = 5

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local unlockBiomeRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UNLOCK_BIOME) :: RemoteEvent

local lastUnlockAttempt: { [number]: number } = {}

unlockBiomeRemote.OnServerEvent:Connect(function(player: Player, biomeName: any)
	if typeof(biomeName) ~= "string" then
		return
	end

	local userId = player.UserId
	local now = os.clock()
	local last = lastUnlockAttempt[userId]
	if last and (now - last) < RATE_LIMIT_SECONDS then
		return
	end
	lastUnlockAttempt[userId] = now

	BiomeManager.UnlockBiome(player, biomeName)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastUnlockAttempt[player.UserId] = nil
end)
