local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local leaderboardUpdateRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.LEADERBOARD_UPDATE) :: RemoteEvent

local TOP_COUNT = 5

local LeaderboardManager = {}

function LeaderboardManager.UpdateLeaderboard()
	local entries = {}

	for _, userId in PlayerManager.GetLoadedUserIds() do
		local player = Players:GetPlayerByUserId(userId)
		local data = PlayerManager.GetData(userId)
		if player and data then
			table.insert(entries, { playerName = player.Name, coins = data.coins })
		end
	end

	table.sort(entries, function(a, b)
		return a.coins > b.coins
	end)

	local top = {}
	for i = 1, math.min(TOP_COUNT, #entries) do
		top[i] = { rank = i, playerName = entries[i].playerName, coins = entries[i].coins }
	end

	for _, player in Players:GetPlayers() do
		leaderboardUpdateRemote:FireClient(player, top)
	end
end

return LeaderboardManager
