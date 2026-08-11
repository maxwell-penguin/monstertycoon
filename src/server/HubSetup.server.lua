local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local COLLISION_GROUP = "PlotGround" -- reuse PlotSetup.server.lua's walkable-ground group

pcall(function()
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
end)

-- Without a SpawnLocation, Roblox drops players at world origin -- which is now
-- the middle of the shared farm world PlotSetup.server.lua builds. This builds
-- a neutral hub south of it so players start outside the farm and walk forward
-- (+Z) through it, past the merchant, and on into the plot grid beyond.
--
-- Layout along Z:
--   -172..-128  spawn plaza
--   -128..-110  walkway
--   -110..110   shared farm world (biomes, sell point), entered through the
--               30-stud gateway in its south border wall at X=0
--    140        merchant stall (offset to X=-70, see MerchantSetup.server.lua)
--    170..380   plot grid rows 0 and 1
local PLAZA_Z = -150
local PLAZA_WIDTH = 90
local PLAZA_DEPTH = 44
local WALKWAY_WIDTH = 14
local WALKWAY_START_Z = -128
-- Runs right up to the farm world's south border wall (Z=-110), whose gateway
-- the player walks through. It must not stop short: a gap would leave a strip
-- of grass 2 studs below the path to drop into and climb back out of.
local WALKWAY_END_Z = -110
-- Matches GROUND_SLAB_THICKNESS in PlotSetup.server.lua; see TERRAIN_TOP_Y in
-- TerrainSetup.server.lua for why these slabs extend below their top face.
local SLAB_THICKNESS = 3

-- Arrival dais under the SpawnLocation. Comfortably wider than the 14-stud
-- spawn pad it carries, and small enough to leave walking room inside the
-- 44-deep plaza.
local DAIS_DIAMETER = 22

-- Natural village palette. This was near-black stone with purple neon accents
-- to match the old void theme; the world is daylit grassland now, so the hub
-- is cobblestone, timber and warm lantern light instead.
local STONE = Color3.fromRGB(148, 144, 136)
local STONE_DARK = Color3.fromRGB(112, 108, 101)
local TIMBER = Color3.fromRGB(112, 78, 50)
local LANTERN = Color3.fromRGB(255, 206, 132)
local GOLD = Color3.fromRGB(255, 210, 60)

local function setCollisionGroup(part: BasePart)
	part.CollisionGroup = COLLISION_GROUP
end

