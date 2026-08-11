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

-- ============================================================
-- Outdoor atmosphere
-- ============================================================
-- This was a "void dimension" -- black fog, purple ambient, a 300-part
-- starfield and hand-built Sun/Moon spheres orbiting the map. That fought the
-- grass terrain underneath it and left everything murky, so the whole thing is
-- replaced with ordinary daylight: a real Sky, an Atmosphere for distance
-- haze, and Roblox's own sun driven by ClockTime. The custom celestial parts
-- are gone entirely -- ClockTime gives a real sun with real shadows for free,
-- which no amount of Neon spheres was ever going to match.

local DAY_AMBIENT = Color3.fromRGB(122, 126, 138)
local DAY_OUTDOOR_AMBIENT = Color3.fromRGB(146, 156, 172)
local DAY_BRIGHTNESS = 2.6
local DAY_ATMOSPHERE_DENSITY = 0.32
local DAY_ATMOSPHERE_COLOR = Color3.fromRGB(199, 209, 224)
local DAY_ATMOSPHERE_HAZE = 1.1

local NIGHT_AMBIENT = Color3.fromRGB(38, 44, 68)
local NIGHT_OUTDOOR_AMBIENT = Color3.fromRGB(48, 58, 88)
local NIGHT_BRIGHTNESS = 0.9
local NIGHT_ATMOSPHERE_DENSITY = 0.42
local NIGHT_ATMOSPHERE_COLOR = Color3.fromRGB(96, 108, 138)
local NIGHT_ATMOSPHERE_HAZE = 1.9

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function setupOutdoorAtmosphere()
	-- Clear anything the previous void setup left behind, including on a live
	-- Rojo sync where Lighting keeps its old children.
	for _, child in Lighting:GetChildren() do
		if
			child:IsA("Sky")
			or child:IsA("Atmosphere")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("BloomEffect")
			or child:IsA("SunRaysEffect")
		then
			child:Destroy()
		end
	end

	Lighting.Ambient = DAY_AMBIENT
	Lighting.OutdoorAmbient = DAY_OUTDOOR_AMBIENT
	Lighting.Brightness = DAY_BRIGHTNESS
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 20
	Lighting.ExposureCompensation = 0.15
	Lighting.GlobalShadows = true
	-- Lighting.Technology is deliberately NOT set here: it is read-only at
	-- runtime and assigning it throws, which killed this whole script before it
	-- reached the plot-building loop at the bottom. It is set to ShadowMap in
	-- default.project.json instead, which is the only place it can be set.

	-- Distance haze is Atmosphere's job now. The old Fog* properties clamped
	-- everything to a flat dark wall 500 studs out, which is what made the map
	-- feel like it ended in a void.
	Lighting.FogEnd = 100000

	-- EnvironmentDiffuseScale/SpecularScale let surfaces pick up sky colour,
	-- which is most of what makes an outdoor scene read as outdoors rather than
	-- as parts sitting in a flat ambient wash.
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.5

	local sky = Instance.new("Sky")
	sky.Name = "OutdoorSky"
	sky.StarCount = 3000 -- only visible once ClockTime passes dusk
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "OutdoorAtmosphere"
	atmosphere.Density = DAY_ATMOSPHERE_DENSITY
	atmosphere.Offset = 0.2
	atmosphere.Color = DAY_ATMOSPHERE_COLOR
	atmosphere.Decay = Color3.fromRGB(106, 112, 125)
	atmosphere.Glare = 0.25
	atmosphere.Haze = DAY_ATMOSPHERE_HAZE
	atmosphere.Parent = Lighting

	-- Threshold well above 1 so only genuinely bright things bloom (sun glints,
	-- lantern glass) instead of the whole scene glowing like the old neon look.
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "OutdoorBloom"
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "OutdoorSunRays"
	sunRays.Intensity = 0.06
	sunRays.Spread = 0.4
	sunRays.Parent = Lighting
end

-- Guarded because this script also builds every plot, further down. Lighting is
-- decoration; plots are the game. A single bad property assignment up here
-- (Lighting.Technology, which is read-only at runtime, did exactly this) would
-- otherwise abort the script and leave the world with no plots at all.
local atmosphereOk, atmosphereErr = pcall(setupOutdoorAtmosphere)
if not atmosphereOk then
	warn(`[PlotSetup] Outdoor atmosphere setup failed: {atmosphereErr}`)
end

-- ============================================================
-- Day / Night Cycle
-- ============================================================
-- Drives Lighting.ClockTime directly, so Roblox's own sun, moon, sky and
-- shadows all move together. Recomputed from elapsed wall-clock time rather
-- than accumulated per-tick deltas so drift never compounds.
local DAY_NIGHT_CYCLE_SECONDS = 20 * 60
local DAY_NIGHT_UPDATE_INTERVAL = 1
local START_CLOCK_TIME = 13 -- early afternoon, so servers open in good light

