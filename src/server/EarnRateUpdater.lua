local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent.Economy)
local PlayerManager = require(script.Parent.PlayerManager)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local UPDATE_INTERVAL = 1
local DEFAULT_INCOME_MULTIPLIER = 1

local EarnRateUpdater = {}

local activeLoops: { [number]: boolean } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateEarnRateRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_EARN_RATE) :: RemoteEvent

function EarnRateUpdater.StartUpdating(player: Player)
	local userId = player.UserId

	if activeLoops[userId] then
		return
	end
	activeLoops[userId] = true

	local removingConnection: RBXScriptConnection
	removingConnection = Players.PlayerRemoving:Connect(function(leftPlayer: Player)
		if leftPlayer.UserId == userId then
			activeLoops[userId] = nil
		end
	end)

	task.spawn(function()
		while activeLoops[userId] do
			local data = PlayerManager.GetData(userId)
			if data then
				local earnRate = Economy.GetEarnRate(data.monsterSlots, DEFAULT_INCOME_MULTIPLIER)
				updateEarnRateRemote:FireClient(player, earnRate)
			end
			task.wait(UPDATE_INTERVAL)
		end
		removingConnection:Disconnect()
	end)
end

return EarnRateUpdater