local function newPart(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	position: Vector3,
	canCollide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = canCollide
	part.Position = position
	return part
end

-- A Roblox Cylinder lies on its side unrotated; this stands it up so its round
-- face points along world Y. Once rotated, local X is the vertical axis, so the
-- Size reads (thickness, diameter, diameter). Same trick as PlotSetup.
local UPRIGHT_CYLINDER = CFrame.Angles(0, 0, math.rad(90))

local function newDisc(
	name: string,
	diameter: number,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	position: Vector3,
	canCollide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(thickness, diameter, diameter)
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = canCollide
	part.CFrame = CFrame.new(position) * UPRIGHT_CYLINDER
	return part
end

local function buildHub(): Model
	local model = Instance.new("Model")
	model.Name = "SpawnHub"

	-- Thickened downward (top face still Y=0) so it reaches through the grass
	-- surface at TERRAIN_TOP_Y instead of floating above it. Same treatment as
	-- the plot Ground slabs in PlotSetup.server.lua.
	local plaza = newPart(
		"Plaza",
		Vector3.new(PLAZA_WIDTH, SLAB_THICKNESS, PLAZA_DEPTH),
		STONE,
		Enum.Material.Cobblestone,
		Vector3.new(0, -SLAB_THICKNESS / 2, PLAZA_Z),
		true
	)
	setCollisionGroup(plaza)
	plaza.Parent = model
	model.PrimaryPart = plaza

	-- Sits slightly proud of the plaza top (Y=0) rather than flush with it;
	-- coplanar faces z-fight, which is what made the plot floors flicker.
	-- SmoothPlastic in a muted tint, not full-bright Neon: this is a large
	-- floor inlay, and now that it's opaque a neon fill would read as a glowing
	-- slab rather than an accent.
	local plazaGlow = newPart(
		"PlazaGlow",
		Vector3.new(PLAZA_WIDTH - 6, 0.02, PLAZA_DEPTH - 6),
		STONE_DARK,
		Enum.Material.Slate,
		Vector3.new(0, 0.03, PLAZA_Z),
		false
	)
	plazaGlow.Parent = model

	local walkwayLength = WALKWAY_END_Z - WALKWAY_START_Z
	local walkwayCenterZ = (WALKWAY_START_Z + WALKWAY_END_Z) / 2

	local walkway = newPart(
		"Walkway",
		Vector3.new(WALKWAY_WIDTH, SLAB_THICKNESS, walkwayLength),
		STONE,
		Enum.Material.Slate,
		Vector3.new(0, -SLAB_THICKNESS / 2, walkwayCenterZ),
		true
	)
	setCollisionGroup(walkway)
	walkway.Parent = model

	-- Neon edge strips down both sides of the walkway -- reads as a lane
	-- pointing at the plot grid, which is the direction a new player needs to
	-- go to find an unclaimed plot gateway.
	for _, side in { { name = "L", sign = -1 }, { name = "R", sign = 1 } } do
		local strip = newPart(
			"WalkwayStrip_" .. side.name,
			Vector3.new(0.4, 0.04, walkwayLength),
			STONE_DARK,
			Enum.Material.Slate,
			Vector3.new(side.sign * (WALKWAY_WIDTH / 2 - 0.5), 0.04, walkwayCenterZ),
			false
		)
		strip.Parent = model
	end

	-- Corner pillars frame the plaza.
	for i, corner in
		{
			Vector3.new(-1, 0, -1),
			Vector3.new(-1, 0, 1),
			Vector3.new(1, 0, -1),
			Vector3.new(1, 0, 1),
		}
	do
		local pillarPosition = Vector3.new(
			corner.X * (PLAZA_WIDTH / 2 - 3),
			6,
			PLAZA_Z + corner.Z * (PLAZA_DEPTH / 2 - 3)
		)

		local pillar = newPart("Pillar_" .. i, Vector3.new(2, 12, 2), TIMBER, Enum.Material.Wood, pillarPosition, false)
		pillar.Parent = model

		local cap = newPart(
			"PillarCap_" .. i,
			Vector3.new(2.6, 0.5, 2.6),
			LANTERN,
			Enum.Material.Neon,
			pillarPosition + Vector3.new(0, 6.2, 0),
			false
		)
		cap.Parent = model

		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range = 26
		light.Color = LANTERN
		light.Parent = cap
	end

	-- Welcome sign at the back of the plaza, facing the player as they spawn.
	local signPost = newPart(
		"SignPost",
		Vector3.new(0.6, 10, 0.6),
		TIMBER,
		Enum.Material.Wood,
		Vector3.new(0, 5, PLAZA_Z - PLAZA_DEPTH / 2 + 4),
		false
	)
	signPost.Parent = model

	local signBoard = newPart(
		"SignBoard",
		Vector3.new(26, 7, 0.6),
		TIMBER,
		Enum.Material.WoodPlanks,
		Vector3.new(0, 12, PLAZA_Z - PLAZA_DEPTH / 2 + 4),
		false
	)
	signBoard.Parent = model

	local signGlow = Instance.new("SurfaceGui")
	signGlow.Name = "SignGui"
	signGlow.Face = Enum.NormalId.Back -- faces +Z, toward a player standing on the plaza
	signGlow.Adornee = signBoard
	signGlow.Parent = signBoard

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextScaled = true
	signLabel.TextColor3 = GOLD
	signLabel.Text = "MONSTER FARM"
	signLabel.Parent = signGlow

	local signLight = Instance.new("PointLight")
	signLight.Brightness = 2
	signLight.Range = 30
	signLight.Color = GOLD
	signLight.Parent = signBoard

	-- Arrival dais. The spawn pad used to be a flat dark square laid straight on
	-- PlazaGlow, near enough the same tone that the point a player actually
	-- materialises on was the least distinct thing in the hub. It is now a
	-- raised round platform with a lit rim, so the spawn reads as a destination
	-- from across the plaza and at night.
	--
	-- The stack is deliberately stepped rather than stacked flush -- coplanar
	-- faces z-fight, which is the flicker this file's other comments keep
	-- warning about. Plaza top is Y=0 and PlazaGlow tops out at 0.04, so every
	-- layer here starts above that and each one overlaps the one below.
	local daisRim = newDisc(
		"SpawnDaisRim",
		DAIS_DIAMETER + 2,
		0.4,
		LANTERN,
		Enum.Material.Neon,
		Vector3.new(0, 0.26, PLAZA_Z),
		false
	)
	daisRim.Parent = model

	local rimLight = Instance.new("PointLight")
	rimLight.Brightness = 1.6
	rimLight.Range = 22
	rimLight.Color = LANTERN
	rimLight.Parent = daisRim

	-- Wider than the rim is tall, so the rim shows as a ring of light around it
	-- rather than being swallowed.
	local dais = newDisc(
		"SpawnDais",
		DAIS_DIAMETER,
		0.5,
		STONE,
		Enum.Material.Cobblestone,
		Vector3.new(0, 0.36, PLAZA_Z),
		true
	)
	setCollisionGroup(dais)
	dais.Parent = model

	-- Chevrons inlaid into the plaza ahead of the dais, pointing the way the
	-- walkway runs (+Z). The walkway's edge strips already draw that line once
	-- you are on it; these give the same cue to someone who has just spawned and
	-- is still standing on the pad deciding which way to face.
	for i = 1, 3 do
		local chevronZ = PLAZA_Z + DAIS_DIAMETER / 2 + 3 + (i - 1) * 3.2
		for _, side in { { name = "L", sign = -1 }, { name = "R", sign = 1 } } do
			local wing = newPart(
				`SpawnChevron_{i}{side.name}`,
				Vector3.new(4.4, 0.04, 0.7),
				LANTERN,
				Enum.Material.Neon,
				Vector3.new(side.sign * 1.5, 0.08, chevronZ),
				false
			)
			-- Angled into a > shape opening toward the walkway.
			wing.CFrame = CFrame.new(wing.Position) * CFrame.Angles(0, side.sign * math.rad(30), 0)
			wing.Transparency = 0.25 + (i - 1) * 0.2 -- fades out with distance from the pad
			wing.Parent = model
		end
	end

	-- Unrotated, a SpawnLocation's LookVector is -Z, which would face players
	-- away from the plot grid. Rotating 180 degrees about Y points them at it.
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "HubSpawn"
	-- Thin pad riding just above the dais top (0.61) rather than a full
	-- stud-tall block sunk into it: a lip in the middle of the spawn point is a
	-- trip hazard for a character that just materialised on top of it.
	spawnLocation.Size = Vector3.new(14, 0.24, 14)
	spawnLocation.CFrame = CFrame.new(0, 0.75, PLAZA_Z) * CFrame.Angles(0, math.rad(180), 0)
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = true
	spawnLocation.Material = Enum.Material.Cobblestone
	spawnLocation.Color = STONE_DARK
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0 -- no spawn forcefield; it hides the character in a dark scene
	setCollisionGroup(spawnLocation)
	spawnLocation.Parent = model

	return model
end

if not Workspace:FindFirstChild("SpawnHub") then
	local hub = buildHub()
	hub.Parent = Workspace
	print("[HubSetup] Created spawn hub")
end
