-- Biome unlock economy data -- shared by BiomeRemotes.server.lua so the
-- unlock cost/emotion list lives in one place.
local BiomeData = {}

BiomeData.BIOMES = {
	Forest = { emotions = { "Sadness", "Void" }, unlockCost = 0 },
	Volcano = { emotions = { "Rage" }, unlockCost = 500000 },
	Waterfall = { emotions = { "Joy", "Nostalgia" }, unlockCost = 50000 },
	Pond = { emotions = { "Dread" }, unlockCost = 2000000 },
}

return BiomeData
