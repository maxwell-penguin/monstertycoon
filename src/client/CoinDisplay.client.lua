local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local NumberFormatter = require(ReplicatedStorage.NumberFormatter)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateCoinsRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_COINS) :: RemoteEvent
local updateEarnRateRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_EARN_RATE) :: RemoteEvent

local TICK_INTERVAL = 0.1
local DRIFT_THRESHOLD = 0.1
local COIN_TICK_SOUND_INTERVAL = 0.5

local actualCoins = 0
local displayCoins = 0
local earnRate = 0

local function getSuffix(formatted: string): string
	return formatted:match("%a+$") or ""
end

-- Seeded from the "0" formatting (no suffix) so the very first publish() doesn't
-- read as a suffix change.
local lastSuffix = getSuffix(NumberFormatter.Format(0))

local function publish()
	local formatted = NumberFormatter.Format(displayCoins)

	local newSuffix = getSuffix(formatted)
	if newSuffix ~= lastSuffix then
		lastSuffix = newSuffix
		if newSuffix ~= "" then
			if shared.SoundManager then
				shared.SoundManager.PlaySound("milestone")
			end
			if shared.ScreenEffects then
				shared.ScreenEffects.SuffixFlash(newSuffix)
			end
		end
	end

	shared.CoinDisplay = {
		displayCoins = displayCoins,
		earnRate = earnRate,
		formatted = formatted,
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

-- Passive-income audio feedback: a soft tick every 0.5s while coins are actively
-- accruing.
task.spawn(function()
	while true do
		task.wait(COIN_TICK_SOUND_INTERVAL)
		if earnRate > 0 and shared.SoundManager then
			shared.SoundManager.PlaySound("coinTick")
		end
	end
end)

while true do
	task.wait(TICK_INTERVAL)
	displayCoins = math.min(displayCoins + earnRate * TICK_INTERVAL, actualCoins)
	publish()
end
