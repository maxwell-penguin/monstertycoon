local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local WarehouseManager = require(script.Parent.WarehouseManager)
local RateLimiter = require(script.Parent.RateLimiter)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local upgradeWarehouseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPGRADE_WAREHOUSE) :: RemoteEvent

local upgradeLimiter = RateLimiter.CreateLimiter(5, 1)

upgradeWarehouseRemote.OnServerEvent:Connect(function(player: Player)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if not upgradeLimiter:Check(userId) then
		warn(`[WarehouseRemotes] Rate limit exceeded for user {userId}`)
		return
	end

	local success = WarehouseManager.UpgradeWarehouse(player)
	upgradeWarehouseRemote:FireClient(player, success)
end)
