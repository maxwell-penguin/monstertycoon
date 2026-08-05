local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")

local Constants = require(ReplicatedStorage.Constants)

local PLOT_COUNT = 10
local PLOTS_PER_ROW = 5
local X_SPACING = 80
local Z_SPACING = 100

local COLLISION_GROUP = "PlotGround"

pcall(function()
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
end)

local function setCollisionGroup(part: BasePart)
	part.CollisionGroup = COLLISION_GROUP
end

local STAR_COUNT = 200
local STAR_MIN_RADIUS = 400
local STAR_MAX_RADIUS = 600
local STAR_MIN_Y = 50
local STAR_COLORS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(200, 180, 255),
	Color3.fromRGB(180, 200, 255),
	Color3.fromRGB(255, 200, 180),
}

local NEBULA_COUNT = 5
local NEBULA_MIN_SIZE = 80
local NEBULA_MAX_SIZE = 150
local NEBULA_MIN_Y = 150
local NEBULA_MAX_Y = 250
local NEBULA_HORIZONTAL_RANGE = 500
local NEBULA_COLORS = {
	Color3.fromRGB(40, 20, 80),
	Color3.fromRGB(60, 15, 60),
	Color3.fromRGB(20, 30, 80),
}

-- Fixed so the star/nebula layout is identical every server start. A
-- dedicated Random object rather than math.randomseed -- reseeding the
-- global RNG would make every OTHER math.random() call on the server
-- (egg rarity, vial offsets, etc.) deterministic too, which is not the point.
local VOID_SKY_SEED = 20260805

-- Uniform point on the sphere of the given radius range, retried (a few
-- times, at most) until it lands above minY so stars only appear in the sky.
local function randomUpperSpherePosition(rng: Random, minRadius: number, maxRadius: number, minY: number): Vector3
	for _ = 1, 20 do
		local y = rng:NextNumber(-1, 1)
		local horizontal = math.sqrt(1 - y * y)
		local phi = rng:NextNumber(0, 2 * math.pi)
		local direction = Vector3.new(horizontal * math.cos(phi), y, horizontal * math.sin(phi))
		local position = direction * rng:NextNumber(minRadius, maxRadius)
		if position.Y > minY then
			return position
		end
	end
	return Vector3.new(0, maxRadius, 0)
end

