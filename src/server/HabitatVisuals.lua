local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local PlotManager = require(script.Parent.PlotManager)
local MonsterVisuals = require(script.Parent.MonsterVisuals)

local HabitatVisuals = {}

-- Height of the pad's flat top above the plot floor; monsters stand this far
-- above ground on top of it, mirroring SlotPad's own base height (6 studs) in
-- PlotSetup.server.lua.
local PAD_HEIGHT = 4
local STAND_Y_OFFSET = PAD_HEIGHT + 2

-- Keyed userId.."_"..habitatId, same convention as MonsterVisuals.activeBlobs.
local activeHabitats: { [string]: Model } = {}

local function habitatKey(userId: number, habitatId: string): string
	return userId .. "_" .. habitatId
end

local function newPart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material, transparency: number, cframe: CFrame, canCollide: boolean): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = canCollide
	part.CFrame = cframe
	return part
end

-- Biome-specific centerpiece decoration, built relative to the pad's local
-- origin (0,0,0) at the pad's top surface -- SpawnHabitat positions the whole
-- model, not these individual parts.
local CENTERPIECE_BUILDERS: { [string]: (Color3) -> { BasePart } } = {
	Volcano = function(color: Color3)
		local parts = {}
		table.insert(parts, newPart("Cone1", Enum.PartType.Cylinder, Vector3.new(3, 3, 3), color, Enum.Material.Slate, 0, CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), false))
		table.insert(parts, newPart("Cone2", Enum.PartType.Cylinder, Vector3.new(2, 1.6, 1.6), color, Enum.Material.Slate, 0, CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), false))
		table.insert(parts, newPart("Magma", Enum.PartType.Cylinder, Vector3.new(0.3, 1, 1), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, 0, CFrame.new(0, 3.9, 0) * CFrame.Angles(0, 0, math.rad(90)), false))
		return parts
	end,
	Waterfall = function(color: Color3)
		local parts = {}
		table.insert(parts, newPart("Rock1", Enum.PartType.Block, Vector3.new(1.5, 3, 1.5), Color3.fromRGB(70, 65, 60), Enum.Material.Rock, 0, CFrame.new(-1.5, 1.5, 0), false))
		table.insert(parts, newPart("Rock2", Enum.PartType.Block, Vector3.new(1.5, 4, 1.5), Color3.fromRGB(70, 65, 60), Enum.Material.Rock, 0, CFrame.new(1.5, 2, 0), false))
		table.insert(parts, newPart("Falls", Enum.PartType.Block, Vector3.new(2.6, 4, 0.4), color, Enum.Material.Glass, 0.3, CFrame.new(0, 2, 0), false))
		table.insert(parts, newPart("Pool", Enum.PartType.Cylinder, Vector3.new(0.2, 5, 5), color, Enum.Material.Glass, 0.2, CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), false))
		return parts
	end,
	Sunfield = function(color: Color3)
		local parts = {}
		table.insert(parts, newPart("Dome", Enum.PartType.Ball, Vector3.new(3, 3, 3), color, Enum.Material.Neon, 0.4, CFrame.new(0, 2.5, 0), false))
		for i = 1, 3 do
			local angle = math.rad((i - 1) * 120)
			table.insert(parts, newPart("Petal" .. i, Enum.PartType.Ball, Vector3.new(1, 1, 1), color, Enum.Material.Neon, 0.2, CFrame.new(math.cos(angle) * 2.5, 1, math.sin(angle) * 2.5), false))
		end
		return parts
	end,
	Crypt = function(color: Color3)
		local parts = {}
		for i = 1, 3 do
			local angle = math.rad((i - 1) * 120 + 60)
			table.insert(parts, newPart("Spire" .. i, Enum.PartType.Block, Vector3.new(0.8, 3 + i * 0.6, 0.8), Color3.fromRGB(30, 28, 40), Enum.Material.Slate, 0, CFrame.new(math.cos(angle) * 2, (3 + i * 0.6) / 2, math.sin(angle) * 2) * CFrame.Angles(0, angle, 0), false))
		end
		table.insert(parts, newPart("Glow", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8), color, Enum.Material.Neon, 0.1, CFrame.new(0, 1, 0), false))
		return parts
	end,
	VoidRift = function(color: Color3)
		local parts = {}
		table.insert(parts, newPart("Rift", Enum.PartType.Cylinder, Vector3.new(0.4, 3.2, 3.2), color, Enum.Material.Neon, 0.15, CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)), false))
		table.insert(parts, newPart("RiftCore", Enum.PartType.Ball, Vector3.new(1, 1, 1), Color3.fromRGB(10, 10, 15), Enum.Material.Neon, 0, CFrame.new(0, 2, 0), false))
		return parts
	end,
	MemoryGarden = function(color: Color3)
		local parts = {}
		for i = 1, 3 do
			local angle = math.rad((i - 1) * 120)
			table.insert(parts, newPart("Orb" .. i, Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8), color, Enum.Material.Neon, 0.3, CFrame.new(math.cos(angle) * 2, 2 + i * 0.3, math.sin(angle) * 2), false))
		end
		table.insert(parts, newPart("Pillar", Enum.PartType.Cylinder, Vector3.new(3, 0.6, 0.6), color, Enum.Material.Neon, 0.5, CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), false))
		return parts
	end,
}

