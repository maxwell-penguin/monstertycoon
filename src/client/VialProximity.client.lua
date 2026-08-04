local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local pickupVialRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PICKUP_VIAL) :: RemoteEvent
local vialRemovedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_REMOVED) :: RemoteEvent

local pendingPickups: { [string]: boolean } = {}

vialRemovedRemote.OnClientEvent:Connect(function(vialId: string)
	pendingPickups[vialId] = nil
end)

while true do
	task.wait(0.5)

	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)

	if rootPart then
		for _, part in Workspace:GetChildren() do
			if part:IsA("BasePart") and part.Name:sub(1, 5) == "Vial_" then
				local ownerIdValue = part:FindFirstChild("OwnerId")
				local vialIdValue = part:FindFirstChild("VialId")

				if ownerIdValue and vialIdValue and ownerIdValue.Value == tostring(player.UserId) then
					local vialId = vialIdValue.Value

					if not pendingPickups[vialId] then
						local distance = (rootPart.Position - part.Position).Magnitude
						if distance <= Constants.VIAL_PICKUP_RADIUS then
							pendingPickups[vialId] = true
							pickupVialRemote:FireServer(vialId)
						end
					end
				end
			end
		end
	end
end
