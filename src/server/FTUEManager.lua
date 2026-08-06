local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BoostState = require(ReplicatedStorage.BoostState)
local PlayerManager = require(script.Parent.PlayerManager)
local WarehouseManager = require(script.Parent.WarehouseManager)
local HallManager = require(script.Parent.HallManager)
local TownManager = require(script.Parent.TownManager)
local RollManager = require(script.Parent.RollManager)

local STARTER_MONSTER = "Sparklet"
local COMPLETION_XP = 200
local PERSONAL_BOOST_ELEMENT = "Thunder"
local PERSONAL_BOOST_MULTIPLIER = 3
local PERSONAL_BOOST_DURATION = 120
local TWO_MINUTE_MILESTONE_SECONDS = 120

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local ftueStepRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.FTUE_STEP) :: RemoteEvent
local ftueProgressRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.FTUE_PROGRESS) :: RemoteEvent

local FTUEManager = {}

-- Bridges the server-authoritative sequence's waits to whatever confirmation (or
-- timeout) arrives first for that player's currently-expected step.
local pendingConfirmations: { [number]: { stepName: string, event: BindableEvent } } = {}

local function waitForConfirmation(userId: number, stepName: string, timeoutSeconds: number)
	local event = Instance.new("BindableEvent")
	pendingConfirmations[userId] = { stepName = stepName, event = event }

	task.delay(timeoutSeconds, function()
		local pending = pendingConfirmations[userId]
		if pending and pending.event == event then
			pendingConfirmations[userId] = nil
			event:Fire()
		end
	end)

	event.Event:Wait()
	event:Destroy()
end

ftueProgressRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local userId = player.UserId
	local pending = pendingConfirmations[userId]
	if pending and pending.stepName == payload.stepName then
		pendingConfirmations[userId] = nil
		pending.event:Fire()
	end
end)

function FTUEManager.IsFTUEComplete(player: Player): boolean
	local data = PlayerManager.GetData(player.UserId)
	return (data and data.ftueComplete) or false
end

local function findSessionReward(seconds: number): any
	for _, entry in Constants.SESSION_REWARDS do
		if entry.seconds == seconds then
			return entry
		end
	end
	return nil
end

-- The generic timer-based session reward system isn't built yet (still a Phase 16+
-- item per the stub comment in DataStore.server.lua); this only grants the one
-- specific milestone FTUE completion is tied to.
local function grantTwoMinuteSessionReward(player: Player)
	local rewardEntry = findSessionReward(TWO_MINUTE_MILESTONE_SECONDS)
	if not rewardEntry then
		return
	end

	if rewardEntry.reward == "coins" then
		PlayerManager.IncrementCoins(player.UserId, rewardEntry.amount)
	elseif rewardEntry.reward == "egg" then
		RollManager.PerformPremiumRoll(player, rewardEntry.rarity, true)
	end

	TownManager.AddXP(player, Constants.XP_REWARDS.sessionMilestone)
end

function FTUEManager.CompleteFTUE(player: Player)
	local userId = player.UserId

	PlayerManager.SetData(userId, "ftueComplete", true)

	BoostState.SetPersonalBoost(userId, PERSONAL_BOOST_ELEMENT, PERSONAL_BOOST_MULTIPLIER, PERSONAL_BOOST_DURATION)

	ftueStepRemote:FireClient(player, { stepName = "complete", firstBoostActive = true })

	TownManager.AddXP(player, COMPLETION_XP)

	grantTwoMinuteSessionReward(player)
end

function FTUEManager.StartFTUE(player: Player)
	if FTUEManager.IsFTUEComplete(player) then
		return
	end

	local userId = player.UserId

	ftueStepRemote:FireClient(player, { stepName = "start" })

	local slottedInstanceIds = {}
	for _ = 1, 3 do
		local added, instanceId = WarehouseManager.AddMonster(player, STARTER_MONSTER)
		if added then
			table.insert(slottedInstanceIds, instanceId)
		end
	end

	for slotIndex, instanceId in slottedInstanceIds do
		HallManager.SlotMonster(player, slotIndex, instanceId)
	end

	ftueStepRemote:FireClient(player, { stepName = "monsters_placed" })

	waitForConfirmation(userId, "vial_collected", 60)
	ftueStepRemote:FireClient(player, { stepName = "sell_now" })

	waitForConfirmation(userId, "vial_sold", 60)
	ftueStepRemote:FireClient(player, { stepName = "roll_now" })

	waitForConfirmation(userId, "egg_rolled", 30)
	ftueStepRemote:FireClient(player, { stepName = "merge_tutorial" })

	-- All 3 starter Sparklets were auto-slotted into the Hall above, so zero sit in
	-- the warehouse -- slotting moves a monster out of the warehouse (HallManager.
	-- SlotMonster calls WarehouseManager.RemoveMonster). Merging needs 3 identical
	-- monsters *in the warehouse*, so 3 fresh ones are granted here, not 2.
	WarehouseManager.AddMonster(player, STARTER_MONSTER)
	WarehouseManager.AddMonster(player, STARTER_MONSTER)
	WarehouseManager.AddMonster(player, STARTER_MONSTER)

	waitForConfirmation(userId, "merge_complete", 60)

	FTUEManager.CompleteFTUE(player)
end

return FTUEManager
