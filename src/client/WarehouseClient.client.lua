local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateWarehouseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_WAREHOUSE) :: RemoteEvent
local openWarehouseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.OPEN_WAREHOUSE) :: RemoteEvent

local function groupByEmotion(monsters: { [string]: any }): { [string]: { any } }
	local groups = {}

	for _, monster in monsters do
		local emotion = monster.emotion
		if not groups[emotion] then
			groups[emotion] = {}
		end
		table.insert(groups[emotion], monster)
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
		byEmotion = groupByEmotion(monsters),
	}

	print(`[WarehouseClient] Warehouse: {count}/{capacity}`)
end)

openWarehouseRemote.OnClientEvent:Connect(function()
	if shared.UIManager then
		shared.UIManager.ShowPanel("WarehousePanel")
	end
end)
