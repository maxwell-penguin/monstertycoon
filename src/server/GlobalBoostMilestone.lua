local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BoostState = require(ReplicatedStorage.BoostState)

local MILESTONES = { 1000000, 10000000, 100000000, 1000000000 }
local REWARD_TYPES = { "luck", "money", "crate" }

local LUCK_REWARD_DURATION = 300
local MONEY_REWARD_MULTIPLIER = 1.5
local MONEY_REWARD_DURATION = 300

-- Lazy requires: EventManager and CrateManager both transitively require Economy
-- (CrateManager -> WarehouseManager -> Economy, EventManager -> RollManager ->
-- Economy), and Economy requires this module -- an eager require here would be a
-- true circular dependency (Roblox errors on those at load time, crashing the
-- server on boot). Deferring until the reward actually fires avoids it entirely,
-- since every module involved has finished loading by then regardless.
local EventManager: any = nil
local CrateManager: any = nil

local function getEventManager(): any
	if not EventManager then
		EventManager = require(script.Parent.EventManager)
	end
	return EventManager
end

local function getCrateManager(): any
	if not CrateManager then
		CrateManager = require(script.Parent.CrateManager)
	end
	return CrateManager
end

local REWARD_EFFECTS: { [string]: () -> () } = {
	luck = function()
		getEventManager().GrantServerLuck(LUCK_REWARD_DURATION)
	end,
	money = function()
		BoostState.SetServerMultiplier(MONEY_REWARD_MULTIPLIER, MONEY_REWARD_DURATION)
	end,
	crate = function()
		local crateManager = getCrateManager()
		for _, player in Players:GetPlayers() do
			crateManager.SpawnCrate(player)
		end
	end,
}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local globalMilestoneHitRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.GLOBAL_MILESTONE_HIT) :: RemoteEvent

local GlobalBoostMilestone = {}

local totalGlobalEarnings = 0
local milestonesHit: { [number]: boolean } = {}
local rewardCycleIndex = 0

function GlobalBoostMilestone.IncrementGlobalEarnings(amount: number)
	if typeof(amount) ~= "number" or amount <= 0 then
		return
	end

	totalGlobalEarnings += amount

	for _, milestone in MILESTONES do
		if totalGlobalEarnings >= milestone and not milestonesHit[milestone] then
			milestonesHit[milestone] = true

			rewardCycleIndex += 1
			local rewardType = REWARD_TYPES[((rewardCycleIndex - 1) % #REWARD_TYPES) + 1]

			local effect = REWARD_EFFECTS[rewardType]
			if effect then
				effect()
			end

			for _, player in Players:GetPlayers() do
				globalMilestoneHitRemote:FireClient(player, { milestone = milestone, rewardType = rewardType })
			end
		end
	end
end

return GlobalBoostMilestone