function HabitatVisuals.BuildHabitatModel(biomeType: string): Model
	local biomeDef
	for _, def in Constants.HABITAT_TYPES do
		if def.biomeType == biomeType then
			biomeDef = def
			break
		end
	end

	local color = (biomeDef and Constants.EMOTION_COLORS[biomeDef.emotion]) or Color3.new(1, 1, 1)
	local footprint = Constants.HABITAT_FOOTPRINT

	local model = Instance.new("Model")
	model.Name = "Habitat_" .. biomeType

	local pad = newPart(
		"Pad",
		Enum.PartType.Cylinder,
		Vector3.new(PAD_HEIGHT, footprint.width, footprint.depth),
		color,
		Enum.Material.SmoothPlastic,
		0,
		CFrame.new(0, PAD_HEIGHT / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		true
	)
	pad.Parent = model
	model.PrimaryPart = pad

	local ring = newPart(
		"Ring",
		Enum.PartType.Cylinder,
		Vector3.new(0.2, footprint.width + 0.6, footprint.depth + 0.6),
		color,
		Enum.Material.Neon,
		0.4,
		CFrame.new(0, PAD_HEIGHT + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		false
	)
	ring.Parent = model

	local builder = CENTERPIECE_BUILDERS[biomeType]
	if builder then
		for _, part in builder(color) do
			part.CFrame = CFrame.new(0, PAD_HEIGHT, 0) * part.CFrame
			part.Parent = model
		end
	end

	-- HabitatClient.client.lua wires this to open the assign/unslot UI --
	-- clicking an empty habitat opens the Warehouse monster picker, clicking an
	-- occupied one unslots it, mirroring the Hall pedestal grid's click behavior.
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.Name = "AssignClickDetector"
	clickDetector.MaxActivationDistance = 20
	clickDetector.Parent = pad

	local stand = Instance.new("Part")
	stand.Name = "MonsterStand"
	stand.Size = Vector3.new(1, 1, 1)
	stand.Transparency = 1
	stand.Anchored = true
	stand.CanCollide = false
	stand.CFrame = CFrame.new(0, STAND_Y_OFFSET, 0)
	stand.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BiomeLabel"
	billboard.Size = UDim2.new(0, 140, 0, 24)
	billboard.StudsOffset = Vector3.new(0, PAD_HEIGHT + 1, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = (biomeDef and biomeDef.displayName) or biomeType
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	return model
end

function HabitatVisuals.SpawnHabitat(player: Player, habitat: { habitatId: string, biomeType: string, placement: { x: number, z: number, rotationY: number } })
	local plotModel = PlotManager.GetPlayerPlot(player)
	if not plotModel then
		return
	end

	local origin = PlotManager.GetPlotOrigin(player)
	if not origin then
		return
	end

	HabitatVisuals.DespawnHabitat(player, habitat.habitatId)

	local model = HabitatVisuals.BuildHabitatModel(habitat.biomeType)
	model.Name = "Habitat_" .. habitat.habitatId

	local placementCFrame = origin
		* CFrame.new(habitat.placement.x, 0, habitat.placement.z)
		* CFrame.Angles(0, habitat.placement.rotationY, 0)

	model:PivotTo(placementCFrame)
	model.Parent = plotModel

	activeHabitats[habitatKey(player.UserId, habitat.habitatId)] = model
end

function HabitatVisuals.DespawnHabitat(player: Player, habitatId: string)
	local key = habitatKey(player.UserId, habitatId)
	local model = activeHabitats[key]
	if not model then
		return
	end

	model:Destroy()
	activeHabitats[key] = nil
end

-- Pure math, no dependency on the spawned model existing -- mirrors
-- SlotPositioner.GetSlotWorldPosition's approach of deriving position from the
-- plot origin + stored offsets rather than reading a live Part. Ground-level
-- (not the elevated MonsterStand height) so VialProducer's own Y_OFFSET float
-- height lands vials at the same height above ground as Hall pedestal vials.
function HabitatVisuals.GetGroundWorldPosition(player: Player, habitat: { placement: { x: number, z: number, rotationY: number } }): Vector3?
	local origin = PlotManager.GetPlotOrigin(player)
	if not origin then
		return nil
	end

	return origin:PointToWorldSpace(Vector3.new(habitat.placement.x, 0, habitat.placement.z))
end

function HabitatVisuals.SpawnMonsterOnHabitat(player: Player, habitatId: string, monsterName: string, emotion: string, rarity: string)
	local key = habitatKey(player.UserId, habitatId)
	local model = activeHabitats[key]
	if not model then
		return
	end

	local stand = model:FindFirstChild("MonsterStand")
	if not stand or not stand:IsA("BasePart") then
		return
	end

	-- Named per-habitat (not just "HabitatMonster") because MonsterVisuals'
	-- idle-animation cancellation is keyed off plotModel.Name.."_"..blobName --
	-- a constant name here would collide across multiple habitats in the same
	-- plot, so stopping one habitat's animation would also stop another's.
	local blobName = "HabitatMonster_" .. habitatId
	local existingBlob = model:FindFirstChild(blobName)
	if existingBlob then
		existingBlob:Destroy()
	end

	local blob = MonsterVisuals.BuildBlob(emotion, rarity)
	blob.Name = blobName
	blob:PivotTo(stand.CFrame)
	blob.Parent = model

	MonsterVisuals.StartIdleAnimation(blob, emotion)
end

function HabitatVisuals.RemoveMonsterFromHabitat(player: Player, habitatId: string)
	local key = habitatKey(player.UserId, habitatId)
	local model = activeHabitats[key]
	if not model then
		return
	end

	local existingBlob = model:FindFirstChild("HabitatMonster_" .. habitatId)
	if existingBlob then
		existingBlob:Destroy()
	end
end

function HabitatVisuals.ClearPlayerHabitats(player: Player)
	local userId = player.UserId
	local prefix = userId .. "_"
	local toRemove = {}
	for key, model in activeHabitats do
		if key:sub(1, #prefix) == prefix then
			table.insert(toRemove, key)
			model:Destroy()
		end
	end
	for _, key in toRemove do
		activeHabitats[key] = nil
	end
end

return HabitatVisuals