local function createVoidSky()
	local rng = Random.new(VOID_SKY_SEED)

	local voidSky = Instance.new("Model")
	voidSky.Name = "VoidSky"
	voidSky.Parent = Workspace

	for i = 1, STAR_COUNT do
		local size = rng:NextNumber(0.3, 0.8)

		local star = Instance.new("Part")
		star.Name = "Star_" .. i
		star.Shape = Enum.PartType.Ball
		star.Size = Vector3.new(size, size, size)
		star.Material = Enum.Material.Neon
		star.Color = STAR_COLORS[rng:NextInteger(1, #STAR_COLORS)]
		star.Anchored = true
		star.CanCollide = false
		star.CastShadow = false
		star.Position = randomUpperSpherePosition(rng, STAR_MIN_RADIUS, STAR_MAX_RADIUS, STAR_MIN_Y)
		star.Parent = voidSky
	end

	for i = 1, NEBULA_COUNT do
		local size = rng:NextNumber(NEBULA_MIN_SIZE, NEBULA_MAX_SIZE)

		local nebula = Instance.new("Part")
		nebula.Name = "Nebula_" .. i
		nebula.Shape = Enum.PartType.Ball
		nebula.Size = Vector3.new(size, size, size)
		nebula.Material = Enum.Material.Neon
		nebula.Color = NEBULA_COLORS[((i - 1) % #NEBULA_COLORS) + 1]
		nebula.Transparency = 0.95
		nebula.Anchored = true
		nebula.CanCollide = false
		nebula.CastShadow = false
		nebula.Position = Vector3.new(
			rng:NextNumber(-NEBULA_HORIZONTAL_RANGE, NEBULA_HORIZONTAL_RANGE),
			rng:NextNumber(NEBULA_MIN_Y, NEBULA_MAX_Y),
			rng:NextNumber(-NEBULA_HORIZONTAL_RANGE, NEBULA_HORIZONTAL_RANGE)
		)
		nebula.Parent = voidSky
	end

	local lightHolder = Instance.new("Part")
	lightHolder.Name = "VoidLight"
	lightHolder.Anchored = true
	lightHolder.CanCollide = false
	lightHolder.CastShadow = false
	lightHolder.Transparency = 1
	lightHolder.Size = Vector3.new(1, 1, 1)
	lightHolder.Position = Vector3.new(0, 200, 0)
	lightHolder.Parent = voidSky

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 500
	light.Color = Color3.fromRGB(60, 30, 100)
	light.Parent = lightHolder
end

local function setupVoidAtmosphere()
	Lighting.Ambient = Color3.fromRGB(15, 10, 30)
	Lighting.OutdoorAmbient = Color3.fromRGB(8, 5, 18)
	Lighting.Brightness = 0
	Lighting.ClockTime = 0
	Lighting.FogEnd = 400
	Lighting.FogStart = 200
	Lighting.FogColor = Color3.fromRGB(5, 3, 15)

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.4
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(80, 60, 120)
	atmosphere.Decay = Color3.fromRGB(20, 10, 40)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.5
	atmosphere.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Brightness = -0.05
	colorCorrection.Contrast = 0.1
	colorCorrection.Saturation = -0.1
	colorCorrection.TintColor = Color3.fromRGB(200, 180, 255)
	colorCorrection.Parent = Lighting

	createVoidSky()
end

setupVoidAtmosphere()

-- A Roblox Cylinder's axis runs along local X by default -- unrotated it lies
-- on its side. Standing it upright (flat round face pointing along world Y)
-- requires this 90-degree-about-Z rotation regardless of orientation intent.
local UPRIGHT_CYLINDER = CFrame.Angles(0, 0, math.rad(90))

-- Once UPRIGHT_CYLINDER is applied, local X becomes the vertical axis and
-- local Y/Z (which must match for a true circle) become the horizontal
-- footprint -- so a Part.Size is built as (thickness, diameter, diameter).
local function padSize(diameter: number, thickness: number): Vector3
	return Vector3.new(thickness, diameter, diameter)
end

local HALL_COLUMNS = 3
local HALL_COLUMN_SPACING = 10
local HALL_ROW_SPACING = 10
-- Hall grid center sits 10 studs back (toward -Z) from PlotOrigin. Row count
-- is fixed to the maximum hall tier (not any player's current tier) so pad
-- positions never shift as a hall upgrades -- only TopGlow/Ring Transparency
-- changes. SlotPositioner.lua mirrors this exact math so runtime vial spawn
-- points always land on the matching pad.
local HALL_ORIGIN_OFFSET = Vector3.new(0, 0, -10)
local TOTAL_HALL_SLOTS = Constants.HALL_SLOT_COUNTS[5]
local TOTAL_HALL_ROWS = math.ceil(TOTAL_HALL_SLOTS / HALL_COLUMNS)
-- Visual-only cutoff, not the real hall tier 1 slot count (Constants.HALL_SLOT_COUNTS[1] stays
-- 9) -- only the first 3 pedestals are built visible/collidable at server start.
local VISIBLE_HALL_SLOTS = 3

local function getSlotOffset(slotIndex: number): Vector3
	local col = (slotIndex - 1) % HALL_COLUMNS
	local row = math.floor((slotIndex - 1) / HALL_COLUMNS)
	local colOffset = (col - (HALL_COLUMNS - 1) / 2) * HALL_COLUMN_SPACING
	local rowOffset = (row - (TOTAL_HALL_ROWS - 1) / 2) * HALL_ROW_SPACING
	return HALL_ORIGIN_OFFSET + Vector3.new(colOffset, 0, rowOffset)
end

local function createCylinder(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	cframe: CFrame,
	canCollide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = canCollide
	part.Material = material
	part.Color = color
	part.Transparency = transparency
	part.Size = size
	part.CFrame = cframe
	return part
end

local PLOT_WIDTH = 60 -- matches Ground.Size.X below
local PLOT_DEPTH = 80 -- matches Ground.Size.Z below
local BORDER_WALL_HEIGHT = 8
local BORDER_WALL_THICKNESS = 0.3
local BORDER_WALL_COLOR = Color3.fromRGB(60, 40, 100)
local BORDER_POST_COLOR = Color3.fromRGB(100, 70, 160)

local function createBorderWall(name: string, size: Vector3, position: Vector3): Part
	local wall = Instance.new("Part")
	wall.Name = name
	wall.Anchored = true
	wall.CanCollide = false
	wall.Material = Enum.Material.Neon
	wall.Color = BORDER_WALL_COLOR
	wall.Transparency = 0.85
	wall.Size = size
	wall.Position = position
	return wall
end

-- Faint boundary walls (see-through) plus 4 brighter corner posts, sized off
-- the Ground Part's own footprint so they always match its edges.
local function createPlotBorder(plotModel: Model, gridPosition: Vector3)
	local wallY = gridPosition.Y + BORDER_WALL_HEIGHT / 2
	local halfWidth = PLOT_WIDTH / 2
	local halfDepth = PLOT_DEPTH / 2

	local walls = {
		createBorderWall(
			"BorderWall_1",
			Vector3.new(PLOT_WIDTH, BORDER_WALL_HEIGHT, BORDER_WALL_THICKNESS),
			gridPosition + Vector3.new(0, BORDER_WALL_HEIGHT / 2, halfDepth)
		),
		createBorderWall(
			"BorderWall_2",
			Vector3.new(PLOT_WIDTH, BORDER_WALL_HEIGHT, BORDER_WALL_THICKNESS),
			gridPosition + Vector3.new(0, BORDER_WALL_HEIGHT / 2, -halfDepth)
		),
		createBorderWall(
			"BorderWall_3",
			Vector3.new(BORDER_WALL_THICKNESS, BORDER_WALL_HEIGHT, PLOT_DEPTH),
			gridPosition + Vector3.new(halfWidth, BORDER_WALL_HEIGHT / 2, 0)
		),
		createBorderWall(
			"BorderWall_4",
			Vector3.new(BORDER_WALL_THICKNESS, BORDER_WALL_HEIGHT, PLOT_DEPTH),
			gridPosition + Vector3.new(-halfWidth, BORDER_WALL_HEIGHT / 2, 0)
		),
	}
	for _, wall in walls do
		wall.Parent = plotModel
	end

	local postSize = padSize(0.4, BORDER_WALL_HEIGHT)
	local corners = {
		Vector3.new(halfWidth, wallY, halfDepth),
		Vector3.new(halfWidth, wallY, -halfDepth),
		Vector3.new(-halfWidth, wallY, halfDepth),
		Vector3.new(-halfWidth, wallY, -halfDepth),
	}
	for i, corner in corners do
		local post = createCylinder(
			"BorderPost_" .. i,
			postSize,
			BORDER_POST_COLOR,
			Enum.Material.Neon,
			0.6,
			CFrame.new(gridPosition + corner) * UPRIGHT_CYLINDER,
			false
		)
		post.Parent = plotModel
	end
end

local function createSlotPad(plotModel: Model, gridPosition: Vector3, slotIndex: number)
	local groundY = gridPosition.Y
	local offset = getSlotOffset(slotIndex)
	local slotX = gridPosition.X + offset.X
	local slotZ = gridPosition.Z + offset.Z

	local function padCFrame(y: number): CFrame
		return CFrame.new(slotX, y, slotZ) * UPRIGHT_CYLINDER
	end

	local slotModel = Instance.new("Model")
	slotModel.Name = "SlotPad_" .. slotIndex
	slotModel.Parent = plotModel

	local isVisible = slotIndex <= VISIBLE_HALL_SLOTS
	local GLOW_BLUE = Color3.fromRGB(120, 190, 255)
	-- Default/empty color for TopGlow and Ring (HallClient.client.lua tweens
	-- to this on unslot, and to the emotion color on slot -- must match its
	-- own DIM_PURPLE or an empty pedestal looks different fresh vs. after a
	-- slot/unslot cycle).
	local DIM_PURPLE = Color3.fromRGB(40, 30, 80)

	-- Sits on the ground (bottom at groundY), top face at groundY + 6.
	local base = createCylinder(
		"Base",
		padSize(3, 6),
		Color3.fromRGB(18, 14, 32),
		Enum.Material.Metal,
		isVisible and 0 or 1,
		padCFrame(groundY + 3),
		isVisible
	)
	setCollisionGroup(base)
	base.Parent = slotModel

	local VEIN_COLOR = Color3.fromRGB(80, 50, 140)
	local VEIN_OFFSET = 1.4
	for i = 1, 4 do
		local angle = math.rad((i - 1) * 90)

		local vein = Instance.new("Part")
		vein.Name = "Vein_" .. i
		vein.Anchored = true
		vein.CanCollide = false
		vein.Material = Enum.Material.Neon
		vein.Color = VEIN_COLOR
		vein.Transparency = isVisible and 0 or 1
		vein.Size = Vector3.new(0.08, 5.8, 0.08)
		vein.Position =
			Vector3.new(slotX + VEIN_OFFSET * math.cos(angle), groundY + 3, slotZ + VEIN_OFFSET * math.sin(angle))
		vein.Parent = slotModel
	end

	local topGlow = createCylinder(
		"TopGlow",
		padSize(2.8, 0.15),
		DIM_PURPLE,
		Enum.Material.Neon,
		isVisible and 0.3 or 1,
		padCFrame(groundY + 6.05),
		false
	)
	topGlow.Parent = slotModel

	local ring = createCylinder(
		"Ring",
		padSize(3.6, 0.2),
		DIM_PURPLE,
		Enum.Material.Neon,
		isVisible and 0.5 or 1,
		padCFrame(groundY + 0.1),
		false
	)
	ring.Parent = slotModel

	local midRing = createCylinder(
		"MidRing",
		padSize(3.2, 0.15),
		GLOW_BLUE,
		Enum.Material.Neon,
		isVisible and 0.7 or 1,
		padCFrame(groundY + 3),
		false
	)
	midRing.Parent = slotModel

	local RUNE_COLOR = Color3.fromRGB(50, 30, 90)

	local rune = createCylinder(
		"Rune",
		padSize(7, 0.1),
		RUNE_COLOR,
		Enum.Material.Neon,
		isVisible and 0.8 or 1,
		padCFrame(groundY + 0.05),
		false
	)
	rune.Parent = slotModel

	local runeInner = createCylinder(
		"RuneInner",
		padSize(4, 0.1),
		RUNE_COLOR,
		Enum.Material.Neon,
		isVisible and 0.85 or 1,
		padCFrame(groundY + 0.06),
		false
	)
	runeInner.Parent = slotModel

	-- Shown only while the slot is empty; HallClient.client.lua hides it
	-- (Transparency 1) on slot and restores it on unslot.
	local crystal = Instance.new("WedgePart")
	crystal.Name = "Crystal"
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.Material = Enum.Material.Neon
	crystal.Color = Color3.fromRGB(100, 70, 180)
	crystal.Transparency = isVisible and 0.4 or 1
	crystal.Size = Vector3.new(0.6, 1.2, 0.6)
	crystal.CFrame = CFrame.new(slotX, groundY + 6 + 2, slotZ) * CFrame.Angles(0, math.rad(45), 0)
	crystal.Parent = slotModel

	local slotIndexValue = Instance.new("IntValue")
	slotIndexValue.Name = "SlotIndex"
	slotIndexValue.Value = slotIndex
	slotIndexValue.Parent = slotModel

	local isOccupied = Instance.new("BoolValue")
	isOccupied.Name = "IsOccupied"
	isOccupied.Value = false
	isOccupied.Parent = slotModel
end

-- Same -30 Z offset used by the Dropbox CFrame further down in createPlot --
-- the platform/pillars only need this constant, not the Dropbox instance
-- itself, so they don't care that Dropbox is built later in createPlot.
local DROPBOX_Z_OFFSET = -30
local HQ_CENTER_Z = 35
local WAREHOUSE_WALL_Z = 28

local function createFloorVeins(plotModel: Model, gridPosition: Vector3)
	local veinYOffset = 0.08
	local veinColor = Color3.fromRGB(40, 25, 70)
	local halfWidth = PLOT_WIDTH / 2
	local halfDepth = PLOT_DEPTH / 2

	for i = 1, 6 do
		local z = -halfDepth + i * (PLOT_DEPTH / 7)

		local horizontal = Instance.new("Part")
		horizontal.Name = "FloorVein_H_" .. i
		horizontal.Anchored = true
		horizontal.CanCollide = false
		horizontal.Material = Enum.Material.Neon
		horizontal.Color = veinColor
		horizontal.Transparency = 0.7
		horizontal.Size = Vector3.new(PLOT_WIDTH, 0.06, 0.08)
		horizontal.Position = gridPosition + Vector3.new(0, veinYOffset, z)
		horizontal.Parent = plotModel
	end

	for i = 1, 6 do
		local x = -halfWidth + i * (PLOT_WIDTH / 7)

		local vertical = Instance.new("Part")
		vertical.Name = "FloorVein_V_" .. i
		vertical.Anchored = true
		vertical.CanCollide = false
		vertical.Material = Enum.Material.Neon
		vertical.Color = veinColor
		vertical.Transparency = 0.7
		vertical.Size = Vector3.new(0.08, 0.06, PLOT_DEPTH)
		vertical.Position = gridPosition + Vector3.new(x, veinYOffset, 0)
		vertical.Parent = plotModel
	end
end

local function createHeadquarters(plotModel: Model, gridPosition: Vector3)
	local hqColor = Color3.fromRGB(18, 14, 32)
	local veinGlowColor = Color3.fromRGB(80, 50, 140)

	local hqModel = Instance.new("Model")
	hqModel.Name = "Headquarters"
	hqModel.Parent = plotModel

	local base = Instance.new("Part")
	base.Name = "HQBase"
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.SmoothPlastic
	base.Color = hqColor
	base.Size = Vector3.new(30, 8, 10)
	base.Position = gridPosition + Vector3.new(0, 4, HQ_CENTER_Z)
	setCollisionGroup(base)
	base.Parent = hqModel

	local towerOffsetX = base.Size.X / 2 - 3
	for _, side in { { name = "L", sign = -1 }, { name = "R", sign = 1 } } do
		local tower = Instance.new("Part")
		tower.Name = "HQTower_" .. side.name
		tower.Anchored = true
		tower.CanCollide = true
		tower.Material = Enum.Material.SmoothPlastic
		tower.Color = hqColor
		tower.Size = Vector3.new(6, 14, 6)
		tower.Position = gridPosition + Vector3.new(side.sign * towerOffsetX, 7, HQ_CENTER_Z)
		setCollisionGroup(tower)
		tower.Parent = hqModel

		local towerGlow = createCylinder(
			"HQTowerGlow_" .. side.name,
			padSize(6.2, 0.4),
			veinGlowColor,
			Enum.Material.Neon,
			0.3,
			CFrame.new(tower.Position + Vector3.new(0, 7.2, 0)) * UPRIGHT_CYLINDER,
			false
		)
		towerGlow.Parent = hqModel
	end

	local antenna = Instance.new("Part")
	antenna.Name = "Antenna"
	antenna.Anchored = true
	antenna.CanCollide = false
	antenna.Material = Enum.Material.SmoothPlastic
	antenna.Color = Color3.fromRGB(30, 25, 45)
	antenna.Size = Vector3.new(0.4, 10, 0.4)
	antenna.Position = gridPosition + Vector3.new(0, 13, HQ_CENTER_Z)
	antenna.Parent = hqModel

	local antennaTip = Instance.new("Part")
	antennaTip.Name = "AntennaTip"
	antennaTip.Shape = Enum.PartType.Ball
	antennaTip.Anchored = true
	antennaTip.CanCollide = false
	antennaTip.Material = Enum.Material.Neon
	antennaTip.Color = Color3.fromRGB(140, 80, 255)
	antennaTip.Size = Vector3.new(1, 1, 1)
	antennaTip.Position = gridPosition + Vector3.new(0, 18.5, HQ_CENTER_Z)
	antennaTip.Parent = hqModel

	local windowZ = HQ_CENTER_Z - base.Size.Z / 2 - 0.05
	for i = 1, 3 do
		local window = Instance.new("Part")
		window.Name = "Window_" .. i
		window.Anchored = true
		window.CanCollide = false
		window.Material = Enum.Material.Neon
		window.Color = Color3.fromRGB(60, 100, 180)
		window.Transparency = 0.5
		window.Size = Vector3.new(3, 3, 0.1)
		window.Position = gridPosition + Vector3.new((i - 2) * 8, 4, windowZ)
		window.Parent = hqModel
	end

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 25
	light.Color = Color3.fromRGB(60, 40, 120)
	light.Parent = base

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HQLabel"
	billboard.Size = UDim2.new(0, 220, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.Parent = base

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "VOID RESEARCH STATION"
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
end

local function createDropboxPlatform(plotModel: Model, gridPosition: Vector3)
	local groundY = gridPosition.Y

	local platform = Instance.new("Part")
	platform.Name = "SellPlatform"
	platform.Anchored = true
	platform.CanCollide = true
	platform.Material = Enum.Material.SmoothPlastic
	platform.Color = Color3.fromRGB(15, 20, 15)
	platform.Size = Vector3.new(14, 0.5, 14)
	platform.Position = gridPosition + Vector3.new(0, 0.25, DROPBOX_Z_OFFSET)
	setCollisionGroup(platform)
	platform.Parent = plotModel

	local pillarSize = padSize(0.6, 3)
	local pillarColor = Color3.fromRGB(0, 180, 80)
	local corners = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
	for i, corner in corners do
		local pillar = createCylinder(
			"SellPillar_" .. i,
			pillarSize,
			pillarColor,
			Enum.Material.Neon,
			0.4,
			CFrame.new(gridPosition + Vector3.new(corner[1] * 7, groundY + 1.5, DROPBOX_Z_OFFSET + corner[2] * 7))
				* UPRIGHT_CYLINDER,
			false
		)
		pillar.Parent = plotModel
	end
end

-- Solid Door_L/Door_R (each 10 studs) flank a real 10-stud walkable gap; the
-- full-width WarehouseWall behind them is CanCollide false so it reads as a
-- backdrop rather than silently sealing the doorway the player is meant to
-- walk through.
local function createWarehouseStructure(plotModel: Model, gridPosition: Vector3)
	local wallColor = Color3.fromRGB(20, 16, 35)

	local wall = Instance.new("Part")
	wall.Name = "WarehouseWall"
	wall.Anchored = true
	wall.CanCollide = false
	wall.Material = Enum.Material.SmoothPlastic
	wall.Color = wallColor
	wall.Size = Vector3.new(PLOT_WIDTH - 10, 6, 1)
	wall.Position = gridPosition + Vector3.new(0, 3, WAREHOUSE_WALL_Z)
	wall.Parent = plotModel

	for _, side in { { name = "L", sign = -1 }, { name = "R", sign = 1 } } do
		local door = Instance.new("Part")
		door.Name = "WarehouseDoor_" .. side.name
		door.Anchored = true
		door.CanCollide = true
		door.Material = Enum.Material.SmoothPlastic
		door.Color = wallColor
		door.Size = Vector3.new(10, 6, 1)
		door.Position = gridPosition + Vector3.new(side.sign * 10, 3, WAREHOUSE_WALL_Z)
		setCollisionGroup(door)
		door.Parent = plotModel
	end

	local doorGlow = Instance.new("Part")
	doorGlow.Name = "WarehouseDoorGlow"
	doorGlow.Anchored = true
	doorGlow.CanCollide = false
	doorGlow.Material = Enum.Material.Neon
	doorGlow.Color = Color3.fromRGB(80, 50, 140)
	doorGlow.Transparency = 0.5
	doorGlow.Size = Vector3.new(10.4, 6.4, 0.2)
	doorGlow.Position = gridPosition + Vector3.new(0, 3, WAREHOUSE_WALL_Z)
	doorGlow.Parent = plotModel

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WarehouseLabel"
	billboard.Size = UDim2.new(0, 160, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.Parent = doorGlow

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "WAREHOUSE"
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	-- Invisible trigger in the doorway gap; WarehouseTrigger.server.lua wires
	-- the actual .Touched -> OPEN_WAREHOUSE firing (same split as Dropbox/vial
	-- pickup elsewhere: this script only builds geometry, a dedicated script
	-- owns touch detection + ownership validation).
	local trigger = Instance.new("Part")
	trigger.Name = "WarehouseTrigger"
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Size = Vector3.new(8, 6, 2)
	trigger.Position = gridPosition + Vector3.new(0, 3, WAREHOUSE_WALL_Z)
	trigger.Parent = plotModel
end

local AMBIENT_PARTICLE_COUNT = 8

local function createAmbientParticles(plotModel: Model, gridPosition: Vector3)
	local halfWidth = PLOT_WIDTH / 2
	local halfDepth = PLOT_DEPTH / 2

	for i = 1, AMBIENT_PARTICLE_COUNT do
		local anchor = Instance.new("Part")
		anchor.Name = "AmbientParticle_" .. i
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = gridPosition
			+ Vector3.new(math.random(-halfWidth, halfWidth), math.random(2, 8), math.random(-halfDepth, halfDepth))
		anchor.Parent = plotModel

		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 2
		emitter.Lifetime = NumberRange.new(3, 6)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Color = ColorSequence.new(Color3.fromRGB(80, 50, 140), Color3.fromRGB(40, 20, 80))
		emitter.LightEmission = 0.8
		emitter.LightInfluence = 0
		emitter.RotSpeed = NumberRange.new(-20, 20)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = anchor
	end
end

local function buildPlotBase(plotModel: Model, origin: Vector3)
	createFloorVeins(plotModel, origin)
	createHeadquarters(plotModel, origin)
	createDropboxPlatform(plotModel, origin)
	createWarehouseStructure(plotModel, origin)
	createAmbientParticles(plotModel, origin)
end

local function createPlot(index: number, plotsFolder: Folder)
	local plotModel = Instance.new("Model")
	plotModel.Name = "Plot_" .. index
	plotModel.Parent = plotsFolder

	local col = (index - 1) % PLOTS_PER_ROW
	local row = math.floor((index - 1) / PLOTS_PER_ROW)
	local gridPosition = Vector3.new(col * X_SPACING, 0, row * Z_SPACING)

	local origin = Instance.new("Part")
	origin.Name = "Origin"
	origin.Anchored = true
	origin.CanCollide = false
	origin.Transparency = 1
	origin.Size = Vector3.new(2, 2, 2)
	origin.Position = gridPosition
	setCollisionGroup(origin)
	origin.Parent = plotModel

	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Anchored = true
	ground.Size = Vector3.new(PLOT_WIDTH, 1, PLOT_DEPTH)
	ground.Position = gridPosition + Vector3.new(0, -0.5, 0)
	ground.Material = Enum.Material.SmoothPlastic
	ground.Color = Color3.fromRGB(12, 9, 22)
	setCollisionGroup(ground)
	ground.Parent = plotModel

	local groundGlow = Instance.new("Part")
	groundGlow.Name = "GroundGlow"
	groundGlow.Anchored = true
	groundGlow.CanCollide = false
	groundGlow.Size = Vector3.new(ground.Size.X, 0.05, ground.Size.Z)
	groundGlow.Position = gridPosition + Vector3.new(0, 0.025, 0)
	groundGlow.Material = Enum.Material.Neon
	groundGlow.Color = Color3.fromRGB(30, 20, 50)
	groundGlow.Transparency = 0.9
	groundGlow.Parent = plotModel

	createPlotBorder(plotModel, gridPosition)
	buildPlotBase(plotModel, gridPosition)

	-- Flat cylinder flush with the ground (top of Ground is at gridPosition.Y) that
	-- players walk onto to trigger a deposit -- DropboxRemotes.server.lua listens
	-- for .Touched on this Part directly, no ClickDetector.
	local dropboxCFrame = CFrame.new(gridPosition + Vector3.new(0, 0.25, -30)) * UPRIGHT_CYLINDER
	local dropbox = createCylinder(
		"Dropbox",
		Vector3.new(0.5, 9, 9),
		Color3.fromRGB(0, 200, 80),
		Enum.Material.Neon,
		0,
		dropboxCFrame,
		true
	)
	setCollisionGroup(dropbox)
	dropbox.Parent = plotModel

	local dropboxRing = createCylinder(
		"DropboxRing",
		Vector3.new(0.3, 10.5, 10.5),
		Color3.fromRGB(0, 255, 100),
		Enum.Material.Neon,
		0.6,
		dropboxCFrame,
		false
	)
	dropboxRing.Parent = dropbox

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SellLabel"
	billboard.Size = UDim2.new(4, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = dropbox

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "SELL"
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.Parent = billboard

	for slotIndex = 1, TOTAL_HALL_SLOTS do
		createSlotPad(plotModel, gridPosition, slotIndex)
	end

	local ownerId = Instance.new("StringValue")
	ownerId.Name = "OwnerId"
	ownerId.Value = ""
	ownerId.Parent = plotModel

	local isOccupied = Instance.new("BoolValue")
	isOccupied.Name = "IsOccupied"
	isOccupied.Value = false
	isOccupied.Parent = plotModel
end

local plotsFolder = Workspace:FindFirstChild("Plots")
if not plotsFolder then
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace
end

-- temporary: only Plot_1 active during visual development
if not plotsFolder:FindFirstChild("Plot_1") then
	createPlot(1, plotsFolder)
end
-- for i = 2, PLOT_COUNT do
-- 	if not plotsFolder:FindFirstChild("Plot_" .. i) then
-- 		createPlot(i, plotsFolder)
-- 	end
-- end

print(`[PlotSetup] Created 1 plot (temporary)`)
