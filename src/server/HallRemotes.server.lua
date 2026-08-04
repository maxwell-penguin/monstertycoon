local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local HallManager = require(script.Parent.HallManager)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local slotMonsterRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SLOT_MONSTER) :: RemoteEvent
local unslotMonsterRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UNSLOT_MONSTER) :: RemoteEvent
local upgradeHallRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPGRADE_HALL) :: RemoteEvent

slotMonsterRemote.OnServerEvent:Connect(function(player: Player, slotIndex: any, monsterName: any)
	if typeof(slotIndex) ~= "number" or typeof(monsterName) ~= "string" then
		return
	end

	HallManager.SlotMonster(player, slotIndex, monsterName)
end)

unslotMonsterRemote.OnServerEvent:Connect(function(player: Player, slotIndex: any)
	if typeof(slotIndex) ~= "number" then
		return
	end

	HallManager.UnslotMonster(player, slotIndex)
end)

upgradeHallRemote.OnServerEvent:Connect(function(player: Player)
	local success = HallManager.UpgradeHall(player)
	upgradeHallRemote:FireClient(player, success)
end)
