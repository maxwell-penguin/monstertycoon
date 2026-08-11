local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local RollManager = require(script.Parent.RollManager)
local BagManager = require(script.Parent.BagManager)
local TownManager = require(script.Parent.TownManager)
local EventManager = require(script.Parent.EventManager)

local CHECK_INTERVAL = 5
local BONUS_TOWN_XP = 100

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateCoinsRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_COINS) :: RemoteEvent
local sessionRewardRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SESSION_REWARD) :: RemoteEvent
local requestSessionRewardRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.REQUEST_SESSION_REWARD) :: RemoteEvent

-- Highest bag tier reachable for free (BAG_TIERS beyond this require Robux) --
-- a session reward should never hand out a paid tier for nothing.
local maxFreeBagTier = 0
for i, tier in Constants.BAG_TIERS do
	if not tier.robux then
		maxFreeBagTier = i
	end
end

local SessionRewards = {}

local activeLoops: { [number]: boolean } = {}
local firedThresholds: { [number]: { [number]: boolean } } = {}

local function describeReward(entry: any): string
	local description
	if entry.reward == "coins" then
		description = `{entry.amount} Coins`
	elseif entry.reward == "egg" then
		description = `{entry.rarity} Egg`
	elseif entry.reward == "bagVoucher" then
		description = "Bag Upgrade"
	else
		description = "Reward"
	end

	if entry.bonusLuck then
		description ..= " + Luck Boost"
	end
	if entry.bonusTownXP then
		description ..= " + Bonus XP"
	end

	return description
end

local function grantReward(player: Player, entry: any)
	local userId = player.UserId

	if entry.chance and math.random() > entry.chance then
		return
	end

	local granted = false

	if entry.reward == "coins" then
		if PlayerManager.IncrementCoins(userId, entry.amount) then
			granted = true
			local data = PlayerManager.GetData(userId)
			if data then
				updateCoinsRemote:FireClient(player, data.coins)
			end
		end
	elseif entry.reward == "egg" then
		granted = RollManager.PerformPremiumRoll(player, entry.rarity, true)
	elseif entry.reward == "bagVoucher" then
		-- GrantBagTier (not UpgradeBag) -- UpgradeBag charges coins for
		-- non-Robux tiers, which would make a "free" session reward cost the
		-- player money. GrantBagTier is the existing no-cost grant path
		-- (already used for gamepass bag grants).
		local currentTier = BagManager.GetBagTier(player)
		if currentTier > 0 and currentTier < maxFreeBagTier then
			granted = BagManager.GrantBagTier(player, currentTier + 1)
		end
	end

	if entry.bonusLuck and entry.luckDuration then
		EventManager.GrantPersonalLuck(userId, entry.luckDuration)
	end

	if entry.bonusTownXP then
		TownManager.AddXP(player, BONUS_TOWN_XP)
	end

	if granted then
		sessionRewardRemote:FireClient(player, {
			type = entry.reward,
			description = describeReward(entry),
			seconds = entry.seconds,
		})
	end
end

-- Server-authoritative elapsed time, off the join timestamp PlayerManager
-- stored at load (not anything the client reports) -- used by both the
-- automatic loop below and the manual REQUEST_SESSION_REWARD claim.
local function getElapsedSeconds(userId: number): number?
	local sessionStartTime = PlayerManager.GetSessionStartTime(userId)
	if not sessionStartTime then
		return nil
	end
	return os.time() - sessionStartTime
end

function SessionRewards.InitSessionRewards(player: Player)
	local userId = player.UserId
	if activeLoops[userId] then
		return
	end

	activeLoops[userId] = true
	firedThresholds[userId] = {}

	task.spawn(function()
		while activeLoops[userId] do
			task.wait(CHECK_INTERVAL)

			if not activeLoops[userId] then
				break
			end

			local elapsed = getElapsedSeconds(userId)
			local fired = firedThresholds[userId]
			if elapsed and fired then
				for _, entry in Constants.SESSION_REWARDS do
					if elapsed >= entry.seconds and not fired[entry.seconds] then
						fired[entry.seconds] = true
						grantReward(player, entry)
					end
				end
			end
		end
	end)
end

-- Manual claim path for the RewardsPanel's CLAIM button. Same firedThresholds
-- table as the automatic loop, so whichever path reaches a milestone first
-- blocks the other from double-granting it.
function SessionRewards.ClaimReward(player: Player, milestoneIndex: number)
	local userId = player.UserId
	local fired = firedThresholds[userId]
	if not fired then
		return
	end

	local entry = Constants.SESSION_REWARDS[milestoneIndex]
	if not entry or fired[entry.seconds] then
		return
	end

	local elapsed = getElapsedSeconds(userId)
	if not elapsed or elapsed < entry.seconds then
		return
	end

	fired[entry.seconds] = true
	grantReward(player, entry)
end

requestSessionRewardRemote.OnServerEvent:Connect(function(player: Player, milestoneIndex: any)
	if typeof(milestoneIndex) ~= "number" then
		return
	end
	SessionRewards.ClaimReward(player, milestoneIndex)
end)

function SessionRewards.StopSessionRewards(player: Player)
	local userId = player.UserId
	activeLoops[userId] = nil
	firedThresholds[userId] = nil
	EventManager.ClearPersonalLuck(userId)
end

return SessionRewards
