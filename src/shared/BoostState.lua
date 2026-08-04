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

-- Server-wide multiplier from ServerBoost developer products, independent of
-- emotion boosts. A token guards against a second purchase's reset-to-1.0 firing
-- early and clobbering a still-active first purchase's window.
local serverMultiplier = 1.0
local serverMultiplierToken = 0

function BoostState.GetCurrentBoost(): Types.BoostState
	return currentBoost
end

-- Includes serverMultiplier so any caller (Economy, VialProducer's visual read)
-- gets the true effective multiplier from a single call.
function BoostState.GetMultiplierForEmotion(emotion: string): number
	local base = 1

	if currentBoost.isActive then
		if currentBoost.emotion == "All" then
			base = currentBoost.multiplier
		elseif currentBoost.emotions then
			base = table.find(currentBoost.emotions, emotion) and currentBoost.multiplier or 1
		elseif currentBoost.emotion == emotion then
			base = currentBoost.multiplier
		end
	end

	return base * serverMultiplier
end

function BoostState.GetServerMultiplier(): number
	return serverMultiplier
end

-- Server-only: called exclusively by MonetizationManager (ServerBoost product).
function BoostState.SetServerMultiplier(multiplier: number, durationSeconds: number)
	serverMultiplierToken += 1
	local token = serverMultiplierToken

	serverMultiplier = multiplier

	task.delay(durationSeconds, function()
		if token == serverMultiplierToken then
			serverMultiplier = 1.0
		end
	end)
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

export type PersonalBoost = {
	emotion: string,
	multiplier: number,
	endTime: number,
}

-- Per-player boosts (e.g. FTUE's first-login Joy surge). Calling the shared
-- SetBoost above for a "personal" boost would incorrectly overwrite the
-- server-wide boost for every player; this is the actual per-player override.
local personalBoosts: { [number]: PersonalBoost } = {}

-- Server-only: called exclusively by FTUEManager.server.lua (or similar
-- single-player reward sources). Never call this for anything meant to be visible
-- to other players -- use SetBoost for that.
function BoostState.SetPersonalBoost(userId: number, emotion: string, multiplier: number, durationSeconds: number)
	personalBoosts[userId] = {
		emotion = emotion,
		multiplier = multiplier,
		endTime = os.time() + durationSeconds,
	}
end

-- Returns nil once expired (lazily clears the entry) or if none was ever set.
function BoostState.GetPersonalBoost(userId: number): PersonalBoost?
	local boost = personalBoosts[userId]
	if not boost then
		return nil
	end

	if os.time() >= boost.endTime then
		personalBoosts[userId] = nil
		return nil
	end

	return boost
end

-- Server-only: called on PlayerRemoving to avoid leaking an entry per player who
-- ever received a personal boost during this server's uptime.
function BoostState.ClearPersonalBoost(userId: number)
	personalBoosts[userId] = nil
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
