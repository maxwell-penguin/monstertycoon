local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)

export type BagVialData = {
	vialId: string,
	rarity: string,
	emotion: string,
	monsterLevel: number,
	monsterStars: number,
	slotIndex: number,
}

export type Bag = {
	tier: number,
	capacity: number,
	contents: { [string]: BagVialData },
	count: number,
}

local BagManager = {}

local playerBags: { [number]: Bag } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_BAG) :: RemoteEvent

local function fireBagUpdate(player: Player, bag: Bag, isFull: boolean?)
	updateBagRemote:FireClient(player, {
		tier = bag.tier,
		capacity = bag.capacity,
		currentCount = bag.count,
		isFull = isFull or false,
	})
end

function BagManager.InitBag(player: Player)
	local userId = player.UserId
	local data = PlayerManager.GetData(userId)
	local bagTier = (data and data.bagTier) or 1
	local bagDef = Constants.BAG_TIERS[bagTier]
	local capacity = (bagDef and bagDef.capacity) or Constants.BAG_TIERS[1].capacity

	local bag: Bag = {
		tier = bagTier,
		capacity = capacity,
		contents = {},
		count = 0,
	}

	playerBags[userId] = bag

	fireBagUpdate(player, bag)
end

function BagManager.AddVial(player: Player, vialData: BagVialData): boolean
	local bag = playerBags[player.UserId]
	if not bag then
		return false
	end

	if bag.count >= bag.capacity then
		fireBagUpdate(player, bag, true)
		return false
	end

	bag.contents[vialData.vialId] = vialData
	bag.count += 1

	fireBagUpdate(player, bag)

	return true
end

function BagManager.GetBagContents(player: Player): { BagVialData }
	local bag = playerBags[player.UserId]
	if not bag then
		return {}
	end

	local result = {}
	for _, vialData in bag.contents do
		table.insert(result, vialData)
	end

	return result
end

function BagManager.ClearBag(player: Player)
	local bag = playerBags[player.UserId]
	if not bag then
		return
	end

	bag.contents = {}
	bag.count = 0

	fireBagUpdate(player, bag)
end

function BagManager.GetBagInfo(player: Player): (number, number, boolean)
	local bag = playerBags[player.UserId]
	if not bag then
		return 0, 0, false
	end

	return bag.count, bag.capacity, bag.count >= bag.capacity
end

function BagManager.GetBagTier(player: Player): number
	local bag = playerBags[player.UserId]
	return bag and bag.tier or 0
end

function BagManager.UpgradeBag(player: Player, targetTier: number, isPurchaseValid: boolean?): (boolean, string)
	local userId = player.UserId
	local bag = playerBags[userId]
	if not bag then
		return false, "invalid_tier"
	end

	if bag.tier >= #Constants.BAG_TIERS then
		return false, "already_max"
	end

	if targetTier ~= bag.tier + 1 then
		return false, "invalid_tier"
	end

	local targetDef = Constants.BAG_TIERS[targetTier]
	if not targetDef then
		return false, "invalid_tier"
	end

	if targetDef.robux then
		-- Robux receipt validation is stubbed until Phase 15; isPurchaseValid is
		-- always passed as false by BagRemotes until then.
		if not isPurchaseValid then
			return false, "requires_robux"
		end
	else
		local data = PlayerManager.GetData(userId)
		if not data or data.coins < targetDef.cost then
			return false, "insufficient_coins"
		end

		if not PlayerManager.DecrementCoins(userId, targetDef.cost) then
			return false, "insufficient_coins"
		end
	end

	PlayerManager.SetData(userId, "bagTier", targetTier)
	bag.tier = targetTier
	bag.capacity = targetDef.capacity

	fireBagUpdate(player, bag)

	return true, ""
end

-- For gamepass grants (InfiniteBag/VoidCarrier): jumps straight to a tier, bypassing
-- both the "one tier at a time" and coin-cost rules UpgradeBag enforces for players.
-- Never downgrades -- if the player is already at or above the target tier, no-op.
function BagManager.GrantBagTier(player: Player, tier: number): boolean
	local userId = player.UserId
	local bag = playerBags[userId]
	if not bag then
		return false
	end

	local targetDef = Constants.BAG_TIERS[tier]
	if not targetDef then
		return false
	end

	if tier <= bag.tier then
		return false
	end

	bag.tier = tier
	bag.capacity = targetDef.capacity

	PlayerManager.SetData(userId, "bagTier", tier)

	fireBagUpdate(player, bag)

	return true
end

function BagManager.SaveBagToPlayerData(player: Player)
	local bag = playerBags[player.UserId]
	if not bag then
		return
	end

	PlayerManager.SetData(player.UserId, "bagTier", bag.tier)
end

function BagManager.ClearBagState(player: Player)
	playerBags[player.UserId] = nil
end

return BagManager
