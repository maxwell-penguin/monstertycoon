local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local vialSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_SPAWNED) :: RemoteEvent
local vialRemovedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_REMOVED) :: RemoteEvent

vialSpawnedRemote.OnClientEvent:Connect(function(vialId: string, position: Vector3, rarity: string, element: string)
	local elementColor = Constants.ELEMENT_COLORS[element] or Color3.new(1, 1, 1)

	local part = Instance.new("Part")
	part.Name = "Vial_" .. vialId
	part.Size = Vector3.new(1.5, 1.5, 1.5)
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Color = elementColor
	part.Position = position

	local vialIdValue = Instance.new("StringValue")
	vialIdValue.Name = "VialId"
	vialIdValue.Value = vialId
	vialIdValue.Parent = part

	local ownerIdValue = Instance.new("StringValue")
	ownerIdValue.Name = "OwnerId"
	ownerIdValue.Value = tostring(player.UserId)
	ownerIdValue.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ElementLabel"
	billboard.Size = UDim2.new(0, 80, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.Parent = part

	local elementLabel = Instance.new("TextLabel")
	elementLabel.Size = UDim2.fromScale(1, 1)
	elementLabel.BackgroundTransparency = 1
	elementLabel.Font = Enum.Font.Gotham
	elementLabel.TextSize = 13
	elementLabel.TextColor3 = elementColor
	elementLabel.Text = element
	elementLabel.Parent = billboard

	part.Parent = Workspace

	if shared.ParticleManager then
		local emitter = shared.ParticleManager.CreateParticleEmitter(part, "vialGlow")
		if emitter then
			emitter.Color = ColorSequence.new(elementColor)
		end
	end

	if shared.SoundManager then
		shared.SoundManager.PlaySoundAtPosition("vialDrop", element, position)
	end
end)

vialRemovedRemote.OnClientEvent:Connect(function(vialId: string)
	local part = Workspace:FindFirstChild("Vial_" .. vialId)
	if part then
		part:Destroy()
	end

	-- Only a genuine pickup (fired by VialProximity's own attempt) should play the
	-- pickup sound -- the same event also fires for a vial despawning after sitting
	-- uncollected too long, which shouldn't sound like a success.
	local vialProximityState = shared.VialProximity
	if vialProximityState and vialProximityState.pendingPickups[vialId] and shared.SoundManager then
		shared.SoundManager.PlaySound("vialPickup")
	end
end)
