local ReplicatedStorage = game:GetService("ReplicatedStorage")

<<<<<<< HEAD
=======
local Constants = require(ReplicatedStorage.Constants)
>>>>>>> dev
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local boostWarningRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_WARNING) :: RemoteEvent
local boostStartedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_STARTED) :: RemoteEvent
local boostEndedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_ENDED) :: RemoteEvent

<<<<<<< HEAD
=======
local VOID_STORM_COLOR = Color3.fromRGB(150, 60, 220)

-- Mirrors the same emotion/"All"/"Mystery"/emotions-array resolution UIManager's
-- polling loop uses for the boost HUD -- duplicated rather than shared since
-- UIManager exposes no function for it, just its own private locals.
local function resolveBoostColor(payload: any): Color3
	if payload.emotions then
		return Constants.EMOTION_COLORS[payload.emotions[1]] or Color3.new(1, 1, 1)
	elseif payload.emotion == "All" then
		return VOID_STORM_COLOR
	elseif payload.emotion == "Mystery" then
		return Color3.fromHSV(os.clock() % 1, 1, 1)
	end
	return Constants.EMOTION_COLORS[payload.emotion] or Color3.new(1, 1, 1)
end

>>>>>>> dev
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
<<<<<<< HEAD
=======

	if shared.SoundManager then
		shared.SoundManager.PlaySound("boost", "warning")
	end
>>>>>>> dev
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
<<<<<<< HEAD
=======

	if shared.SoundManager then
		shared.SoundManager.PlaySound("boost", "start")
	end

	if shared.ScreenEffects then
		shared.ScreenEffects.BoostFlash(resolveBoostColor(payload))
	end
>>>>>>> dev
end)

boostEndedRemote.OnClientEvent:Connect(function()
	shared.BoostClient = {
		isActive = false,
		emotion = "",
		emotions = nil,
		multiplier = 1,
		endTime = 0,
	}
<<<<<<< HEAD
=======

	if shared.SoundManager then
		shared.SoundManager.PlaySound("boost", "end_")
	end
>>>>>>> dev
end)
