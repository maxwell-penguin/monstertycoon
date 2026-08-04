local AntiCheat = require(script.Parent.AntiCheat)
require(script.Parent.RateLimiter)

-- CheckBan is NOT wired here via its own Players.PlayerAdded connection. Two
-- independent scripts each connecting PlayerAdded gives no guarantee about which
-- fires first, which is exactly the ordering problem "before DataStore setup"
-- needs to avoid. Instead, DataStore.server.lua calls AntiCheat.CheckBan(player)
-- directly as the first line of its own onPlayerAdded -- a plain module function
-- call, not a second listener, so there's no ordering race to coordinate at all.

AntiCheat.InitAntiCheat()

print("[AntiCheatSetup] Anti-cheat initialized")
