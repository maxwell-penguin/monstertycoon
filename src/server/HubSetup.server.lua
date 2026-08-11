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

	-- Unrotated, a SpawnLocation's LookVector is -Z, which would face players
	-- away from the plot grid. Rotating 180 degrees about Y points them at it.
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "HubSpawn"
	-- Thin pad riding just above PlazaGlow (which tops out at Y=0.04) rather
	-- than a full stud-tall block sitting in it: overlapping neon surfaces
	-- z-fight, and a 1-stud lip in the middle of the spawn point is a trip
	-- hazard for a character that just materialised on top of it.
	spawnLocation.Size = Vector3.new(16, 0.24, 16)
	spawnLocation.CFrame = CFrame.new(0, 0.2, PLAZA_Z) * CFrame.Angles(0, math.rad(180), 0)
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
