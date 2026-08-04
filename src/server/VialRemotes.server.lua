local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local VialProducer = require(script.Parent.VialProducer)

local GUID_LENGTH = 36
local RATE_LIMIT = 10
local RATE_WINDOW = 1

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local pickupVialRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PICKUP_VIAL) :: RemoteEvent

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

pickupVialRemote.OnServerEvent:Connect(function(player: Player, vialId: any)
	local userId = player.UserId

	if not checkRateLimit(userId) then
		warn(`[VialRemotes] Rate limit exceeded for user {userId}`)
		return
	end

	if typeof(vialId) ~= "string" or #vialId ~= GUID_LENGTH then
		warn(`[VialRemotes] Rejected malformed vialId from user {userId}`)
		return
	end

	VialProducer.CollectVial(player, vialId)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	rateData[player.UserId] = nil
end)
