-- Maps monsterName -> what it evolves into when 3 are merged
local MergeRules = {
	-- Sadness lineage
	Weeper = { evolvesInto = "Glumpling", isMaxLevel = false },
	Glumpling = { evolvesInto = "Soaker", isMaxLevel = false },
	Soaker = { evolvesInto = "Cryo", isMaxLevel = false },
	Cryo = { evolvesInto = "Abyssal", isMaxLevel = false },
	Abyssal = { evolvesInto = "Abyssal", isMaxLevel = true },

	-- Rage lineage
	Ember = { evolvesInto = "Furon", isMaxLevel = false },
	Furon = { evolvesInto = "Scorcher", isMaxLevel = false },
	Scorcher = { evolvesInto = "Inferno", isMaxLevel = false },
	Inferno = { evolvesInto = "Pyroclast", isMaxLevel = false },
	Pyroclast = { evolvesInto = "Pyroclast", isMaxLevel = true },

	-- Joy lineage
	Sparklet = { evolvesInto = "Sunkling", isMaxLevel = false },
	Sunkling = { evolvesInto = "Radiant", isMaxLevel = false },
	Radiant = { evolvesInto = "Solaris", isMaxLevel = false },
	Solaris = { evolvesInto = "Luminar", isMaxLevel = false },
	Luminar = { evolvesInto = "Luminar", isMaxLevel = true },

	-- Dread lineage
	Shiver = { evolvesInto = "Lurk", isMaxLevel = false },
	Lurk = { evolvesInto = "Phantom", isMaxLevel = false },
	Phantom = { evolvesInto = "Specter", isMaxLevel = false },
	Specter = { evolvesInto = "Eclipse", isMaxLevel = false },
	Eclipse = { evolvesInto = "Eclipse", isMaxLevel = true },

	-- Void lineage
	Mote = { evolvesInto = "Nullling", isMaxLevel = false },
	Nullling = { evolvesInto = "Rift", isMaxLevel = false },
	Rift = { evolvesInto = "Sunder", isMaxLevel = false },
	Sunder = { evolvesInto = "Null", isMaxLevel = false },
	Null = { evolvesInto = "Null", isMaxLevel = true },

	-- Nostalgia lineage
	Wisp = { evolvesInto = "Reminisce", isMaxLevel = false },
	Reminisce = { evolvesInto = "Reverie", isMaxLevel = false },
	Reverie = { evolvesInto = "Chronos", isMaxLevel = false },
	Chronos = { evolvesInto = "Eternity", isMaxLevel = false },
	Eternity = { evolvesInto = "Eternity", isMaxLevel = true },

	-- Mythic tier: merging adds stars, no name change
	TheWatcher = { evolvesInto = "TheWatcher", isMaxLevel = true },
	Unknown = { evolvesInto = "Unknown", isMaxLevel = true },
	VoidNull = { evolvesInto = "VoidNull", isMaxLevel = true },
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
