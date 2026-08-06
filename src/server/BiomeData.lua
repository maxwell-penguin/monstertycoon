-- Biome unlock economy data -- shared by BiomeRemotes.server.lua so the
-- unlock cost/element list lives in one place.
local BiomeData = {}

BiomeData.BIOMES = {
	Forest = { elements = { "Nature", "Poison" }, unlockCost = 0, center = Vector3.new(0, 0, 0), radius = 100 },
	Volcano = { elements = { "Fire", "Magma" }, unlockCost = 500000, center = Vector3.new(-90, 0, -90), radius = 40 },
	Waterfall = { elements = { "Water", "Ice" }, unlockCost = 50000, center = Vector3.new(80, 0, -80), radius = 40 },
	Pond = { elements = { "Void", "Galaxy" }, unlockCost = 2000000, center = Vector3.new(0, 0, -70), radius = 35 },
}

function BiomeData.GetBiomeForElement(element: string): string?
	for biomeName, biome in BiomeData.BIOMES do
		if table.find(biome.elements, element) then
			return biomeName
		end
	end
	return nil
end

-- Horizontal-only (X/Z) distance check -- a biome's roam area is a ground
-- footprint, not a sphere, so a monster/vial's height above terrain shouldn't
-- push it "outside" its own biome.
function BiomeData.IsInBiome(position: Vector3, biomeName: string): boolean
	local biome = BiomeData.BIOMES[biomeName]
	if not biome then
		return false
	end
	local dx = position.X - biome.center.X
	local dz = position.Z - biome.center.Z
	return (dx * dx + dz * dz) <= (biome.radius * biome.radius)
end

return BiomeData
