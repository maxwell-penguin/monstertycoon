local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local boostWarningRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_WARNING) :: RemoteEvent
local boostStartedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_STARTED) :: RemoteEvent
local boostEndedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_ENDED) :: RemoteEvent

-- Pure state publisher, mirroring CoinDisplay/WarehouseClient/BagClient. Phase 14's
-- UIManager owns all boost visuals (HUD + warning banner) by polling these tables;
-- this script used to render them itself, but that predates UIManager and would now
-- double up with it.
shared.BoostWarning = {
	isActive = false,
	emotion = "",
	multiplier = 1,
	endTime = 0,
}

shared.BoostClient = {
	isActive = false,
	emotion = "",
	emotions = nil,
	multiplier = 1,
	endTime = 0,
}

boostWarningRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	shared.BoostWarning = {
		isActive = true,
		emotion = payload.nextEmotion,
		multiplier = payload.nextMultiplier,
		endTime = os.time() + (payload.warningDuration or 60),
	}
end)

boostStartedRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	shared.BoostWarning = {
		isActive = false,
		emotion = "",
		multiplier = 1,
		endTime = 0,
	}

	shared.BoostClient = {
		isActive = true,
		emotion = payload.emotion,
		emotions = payload.emotions,
		multiplier = payload.multiplier,
		endTime = os.time() + (payload.durationSeconds or 0),
	}
end)

boostEndedRemote.OnClientEvent:Connect(function()
	shared.BoostClient = {
		isActive = false,
		emotion = "",
		emotions = nil,
		multiplier = 1,
		endTime = 0,
	}
end)
