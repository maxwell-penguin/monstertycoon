local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateWarehouseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_WAREHOUSE) :: RemoteEvent

local function groupByElement(monsters: { [string]: any }): { [string]: { any } }
	local groups = {}

	for _, monster in monsters do
		local element = monster.element
		if not groups[element] then
			groups[element] = {}
		end
		table.insert(groups[element], monster)
	end

	return groups
end

updateWarehouseRemote.OnClientEvent:Connect(function(warehouse: any)
	local monsters = warehouse.monsters or {}
	local capacity = warehouse.capacity or 0

	local count = 0
	for _ in monsters do
		count += 1
	end

	shared.WarehouseClient = {
		monsters = monsters,
		capacity = capacity,
		count = count,
		byElement = groupByElement(monsters),
	}

	print(`[WarehouseClient] Warehouse: {count}/{capacity}`)
end)