local function setupDayNightCycle()
	local atmosphere = Lighting:FindFirstChild("OutdoorAtmosphere") :: Atmosphere?
	local startTime = os.clock()

	local function update()
		local elapsed = os.clock() - startTime
		local hours = (START_CLOCK_TIME + (elapsed / DAY_NIGHT_CYCLE_SECONDS) * 24) % 24

		Lighting.ClockTime = hours

		-- Sun is above the horizon between 06:00 and 18:00, peaking at noon.
		-- Clamping the negative half keeps the whole night at full night values
		-- instead of overshooting past them.
		local dayFactor = math.clamp(math.sin((hours - 6) / 12 * math.pi), 0, 1)

		Lighting.Ambient = lerpColor(NIGHT_AMBIENT, DAY_AMBIENT, dayFactor)
		Lighting.OutdoorAmbient = lerpColor(NIGHT_OUTDOOR_AMBIENT, DAY_OUTDOOR_AMBIENT, dayFactor)
		Lighting.Brightness = lerp(NIGHT_BRIGHTNESS, DAY_BRIGHTNESS, dayFactor)

		if atmosphere then
			atmosphere.Density = lerp(NIGHT_ATMOSPHERE_DENSITY, DAY_ATMOSPHERE_DENSITY, dayFactor)
			atmosphere.Haze = lerp(NIGHT_ATMOSPHERE_HAZE, DAY_ATMOSPHERE_HAZE, dayFactor)
			atmosphere.Color = lerpColor(NIGHT_ATMOSPHERE_COLOR, DAY_ATMOSPHERE_COLOR, dayFactor)
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

local cycleOk, cycleErr = pcall(setupDayNightCycle)
if not cycleOk then
	warn(`[PlotSetup] Day/night cycle setup failed: {cycleErr}`)
end

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
-- Deep enough for the slab's underside to sink past the grass surface
-- (TERRAIN_TOP_Y = -2 in TerrainSetup.server.lua). Its top face stays at the
-- plot origin, so this is purely skirt below the floor.
local GROUND_SLAB_THICKNESS = 3
-- Wooden post-and-rail fence, replacing the neon curbs the void theme used.
-- Rails are opaque timber; posts are spaced along each run rather than only at
-- the corners, so a plot boundary reads as an enclosure you could actually
-- lean on instead of a glowing line painted on the floor.
local FENCE_POST_HEIGHT = 4.2
local FENCE_POST_WIDTH = 0.7
local FENCE_POST_SPACING = 10

-- Claim gateway dimensions. Declared up here rather than beside createClaimGate
-- further down because createPlotBorder needs GATE_CLEAR_HALF_WIDTH to leave a
-- gap in the front fence -- a local declared after a function is a different
-- (global, nil) name inside that function's body, not a forward reference.
local GATE_WIDTH = 12
local GATE_HEIGHT = 11
local GATE_POST_WIDTH = 1.4
local GATE_CLEAR_HALF_WIDTH = GATE_WIDTH / 2 + 1
local RAIL_THICKNESS = 0.45
local RAIL_HEIGHTS = { 1.5, 3.1 }

local TIMBER_DARK = Color3.fromRGB(92, 63, 40)
local TIMBER_LIGHT = Color3.fromRGB(126, 88, 56)
local PLOT_SOIL_COLOR = Color3.fromRGB(104, 76, 50)
-- Must match GROUND_GLOW_COLOR.off in PlotManager.lua, which tweens between
-- this and the powered colour when a plot is claimed or released.
local GROUND_GLOW_UNPOWERED_COLOR = Color3.fromRGB(96, 132, 72)

