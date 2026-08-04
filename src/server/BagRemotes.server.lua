local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BagManager = require(script.Parent.BagManager)

local RATE_LIMIT_WINDOW = 10
local RATE_LIMIT_COUNT = 3

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local upgradeBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPGRADE_BAG) :: RemoteEvent

local requestTimes: { [number]: { number } } = {}

local function isRateLimited(userId: number): boolean
	local now = os.clock()
	local times = requestTimes[userId]
	if not times then
		times = {}
		requestTimes[userId] = times
	end

	local i = 1
	while i <= #times do
		if now - times[i] >= RATE_LIMIT_WINDOW then
			table.remove(times, i)
		else
			i += 1
		end
	end

	if #times >= RATE_LIMIT_COUNT then
		return true
	end

	table.insert(times, now)
	return false
end

upgradeBagRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local targetTier = payload.targetTier
	if typeof(targetTier) ~= "number" or targetTier ~= math.floor(targetTier) then
		return
	end

	if targetTier < 1 or targetTier > #Constants.BAG_TIERS then
		return
	end

	if isRateLimited(player.UserId) then
		warn(`[BagRemotes] Rate limit exceeded for user {player.UserId}`)
		return
	end

	-- Robux validation is stubbed until Phase 15; always pass isPurchaseValid=false.
	local success, reason = BagManager.UpgradeBag(player, targetTier, false)
	local _, newCapacity = BagManager.GetBagInfo(player)
	local newTier = BagManager.GetBagTier(player)

	upgradeBagRemote:FireClient(player, {
		success = success,
		reason = reason,
		newTier = newTier,
		newCapacity = newCapacity,
	})
end)

Players.PlayerRemoving:Connect(function(player: Player)
	requestTimes[player.UserId] = nil
end)
