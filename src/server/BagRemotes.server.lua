local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BagManager = require(script.Parent.BagManager)
local RateLimiter = require(script.Parent.RateLimiter)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local upgradeBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPGRADE_BAG) :: RemoteEvent

local upgradeLimiter = RateLimiter.CreateLimiter(3, 10)

upgradeBagRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

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

	if not upgradeLimiter:Check(userId) then
		warn(`[BagRemotes] Rate limit exceeded for user {userId}`)
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