local function newTimber(name: string, size: Vector3, color: Color3, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Wood
	part.Color = color
	part.Size = size
	part.Position = position
	return part
end

-- Kept for PlotManager.setPlotPowered, which looks up BorderWall_1..4 by name
-- to light a plot up on claim. Those are the four rail runs.
local function createBorderWall(name: string, size: Vector3, position: Vector3): Part
	return newTimber(name, size, TIMBER_LIGHT, position)
end

local function createPlotBorder(plotModel: Model, gridPosition: Vector3)
	local halfWidth = PLOT_WIDTH / 2
	local halfDepth = PLOT_DEPTH / 2

	-- Two horizontal rails per side. Named BorderWall_1..4 by the lower rail so
	-- the existing powered-plot lookup keeps working unchanged.
	local sides = {
		{ size = Vector3.new(PLOT_WIDTH, RAIL_THICKNESS, RAIL_THICKNESS), offset = Vector3.new(0, 0, halfDepth) },
		{ size = Vector3.new(PLOT_WIDTH, RAIL_THICKNESS, RAIL_THICKNESS), offset = Vector3.new(0, 0, -halfDepth) },
		{ size = Vector3.new(RAIL_THICKNESS, RAIL_THICKNESS, PLOT_DEPTH), offset = Vector3.new(halfWidth, 0, 0) },
		{ size = Vector3.new(RAIL_THICKNESS, RAIL_THICKNESS, PLOT_DEPTH), offset = Vector3.new(-halfWidth, 0, 0) },
	}

	for i, side in sides do
		for railIndex, railHeight in RAIL_HEIGHTS do
			-- Only the first rail carries the BorderWall_N name PlotManager
			-- recolours; the second is decorative and follows it visually.
			local name = if railIndex == 1 then "BorderWall_" .. i else `BorderRail_{i}_{railIndex}`
			local rail = createBorderWall(name, side.size, gridPosition + side.offset + Vector3.new(0, railHeight, 0))
			rail.Parent = plotModel
		end
	end

	-- Posts march along every side, not just the corners.
	local postSize = Vector3.new(FENCE_POST_WIDTH, FENCE_POST_HEIGHT, FENCE_POST_WIDTH)
	local postY = gridPosition.Y + FENCE_POST_HEIGHT / 2
	local postIndex = 0

	local function addPost(x: number, z: number)
		postIndex += 1
		local post = newTimber(
			"BorderPost_" .. postIndex,
			postSize,
			TIMBER_DARK,
			Vector3.new(gridPosition.X + x, postY, gridPosition.Z + z)
		)
		post.CanCollide = true
		setCollisionGroup(post)
		post.Parent = plotModel
	end

	local widthPosts = math.floor(PLOT_WIDTH / FENCE_POST_SPACING)
	local depthPosts = math.floor(PLOT_DEPTH / FENCE_POST_SPACING)

	for i = 0, widthPosts do
		local x = -halfWidth + i * (PLOT_WIDTH / widthPosts)
		addPost(x, halfDepth)
		-- Front (-Z) side leaves a gap for the claim gateway, which stands in
		-- this fence line. Without this a collidable fence post sits squarely in
		-- the middle of the doorway the player is meant to walk through.
		if math.abs(x) > GATE_CLEAR_HALF_WIDTH then
			addPost(x, -halfDepth)
		end
	end

	for i = 1, depthPosts - 1 do
		local z = -halfDepth + i * (PLOT_DEPTH / depthPosts)
		addPost(halfWidth, z)
		addPost(-halfWidth, z)
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
	-- Stone-and-timber planter, restyled from the neon pedestal the void theme
	-- used. Part NAMES are unchanged on purpose: HallClient.client.lua tweens
	-- TopGlow/Ring/Crystal, and MonsterVisuals.lua stands each monster on
	-- "Base", so renaming them would silently break slotting.
	local PLANTER_STONE = Color3.fromRGB(138, 133, 124)
	-- Default/empty colour for TopGlow and Ring (HallClient.client.lua tweens
	-- to this on unslot, and to the emotion colour on slot -- must match its
	-- own DIM_PURPLE or an empty pedestal looks different fresh vs. after a
	-- slot/unslot cycle).
	local DIM_PURPLE = Color3.fromRGB(104, 78, 52)

	-- Sits on the ground (bottom at groundY), top face at groundY + 6.
	local base = createCylinder(
		"Base",
		padSize(3.4, 6),
		PLANTER_STONE,
		Enum.Material.Slate,
		isVisible and 0 or 1,
		padCFrame(groundY + 3),
		isVisible
	)
	setCollisionGroup(base)
	base.Parent = slotModel

	-- Vertical timber staves banding the planter, where glowing veins used to run.
	local VEIN_COLOR = TIMBER_DARK
	local VEIN_OFFSET = 1.68
	for i = 1, 8 do
		local angle = math.rad((i - 1) * 45)

		local vein = Instance.new("Part")
		vein.Name = "Vein_" .. i
		vein.Anchored = true
		vein.CanCollide = false
		vein.Material = Enum.Material.Wood
		vein.Color = VEIN_COLOR
		vein.Transparency = isVisible and 0 or 1
		vein.Size = Vector3.new(0.45, 5.9, 0.45)
		vein.Position =
			Vector3.new(slotX + VEIN_OFFSET * math.cos(angle), groundY + 3, slotZ + VEIN_OFFSET * math.sin(angle))
		vein.Parent = slotModel
	end

	-- Soil surface the monster stands on; HallClient tints this to the
	-- creature's emotion colour when a slot is filled.
	local topGlow = createCylinder(
		"TopGlow",
		padSize(3, 0.3),
		DIM_PURPLE,
		Enum.Material.Ground,
		isVisible and 0 or 1,
		padCFrame(groundY + 6.05),
		false
	)
	topGlow.Parent = slotModel

	local ring = createCylinder(
		"Ring",
		padSize(4.6, 0.35),
		PLANTER_STONE,
		Enum.Material.Slate,
		isVisible and 0 or 1,
		padCFrame(groundY + 0.24),
		false
	)
	ring.Parent = slotModel

	-- Timber hoop around the planter's waist.
	local midRing = createCylinder(
		"MidRing",
		padSize(3.6, 0.4),
		TIMBER_LIGHT,
		Enum.Material.Wood,
		isVisible and 0 or 1,
		padCFrame(groundY + 3),
		false
	)
	midRing.Parent = slotModel

	local RUNE_COLOR = Color3.fromRGB(150, 144, 132)

	-- Flagstone apron under the planter, replacing the etched rune discs.
	local rune = createCylinder(
		"Rune",
		padSize(7, 0.12),
		RUNE_COLOR,
		Enum.Material.Slate,
		isVisible and 0 or 1,
		padCFrame(groundY + 0.08),
		false
	)
	rune.Parent = slotModel

	local runeInner = createCylinder(
		"RuneInner",
		padSize(5.4, 0.14),
		Color3.fromRGB(168, 162, 150),
		Enum.Material.Cobblestone,
		isVisible and 0 or 1,
		padCFrame(groundY + 0.16),
		false
	)
	runeInner.Parent = slotModel

	-- A sprout marking an empty planter. Shown only while the slot is empty;
	-- HallClient.client.lua hides it (Transparency 1) on slot and restores it
	-- on unslot.
	local crystal = Instance.new("WedgePart")
	crystal.Name = "Crystal"
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.Material = Enum.Material.Grass
	crystal.Color = Color3.fromRGB(104, 160, 74)
	crystal.Transparency = isVisible and 0 or 1
	crystal.Size = Vector3.new(0.7, 1.6, 0.7)
	crystal.CFrame = CFrame.new(slotX, groundY + 6 + 1, slotZ) * CFrame.Angles(0, math.rad(45), 0)
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

-- Stone path and tilled crop furrows, replacing the neon grid the void theme
-- drew across every plot floor. The path runs front-to-back so the route from
-- the fence gate to the farmhouse door is legible, and the furrows give the
-- open soil some texture instead of leaving it a flat brown rectangle.
local PATH_COLOR = Color3.fromRGB(150, 144, 132)
local FURROW_COLOR = Color3.fromRGB(86, 62, 40)
local DECOR_Y = 0.06

local function createFloorVeins(plotModel: Model, gridPosition: Vector3)
	local halfDepth = PLOT_DEPTH / 2

	-- Main path: irregular slabs rather than one long strip, so it reads as
	-- laid stone.
	local slabCount = 16
	for i = 1, slabCount do
		local z = -halfDepth + 4 + (i - 1) * ((PLOT_DEPTH - 10) / slabCount)
		local slab = Instance.new("Part")
		slab.Name = "PathSlab_" .. i
		slab.Anchored = true
		slab.CanCollide = false
		slab.Material = Enum.Material.Slate
		slab.Color = PATH_COLOR
		slab.Size = Vector3.new(7 + (i % 3) * 0.6, 0.12, 3.4)
		slab.Position = gridPosition + Vector3.new((i % 2 == 0) and 0.3 or -0.3, DECOR_Y, z)
		slab.Parent = plotModel
	end

	-- Furrows either side of the path, angled the long way like planted rows.
	for side, sign in { -1, 1 } do
		for i = 1, 5 do
			local furrow = Instance.new("Part")
			furrow.Name = `Furrow_{side}_{i}`
			furrow.Anchored = true
			furrow.CanCollide = false
			furrow.Material = Enum.Material.Ground
			furrow.Color = FURROW_COLOR
			furrow.Size = Vector3.new(1.6, 0.16, PLOT_DEPTH - 22)
			furrow.Position = gridPosition + Vector3.new(sign * (7 + i * 4), DECOR_Y, -6)
			furrow.Parent = plotModel
		end
	end
end

-- Farmhouse, replacing the flat dark slab-plus-towers the void theme used.
-- Built from a stone footing, timber walls with corner posts and a framed
-- doorway, a real pitched roof made from two WedgeParts, and a chimney -- so
-- the building has a silhouette instead of being a box with a light on it.
local STONE_COLOR = Color3.fromRGB(122, 120, 114)
local WALL_COLOR = Color3.fromRGB(198, 176, 142)
local ROOF_COLOR = Color3.fromRGB(126, 58, 48)
local WINDOW_COLOR = Color3.fromRGB(168, 208, 226)

local HQ_WIDTH = 26
local HQ_DEPTH = 14
local HQ_WALL_HEIGHT = 10
local HQ_ROOF_HEIGHT = 6

local function createHeadquarters(plotModel: Model, gridPosition: Vector3)
	local hqModel = Instance.new("Model")
	hqModel.Name = "Headquarters"
	hqModel.Parent = plotModel

	local center = gridPosition + Vector3.new(0, 0, HQ_CENTER_Z)

	local function place(
		name: string,
		size: Vector3,
		color: Color3,
		material: Enum.Material,
		offset: Vector3,
		collide: boolean
	): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = collide
		part.Material = material
		part.Color = color
		part.Size = size
		part.Position = center + offset
		if collide then
			setCollisionGroup(part)
		end
		part.Parent = hqModel
		return part
	end

	-- Stone footing, slightly wider than the walls so the building sits into
	-- the ground rather than balancing on it.
	local footing = place(
		"Footing",
		Vector3.new(HQ_WIDTH + 1.6, 1.4, HQ_DEPTH + 1.6),
		STONE_COLOR,
		Enum.Material.Slate,
		Vector3.new(0, 0.7, 0),
		true
	)
	hqModel.PrimaryPart = footing

	-- Base named for PlotManager/beacon lookups that expect an "HQBase".
	place(
		"HQBase",
		Vector3.new(HQ_WIDTH, HQ_WALL_HEIGHT, HQ_DEPTH),
		WALL_COLOR,
		Enum.Material.WoodPlanks,
		Vector3.new(0, 1.4 + HQ_WALL_HEIGHT / 2, 0),
		true
	)

	-- Exposed corner timbers break up the flat wall faces.
	for i, corner in { Vector3.new(-1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(1, 0, 1) } do
		place(
			"CornerBeam_" .. i,
			Vector3.new(1.2, HQ_WALL_HEIGHT, 1.2),
			TIMBER_DARK,
			Enum.Material.Wood,
			Vector3.new(corner.X * (HQ_WIDTH / 2 - 0.6), 1.4 + HQ_WALL_HEIGHT / 2, corner.Z * (HQ_DEPTH / 2 - 0.6)),
			false
		)
	end

	-- Pitched roof: two wedges leaning against each other along the ridge. A
	-- WedgePart's slope rises toward +Z, so the far half is spun 180 degrees.
	local roofY = 1.4 + HQ_WALL_HEIGHT + HQ_ROOF_HEIGHT / 2
	local roofHalfDepth = HQ_DEPTH / 2 + 1.2
	for _, half in { { name = "L", yaw = 0, sign = -1 }, { name = "R", yaw = 180, sign = 1 } } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof_" .. half.name
		wedge.Anchored = true
		wedge.CanCollide = true
		wedge.Material = Enum.Material.Slate
		wedge.Color = ROOF_COLOR
		wedge.Size = Vector3.new(HQ_WIDTH + 2.4, HQ_ROOF_HEIGHT, roofHalfDepth)
		wedge.CFrame = CFrame.new(center + Vector3.new(0, roofY, half.sign * roofHalfDepth / 2))
			* CFrame.Angles(0, math.rad(half.yaw), 0)
		setCollisionGroup(wedge)
		wedge.Parent = hqModel
	end

	-- Ridge cap hides the seam where the two wedges meet.
	place(
		"RoofRidge",
		Vector3.new(HQ_WIDTH + 2.8, 0.7, 1),
		TIMBER_DARK,
		Enum.Material.Wood,
		Vector3.new(0, 1.4 + HQ_WALL_HEIGHT + HQ_ROOF_HEIGHT, 0),
		false
	)

	local chimney = place(
		"Chimney",
		Vector3.new(2.4, 7, 2.4),
		STONE_COLOR,
		Enum.Material.Brick,
		Vector3.new(HQ_WIDTH / 2 - 4, 1.4 + HQ_WALL_HEIGHT + 3.5, 0),
		false
	)
	place(
		"ChimneyCap",
		Vector3.new(3, 0.6, 3),
		Color3.fromRGB(86, 84, 80),
		Enum.Material.Slate,
		Vector3.new(HQ_WIDTH / 2 - 4, 1.4 + HQ_WALL_HEIGHT + 7.2, 0),
		false
	)

	local smoke = Instance.new("Smoke")
	smoke.Size = 2.4
	smoke.RiseVelocity = 4
	smoke.Opacity = 0.18
	smoke.Color = Color3.fromRGB(196, 196, 196)
	smoke.Parent = chimney

	-- Front face (toward the player, -Z) gets a framed door and windows.
	local frontZ = -(HQ_DEPTH / 2) - 0.2

	place(
		"DoorFrame",
		Vector3.new(5.4, 8, 0.5),
		TIMBER_DARK,
		Enum.Material.Wood,
		Vector3.new(0, 1.4 + 4, frontZ),
		false
	)
	place(
		"Door",
		Vector3.new(4.4, 7, 0.4),
		Color3.fromRGB(104, 68, 44),
		Enum.Material.WoodPlanks,
		Vector3.new(0, 1.4 + 3.5, frontZ - 0.15),
		false
	)
	place(
		"DoorHandle",
		Vector3.new(0.4, 0.4, 0.4),
		Color3.fromRGB(214, 178, 88),
		Enum.Material.Metal,
		Vector3.new(1.5, 1.4 + 3.5, frontZ - 0.4),
		false
	)

	for i, side in { -1, 1 } do
		local windowX = side * 8.5
		place(
			"WindowFrame_" .. i,
			Vector3.new(4.4, 4.4, 0.4),
			TIMBER_DARK,
			Enum.Material.Wood,
			Vector3.new(windowX, 1.4 + 6, frontZ),
			false
		)
		place(
			"Window_" .. i,
			Vector3.new(3.6, 3.6, 0.3),
			WINDOW_COLOR,
			Enum.Material.Glass,
			Vector3.new(windowX, 1.4 + 6, frontZ - 0.15),
			false
		)
		-- Flower box under each window.
		place(
			"WindowBox_" .. i,
			Vector3.new(4.4, 0.9, 1.2),
			TIMBER_DARK,
			Enum.Material.Wood,
			Vector3.new(windowX, 1.4 + 3.4, frontZ - 0.5),
			false
		)
		place(
			"WindowFlowers_" .. i,
			Vector3.new(4, 0.8, 1),
			Color3.fromRGB(206, 88, 116),
			Enum.Material.Grass,
			Vector3.new(windowX, 1.4 + 4.1, frontZ - 0.5),
			false
		)
	end

	-- Warm interior glow spilling out of the doorway.
	local light = Instance.new("PointLight")
	light.Brightness = 1.4
	light.Range = 22
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Parent = footing

	-- Deliberately no floating "VOID RESEARCH STATION" billboard here. Every
	-- plot built one, so 10 plots put 10 identical labels in the sky on top of
	-- their CLAIM PLOT / SELL / WAREHOUSE labels. The plot number now lives on
	-- the ClaimGate sign instead, and SELL/WAREHOUSE only appear once a plot
	-- is actually claimed (see setPlotPowered in PlotManager.lua).
end

-- Claim gate: a timber gateway standing in the plot's front fence line. Walking
-- through the opening claims the plot -- PlotClaimTrigger.server.lua owns the
-- .Touched wiring, matching how the Dropbox and Warehouse triggers are split
-- between geometry here and behaviour there.
--
-- This replaces a floating neon orb above the farmhouse that had to be clicked
-- from within range. A gateway sits exactly where a player is already walking
-- (the hub walkway leads straight into it) and needs no aiming.
-- Dimensions (GATE_WIDTH/HEIGHT/POST_WIDTH/CLEAR_HALF_WIDTH) are declared near
-- the fence constants above, since createPlotBorder needs them to leave the
-- doorway gap in the front fence line.
local function createClaimGate(plotModel: Model, gridPosition: Vector3, plotIndex: number)
	local gate = Instance.new("Model")
	gate.Name = "ClaimGate"
	gate.Parent = plotModel

	-- Sits in the front fence line (-Z edge), which is the side the spawn
	-- walkway arrives from.
	local center = gridPosition + Vector3.new(0, 0, -PLOT_DEPTH / 2)

	local function place(name: string, size: Vector3, color: Color3, material: Enum.Material, offset: Vector3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.Material = material
		part.Color = color
		part.Size = size
		part.Position = center + offset
		part.Parent = gate
		return part
	end

	for _, side in { { name = "L", sign = -1 }, { name = "R", sign = 1 } } do
		local post = place(
			"GatePost_" .. side.name,
			Vector3.new(GATE_POST_WIDTH, GATE_HEIGHT, GATE_POST_WIDTH),
			TIMBER_DARK,
			Enum.Material.Wood,
			Vector3.new(side.sign * (GATE_WIDTH / 2), GATE_HEIGHT / 2, 0)
		)
		post.CanCollide = true
		setCollisionGroup(post)

		-- Cap on each post so the gateway has a finished top.
		place(
			"GatePostCap_" .. side.name,
			Vector3.new(GATE_POST_WIDTH + 0.7, 0.6, GATE_POST_WIDTH + 0.7),
			TIMBER_LIGHT,
			Enum.Material.Wood,
			Vector3.new(side.sign * (GATE_WIDTH / 2), GATE_HEIGHT + 0.3, 0)
		)
	end

	-- Crossbeam spanning the posts, with a signboard hung beneath it.
	place(
		"GateBeam",
		Vector3.new(GATE_WIDTH + GATE_POST_WIDTH + 1.6, 1.2, 1.4),
		TIMBER_LIGHT,
		Enum.Material.Wood,
		Vector3.new(0, GATE_HEIGHT + 0.6, 0)
	)

	local signBoard = place(
		"GateSign",
		Vector3.new(GATE_WIDTH - 1, 2.6, 0.4),
		Color3.fromRGB(146, 104, 66),
		Enum.Material.WoodPlanks,
		Vector3.new(0, GATE_HEIGHT - 1.2, 0)
	)

	-- Kept named ClaimLabel: PlotManager.lua toggles this on claim/release.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ClaimLabel"
	billboard.Size = UDim2.new(0, 200, 0, 44)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = signBoard

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = `PLOT {plotIndex}\nWALK IN TO CLAIM`
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = label

	-- Warm lamp over the gateway so it reads at night and from a distance.
	local lampColor = Color3.fromRGB(255, 214, 92)
	local lamp = place(
		"GateLamp",
		Vector3.new(1, 1, 1),
		lampColor,
		Enum.Material.Neon,
		Vector3.new(0, GATE_HEIGHT + 1.4, 0)
	)

	local light = Instance.new("PointLight")
	light.Brightness = 2.5
	light.Range = 26
	light.Color = lampColor
	light.Parent = lamp

	-- The claim itself. CanCollide false so the player walks straight through;
	-- CanTouch is what makes .Touched fire. PlotManager disables CanTouch once
	-- the plot is owned.
	local trigger = Instance.new("Part")
	trigger.Name = "ClaimTrigger"
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanTouch = true
	trigger.Transparency = 1
	trigger.Size = Vector3.new(GATE_WIDTH, GATE_HEIGHT - 2, 3)
	trigger.Position = center + Vector3.new(0, (GATE_HEIGHT - 2) / 2, 0)
	trigger.Parent = gate

	-- Stored so PlotClaimTrigger.server.lua can resolve the plot without
	-- re-parsing the model name at touch time.
	local indexValue = Instance.new("IntValue")
	indexValue.Name = "PlotIndex"
	indexValue.Value = plotIndex
	indexValue.Parent = gate
end

-- Market stall where produce gets sold, replacing the neon sell platform and
-- its four glowing pillars. Timber deck, corner posts and a striped awning, so
-- the sell point reads as somewhere a trader stands.
local AWNING_COLOR = Color3.fromRGB(196, 76, 68)
local AWNING_STRIPE = Color3.fromRGB(238, 232, 216)

local function createDropboxPlatform(plotModel: Model, gridPosition: Vector3)
	local groundY = gridPosition.Y
	local center = gridPosition + Vector3.new(0, 0, DROPBOX_Z_OFFSET)

	local function place(
		name: string,
		size: Vector3,
		color: Color3,
		material: Enum.Material,
		offset: Vector3,
		collide: boolean
	): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = collide
		part.Material = material
		part.Color = color
		part.Size = size
		part.Position = center + offset
		if collide then
			setCollisionGroup(part)
		end
		part.Parent = plotModel
		return part
	end

	place(
		"SellPlatform",
		Vector3.new(15, 0.6, 15),
		Color3.fromRGB(146, 104, 66),
		Enum.Material.WoodPlanks,
		Vector3.new(0, groundY + 0.3, 0),
		true
	)

	-- Corner posts holding the awning up.
	local postHeight = 7
	for i, corner in { Vector3.new(-1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(1, 0, 1) } do
		place(
			"SellPillar_" .. i,
			Vector3.new(0.8, postHeight, 0.8),
			TIMBER_DARK,
			Enum.Material.Wood,
			Vector3.new(corner.X * 6.8, groundY + 0.6 + postHeight / 2, corner.Z * 6.8),
			false
		)
	end

	-- Striped awning: alternating slats rather than one flat sheet.
	local awningY = groundY + 0.6 + postHeight + 0.4
	for i = 1, 8 do
		place(
			"AwningSlat_" .. i,
			Vector3.new(15.6, 0.5, 2),
			(i % 2 == 0) and AWNING_COLOR or AWNING_STRIPE,
			Enum.Material.Fabric,
			Vector3.new(0, awningY, -7 + (i - 1) * 2),
			false
		)
	end

	-- Crates stacked at the back of the stall.
	for i, crate in { Vector3.new(-5, 0, 5.5), Vector3.new(-5, 1.8, 5.5), Vector3.new(5.2, 0, 5.8) } do
		place(
			"Crate_" .. i,
			Vector3.new(2.6, 2.6, 2.6),
			Color3.fromRGB(158, 118, 74),
			Enum.Material.WoodPlanks,
			Vector3.new(crate.X, groundY + 1.9 + crate.Y, crate.Z),
			false
		)
	end
end

-- Barn, replacing the two flat wall segments the void theme used. Same solid
-- wall / real doorway arrangement as before -- two collidable segments flanking
-- a DOORWAY_WIDTH gap -- but with a pitched roof, plank siding and cross-braced
-- doors so it reads as a building instead of a fence panel.
local DOORWAY_WIDTH = 10
local BARN_COLOR = Color3.fromRGB(158, 62, 54)
local BARN_TRIM = Color3.fromRGB(238, 232, 216)
local BARN_HEIGHT = 12
local BARN_ROOF_HEIGHT = 5

local function createWarehouseStructure(plotModel: Model, gridPosition: Vector3)
	local wallSpan = PLOT_WIDTH - 10
	local segmentWidth = (wallSpan - DOORWAY_WIDTH) / 2
	local segmentCenterX = DOORWAY_WIDTH / 2 + segmentWidth / 2
	local center = gridPosition + Vector3.new(0, 0, WAREHOUSE_WALL_Z)

	local function place(
		name: string,
		size: Vector3,
		color: Color3,
		material: Enum.Material,
		offset: Vector3,
		collide: boolean
	): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = collide
		part.Material = material
		part.Color = color
		part.Size = size
		part.Position = center + offset
		if collide then
			setCollisionGroup(part)
		end
		part.Parent = plotModel
		return part
	end

	for _, side in { { name = "L", sign = -1 }, { name = "R", sign = 1 } } do
		place(
			"WarehouseWall_" .. side.name,
			Vector3.new(segmentWidth, BARN_HEIGHT, 3),
			BARN_COLOR,
			Enum.Material.WoodPlanks,
			Vector3.new(side.sign * segmentCenterX, BARN_HEIGHT / 2, 0),
			true
		)
		-- White corner trim, the detail that makes a red barn read as a barn.
		place(
			"BarnTrim_" .. side.name,
			Vector3.new(1, BARN_HEIGHT, 3.3),
			BARN_TRIM,
			Enum.Material.WoodPlanks,
			Vector3.new(side.sign * (segmentCenterX + segmentWidth / 2 - 0.5), BARN_HEIGHT / 2, 0),
			false
		)
	end

	-- Pitched roof spanning the whole barn front.
	local roofY = BARN_HEIGHT + BARN_ROOF_HEIGHT / 2
	local roofDepth = 4.5
	for _, half in { { name = "L", yaw = 0, sign = -1 }, { name = "R", yaw = 180, sign = 1 } } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "BarnRoof_" .. half.name
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.Material = Enum.Material.Slate
		wedge.Color = Color3.fromRGB(88, 84, 88)
		wedge.Size = Vector3.new(wallSpan + 3, BARN_ROOF_HEIGHT, roofDepth)
		wedge.CFrame = CFrame.new(center + Vector3.new(0, roofY, half.sign * roofDepth / 2))
			* CFrame.Angles(0, math.rad(half.yaw), 0)
		wedge.Parent = plotModel
	end

	-- Doorway lintel and its cross-braced doors either side of the gap.
	place(
		"WarehouseDoorGlow",
		Vector3.new(DOORWAY_WIDTH + 1.5, 1.1, 3.4),
		BARN_TRIM,
		Enum.Material.WoodPlanks,
		Vector3.new(0, BARN_HEIGHT - 0.55, 0),
		false
	)

	for _, side in { { name = "L", sign = -1 }, { name = "R", sign = 1 } } do
		place(
			"BarnDoor_" .. side.name,
			Vector3.new(DOORWAY_WIDTH / 2 - 0.3, BARN_HEIGHT - 1.6, 0.5),
			Color3.fromRGB(126, 48, 42),
			Enum.Material.WoodPlanks,
			Vector3.new(side.sign * (DOORWAY_WIDTH / 4), (BARN_HEIGHT - 1.6) / 2, -1.6),
			false
		)
		place(
			"BarnDoorBrace_" .. side.name,
			Vector3.new(DOORWAY_WIDTH / 2 - 0.6, 0.6, 0.3),
			BARN_TRIM,
			Enum.Material.WoodPlanks,
			Vector3.new(side.sign * (DOORWAY_WIDTH / 4), (BARN_HEIGHT - 1.6) / 2, -1.9),
			false
		)
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WarehouseLabel"
	billboard.Size = UDim2.new(0, 160, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	-- Off until the plot is claimed; PlotManager.setPlotPowered turns it on.
	billboard.Enabled = false
	billboard.Parent = plotModel:FindFirstChild("WarehouseDoorGlow")

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "BARN"
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	-- Invisible trigger in the doorway gap; WarehouseTrigger.server.lua wires
	-- the actual .Touched -> OPEN_WAREHOUSE firing.
	local trigger = Instance.new("Part")
	trigger.Name = "WarehouseTrigger"
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Size = Vector3.new(8, 6, 2)
	trigger.Position = center + Vector3.new(0, 3, 0)
	trigger.Parent = plotModel
end

local function buildPlotBase(plotModel: Model, origin: Vector3, plotIndex: number)
	createFloorVeins(plotModel, origin)
	createHeadquarters(plotModel, origin)
	createClaimGate(plotModel, origin, plotIndex)
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

	-- Thickened downward, top face still at gridPosition.Y, so the slab reaches
	-- through the grass surface below (TERRAIN_TOP_Y in TerrainSetup.server.lua)
	-- instead of floating above it -- while every position on the plot that
	-- other code derives from gridPosition.Y stays exactly where it was.
	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Anchored = true
	ground.Size = Vector3.new(PLOT_WIDTH, GROUND_SLAB_THICKNESS, PLOT_DEPTH)
	ground.Position = gridPosition + Vector3.new(0, -GROUND_SLAB_THICKNESS / 2, 0)
	ground.Material = Enum.Material.Ground
	ground.Color = PLOT_SOIL_COLOR
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
	groundGlow.Material = Enum.Material.Grass
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
		Color3.fromRGB(196, 150, 84),
		Enum.Material.WoodPlanks,
		0,
		dropboxCFrame,
		true
	)
	setCollisionGroup(dropbox)
	dropbox.Parent = plotModel

	local dropboxRing = createCylinder(
		"DropboxRing",
		Vector3.new(0.3, 10.5, 10.5),
		Color3.fromRGB(238, 200, 120),
		Enum.Material.Wood,
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

-- Per-plot pcall so a fault in one plot's geometry can't wipe out the other
-- nine, and so the failure is reported by name instead of the world just
-- silently coming up empty.
local builtPlots = 0
for i = 1, PLOT_COUNT do
	if not plotsFolder:FindFirstChild("Plot_" .. i) then
		local ok, err = pcall(createPlot, i, plotsFolder)
		if ok then
			builtPlots += 1
		else
			warn(`[PlotSetup] Failed to build Plot_{i}: {err}`)
		end
	else
		builtPlots += 1
	end
end

-- Sentinel other setup scripts can WaitForChild on. ScenerySetup.server.lua
-- needs every plot to exist before it measures their bounding boxes to decide
-- where scenery may go; watching the folder alone would race, since children
-- appear one at a time during the loop above.
if not plotsFolder:FindFirstChild("PlotsReady") then
	local ready = Instance.new("BoolValue")
	ready.Name = "PlotsReady"
	ready.Value = true
	ready.Parent = plotsFolder
end

print(`[PlotSetup] Created {builtPlots}/{PLOT_COUNT} plots`)
