local DataStoreService = game:GetService("DataStoreService")

local MAX_LOG_ENTRIES = 500
local SAVE_ENTRY_COUNT = 50

local violationLogStore = DataStoreService:GetDataStore("ViolationLog")

local AntiCheatLog = {}

-- Kept in chronological order (oldest first) and capped at MAX_LOG_ENTRIES by
-- dropping the oldest entry -- same fixed-size, oldest-evicted behavior as a
-- circular buffer, without needing a separate wraparound write-index to keep
-- "the last 50" queryable in order.
local log: { any } = {}

function AntiCheatLog.LogViolation(userId: number, playerName: string, violation: string, strikeCount: number)
	table.insert(log, {
		timestamp = os.time(),
		userId = userId,
		playerName = playerName,
		violation = violation,
		strikeCount = strikeCount,
	})

	if #log > MAX_LOG_ENTRIES then
		table.remove(log, 1)
	end
end

function AntiCheatLog.GetLog(): { any }
	return log
end

game:BindToClose(function()
	local startIndex = math.max(#log - SAVE_ENTRY_COUNT + 1, 1)
	local recent = {}
	for i = startIndex, #log do
		table.insert(recent, log[i])
	end

	if #recent == 0 then
		return
	end

	local serverId = game.JobId ~= "" and game.JobId or "studio"

	pcall(function()
		violationLogStore:SetAsync("ViolationLog_" .. serverId, recent)
	end)
end)

return AntiCheatLog
