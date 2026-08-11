local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local boostWarningRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_WARNING) :: RemoteEvent
local boostStartedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_STARTED) :: RemoteEvent
local boostEndedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_ENDED) :: RemoteEvent

local VOID_STORM_COLOR = Color3.fromRGB(150, 60, 220)

-- Mirrors the same element/"All"/"Mystery"/elements-array resolution UIManager's
-- polling loop uses for the boost HUD -- duplicated rather than shared since
-- UIManager exposes no function for it, just its own private locals.
local function resolveBoostColor(payload: any): Color3
	if payload.elements then
		return Constants.ELEMENT_COLORS[payload.elements[1]] or Color3.new(1, 1, 1)
	elseif payload.element == "All" then
		return VOID_STORM_COLOR
	elseif payload.element == "Mystery" then
		return Color3.fromHSV(os.clock() % 1, 1, 1)
	end
	return Constants.ELEMENT_COLORS[payload.element] or Color3.new(1, 1, 1)
end

-- Pure state publisher, mirroring CoinDisplay/WarehouseClient/BagClient. Phase 14's
-- UIManager owns all boost visuals (HUD + warning banner) by polling these tables;
-- this script used to render them itself, but that predates UIManager and would now
-- double up with it.
shared.BoostWarning = {
	isActive = false,
	element = "",
	multiplier = 1,
	endTime = 0,
}

shared.BoostClient = {
	isActive = false,
	element = "",
	elements = nil,
	multiplier = 1,
	endTime = 0,
}

boostWarningRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	shared.BoostWarning = {
		isActive = true,
		element = payload.nextElement,
		multiplier = payload.nextMultiplier,
		endTime = os.time() + (payload.warningDuration or 60),
	}

	if shared.SoundManager then
		shared.SoundManager.PlaySound("boost", "warning")
	end
end)

boostStartedRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	shared.BoostWarning = {
		isActive = false,
		element = "",
		multiplier = 1,
		endTime = 0,
	}

	shared.BoostClient = {
		isActive = true,
		element = payload.element,
		elements = payload.elements,
		multiplier = payload.multiplier,
		endTime = os.time() + (payload.durationSeconds or 0),
	}

	if shared.SoundManager then
		shared.SoundManager.PlaySound("boost", "start")
	end

	if shared.ScreenEffects then
		shared.ScreenEffects.BoostFlash(resolveBoostColor(payload))
	end
end)

boostEndedRemote.OnClientEvent:Connect(function()
	shared.BoostClient = {
		isActive = false,
		element = "",
		elements = nil,
		multiplier = 1,
		endTime = 0,
	}

	if shared.SoundManager then
		shared.SoundManager.PlaySound("boost", "end_")
	end
end)
