local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local rollEggRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.ROLL_EGG) :: RemoteEvent
local slotMonsterRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SLOT_MONSTER) :: RemoteEvent
local unslotMonsterRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UNSLOT_MONSTER) :: RemoteEvent
local mergeMonstersRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.MERGE_MONSTERS) :: RemoteEvent
local upgradeHallRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPGRADE_HALL) :: RemoteEvent
local upgradeBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPGRADE_BAG) :: RemoteEvent
local eventStationPurchaseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.EVENT_STATION_PURCHASE) :: RemoteEvent
local requestSessionRewardRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.REQUEST_SESSION_REWARD) :: RemoteEvent

local DEBOUNCE_WINDOW = 0.3
local lastFireTime: { [string]: number } = {}

local function isDebounced(actionName: string): boolean
	local now = os.clock()
	local last = lastFireTime[actionName]
	if last and (now - last) < DEBOUNCE_WINDOW then
		return true
	end
	lastFireTime[actionName] = now
	return false
end

-- UIManager.client.lua creates shared.UIActionEvent at its own startup, before it
-- wires any buttons, but script start order between the two LocalScripts isn't
-- guaranteed, so wait briefly for it to appear.
local WAIT_TIMEOUT = 5
local waited = 0
while not shared.UIActionEvent and waited < WAIT_TIMEOUT do
	task.wait(0.1)
	waited += 0.1
end

local actionEvent = shared.UIActionEvent :: BindableEvent?
if not actionEvent then
	warn("[UIInput] UIManager's action event never appeared; button input will not fire")
else
	actionEvent.Event:Connect(function(action: string, payload: any)
		if isDebounced(action) then
			return
		end

		-- Payload shapes below match the server remote handlers actually deployed in
		-- earlier phases (SLOT_MONSTER/UNSLOT_MONSTER/ROLL_EGG take positional args,
		-- not a table), not the generic {field=value} shorthand used to describe them.
		if action == "ROLL_EGG" then
			rollEggRemote:FireServer(payload.count)
		elseif action == "SLOT_MONSTER" then
			slotMonsterRemote:FireServer(payload.slotIndex, payload.instanceId)
		elseif action == "UNSLOT_MONSTER" then
			unslotMonsterRemote:FireServer(payload.slotIndex)
		elseif action == "MERGE_MONSTERS" then
			mergeMonstersRemote:FireServer({ instanceIds = payload.instanceIds })
		elseif action == "UPGRADE_HALL" then
			upgradeHallRemote:FireServer()
		elseif action == "UPGRADE_BAG" then
			upgradeBagRemote:FireServer({ targetTier = payload.targetTier })
		elseif action == "EVENT_STATION_PURCHASE" then
			eventStationPurchaseRemote:FireServer({ monsterName = payload.monsterName })
		elseif action == "REQUEST_SESSION_REWARD" then
			requestSessionRewardRemote:FireServer(payload.milestoneIndex)
		end
	end)
end
