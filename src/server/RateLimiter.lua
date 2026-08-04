local Players = game:GetService("Players")

local CLEANUP_INTERVAL = 60
local MAX_REMOTE_CALLS_PER_SECOND = 30

export type Limiter = {
	Check: (self: Limiter, userId: number) -> boolean,
}

type LimiterState = {
	maxCalls: number,
	windowSeconds: number,
	callTimes: { [number]: { number } },
	lastSeen: { [number]: number },
}

local RateLimiter = {}

local allLimiterStates: { LimiterState } = {}

local function cleanupInactive(state: LimiterState)
	local now = os.clock()
	for userId, lastSeenTime in state.lastSeen do
		if now - lastSeenTime >= CLEANUP_INTERVAL then
			state.callTimes[userId] = nil
			state.lastSeen[userId] = nil
		end
	end
end

-- One shared cleanup loop for every limiter ever created, rather than each
-- limiter spawning its own polling loop.
task.spawn(function()
	while true do
		task.wait(CLEANUP_INTERVAL)
		for _, state in allLimiterStates do
			cleanupInactive(state)
		end
	end
end)

function RateLimiter.CreateLimiter(maxCalls: number, windowSeconds: number): Limiter
	local state: LimiterState = {
		maxCalls = maxCalls,
		windowSeconds = windowSeconds,
		callTimes = {},
		lastSeen = {},
	}
	table.insert(allLimiterStates, state)

	local limiter = {}

	function limiter.Check(_self, userId: number): boolean
		local now = os.clock()
		state.lastSeen[userId] = now

		local times = state.callTimes[userId]
		if not times then
			times = {}
			state.callTimes[userId] = times
		end

		local i = 1
		while i <= #times do
			if now - times[i] >= state.windowSeconds then
				table.remove(times, i)
			else
				i += 1
			end
		end

		if #times >= state.maxCalls then
			return false
		end

		table.insert(times, now)
		return true
	end

	return (limiter :: any) :: Limiter
end

-- Lazy require: AntiCheat doesn't require RateLimiter, so this isn't a true
-- circular dependency, but deferring it still avoids paying for AntiCheat's own
-- (larger) require chain unless a violation actually needs reporting.
local AntiCheat: any = nil

local function getAntiCheat(): any
	if not AntiCheat then
		AntiCheat = require(script.Parent.AntiCheat)
	end
	return AntiCheat
end

local globalCallLimiter = RateLimiter.CreateLimiter(MAX_REMOTE_CALLS_PER_SECOND, 1)

function RateLimiter.TrackRemoteCall(userId: number)
	if not globalCallLimiter:Check(userId) then
		local player = Players:GetPlayerByUserId(userId)
		if player then
			getAntiCheat().RecordViolation(player, `remote_spam: exceeded {MAX_REMOTE_CALLS_PER_SECOND}/sec`)
		end
	end
end

return RateLimiter
