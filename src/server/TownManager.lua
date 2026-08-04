local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local RollTable = require(ReplicatedStorage.RollTable)
local PlayerManager = require(script.Parent.PlayerManager)

export type Town = {
	townLevel: number,
	townXP: number,
}

local TownManager = {}

local playerTowns: { [number]: Town } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local townUpdatedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.TOWN_UPDATED) :: RemoteEvent

local RARITY_RANK = {}
for i, rarity in RollTable.RARITY_ORDER do
	RARITY_RANK[rarity] = i
end

function TownManager.GetXPRequired(level: number): number
	if level >= Constants.MAX_TOWN_LEVEL then
		return math.huge
	end
	return math.floor(100 * (level ^ 1.5))
end

local function fireTownUpdate(player: Player, townLevel: number, townXP: number)
	townUpdatedRemote:FireClient(player, {
		townLevel = townLevel,
		townXP = townXP,
		xpRequired = TownManager.GetXPRequired(townLevel),
		rollProbabilities = RollTable.GetProbabilities(townLevel),
	})
end

function TownManager.InitTown(player: Player)
	local userId = player.UserId
	local data = PlayerManager.GetData(userId)
	local townLevel = (data and data.townLevel) or 1
	local townXP = (data and data.townXP) or 0

	playerTowns[userId] = { townLevel = townLevel, townXP = townXP }

	fireTownUpdate(player, townLevel, townXP)
end

function TownManager.GetTownLevel(player: Player): number
	local town = playerTowns[player.UserId]
	return town and town.townLevel or 1
end

function TownManager.AddXP(player: Player, amount: number): (number, boolean)
	local userId = player.UserId
	local town = playerTowns[userId]
	if not town then
		return 1, false
	end

	if typeof(amount) ~= "number" or amount <= 0 then
		return town.townLevel, false
	end

	town.townXP += amount

	local leveledUp = false

	while town.townLevel < Constants.MAX_TOWN_LEVEL do
		local xpRequired = TownManager.GetXPRequired(town.townLevel)
		if town.townXP < xpRequired then
			break
		end

		town.townXP -= xpRequired
		town.townLevel += 1
		leveledUp = true
	end

	fireTownUpdate(player, town.townLevel, town.townXP)

	return town.townLevel, leveledUp
end

-- Shared egg-open XP formula so RollManager and CrateManager don't each duplicate
-- the rarity-bonus tiering; crate claims intentionally earn the same XP as rolls.
function TownManager.GetEggOpenXP(rarity: string): number
	local amount = Constants.XP_REWARDS.eggOpen
	local rank = RARITY_RANK[rarity]
	if not rank then
		return amount
	end

	if rank >= RARITY_RANK.Mythic then
		amount += Constants.XP_REWARDS.eggMythic
	elseif rank >= RARITY_RANK.Legendary then
		amount += Constants.XP_REWARDS.eggLegendary
	elseif rank >= RARITY_RANK.Rare then
		amount += Constants.XP_REWARDS.eggRare
	end

	return amount
end

function TownManager.SaveTownData(player: Player)
	local town = playerTowns[player.UserId]
	if not town then
		return
	end

	PlayerManager.SetData(player.UserId, "townLevel", town.townLevel)
	PlayerManager.SetData(player.UserId, "townXP", town.townXP)
end

function TownManager.ClearTownState(player: Player)
	playerTowns[player.UserId] = nil
end

return TownManager
