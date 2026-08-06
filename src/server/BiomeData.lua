-- Shared by PlotSetup.server.lua (world building) and BiomeManager.lua (unlock
-- logic) so biome geometry and unlock rules can never drift out of sync.
local BiomeData = {}

BiomeData.FARM_SIZE = 200
BiomeData.FARM_CENTER = Vector3.new(0, 0, 0)
BiomeData.GROUND_Y = 0

BiomeData.BIOMES = {
	Forest = {
		center = Vector3.new(-60, 0, 20),
		radius = 55,
		groundColor = Color3.fromRGB(80, 120, 60),
		groundMaterial = Enum.Material.Grass,
		emotions = { "Sadness", "Void" },
		unlockCost = 0,
	},
	Waterfall = {
		center = Vector3.new(60, 0, -20),
		radius = 45,
		groundColor = Color3.fromRGB(60, 100, 80),
		groundMaterial = Enum.Material.Grass,
		emotions = { "Joy", "Nostalgia" },
		unlockCost = 50000,
	},
	Volcano = {
		center = Vector3.new(0, 0, -70),
		radius = 45,
		groundColor = Color3.fromRGB(80, 40, 20),
		groundMaterial = Enum.Material.Basalt,
		emotions = { "Rage" },
		unlockCost = 500000,
	},
	Pond = {
		center = Vector3.new(20, 0, 60),
		radius = 40,
		groundColor = Color3.fromRGB(40, 60, 80),
		groundMaterial = Enum.Material.Mud,
		emotions = { "Dread" },
		unlockCost = 2000000,
	},
}

return BiomeData
