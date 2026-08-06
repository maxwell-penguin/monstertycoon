-- Biome unlock economy data -- shared by BiomeRemotes.server.lua so the
-- unlock cost/emotion list lives in one place.
local BiomeData = {}

BiomeData.BIOMES = {
	Forest = { emotions = { "Sadness", "Void" }, unlockCost = 0 },
	Volcano = { emotions = { "Rage" }, unlockCost = 500000 },
	Waterfall = { emotions = { "Joy", "Nostalgia" }, unlockCost = 50000 },
	Pond = { emotions = { "Dread" }, unlockCost = 2000000 },
}

function BiomeData.GetBiomeForEmotion(emotion: string): string?
	for biomeName, biome in BiomeData.BIOMES do
		if table.find(biome.emotions, emotion) then
			return biomeName
		end
	end
	return nil
end

return BiomeData
