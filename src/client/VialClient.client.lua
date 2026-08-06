local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local vialSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_SPAWNED) :: RemoteEvent
local vialRemovedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_REMOVED) :: RemoteEvent

-- A Roblox Cylinder's axis runs along its local X by default, so rotating 90
-- degrees about Z stands it upright: local X becomes the vertical (thin/tall)
-- axis and local Y/Z become the horizontal circular footprint.
local UPRIGHT_CYLINDER = CFrame.Angles(0, 0, math.rad(90))

-- The farm is flat ground (no pedestals), so the stage Y values are computed
-- from ground level rather than from vialSpawnedRemote's position.Y -- that
-- field is the vial's final resting height (VialProducer's Y_OFFSET), not any
-- of the earlier stages' heights.
local GROUND_Y = 0
local DROPLET_START_Y = GROUND_Y + 3 -- roughly monster height, wherever it's standing
local PUDDLE_Y = GROUND_Y + 0.1
local VIAL_FLOAT_Y = GROUND_Y + 1 -- ground level + 1 stud

-- Keyed by vialId, holds every Part/light/emitter created for that vial across
-- all three animation stages so VIAL_REMOVED can wipe them regardless of which
-- stage is currently playing.
local activeParts: { [string]: { Instance } } = {}
-- Never cleared once set: vialIds are GUIDs that are never reused, so a stale
-- entry is harmless, but clearing it would race against an in-flight stage
-- tween's Completed firing after removal and resurrecting the vial.
local cancelled: { [string]: boolean } = {}

local function track(vialId: string, instance: Instance)
	local list = activeParts[vialId]
	if not list then
		list = {}
		activeParts[vialId] = list
	end
	table.insert(list, instance)
end

local function cleanup(vialId: string)
	cancelled[vialId] = true
	local list = activeParts[vialId]
	if list then
		for _, instance in list do
			instance:Destroy()
		end
		activeParts[vialId] = nil
	end
end

local spawnVial

local function spawnPuddle(vialId: string, position: Vector3, emotion: string, emotionColor: Color3)
	if cancelled[vialId] then
		return
	end

	local puddle = Instance.new("Part")
	puddle.Name = "Puddle_" .. vialId
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Anchored = true
	puddle.CanCollide = false
	puddle.Material = Enum.Material.Neon
	puddle.Color = emotionColor
	puddle.Transparency = 0.2
	puddle.CFrame = CFrame.new(position) * UPRIGHT_CYLINDER
	puddle.Size = Vector3.new(0.1, 0.3, 0.3)
	puddle.Parent = Workspace
	track(vialId, puddle)

	local light = Instance.new("PointLight")
	light.Brightness = 1.5
	light.Range = 6
	light.Color = emotionColor
	light.Parent = puddle

	if shared.ParticleManager then
		local emitter = shared.ParticleManager.CreateParticleEmitter(puddle, "puddleSwirl")
		if emitter then
			emitter.Color = ColorSequence.new(emotionColor)
		end
	end

	local spreadTween = TweenService:Create(
		puddle,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.1, 2.5, 2.5), Transparency = 0.4 }
	)
	spreadTween.Completed:Connect(function()
		task.delay(1, function()
			if not cancelled[vialId] then
				spawnVial(vialId, position, emotion, emotionColor)
			end
		end)
	end)
	spreadTween:Play()
end

local function spawnDroplet(vialId: string, position: Vector3, emotion: string, emotionColor: Color3)
	local startPosition = Vector3.new(position.X, DROPLET_START_Y, position.Z)
	local landPosition = Vector3.new(position.X, PUDDLE_Y, position.Z)

	local droplet = Instance.new("Part")
	droplet.Name = "Droplet_" .. vialId
	droplet.Shape = Enum.PartType.Ball
	droplet.Anchored = true
	droplet.CanCollide = false
	droplet.Color = emotionColor
	droplet.Size = Vector3.new(0.3, 0.3, 0.3)
	droplet.Position = startPosition
	droplet.Parent = Workspace
	track(vialId, droplet)

	local fallTween = TweenService:Create(
		droplet,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = landPosition }
	)
	fallTween.Completed:Connect(function()
		droplet:Destroy()
		if not cancelled[vialId] then
			spawnPuddle(vialId, landPosition, emotion, emotionColor)
		end
	end)
	fallTween:Play()
end

local function startBob(vial: BasePart)
	local basePosition = vial.Position
	TweenService:Create(
		vial,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = basePosition + Vector3.new(0, 0.2, 0) }
	):Play()
end

function spawnVial(vialId: string, position: Vector3, emotion: string, emotionColor: Color3)
	local puddle = Workspace:FindFirstChild("Puddle_" .. vialId)
	if puddle then
		puddle:Destroy()
	end

	local startPosition = Vector3.new(position.X, PUDDLE_Y, position.Z)
	local floatPosition = Vector3.new(position.X, VIAL_FLOAT_Y, position.Z)

	local vial = Instance.new("Part")
	vial.Name = "Vial_" .. vialId
	vial.Shape = Enum.PartType.Cylinder
	vial.Anchored = true
	vial.CanCollide = false
	vial.Material = Enum.Material.Neon
	vial.Color = emotionColor
	vial.Transparency = 0.1
	vial.CFrame = CFrame.new(startPosition) * UPRIGHT_CYLINDER
	vial.Size = Vector3.new(1.4, 0.7, 0.7)
	vial.Parent = Workspace
	track(vialId, vial)

	local vialIdValue = Instance.new("StringValue")
	vialIdValue.Name = "VialId"
	vialIdValue.Value = vialId
	vialIdValue.Parent = vial

	local ownerIdValue = Instance.new("StringValue")
	ownerIdValue.Name = "OwnerId"
	ownerIdValue.Value = tostring(player.UserId)
	ownerIdValue.Parent = vial

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 8
	light.Color = emotionColor
	light.Parent = vial

	local riseTween = TweenService:Create(
		vial,
		TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(floatPosition) * UPRIGHT_CYLINDER }
	)
	riseTween.Completed:Connect(function()
		if not cancelled[vialId] then
			startBob(vial)
		end
	end)
	riseTween:Play()
end

vialSpawnedRemote.OnClientEvent:Connect(function(vialId: string, position: Vector3, _rarity: string, emotion: string)
	cancelled[vialId] = nil
	local emotionColor = Constants.EMOTION_COLORS[emotion] or Color3.new(1, 1, 1)

	if shared.SoundManager then
		shared.SoundManager.PlaySoundAtPosition("vialDrop", emotion, position)
	end

	spawnDroplet(vialId, position, emotion, emotionColor)
end)

vialRemovedRemote.OnClientEvent:Connect(function(vialId: string)
	local vial = Workspace:FindFirstChild("Vial_" .. vialId)
	if vial and vial:IsA("BasePart") then
		local collectTween = TweenService:Create(
			vial,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = Vector3.new(0, 0, 0), CFrame = vial.CFrame + Vector3.new(0, 1, 0), Transparency = 1 }
		)
		collectTween.Completed:Connect(function()
			cleanup(vialId)
		end)
		collectTween:Play()
	else
		cleanup(vialId)
	end

	-- Only a genuine pickup (fired by VialProximity's own attempt) should play the
	-- pickup sound -- the same event also fires for a vial despawning after sitting
	-- uncollected too long, which shouldn't sound like a success.
	local vialProximityState = shared.VialProximity
	if vialProximityState and vialProximityState.pendingPickups[vialId] and shared.SoundManager then
		shared.SoundManager.PlaySound("vialPickup")
	end
end)
