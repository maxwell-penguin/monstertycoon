local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local WarehouseManager = require(script.Parent.WarehouseManager)

local RATE_LIMIT = 5
local RATE_WINDOW = 1

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local upgradeWarehouseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPGRADE_WAREHOUSE) :: RemoteEvent

local rateData: { [number]: { count: number, windowStart: number } } = {}

local function checkRateLimit(userId: number): boolean
	local now = os.clock()
	local record = rateData[userId]

	if not record or (now - record.windowStart) >= RATE_WINDOW then
		record = { count = 0, windowStart = now }
		rateData[userId] = record
	end

	record.count += 1

	return record.count <= RATE_LIMIT
end

upgradeWarehouseRemote.OnServerEvent:Connect(function(player: Player)
	local userId = player.UserId

	if not checkRateLimit(userId) then
		warn(`[WarehouseRemotes] Rate limit exceeded for user {userId}`)
		return
	end

	local success = WarehouseManager.UpgradeWarehouse(player)
	upgradeWarehouseRemote:FireClient(player, success)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	rateData[player.UserId] = nil
end)
