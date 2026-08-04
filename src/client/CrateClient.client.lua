local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local crateSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.CRATE_SPAWNED) :: RemoteEvent
local openCrateRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.OPEN_CRATE) :: RemoteEvent
local eggResultRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.EGG_RESULT) :: RemoteEvent

local PROXIMITY_RADIUS = 15
local FALL_DURATION = 2

local activeCrates: { [string]: Vector3 } = {}
local pendingClaims: { [string]: boolean } = {}

local function spawnCratePart(crateId: string, spawnPosition: Vector3, landingPosition: Vector3)
	local part = Instance.new("Part")
	part.Name = "Crate_" .. crateId
	part.Size = Vector3.new(4, 4, 4)
	part.BrickColor = BrickColor.new("New Yeller")
	part.Anchored = true
	part.CanCollide = false
	part.Position = spawnPosition
	part.Parent = Workspace

	local fallTween =
		TweenService:Create(part, TweenInfo.new(FALL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = landingPosition,
		})
	fallTween:Play()

	fallTween.Completed:Connect(function()
		if not part.Parent then
			return
		end

		if shared.SoundManager then
			shared.SoundManager.PlaySoundAtPosition("crateDrop", nil, landingPosition)
		end

		TweenService:Create(
			part,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Size = Vector3.new(4.5, 4.5, 4.5) }
		):Play()
	end)
end

crateSpawnedRemote.OnClientEvent:Connect(function(crateId: string, spawnPosition: Vector3, landingPosition: Vector3)
	activeCrates[crateId] = landingPosition
	spawnCratePart(crateId, spawnPosition, landingPosition)
end)

eggResultRemote.OnClientEvent:Connect(function(result: any)
	if typeof(result) ~= "table" or not result.isCrate or not result.crateId then
		return
	end

	local crateId = result.crateId
	activeCrates[crateId] = nil
	pendingClaims[crateId] = nil

	local part = Workspace:FindFirstChild("Crate_" .. crateId)
	if part then
		part:Destroy()
	end

	if shared.SoundManager then
		shared.SoundManager.PlaySound("crateOpen")
	end
end)

while true do
	task.wait(0.5)

	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)

	if rootPart then
		for crateId, landingPosition in activeCrates do
			if not pendingClaims[crateId] then
				local distance = (rootPart.Position - landingPosition).Magnitude
				if distance <= PROXIMITY_RADIUS then
					pendingClaims[crateId] = true
					openCrateRemote:FireServer(crateId)
				end
			end
		end
	end
end
