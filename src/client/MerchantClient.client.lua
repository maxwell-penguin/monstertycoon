local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local openMerchantRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.OPEN_MERCHANT) :: RemoteEvent
local updateHabitatsRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_HABITATS) :: RemoteEvent

openMerchantRemote.OnClientEvent:Connect(function()
	if shared.UIManager then
		shared.UIManager.ShowPanel("MerchantPanel")
	end
end)

-- Named HabitatState (not HabitatClient) so it doesn't collide with
-- shared.HabitatClient, the placement-mode API object HabitatClient.client.lua
-- publishes -- overwriting that table wholesale on every update would wipe
-- out its EnterPlacementMode function reference.
updateHabitatsRemote.OnClientEvent:Connect(function(state: any)
	shared.HabitatState = {
		habitats = state.habitats or {},
		inventory = state.inventory or {},
		nextCost = state.nextCost or 0,
	}
end)
