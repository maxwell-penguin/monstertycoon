local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local vialSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_SPAWNED) :: RemoteEvent
local vialRemovedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_REMOVED) :: RemoteEvent

vialSpawnedRemote.OnClientEvent:Connect(function(vialId: string, position: Vector3, rarity: string, emotion: string)
	local part = Instance.new("Part")
	part.Name = "Vial_" .. vialId
	part.Size = Vector3.new(1.5, 1.5, 1.5)
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Color = Constants.EMOTION_COLORS[emotion] or Color3.new(1, 1, 1)
	part.Position = position

	local vialIdValue = Instance.new("StringValue")
	vialIdValue.Name = "VialId"
	vialIdValue.Value = vialId
	vialIdValue.Parent = part

	local ownerIdValue = Instance.new("StringValue")
	ownerIdValue.Name = "OwnerId"
	ownerIdValue.Value = tostring(player.UserId)
	ownerIdValue.Parent = part

	part.Parent = Workspace
end)

vialRemovedRemote.OnClientEvent:Connect(function(vialId: string)
	local part = Workspace:FindFirstChild("Vial_" .. vialId)
	if part then
		part:Destroy()
	end
end)
