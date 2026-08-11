local Workspace = game:GetService("Workspace")

-- Scatters trees and rocks across the terrain around the built world. The
-- grass itself is Terrain (see TerrainSetup.server.lua), whose Decoration
-- setting grows real 3D blades -- placing blocky part "tufts" on top of that
-- only made the ground look built out of bricks.
--
-- Keep-out areas are measured from the actual models at runtime (plot bounding
-- boxes, the spawn hub, the merchant stall) rather than re-deriving the grid
-- maths from PlotSetup.server.lua's constants. Those constants are already
-- duplicated once in MerchantSetup.server.lua and drifted when the spacing
-- changed; reading the world keeps this correct no matter how the layout moves.
--
-- Everything built here is opaque on purpose -- see the transparency notes in
-- PlotSetup.server.lua. Semi-transparent props scattered across the whole map
-- would bring back exactly the sorting shimmer that was just removed.

-- Terrain is 700x700 centred on the origin (see TerrainSetup.server.lua); stay
-- inside its edge so nothing hangs over into the void.
local TERRAIN_HALF = 350
local SCATTER_LIMIT = TERRAIN_HALF - 15
-- Must match TERRAIN_TOP_Y in TerrainSetup.server.lua. Terrain surfaces are
-- smoothed between voxels, so props sink slightly in places -- which reads
-- fine for trunks and rocks sitting in grass.
local GROUND_Y = -2

local PLOT_PADDING = 14
local STRUCTURE_PADDING = 10

local TREE_COUNT = 70
local ROCK_COUNT = 55
local BUSH_COUNT = 90
local FLOWER_COUNT = 110

-- Fixed seed so the scenery is identical on every server, and scoped to its own
-- Random rather than math.randomseed so it can't make the rest of the server's
-- math.random calls (egg rarity, vial offsets) deterministic too. Same reasoning
-- as VOID_SKY_SEED in PlotSetup.server.lua.
local SCENERY_SEED = 1337
local rng = Random.new(SCENERY_SEED)

local TRUNK_COLOR = Color3.fromRGB(64, 44, 32)
local FOLIAGE_COLORS = {
	Color3.fromRGB(46, 84, 42),
	Color3.fromRGB(58, 100, 50),
	Color3.fromRGB(38, 72, 40),
}
local ROCK_COLORS = {
	Color3.fromRGB(128, 124, 116),
	Color3.fromRGB(146, 142, 133),
	Color3.fromRGB(108, 104, 98),
}
local BUSH_COLORS = {
	Color3.fromRGB(64, 108, 54),
	Color3.fromRGB(78, 124, 62),
	Color3.fromRGB(52, 94, 48),
}
local FLOWER_COLORS = {
	Color3.fromRGB(226, 96, 116),
	Color3.fromRGB(240, 198, 84),
	Color3.fromRGB(158, 130, 216),
	Color3.fromRGB(238, 240, 244),
	Color3.fromRGB(238, 138, 74),
}
-- A Roblox cylinder's axis runs along local X, so this stands one upright and
-- its Size becomes (height, diameter, diameter). Same trick PlotSetup uses.
local UPRIGHT_CYLINDER = CFrame.Angles(0, 0, math.rad(90))

type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

local keepOut: { Rect } = {}

local function addKeepOut(instance: Instance?, padding: number)
	if not instance then
		return
	end

	local cframe: CFrame
	local size: Vector3

	if instance:IsA("Model") then
		cframe, size = instance:GetBoundingBox()
	elseif instance:IsA("BasePart") then
		cframe, size = instance.CFrame, instance.Size
	else
		return
	end

	local center = cframe.Position
	table.insert(keepOut, {
		minX = center.X - size.X / 2 - padding,
		maxX = center.X + size.X / 2 + padding,
		minZ = center.Z - size.Z / 2 - padding,
		maxZ = center.Z + size.Z / 2 + padding,
	})
end

