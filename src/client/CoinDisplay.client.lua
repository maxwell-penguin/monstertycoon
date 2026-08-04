local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local NumberFormatter = require(ReplicatedStorage.NumberFormatter)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateCoinsRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_COINS) :: RemoteEvent
local updateEarnRateRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_EARN_RATE) :: RemoteEvent

local TICK_INTERVAL = 0.1
local DRIFT_THRESHOLD = 0.1

local actualCoins = 0
local displayCoins = 0
local earnRate = 0

local function publish()
	shared.CoinDisplay = {
		displayCoins = displayCoins,
		earnRate = earnRate,
		formatted = NumberFormatter.Format(displayCoins),
	}
end

publish()

updateCoinsRemote.OnClientEvent:Connect(function(newCoins: number)
	actualCoins = newCoins

	local drift = math.abs(displayCoins - actualCoins)
	if drift > actualCoins * DRIFT_THRESHOLD then
		displayCoins = actualCoins
	end

	publish()
end)

updateEarnRateRemote.OnClientEvent:Connect(function(newEarnRate: number)
	earnRate = newEarnRate
	publish()
end)

while true do
	task.wait(TICK_INTERVAL)
	displayCoins = math.min(displayCoins + earnRate * TICK_INTERVAL, actualCoins)
	publish()
end
