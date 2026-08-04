local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_BAG) :: RemoteEvent

shared.BagClient = {
	count = 0,
	capacity = 0,
	isFull = false,
	tier = 1,
}

updateBagRemote.OnClientEvent:Connect(function(bagState: any)
	if typeof(bagState) ~= "table" then
		return
	end

	shared.BagClient = {
		count = bagState.currentCount or 0,
		capacity = bagState.capacity or 0,
		isFull = bagState.isFull or false,
		tier = bagState.tier or 1,
	}

	-- Bag-full red-flash UI lands in Phase 14; the flag is available now via
	-- shared.BagClient.isFull for whatever consumes it.
end)
