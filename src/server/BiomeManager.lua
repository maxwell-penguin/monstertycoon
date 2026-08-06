local PlayerManager = require(script.Parent.PlayerManager)

local BiomeManager = {}

function BiomeManager.GetUnlockedBiomes(player: Player): { string }
	local data = PlayerManager.GetData(player.UserId)
	if not data or not data.unlockedBiomes or #data.unlockedBiomes == 0 then
		return { "Forest" }
	end
	return data.unlockedBiomes
end

return BiomeManager
