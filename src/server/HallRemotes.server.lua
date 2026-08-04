local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local HallManager = require(script.Parent.HallManager)

local INSTANCE_ID_LENGTH = 8

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local slotMonsterRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SLOT_MONSTER) :: RemoteEvent
local unslotMonsterRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UNSLOT_MONSTER) :: RemoteEvent
local upgradeHallRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPGRADE_HALL) :: RemoteEvent

local function isValidInstanceId(instanceId: any): boolean
	return typeof(instanceId) == "string"
		and #instanceId == INSTANCE_ID_LENGTH
		and instanceId:match("^%w+$") ~= nil
end

slotMonsterRemote.OnServerEvent:Connect(function(player: Player, slotIndex: any, instanceId: any)
	if typeof(slotIndex) ~= "number" then
		return
	end

	if not isValidInstanceId(instanceId) then
		return
	end

	HallManager.SlotMonster(player, slotIndex, instanceId)
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
