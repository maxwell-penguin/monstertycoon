local LeaderboardManager = require(script.Parent.LeaderboardManager)

local UPDATE_INTERVAL = 10
local INITIAL_DELAY = 3

-- Delayed so players have actually loaded (PlayerManager data populated)
-- before the first snapshot; the recurring loop starts from that same point.
task.delay(INITIAL_DELAY, function()
	LeaderboardManager.UpdateLeaderboard()

	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL)
			LeaderboardManager.UpdateLeaderboard()
		end
	end)
end)
