local BagManager = {}

-- Stub until Phase 12 (Bag system and upgrades).
function BagManager.AddVial(player: Player, vialData: any)
end

-- Stub until Phase 12: returns a hardcoded bag so the sell loop is testable end-to-end.
function BagManager.GetBagContents(player: Player): { any }
	local vials = {}
	for i = 1, 5 do
		vials[i] = {
			rarity = "Common",
			emotion = "Sadness",
			monsterLevel = 1,
			monsterStars = 0,
		}
	end
	return vials
end

-- Stub until Phase 12 (Bag system and upgrades).
function BagManager.ClearBag(player: Player)
end

return BagManager
