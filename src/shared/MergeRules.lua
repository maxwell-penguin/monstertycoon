-- Maps monsterName -> what it evolves into when 3 are merged
local MergeRules = {
	-- Fire lineage
	Embret = { evolvesInto = "Fuming", isMaxLevel = false },
	Fuming = { evolvesInto = "Scorchling", isMaxLevel = false },
	Scorchling = { evolvesInto = "Infernix", isMaxLevel = false },
	Infernix = { evolvesInto = "Pyragon", isMaxLevel = false },
	Pyragon = { evolvesInto = "Pyragon", isMaxLevel = true },

	-- Magma lineage
	Slaglet = { evolvesInto = "Molten", isMaxLevel = false },
	Molten = { evolvesInto = "Crustone", isMaxLevel = false },
	Crustone = { evolvesInto = "Lavark", isMaxLevel = false },
	Lavark = { evolvesInto = "Volcron", isMaxLevel = false },
	Volcron = { evolvesInto = "Volcron", isMaxLevel = true },

	-- Water lineage
	Droplet = { evolvesInto = "Rippler", isMaxLevel = false },
	Rippler = { evolvesInto = "Tidalfin", isMaxLevel = false },
	Tidalfin = { evolvesInto = "Deepcrest", isMaxLevel = false },
	Deepcrest = { evolvesInto = "Abyssion", isMaxLevel = false },
	Abyssion = { evolvesInto = "Abyssion", isMaxLevel = true },

	-- Ice lineage
	Frostbit = { evolvesInto = "Chillow", isMaxLevel = false },
	Chillow = { evolvesInto = "Glacite", isMaxLevel = false },
	Glacite = { evolvesInto = "Cryovex", isMaxLevel = false },
	Cryovex = { evolvesInto = "Permafrost", isMaxLevel = false },
	Permafrost = { evolvesInto = "Permafrost", isMaxLevel = true },

	-- Wind lineage
	Breezlet = { evolvesInto = "Gustling", isMaxLevel = false },
	Gustling = { evolvesInto = "Cycloid", isMaxLevel = false },
	Cycloid = { evolvesInto = "Tempestix", isMaxLevel = false },
	Tempestix = { evolvesInto = "Stormwing", isMaxLevel = false },
	Stormwing = { evolvesInto = "Stormwing", isMaxLevel = true },

	-- Thunder lineage
	Sparklet = { evolvesInto = "Voltling", isMaxLevel = false },
	Voltling = { evolvesInto = "Boltfang", isMaxLevel = false },
	Boltfang = { evolvesInto = "Thunderclaw", isMaxLevel = false },
	Thunderclaw = { evolvesInto = "Stormcaller", isMaxLevel = false },
	Stormcaller = { evolvesInto = "Stormcaller", isMaxLevel = true },

	-- Nature lineage
	Sproutlet = { evolvesInto = "Thornling", isMaxLevel = false },
	Thornling = { evolvesInto = "Rootclaw", isMaxLevel = false },
	Rootclaw = { evolvesInto = "Verdantix", isMaxLevel = false },
	Verdantix = { evolvesInto = "Sylvaron", isMaxLevel = false },
	Sylvaron = { evolvesInto = "Sylvaron", isMaxLevel = true },

	-- Poison lineage
	Toxling = { evolvesInto = "Venmoth", isMaxLevel = false },
	Venmoth = { evolvesInto = "Corrosix", isMaxLevel = false },
	Corrosix = { evolvesInto = "Plagewing", isMaxLevel = false },
	Plagewing = { evolvesInto = "Virulox", isMaxLevel = false },
	Virulox = { evolvesInto = "Virulox", isMaxLevel = true },

	-- Void lineage
	Mote = { evolvesInto = "Nullling", isMaxLevel = false },
	Nullling = { evolvesInto = "Riftshade", isMaxLevel = false },
	Riftshade = { evolvesInto = "Sundervex", isMaxLevel = false },
	Sundervex = { evolvesInto = "Voidborn", isMaxLevel = false },
	Voidborn = { evolvesInto = "Voidborn", isMaxLevel = true },

	-- Galaxy lineage
	Stardust = { evolvesInto = "Nebulite", isMaxLevel = false },
	Nebulite = { evolvesInto = "Cosmling", isMaxLevel = false },
	Cosmling = { evolvesInto = "Galaxion", isMaxLevel = false },
	Galaxion = { evolvesInto = "Celestrix", isMaxLevel = false },
	Celestrix = { evolvesInto = "Celestrix", isMaxLevel = true },

	-- Light lineage
	Glimmer = { evolvesInto = "Lumling", isMaxLevel = false },
	Lumling = { evolvesInto = "Radiantis", isMaxLevel = false },
	Radiantis = { evolvesInto = "Solarburst", isMaxLevel = false },
	Solarburst = { evolvesInto = "Luminar", isMaxLevel = false },
	Luminar = { evolvesInto = "Luminar", isMaxLevel = true },

	-- Radiance lineage
	Shimmer = { evolvesInto = "Aurelius", isMaxLevel = false },
	Aurelius = { evolvesInto = "Brilliance", isMaxLevel = false },
	Brilliance = { evolvesInto = "Divinix", isMaxLevel = false },
	Divinix = { evolvesInto = "Eternalis", isMaxLevel = false },
	Eternalis = { evolvesInto = "Eternalis", isMaxLevel = true },

	-- Mythic tier: merging adds stars, no name change
	Emberlord = { evolvesInto = "Emberlord", isMaxLevel = true },
	Glacieron = { evolvesInto = "Glacieron", isMaxLevel = true },
	Stormrex = { evolvesInto = "Stormrex", isMaxLevel = true },
	Thornwrath = { evolvesInto = "Thornwrath", isMaxLevel = true },
	Nullstar = { evolvesInto = "Nullstar", isMaxLevel = true },
	Solargod = { evolvesInto = "Solargod", isMaxLevel = true },
}

local MAX_STARS = 3

function MergeRules.CanMerge(monsterName: string, stars: number): boolean
	if stars >= MAX_STARS then
		return false
	end

	if not MergeRules[monsterName] then
		return false
	end

	return true
end

function MergeRules.GetMergeResult(monsterName: string, currentStars: number): (string?, number?)
	local rule = MergeRules[monsterName]
	if not rule then
		return nil, nil
	end

	if rule.isMaxLevel then
		local newStars = currentStars + 1
		if newStars > MAX_STARS then
			return nil, nil
		end
		return monsterName, newStars
	end

	return rule.evolvesInto, 0
end

return MergeRules
