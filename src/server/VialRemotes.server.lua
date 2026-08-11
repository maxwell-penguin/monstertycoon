local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local VialProducer = require(script.Parent.VialProducer)
local RateLimiter = require(script.Parent.RateLimiter)
local AntiCheat = require(script.Parent.AntiCheat)

local GUID_LENGTH = 36

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local pickupVialRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PICKUP_VIAL) :: RemoteEvent

local pickupLimiter = RateLimiter.CreateLimiter(10, 1)

pickupVialRemote.OnServerEvent:Connect(function(player: Player, vialId: any)
	local userId = player.UserId
	RateLimiter.TrackRemoteCall(userId)

	if not pickupLimiter:Check(userId) then
		warn(`[VialRemotes] Rate limit exceeded for user {userId}`)
		return
	end

	if typeof(vialId) ~= "string" or #vialId ~= GUID_LENGTH then
		warn(`[VialRemotes] Rejected malformed vialId from user {userId}`)
		return
	end

	local success, reason = VialProducer.CollectVial(player, vialId)
	if not success and reason == "out_of_range" then
		AntiCheat.RecordViolation(player, `position_mismatch: vial pickup out of range`)
	end
end)
