local Types = require(script.Parent.Types)

local BoostState = {}

local currentBoost: Types.BoostState = {
	emotion = "",
	emotions = nil,
	multiplier = 1,
	startTime = 0,
	endTime = 0,
	isActive = false,
}

-- Only meaningful during a Mystery Surge. Never exposed via GetCurrentBoost,
-- only through the server-only GetRealEmotion below.
local realEmotion: string? = nil

function BoostState.GetCurrentBoost(): Types.BoostState
	return currentBoost
end

function BoostState.GetMultiplierForEmotion(emotion: string): number
	if not currentBoost.isActive then
		return 1
	end

	if currentBoost.emotion == "All" then
		return currentBoost.multiplier
	end

	if currentBoost.emotions then
		if table.find(currentBoost.emotions, emotion) then
			return currentBoost.multiplier
		end
		return 1
	end

	if currentBoost.emotion == emotion then
		return currentBoost.multiplier
	end

	return 1
end

-- Server-only: reveals the true boosted emotion during a Mystery Surge.
-- This module is shared (ReplicatedStorage), so a client CAN require it, but each
-- environment (server, each client) runs its own independent copy of this state --
-- a client calling this only ever sees its own local realEmotion (always nil, since
-- only the server ever calls SetBoost), never the server's actual value. Only
-- BoostRotation.server.lua and Economy.lua (both server-side) should call this.
function BoostState.GetRealEmotion(): string?
	return realEmotion
end

-- Server-only: called exclusively by BoostRotation.server.lua. See GetRealEmotion
-- comment above for why no further enforcement is needed.
function BoostState.SetBoost(
	emotion: string,
	multiplier: number,
	durationSeconds: number,
	emotions: { string }?,
	hiddenEmotion: string?
)
	currentBoost.emotion = emotion
	currentBoost.emotions = emotions
	currentBoost.multiplier = multiplier
	currentBoost.startTime = os.time()
	currentBoost.endTime = os.time() + durationSeconds
	currentBoost.isActive = true
	realEmotion = hiddenEmotion
end

-- Server-only: called exclusively by BoostRotation.server.lua.
function BoostState.ClearBoost()
	currentBoost.isActive = false
	currentBoost.emotion = ""
	currentBoost.emotions = nil
	currentBoost.multiplier = 1
	currentBoost.endTime = 0
	realEmotion = nil
end

function BoostState.GetTimeRemaining(): number
	if not currentBoost.isActive then
		return 0
	end
	return math.max(currentBoost.endTime - os.time(), 0)
end

function BoostState.IsExpired(): boolean
	if not currentBoost.isActive then
		return false
	end
	return os.time() >= currentBoost.endTime
end

return BoostState
