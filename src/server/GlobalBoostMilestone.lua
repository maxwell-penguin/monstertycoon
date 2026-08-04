local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local MILESTONES = { 1000000, 10000000, 100000000, 1000000000 }
local REWARD_TYPES = { "luck", "money", "crate" }

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

			-- Reward effects are stubs; Phase 17 will implement luck/money/crate bonuses.
			for _, player in Players:GetPlayers() do
				globalMilestoneHitRemote:FireClient(player, { milestone = milestone, rewardType = rewardType })
			end
		end
	end
end

return GlobalBoostMilestone
