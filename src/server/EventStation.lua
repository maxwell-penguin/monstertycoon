local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local PlayerManager = require(script.Parent.PlayerManager)
local WarehouseManager = require(script.Parent.WarehouseManager)

local EventStation = {}

local function findEventMonster(monsterName: string): any
	for _, entry in Constants.EVENT_MONSTERS do
		if entry.name == monsterName then
			return entry
		end
	end
	return nil
end

function EventStation.PurchaseEventMonster(player: Player, monsterName: string): (boolean, string)
	local entry = findEventMonster(monsterName)
	if not entry then
		return false, "invalid_monster"
	end

	local userId = player.UserId
	local data = PlayerManager.GetData(userId)
	local rawTokens = (data and data.eventTokens) or 0

	-- Balances can be fractional (0.5 per Shard Hunt's 5-9 shard tier), but
	-- affordability is checked on whole tokens only -- "rounded down when spending".
	if math.floor(rawTokens) < entry.tokenCost then
		return false, "insufficient_tokens"
	end

	PlayerManager.SetData(userId, "eventTokens", rawTokens - entry.tokenCost)

	local added, instanceId = WarehouseManager.AddMonster(player, monsterName)
	if not added then
		-- Refund on failure (warehouse full) -- re-read in case something else
		-- changed the balance between the two SetData calls.
		local refreshedData = PlayerManager.GetData(userId)
		local currentTokens = (refreshedData and refreshedData.eventTokens) or 0
		PlayerManager.SetData(userId, "eventTokens", currentTokens + entry.tokenCost)
		return false, instanceId
	end

	return true, instanceId
end

return EventStation
