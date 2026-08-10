local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")

local Constants = require(ReplicatedStorage.Constants)

local PLOT_COUNT = 10
local PLOTS_PER_ROW = 5
-- Plot footprint is 60x80 (PLOT_WIDTH x PLOT_DEPTH below); these spacings
-- leave a 50-stud walkable gap between neighboring plots in both directions
-- so the grid doesn't feel cramped. MerchantSetup.server.lua keeps its own
-- copy of X_SPACING/PLOTS_PER_ROW in sync to stay centered on this grid.
local X_SPACING = 110
local Z_SPACING = 130

local COLLISION_GROUP = "PlotGround"

pcall(function()
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
end)

local function setCollisionGroup(part: BasePart)
	part.CollisionGroup = COLLISION_GROUP
end

-- Fixed so the star/nebula layout is identical every server start. A scoped
-- Random object rather than math.randomseed(42) -- reseeding the global RNG
-- would make every OTHER math.random() call on the server (egg rarity, vial
-- offsets, etc.) deterministic too for the rest of the server's lifetime.
local VOID_SKY_SEED = 42

local function setupVoidAtmosphere()
	-- Lighting
	local lighting = Lighting
	lighting.Ambient = Color3.fromRGB(70, 60, 110)
	lighting.OutdoorAmbient = Color3.fromRGB(45, 38, 80)
	lighting.Brightness = 1.5
	-- Real value gets set by setupDayNightCycle()'s first update() call below;
	-- 12 (noon) here just avoids a one-frame flash of Roblox's default
	-- midnight sun before that runs.
	lighting.ClockTime = 12
	lighting.FogEnd = 500
	lighting.FogStart = 250
	lighting.FogColor = Color3.fromRGB(5, 3, 15)
	lighting.GlobalShadows = true

	-- Remove default sky
	for _, child in ipairs(lighting:GetChildren()) do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end

	-- Color correction
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0
	cc.Contrast = 0.15
	cc.Saturation = -0.05
	cc.TintColor = Color3.fromRGB(190, 170, 255)
	cc.Parent = lighting

	-- Bloom for neon glow -- without this, Neon materials (pedestals, veins,
	-- sell pad, monster eyes) look flat; Threshold 0.95 keeps only truly
	-- bright neon parts blooming, not the dark background.
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 24
	bloom.Threshold = 0.95
	bloom.Parent = lighting

	-- Star field
	local voidSky = Instance.new("Model")
	voidSky.Name = "VoidSky"
	voidSky.Parent = Workspace

	local starColors = {
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(210, 190, 255),
		Color3.fromRGB(180, 200, 255),
		Color3.fromRGB(255, 210, 180),
		Color3.fromRGB(200, 230, 255),
	}

	local rng = Random.new(VOID_SKY_SEED)

	for i = 1, 300 do
		local star = Instance.new("Part")
		star.Name = "Star_" .. i
		star.Shape = Enum.PartType.Ball
		local size = rng:NextInteger(20, 80) / 100
		star.Size = Vector3.new(size, size, size)
		star.Material = Enum.Material.Neon
		star.Color = starColors[rng:NextInteger(1, #starColors)]
		star.Anchored = true
		star.CanCollide = false
		star.CastShadow = false
		star.Locked = true

		-- Random position on sphere shell
		local theta = rng:NextNumber() * math.pi * 2
		local phi = math.acos(rng:NextNumber() * 2 - 1)
		local radius = rng:NextInteger(350, 550)

		local x = radius * math.sin(phi) * math.cos(theta)
		local y = math.abs(radius * math.cos(phi)) + 80 -- force above Y=80
		local z = radius * math.sin(phi) * math.sin(theta)

		star.Position = Vector3.new(x, y, z)
		star.Parent = voidSky
	end

	-- Nebula clouds deliberately removed. They were six 80-180 stud spheres at
	-- 93-97% transparency sitting directly over the playfield (X/Z within +-200,
	-- Y 120-280). Semi-transparent parts don't write depth, so their draw order
	-- against each other and against everything below them re-sorted as the
	-- camera moved -- that was the flickering you'd see just from walking
	-- around, and at 95% transparency they contributed almost nothing visually.
	-- The bloom + fog + ambient lighting already carry the void atmosphere.

	-- World ambient light source
	local ambientPart = Instance.new("Part")
	ambientPart.Size = Vector3.new(1, 1, 1)
	ambientPart.Position = Vector3.new(0, 300, 0)
	ambientPart.Anchored = true
	ambientPart.CanCollide = false
	ambientPart.Transparency = 1
	ambientPart.Parent = voidSky

	local ambientLight = Instance.new("PointLight")
	ambientLight.Brightness = 1.5
	ambientLight.Range = 600
	ambientLight.Color = Color3.fromRGB(50, 25, 90)
	ambientLight.Parent = ambientPart
end

setupVoidAtmosphere()

-- ============================================================
-- Day / Night Cycle
-- ============================================================
-- Sun and Moon sit on opposite ends of a diameter, so each is above the
-- horizon for exactly half the cycle -- day and night each last ~10 minutes
-- out of this ~20 minute total. Position/lighting is recomputed off elapsed
-- wall-clock time (not accumulated per-tick dt) so drift never compounds.
local DAY_NIGHT_CYCLE_SECONDS = 20 * 60
local DAY_NIGHT_UPDATE_INTERVAL = 1

-- pi/2 puts the sun at zenith (brightest point) the instant the server
-- starts, satisfying "start at daytime".
local DAY_NIGHT_START_ANGLE = math.pi / 2

-- Grid is PLOTS_PER_ROW plots wide x however many rows deep; center the
-- orbit over the middle of that footprint so the sun/moon arc over the
-- base instead of off to one side.
local ORBIT_CENTER = Vector3.new(
	0, -- grid columns are centered on X=0 (see createPlot)
	120,
	(math.ceil(PLOT_COUNT / PLOTS_PER_ROW) - 1) * Z_SPACING / 2
)
local ORBIT_RADIUS = 420

-- Night values match the void atmosphere's original (pre-tweak) dark
-- palette; day values match the brighter palette setupVoidAtmosphere uses
-- above, so the cycle swings between the two looks that already exist.
local NIGHT_AMBIENT = Color3.fromRGB(15, 10, 30)
local NIGHT_OUTDOOR_AMBIENT = Color3.fromRGB(8, 5, 18)
local NIGHT_BRIGHTNESS = 0.15
local NIGHT_CC_BRIGHTNESS = -0.08
local NIGHT_FOG_COLOR = Color3.fromRGB(5, 3, 15)
local NIGHT_STAR_TRANSPARENCY = 0

local DAY_AMBIENT = Color3.fromRGB(70, 60, 110)
local DAY_OUTDOOR_AMBIENT = Color3.fromRGB(45, 38, 80)
local DAY_BRIGHTNESS = 1.5
local DAY_CC_BRIGHTNESS = 0
local DAY_FOG_COLOR = Color3.fromRGB(20, 14, 45)
-- Fully hidden at midday rather than dimmed to 0.75. At any partial value all
-- 300 stars are semi-transparent at once, and semi-transparent parts re-sort
-- against each other every time the camera moves, which reads as flickering.
-- At 1 Roblox culls them outright, so daytime costs nothing and night still
-- gets fully opaque stars.
local DAY_STAR_TRANSPARENCY = 1

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function createCelestialBody(name: string, diameter: number, color: Color3, lightColor: Color3, lightBrightness: number, lightRange: number): Part
	local body = Instance.new("Part")
	body.Name = name
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(diameter, diameter, diameter)
	body.Material = Enum.Material.Neon
	body.Color = color
	body.Anchored = true
	body.CanCollide = false
	body.CastShadow = false
	body.Locked = true

	-- Oversized, mostly-transparent shell behind the body so the Bloom
	-- effect (see setupVoidAtmosphere) gives it a soft halo like the
	-- nebula clouds get.
	local halo = Instance.new("Part")
	halo.Name = "Halo"
	halo.Shape = Enum.PartType.Ball
	halo.Size = Vector3.new(diameter * 1.8, diameter * 1.8, diameter * 1.8)
	halo.Material = Enum.Material.Neon
	halo.Color = color
	halo.Transparency = 0.85
	halo.Anchored = true
	halo.CanCollide = false
	halo.CastShadow = false
	halo.Locked = true
	halo.Parent = body

	local light = Instance.new("PointLight")
	light.Color = lightColor
	light.Brightness = lightBrightness
	light.Range = lightRange
	light.Parent = body

	return body
end

local function setupDayNightCycle()
	local voidSky = Workspace:WaitForChild("VoidSky")

	local sun = createCelestialBody("Sun", 46, Color3.fromRGB(255, 205, 110), Color3.fromRGB(255, 190, 120), 3, 250)
	sun.Parent = voidSky

	local moon = createCelestialBody("Moon", 30, Color3.fromRGB(215, 225, 255), Color3.fromRGB(160, 180, 255), 1.5, 180)
	moon.Parent = voidSky

	local stars = {}
	for _, child in voidSky:GetChildren() do
		if child.Name:match("^Star_") then
			table.insert(stars, child)
		end
	end

	local startTime = os.clock()

	local function update()
		local elapsed = os.clock() - startTime
		local angle = DAY_NIGHT_START_ANGLE + (elapsed / DAY_NIGHT_CYCLE_SECONDS) * (math.pi * 2)

		local sunHeight = math.sin(angle)
		local dayFactor = (sunHeight + 1) / 2 -- 0 = full night, 1 = full day

		sun.Position = ORBIT_CENTER + Vector3.new(math.cos(angle) * ORBIT_RADIUS, sunHeight * ORBIT_RADIUS, 0)
		moon.Position = ORBIT_CENTER + Vector3.new(-math.cos(angle) * ORBIT_RADIUS, -sunHeight * ORBIT_RADIUS, 0)

		-- Roblox's built-in sun (and the shadows GlobalShadows casts) is driven
		-- by Lighting.ClockTime, not by our custom Sun/Moon parts or the
		-- Ambient/Brightness tweaks below -- without moving this too, the real
		-- key light stays stuck at whatever ClockTime was last set to (e.g.
		-- midnight) and the scene reads as dark no matter what Ambient says.
		-- angle == DAY_NIGHT_START_ANGLE (sun at zenith) must map to ClockTime
		-- 12 (noon); a full 2*pi loop must map to a full 24-hour loop.
		Lighting.ClockTime = ((angle - DAY_NIGHT_START_ANGLE) / (math.pi * 2) * 24 + 12) % 24

		Lighting.Ambient = lerpColor(NIGHT_AMBIENT, DAY_AMBIENT, dayFactor)
		Lighting.OutdoorAmbient = lerpColor(NIGHT_OUTDOOR_AMBIENT, DAY_OUTDOOR_AMBIENT, dayFactor)
		Lighting.Brightness = NIGHT_BRIGHTNESS + (DAY_BRIGHTNESS - NIGHT_BRIGHTNESS) * dayFactor
		Lighting.FogColor = lerpColor(NIGHT_FOG_COLOR, DAY_FOG_COLOR, dayFactor)

		local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		if cc then
			cc.Brightness = NIGHT_CC_BRIGHTNESS + (DAY_CC_BRIGHTNESS - NIGHT_CC_BRIGHTNESS) * dayFactor
		end

		local starTransparency = NIGHT_STAR_TRANSPARENCY + (DAY_STAR_TRANSPARENCY - NIGHT_STAR_TRANSPARENCY) * dayFactor
		for _, star in stars do
			star.Transparency = starTransparency
		end
	end

	update()

	task.spawn(function()
		while true do
			task.wait(DAY_NIGHT_UPDATE_INTERVAL)
			update()
		end
	end)
end

setupDayNightCycle()

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
-- Solid curbs, not the old 8-stud 85%-transparent neon panels. Four
-- see-through walls per plot across 10 plots meant 40 large translucent
-- surfaces overlapping each other and everything behind them, which is what
-- made the plots look ghostly and shimmer as the camera moved. A short opaque
-- curb marks the boundary just as clearly and writes to the depth buffer.
local BORDER_WALL_HEIGHT = 1.6
local BORDER_WALL_THICKNESS = 0.8
local BORDER_POST_HEIGHT = 5
local BORDER_WALL_COLOR = Color3.fromRGB(46, 32, 78)
local BORDER_POST_COLOR = Color3.fromRGB(100, 70, 160)
-- Must match GROUND_GLOW_COLOR.off in PlotManager.lua, which tweens between
-- this and the powered colour when a plot is claimed or released.
local GROUND_GLOW_UNPOWERED_COLOR = Color3.fromRGB(24, 18, 42)

local function createBorderWall(name: string, size: Vector3, position: Vector3): Part
	local wall = Instance.new("Part")
	wall.Name = name
	wall.Anchored = true
	wall.CanCollide = false
	wall.Material = Enum.Material.SmoothPlastic
	wall.Color = BORDER_WALL_COLOR
	wall.Size = size
	wall.Position = position
	return wall
end

-- Opaque boundary curbs plus 4 brighter corner posts, sized off the Ground
-- Part's own footprint so they always match its edges.
local function createPlotBorder(plotModel: Model, gridPosition: Vector3)
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

	-- Posts keep their own height now that the curbs are short, so the plot
	-- corners still read from a distance. Opaque -- see the note on
	-- createBorderWall about why nothing here is semi-transparent any more.
	local postY = gridPosition.Y + BORDER_POST_HEIGHT / 2
	local postSize = padSize(0.7, BORDER_POST_HEIGHT)
	local corners = {
		Vector3.new(halfWidth, postY, halfDepth),
		Vector3.new(halfWidth, postY, -halfDepth),
		Vector3.new(-halfWidth, postY, halfDepth),
		Vector3.new(-halfWidth, postY, -halfDepth),
	}
	for i, corner in corners do
		local post = createCylinder(
			"BorderPost_" .. i,
			postSize,
			BORDER_POST_COLOR,
			Enum.Material.Neon,
			0,
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
		isVisible and 0 or 1,
		padCFrame(groundY + 6.05),
		false
	)
	topGlow.Parent = slotModel

	local ring = createCylinder(
		"Ring",
		padSize(3.6, 0.02),
		DIM_PURPLE,
		Enum.Material.Neon,
		isVisible and 0 or 1,
		padCFrame(groundY + 0.24),
		false
	)
	ring.Parent = slotModel

	local midRing = createCylinder(
		"MidRing",
		padSize(3.2, 0.15),
		GLOW_BLUE,
		Enum.Material.Neon,
		isVisible and 0 or 1,
		padCFrame(groundY + 3),
		false
	)
	midRing.Parent = slotModel

	local RUNE_COLOR = Color3.fromRGB(50, 30, 90)

	local rune = createCylinder(
		"Rune",
		padSize(7, 0.02),
		RUNE_COLOR,
		Enum.Material.Neon,
		isVisible and 0 or 1,
		padCFrame(groundY + 0.08),
		false
	)
	rune.Parent = slotModel

	local runeInner = createCylinder(
		"RuneInner",
		padSize(4, 0.02),
		RUNE_COLOR,
		Enum.Material.Neon,
		isVisible and 0 or 1,
		padCFrame(groundY + 0.14),
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
	crystal.Transparency = isVisible and 0 or 1
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
	local veinYOffset = 0.19
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
		horizontal.Transparency = 0
		horizontal.Size = Vector3.new(PLOT_WIDTH, 0.02, 0.08)
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
		vertical.Transparency = 0
		vertical.Size = Vector3.new(0.08, 0.02, PLOT_DEPTH)
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
			0,
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
		window.Transparency = 0
		window.Size = Vector3.new(3, 3, 0.1)
		window.Position = gridPosition + Vector3.new((i - 2) * 8, 4, windowZ)
		window.Parent = hqModel
	end

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 25
	light.Color = Color3.fromRGB(60, 40, 120)
	light.Parent = base

	-- Deliberately no floating "VOID RESEARCH STATION" billboard here. Every
	-- plot built one, so 10 plots put 10 identical labels in the sky on top of
	-- their CLAIM PLOT / SELL / WAREHOUSE labels. The plot number now lives on
	-- the ClaimBeacon label instead, and SELL/WAREHOUSE only appear once a plot
	-- is actually claimed (see setPlotPowered in PlotManager.lua).
end

-- Floating "CLAIM PLOT" prompt shown above the Headquarters while a plot is
-- unowned; PlotManager.lua toggles its visibility/ClickDetector on
-- claim/release, and PlotClaimTrigger.server.lua wires the actual click.
-- Beacon Y was 22 with a MaxActivationDistance of 25 -- but it also sits
-- HQ_CENTER_Z (35) studs back from the plot origin, putting it ~41 studs from
-- where a player standing mid-plot actually is, so the claim click silently
-- did nothing anywhere except right at the HQ. Lower it and widen the radius
-- (see BEACON_ACTIVE_DISTANCE in PlotManager.lua, which must match) so the
-- whole plot is a valid place to claim from.
local BEACON_HEIGHT = 14
local BEACON_ACTIVATION_DISTANCE = 70

local function createClaimBeacon(plotModel: Model, gridPosition: Vector3, plotIndex: number)
	local beaconColor = Color3.fromRGB(80, 220, 120)
	local beaconCFrame = CFrame.new(gridPosition + Vector3.new(0, BEACON_HEIGHT, HQ_CENTER_Z))

	local beacon = Instance.new("Part")
	beacon.Name = "ClaimBeacon"
	beacon.Shape = Enum.PartType.Ball
	beacon.Size = Vector3.new(2, 2, 2)
	beacon.Material = Enum.Material.Neon
	beacon.Color = beaconColor
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CFrame = beaconCFrame
	beacon.Parent = plotModel

	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 30
	light.Color = beaconColor
	light.Parent = beacon

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ClaimLabel"
	billboard.Size = UDim2.new(0, 130, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = beacon

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "CLAIM PLOT " .. plotIndex
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.Name = "ClaimClickDetector"
	clickDetector.MaxActivationDistance = BEACON_ACTIVATION_DISTANCE
	clickDetector.Parent = beacon
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
			0,
			CFrame.new(gridPosition + Vector3.new(corner[1] * 7, groundY + 1.5, DROPBOX_Z_OFFSET + corner[2] * 7))
				* UPRIGHT_CYLINDER,
			false
		)
		pillar.Parent = plotModel
	end
end

-- Two solid wall segments flanking a real DOORWAY_WIDTH walkable gap. This
-- used to be a full-width CanCollide=false backdrop plus two narrower
-- collidable "doors", which left the outer stretches of the wall walk-through
-- -- it looked like a wall but wasn't one. The segments below are the wall:
-- opaque, collidable, and sized so only the doorway is actually open.
local DOORWAY_WIDTH = 10

local function createWarehouseStructure(plotModel: Model, gridPosition: Vector3)
	local wallColor = Color3.fromRGB(20, 16, 35)
	local wallSpan = PLOT_WIDTH - 10 -- total width the wall covers, doorway included
	local segmentWidth = (wallSpan - DOORWAY_WIDTH) / 2
	local segmentCenterX = DOORWAY_WIDTH / 2 + segmentWidth / 2

	for _, side in { { name = "L", sign = -1 }, { name = "R", sign = 1 } } do
		local segment = Instance.new("Part")
		segment.Name = "WarehouseWall_" .. side.name
		segment.Anchored = true
		segment.CanCollide = true
		segment.Material = Enum.Material.SmoothPlastic
		segment.Color = wallColor
		segment.Size = Vector3.new(segmentWidth, 6, 1)
		segment.Position = gridPosition + Vector3.new(side.sign * segmentCenterX, 3, WAREHOUSE_WALL_Z)
		setCollisionGroup(segment)
		segment.Parent = plotModel
	end

	-- Lintel across the top of the doorway rather than a translucent pane
	-- filling it. The pane read as a half-visible barrier over an opening the
	-- player is meant to walk straight through, and semi-transparent parts are
	-- exactly what makes the plots shimmer when the camera moves.
	local doorGlow = Instance.new("Part")
	doorGlow.Name = "WarehouseDoorGlow"
	doorGlow.Anchored = true
	doorGlow.CanCollide = false
	doorGlow.Material = Enum.Material.Neon
	doorGlow.Color = Color3.fromRGB(80, 50, 140)
	doorGlow.Size = Vector3.new(DOORWAY_WIDTH + 0.4, 0.6, 1.2)
	doorGlow.Position = gridPosition + Vector3.new(0, 6.3, WAREHOUSE_WALL_Z)
	doorGlow.Parent = plotModel

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WarehouseLabel"
	billboard.Size = UDim2.new(0, 160, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	-- Off until the plot is claimed; PlotManager.setPlotPowered turns it on.
	billboard.Enabled = false
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

local function buildPlotBase(plotModel: Model, origin: Vector3, plotIndex: number)
	createFloorVeins(plotModel, origin)
	createHeadquarters(plotModel, origin)
	createClaimBeacon(plotModel, origin, plotIndex)
	createDropboxPlatform(plotModel, origin)
	createWarehouseStructure(plotModel, origin)
end

local function createPlot(index: number, plotsFolder: Folder)
	local plotModel = Instance.new("Model")
	plotModel.Name = "Plot_" .. index
	plotModel.Parent = plotsFolder

	local col = (index - 1) % PLOTS_PER_ROW
	local row = math.floor((index - 1) / PLOTS_PER_ROW)
	-- Columns are centered on world X=0 (not grown purely in +X) so the grid
	-- stays within the 512-stud Baseplate defined in default.project.json
	-- instead of hanging off its right edge.
	local gridPosition = Vector3.new((col - (PLOTS_PER_ROW - 1) / 2) * X_SPACING, 0, row * Z_SPACING)

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

	-- Opaque floor skin rather than a 90%-transparent sheet laid over Ground.
	-- One of these covers every plot edge to edge, so at 10 plots they were ten
	-- full-size translucent surfaces stacked into the view -- the single
	-- biggest reason the plots looked washed out and see-through. Powered state
	-- is now expressed through Color instead of Transparency; see
	-- setPlotPowered in PlotManager.lua.
	local groundGlow = Instance.new("Part")
	groundGlow.Name = "GroundGlow"
	groundGlow.Anchored = true
	groundGlow.CanCollide = false
	groundGlow.Size = Vector3.new(ground.Size.X, 0.02, ground.Size.Z)
	groundGlow.Position = gridPosition + Vector3.new(0, 0.03, 0)
	groundGlow.Material = Enum.Material.SmoothPlastic
	groundGlow.Color = GROUND_GLOW_UNPOWERED_COLOR
	groundGlow.Parent = plotModel

	createPlotBorder(plotModel, gridPosition)
	buildPlotBase(plotModel, gridPosition, index)

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
		0,
		dropboxCFrame,
		false
	)
	dropboxRing.Parent = dropbox

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SellLabel"
	-- Was UDim2.new(4, 0, 2, 0) -- Scale units on a BillboardGui render as a
	-- fraction of the viewport, so that was ~400%x200% of the screen. Offset
	-- studs like the other plot billboards instead.
	billboard.Size = UDim2.new(0, 130, 0, 44)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	-- Off until the plot is claimed; PlotManager.setPlotPowered turns it on.
	billboard.Enabled = false
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

for i = 1, PLOT_COUNT do
	if not plotsFolder:FindFirstChild("Plot_" .. i) then
		createPlot(i, plotsFolder)
	end
end

print(`[PlotSetup] Created {PLOT_COUNT} plots`)