local function addKeepOutForParts(model: Instance, padding: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			addKeepOut(descendant, padding)
		end
	end
end

local function isBlocked(x: number, z: number): boolean
	for _, rect in keepOut do
		if x >= rect.minX and x <= rect.maxX and z >= rect.minZ and z <= rect.maxZ then
			return true
		end
	end
	return false
end

-- Rejection sampling: the keep-out areas cover a modest share of the baseplate,
-- so a bounded number of tries per prop is plenty and can't spin forever if the
-- world ever grows enough to crowd the map.
local function findOpenSpot(): (number?, number?)
	for _ = 1, 30 do
		local x = rng:NextNumber(-SCATTER_LIMIT, SCATTER_LIMIT)
		local z = rng:NextNumber(-SCATTER_LIMIT, SCATTER_LIMIT)
		if not isBlocked(x, z) then
			return x, z
		end
	end
	return nil, nil
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function newPart(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	cframe: CFrame,
	canCollide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = canCollide
	part.CastShadow = false
	part.Locked = true
	part.CFrame = cframe
	return part
end

local function buildTree(parent: Instance, x: number, z: number, index: number)
	local model = Instance.new("Model")
	model.Name = "Tree_" .. index

	local height = rng:NextNumber(9, 16)
	local trunkWidth = rng:NextNumber(1.1, 1.8)
	local foliageColor = pick(FOLIAGE_COLORS)

	local trunk = newPart(
		"Trunk",
		Vector3.new(height, trunkWidth, trunkWidth),
		TRUNK_COLOR,
		Enum.Material.Wood,
		CFrame.new(x, GROUND_Y + height / 2, z) * UPRIGHT_CYLINDER,
		true
	)
	trunk.Shape = Enum.PartType.Cylinder
	-- Trees are the tallest scenery and the only props worth the shadow cost;
	-- rocks stay CastShadow=false (set in newPart).
	trunk.CastShadow = true
	trunk.Parent = model
	model.PrimaryPart = trunk

	-- Three overlapping spheres of decreasing size make a rough canopy without
	-- needing a mesh asset.
	local canopyBase = GROUND_Y + height * 0.75
	for i = 1, 3 do
		local diameter = rng:NextNumber(6, 9) - (i - 1) * 1.4
		local blob = newPart(
			"Canopy_" .. i,
			Vector3.new(diameter, diameter, diameter),
			foliageColor,
			Enum.Material.Grass,
			CFrame.new(
				x + rng:NextNumber(-1.2, 1.2),
				canopyBase + (i - 1) * 2.1,
				z + rng:NextNumber(-1.2, 1.2)
			),
			false
		)
		blob.Shape = Enum.PartType.Ball
		blob.CastShadow = true
		blob.Parent = model
	end

	model.Parent = parent
end

local function buildRock(parent: Instance, x: number, z: number, index: number)
	-- Bigger and sitting higher than before. Grass decoration blades stand
	-- roughly a stud tall, and a small rock half-buried at the old height
	-- disappeared into them entirely.
	local diameter = rng:NextNumber(2.4, 5.5)
	local rock = newPart(
		"Rock_" .. index,
		Vector3.new(diameter, diameter * rng:NextNumber(0.6, 0.9), diameter),
		pick(ROCK_COLORS),
		Enum.Material.Slate,
		CFrame.new(x, GROUND_Y + diameter * 0.4, z) * CFrame.Angles(
			rng:NextNumber(-0.2, 0.2),
			rng:NextNumber(0, math.pi * 2),
			rng:NextNumber(-0.2, 0.2)
		),
		false
	)
	rock.Shape = Enum.PartType.Ball
	rock.Parent = parent
end

-- Clustered spheres at ground level. Cheap, but they break up the flat lawn
-- between plots far more than scattered rocks alone did.
local function buildBush(parent: Instance, x: number, z: number, index: number)
	local model = Instance.new("Model")
	model.Name = "Bush_" .. index

	local color = pick(BUSH_COLORS)
	local lobes = rng:NextInteger(3, 5)

	for i = 1, lobes do
		local diameter = rng:NextNumber(2.4, 4.4)
		local lobe = newPart(
			"Lobe_" .. i,
			Vector3.new(diameter, diameter, diameter),
			color,
			Enum.Material.Grass,
			CFrame.new(
				x + rng:NextNumber(-1.5, 1.5),
				GROUND_Y + diameter * 0.35,
				z + rng:NextNumber(-1.5, 1.5)
			),
			false
		)
		lobe.Shape = Enum.PartType.Ball
		lobe.Parent = model
	end

	model.Parent = parent
end

-- A patch of stems with coloured heads. Purely decorative and non-colliding,
-- so they never get in the way of walking.
local function buildFlowerPatch(parent: Instance, x: number, z: number, index: number)
	local model = Instance.new("Model")
	model.Name = "Flowers_" .. index

	local color = pick(FLOWER_COLORS)
	local count = rng:NextInteger(4, 8)

	for i = 1, count do
		local fx = x + rng:NextNumber(-2.6, 2.6)
		local fz = z + rng:NextNumber(-2.6, 2.6)
		local height = rng:NextNumber(1, 1.8)

		local stem = newPart(
			"Stem_" .. i,
			Vector3.new(0.16, height, 0.16),
			Color3.fromRGB(72, 116, 56),
			Enum.Material.Grass,
			CFrame.new(fx, GROUND_Y + height / 2, fz),
			false
		)
		stem.Parent = model

		local head = newPart(
			"Head_" .. i,
			Vector3.new(0.7, 0.7, 0.7),
			color,
			Enum.Material.Grass,
			CFrame.new(fx, GROUND_Y + height + 0.2, fz),
			false
		)
		head.Shape = Enum.PartType.Ball
		head.Parent = model
	end

	model.Parent = parent
end

local function buildScenery()
	local sceneryFolder = Instance.new("Folder")
	sceneryFolder.Name = "Scenery"
	sceneryFolder.Parent = Workspace

	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = sceneryFolder

	local rocks = Instance.new("Folder")
	rocks.Name = "Rocks"
	rocks.Parent = sceneryFolder

	local placed = 0

	for i = 1, TREE_COUNT do
		local x, z = findOpenSpot()
		if x and z then
			buildTree(trees, x, z, i)
			placed += 1
		end
	end

	for i = 1, ROCK_COUNT do
		local x, z = findOpenSpot()
		if x and z then
			buildRock(rocks, x, z, i)
			placed += 1
		end
	end

	local bushes = Instance.new("Folder")
	bushes.Name = "Bushes"
	bushes.Parent = sceneryFolder

	for i = 1, BUSH_COUNT do
		local x, z = findOpenSpot()
		if x and z then
			buildBush(bushes, x, z, i)
			placed += 1
		end
	end

	local flowers = Instance.new("Folder")
	flowers.Name = "Flowers"
	flowers.Parent = sceneryFolder

	for i = 1, FLOWER_COUNT do
		local x, z = findOpenSpot()
		if x and z then
			buildFlowerPatch(flowers, x, z, i)
			placed += 1
		end
	end

	return placed
end

if not Workspace:FindFirstChild("Scenery") then
	-- Wait for the world these props have to route around. PlotsReady is set by
	-- PlotSetup.server.lua only once every plot exists.
	local plotsFolder = Workspace:WaitForChild("Plots")
	plotsFolder:WaitForChild("PlotsReady")

	for _, plotModel in plotsFolder:GetChildren() do
		if plotModel:IsA("Model") then
			addKeepOut(plotModel, PLOT_PADDING)
		end
	end

	-- Per-part rather than one model-wide box. The hub's bounding box spans the
	-- full plaza width for the entire length of the walkway, which would strip
	-- scenery from a 90-stud corridor either side of a 14-stud path -- the
	-- stretch where planting actually looks best.
	addKeepOutForParts(Workspace:WaitForChild("SpawnHub"), STRUCTURE_PADDING)
	addKeepOutForParts(Workspace:WaitForChild("Merchant"), STRUCTURE_PADDING)

	local placed = buildScenery()
	print(`[ScenerySetup] Placed {placed} scenery props`)
end
