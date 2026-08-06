-- Shared by PlotSetup.server.lua (world building) and BiomeManager.lua (unlock
-- logic) so biome geometry and unlock rules can never drift out of sync.
local BiomeData = {}

BiomeData.FARM_SIZE = 200
BiomeData.FARM_CENTER = Vector3.new(0, 0, 0)
BiomeData.GROUND_Y = 0

BiomeData.BIOMES = {
	Forest = {
		center = Vector3.new(0, 0, 0), -- forest surrounds everything
		radius = 100, -- whole map
		groundColor = Color3.fromRGB(40, 80, 30),
		groundMaterial = Enum.Material.Grass,
		emotions = { "Sadness", "Void" },
		unlockCost = 0,
	},
	Volcano = {
		center = Vector3.new(-80, 0, -80),
		radius = 40,
		groundColor = Color3.fromRGB(80, 40, 20),
		groundMaterial = Enum.Material.Basalt,
		emotions = { "Rage" },
		unlockCost = 500000,
	},
	Waterfall = {
		center = Vector3.new(80, 0, -80),
		radius = 40,
		groundColor = Color3.fromRGB(60, 100, 80),
		groundMaterial = Enum.Material.Grass,
		emotions = { "Joy", "Nostalgia" },
		unlockCost = 50000,
	},
	Pond = {
		center = Vector3.new(0, 0, -70),
		radius = 35,
		groundColor = Color3.fromRGB(40, 60, 80),
		groundMaterial = Enum.Material.Mud,
		emotions = { "Dread" },
		unlockCost = 2000000,
	},
}

return BiomeData
