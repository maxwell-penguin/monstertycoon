local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local BiomeData = require(script.Parent.BiomeData)

local FARM_SIZE = BiomeData.FARM_SIZE
local FARM_CENTER = BiomeData.FARM_CENTER
local GROUND_Y = BiomeData.GROUND_Y
local BIOMES = BiomeData.BIOMES

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local biomeUnlockPromptRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BIOME_UNLOCK_PROMPT) :: RemoteEvent

local function setupVoidAtmosphere()
	local lighting = game:GetService("Lighting")

	-- Keep normal lighting so everything is visible
	lighting.Brightness = 2
	lighting.Ambient = Color3.fromRGB(180, 180, 200)
	lighting.OutdoorAmbient = Color3.fromRGB(160, 160, 185)
	lighting.ClockTime = 0
	lighting.GlobalShadows = true
	lighting.FogEnd = 1200
	lighting.FogStart = 800
	lighting.FogColor = Color3.fromRGB(10, 8, 20)

	-- Remove any existing atmosphere/sky/effects
	for _, child in ipairs(lighting:GetChildren()) do
		if
			child:IsA("Sky")
			or child:IsA("Atmosphere")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("BloomEffect")
		then
			child:Destroy()
		end
	end

	-- Subtle bloom only for neon parts
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 0.99
	bloom.Parent = lighting

	-- Void starfield sky
	local voidSky = Instance.new("Model")
	voidSky.Name = "VoidSky"
	voidSky.Parent = workspace

	local rng = Random.new(42)
	local starColors = {
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(210, 190, 255),
		Color3.fromRGB(180, 200, 255),
		Color3.fromRGB(255, 220, 200),
	}

	-- Stars
	for i = 1, 300 do
		local star = Instance.new("Part")
		star.Name = "Star_" .. i
		star.Shape = Enum.PartType.Ball
		local size = rng:NextNumber(0.2, 0.7)
		star.Size = Vector3.new(size, size, size)
		star.Material = Enum.Material.Neon
		star.Color = starColors[rng:NextInteger(1, #starColors)]
		star.Anchored = true
		star.CanCollide = false
		star.CastShadow = false
		star.Locked = true

		local theta = rng:NextNumber(0, math.pi * 2)
		local phi = math.acos(rng:NextNumber(-1, 1))
		local radius = rng:NextNumber(400, 600)

		local x = radius * math.sin(phi) * math.cos(theta)
		local y = math.abs(radius * math.cos(phi)) + 100
		local z = radius * math.sin(phi) * math.sin(theta)

		star.Position = Vector3.new(x, y, z)
		star.Parent = voidSky
	end

	-- Nebula clouds high up
	local nebulaColors = {
		Color3.fromRGB(60, 20, 100),
		Color3.fromRGB(80, 15, 80),
		Color3.fromRGB(20, 30, 100),
		Color3.fromRGB(40, 10, 70),
		Color3.fromRGB(15, 40, 90),
		Color3.fromRGB(50, 10, 60),
	}

	for i = 1, 6 do
		local nebula = Instance.new("Part")
		nebula.Name = "Nebula_" .. i
		nebula.Shape = Enum.PartType.Ball
		local size = rng:NextNumber(100, 200)
		nebula.Size = Vector3.new(size, size, size)
		nebula.Material = Enum.Material.Neon
		nebula.Color = nebulaColors[i]
		nebula.Transparency = rng:NextNumber(0.93, 0.97)
		nebula.Anchored = true
		nebula.CanCollide = false
		nebula.CastShadow = false
		nebula.Locked = true
		nebula.Position = Vector3.new(rng:NextNumber(-300, 300), rng:NextNumber(150, 350), rng:NextNumber(-300, 300))
		nebula.Parent = voidSky
	end
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

local function createBlock(
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
	part.Anchored = true
	part.CanCollide = canCollide
	part.Material = material
	part.Color = color
	part.Transparency = transparency
	part.Size = size
	part.CFrame = cframe
	return part
end

local function createBall(name: string, size: Vector3, color: Color3, material: Enum.Material, transparency: number, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Material = material
	part.Color = color
	part.Transparency = transparency
	part.Size = size
	part.Position = position
	return part
end

local decorRng = Random.new(7)

-- Ring/annulus placement (min..max radius from center) rather than a filled
-- disk -- used everywhere decorations need to avoid the open play area near
-- the map center (Forest's ring, the Pond's dead-tree ring, etc.).
local function randomPointInAnnulus(center: Vector3, minRadius: number, maxRadius: number): Vector3
	local angle = decorRng:NextNumber(0, math.pi * 2)
	local dist = decorRng:NextNumber(minRadius, maxRadius)
	return center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
end

local function createFarmGround()
	local terrain = Workspace.Terrain
	terrain:FillBlock(CFrame.new(FARM_CENTER), Vector3.new(FARM_SIZE, 2, FARM_SIZE), Enum.Material.Grass)
	terrain:SetMaterialColor(Enum.Material.Grass, BIOMES.Forest.groundColor)
	terrain:SetMaterialColor(Enum.Material.Basalt, BIOMES.Volcano.groundColor)
	terrain:SetMaterialColor(Enum.Material.Mud, BIOMES.Pond.groundColor)

	-- Forest (radius 100) now overlaps every other biome by design -- it has to
	-- fill first as the base layer, with Volcano/Waterfall/Pond carved on top in
	-- a fixed order. `for _, biome in BIOMES` has no guaranteed iteration order,
	-- which would risk Forest re-filling over an already-carved biome.
	local forest = BIOMES.Forest
	terrain:FillCylinder(CFrame.new(forest.center), 2, forest.radius, forest.groundMaterial)

	for _, biomeName in { "Volcano", "Waterfall", "Pond" } do
		local biome = BIOMES[biomeName]
		terrain:FillCylinder(CFrame.new(biome.center), 2, biome.radius, biome.groundMaterial)
	end
end

-- (trunk diameter, trunk height, top size, top color) -- trunk color is the
-- same bark brown across all three variants.
local FOREST_TREE_VARIANTS = {
	{ trunkDiameter = 1.2, trunkHeight = 12, topSize = Vector3.new(4, 5, 4), topColor = Color3.fromRGB(50, 130, 60) },
	{ trunkDiameter = 2, trunkHeight = 6, topSize = Vector3.new(6, 4, 6), topColor = Color3.fromRGB(70, 150, 50) },
	{ trunkDiameter = 1.5, trunkHeight = 9, topSize = Vector3.new(5, 5, 5), topColor = Color3.fromRGB(40, 120, 55) },
}
local FOREST_TRUNK_COLOR = Color3.fromRGB(90, 65, 35)

local function createForestDecorations(biome)
	local folder = Instance.new("Model")
	folder.Name = "ForestDecorations"
	folder.Parent = Workspace

	-- Outer ring of trees around the map edge, well clear of the center play
	-- area (SellPoint's 30-stud clearance).
	for i = 1, 40 do
		local pos = randomPointInAnnulus(biome.center, 85, 98)
		local variant = FOREST_TREE_VARIANTS[decorRng:NextInteger(1, #FOREST_TREE_VARIANTS)]
		local yRotation = decorRng:NextNumber(0, math.pi * 2)

		local trunk = createCylinder(
			"Tree_" .. i,
			padSize(variant.trunkDiameter, variant.trunkHeight),
			FOREST_TRUNK_COLOR,
			Enum.Material.SmoothPlastic,
			0,
			CFrame.new(pos + Vector3.new(0, GROUND_Y + variant.trunkHeight / 2, 0)) * CFrame.Angles(0, yRotation, 0) * UPRIGHT_CYLINDER,
			true
		)
		trunk.Parent = folder

		local top = createBall(
			"Tree_" .. i .. "_Top",
			variant.topSize,
			variant.topColor,
			Enum.Material.Grass,
			0,
			pos + Vector3.new(0, GROUND_Y + variant.trunkHeight + variant.topSize.Y / 2, 0)
		)
		top.Parent = folder
	end

	-- Undergrowth hugging the inner edge of the tree ring.
	for i = 1, 30 do
		local pos = randomPointInAnnulus(biome.center, 80, 90)
		local size = decorRng:NextNumber(1, 2)
		local bush = createBall(
			"Bush_" .. i,
			Vector3.new(size, size, size),
			Color3.fromRGB(55, 120, 45),
			Enum.Material.Grass,
			0,
			pos + Vector3.new(0, GROUND_Y + size / 2, 0)
		)
		bush.Parent = folder
	end

	-- Glowing mushrooms scattered through the forest band.
	for i = 1, 8 do
		local pos = randomPointInAnnulus(biome.center, 60, 90)

		local stem = createCylinder(
			"Mushroom_" .. i .. "_Stem",
			padSize(1.2, 5),
			Color3.fromRGB(210, 190, 230),
			Enum.Material.SmoothPlastic,
			0,
			CFrame.new(pos + Vector3.new(0, GROUND_Y + 2.5, 0)) * UPRIGHT_CYLINDER,
			true
		)
		stem.Parent = folder

		local cap = createBall(
			"Mushroom_" .. i .. "_Cap",
			Vector3.new(6, 4, 6),
			Color3.fromRGB(190, 130, 230),
			Enum.Material.Neon,
			0.15,
			pos + Vector3.new(0, GROUND_Y + 5 + 2, 0)
		)
		cap.Parent = folder

		local light = Instance.new("PointLight")
		light.Brightness = 1.5
		light.Range = 15
		light.Color = Color3.fromRGB(180, 100, 255)
		light.Parent = cap
	end
end

local function createWaterfallDecorations(biome)
	local folder = Instance.new("Model")
	folder.Name = "WaterfallDecorations"
	folder.Parent = Workspace

	local cliffPos = biome.center + Vector3.new(0, 0, -biome.radius * 0.5)
	local cliff = createBlock(
		"Cliff",
		Vector3.new(8, 35, 25),
		Color3.fromRGB(90, 100, 80),
		Enum.Material.SmoothPlastic,
		0,
		CFrame.new(cliffPos + Vector3.new(0, GROUND_Y + 17.5, 0)),
		true
	)
	cliff.Parent = folder

	for i = 1, 8 do
		local strip = createBlock(
			"WaterfallStrip_" .. i,
			Vector3.new(5, 5, 0.4),
			Color3.fromRGB(120, 190, 255),
			Enum.Material.Neon,
			0.25,
			CFrame.new(cliffPos + Vector3.new(0, GROUND_Y + 2 + (i - 1) * 4, 4 + i * 0.4)),
			false
		)
		strip.Parent = folder
	end

	local mist = createBall(
		"Mist",
		Vector3.new(12, 6, 12),
		Color3.fromRGB(200, 230, 255),
		Enum.Material.Neon,
		0.85,
		cliffPos + Vector3.new(0, GROUND_Y + 2, 12)
	)
	mist.Parent = folder

	local pool = createCylinder(
		"Pool",
		padSize(18, 0.5),
		Color3.fromRGB(80, 160, 220),
		Enum.Material.Neon,
		0.45,
		CFrame.new(biome.center + Vector3.new(0, GROUND_Y + 0.25, 0)) * UPRIGHT_CYLINDER,
		false
	)
	pool.Parent = folder

	local poolLight = Instance.new("PointLight")
	poolLight.Brightness = 2
	poolLight.Range = 30
	poolLight.Color = Color3.fromRGB(100, 180, 255)
	poolLight.Parent = pool
end

-- First component of each segment's Size is the vertical thickness (matching
-- padSize's own (thickness, diameter, diameter) convention), so these stack
-- directly as literal Vector3s under UPRIGHT_CYLINDER -- no permutation needed.
local VOLCANO_SEGMENTS = {
	Vector3.new(8, 30, 30),
	Vector3.new(8, 25, 20),
	Vector3.new(8, 20, 12),
	Vector3.new(8, 15, 6),
}

local function createVolcanoDecorations(biome)
	local folder = Instance.new("Model")
	folder.Name = "VolcanoDecorations"
	folder.Parent = Workspace

	local center = biome.center
	local stackY = GROUND_Y
	local peakY = GROUND_Y

	for i, size in VOLCANO_SEGMENTS do
		local height = size.X
		local segmentCenterY = stackY + height / 2
		local segment = createCylinder(
			i == 1 and "VolcanoBase" or ("VolcanoSegment_" .. i),
			size,
			Color3.fromRGB(60, 30, 10),
			Enum.Material.Basalt,
			0,
			CFrame.new(center + Vector3.new(0, segmentCenterY, 0)) * UPRIGHT_CYLINDER,
			true
		)
		segment.Parent = folder
		stackY += height
		peakY = stackY
	end

	local crater = createBall(
		"CraterGlow",
		Vector3.new(8, 8, 8),
		Color3.fromRGB(255, 60, 0),
		Enum.Material.Neon,
		0.2,
		center + Vector3.new(0, peakY, 0)
	)
	crater.Parent = folder

	local light = Instance.new("PointLight")
	light.Brightness = 5
	light.Range = 60
	light.Color = Color3.fromRGB(255, 80, 20)
	light.Parent = crater

	-- Lava flow down one side (+Z), hugging the cone's taper as it descends.
	for i = 1, 4 do
		local segTop = peakY - (i - 1) * (peakY - GROUND_Y) / 4
		local segBottom = peakY - i * (peakY - GROUND_Y) / 4
		local outward = 5 + (i - 1) * 3
		local flow = createBlock(
			"LavaFlow_" .. i,
			Vector3.new(2, segTop - segBottom, 0.3),
			Color3.fromRGB(255, 100, 0),
			Enum.Material.Neon,
			0.3,
			CFrame.new(center + Vector3.new(0, (segTop + segBottom) / 2, outward)),
			false
		)
		flow.Parent = folder
	end
end

local function createPondDecorations(biome)
	local folder = Instance.new("Model")
	folder.Name = "PondDecorations"
	folder.Parent = Workspace

	local water = createCylinder(
		"MurkyPond",
		padSize(22, 0.5),
		Color3.fromRGB(15, 25, 35),
		Enum.Material.Neon,
		0.5,
		CFrame.new(biome.center + Vector3.new(0, GROUND_Y + 0.25, 0)) * UPRIGHT_CYLINDER,
		false
	)
	water.Parent = folder

	for i = 1, 6 do
		local pos = randomPointInAnnulus(biome.center, 0, biome.radius * 0.7)
		local lily = createCylinder(
			"LilyPad_" .. i,
			padSize(3, 0.2),
			Color3.fromRGB(40, 100, 50),
			Enum.Material.Neon,
			0.3,
			CFrame.new(pos + Vector3.new(0, GROUND_Y + 0.35, 0)) * UPRIGHT_CYLINDER,
			false
		)
		lily.Parent = folder
	end

	for i = 1, 10 do
		local pos = randomPointInAnnulus(biome.center, biome.radius * 0.6, biome.radius)
		local tilt = decorRng:NextNumber(-0.2, 0.2)
		local tree = createCylinder(
			"DeadTree_" .. i,
			padSize(1.2, 7),
			Color3.fromRGB(35, 30, 25),
			Enum.Material.SmoothPlastic,
			0,
			CFrame.new(pos + Vector3.new(0, GROUND_Y + 3.5, 0)) * CFrame.Angles(tilt, 0, tilt) * UPRIGHT_CYLINDER,
			true
		)
		tree.Parent = folder
	end

	for i = 1, 3 do
		local angle = (i / 3) * math.pi * 2
		local pos = biome.center + Vector3.new(math.cos(angle) * 10, 0, math.sin(angle) * 10)
		local fog = createBall(
			"Fog_" .. i,
			Vector3.new(15, 5, 15),
			Color3.fromRGB(60, 80, 70),
			Enum.Material.Neon,
			0.9,
			pos + Vector3.new(0, GROUND_Y + 4, 0)
		)
		fog.Parent = folder
	end
end

-- Off-center so the play area isn't dead-center on the map; SpawnLocation
-- below is placed further along +Z so players spawn facing it.
local SELL_POINT_CENTER = FARM_CENTER + Vector3.new(0, 0, 40)

local function createSellPoint()
	local sellPoint = Instance.new("Model")
	sellPoint.Name = "SellPoint"
	sellPoint.Parent = Workspace

	local platform = createCylinder(
		"SellPlatform",
		Vector3.new(2, 18, 18),
		Color3.fromRGB(0, 220, 100),
		Enum.Material.Neon,
		0,
		CFrame.new(SELL_POINT_CENTER + Vector3.new(0, GROUND_Y + 1, 0)) * UPRIGHT_CYLINDER,
		true
	)
	platform.Parent = sellPoint

	local ring = createCylinder(
		"OuterRing",
		Vector3.new(0.3, 22, 22),
		Color3.fromRGB(0, 255, 120),
		Enum.Material.Neon,
		0.4,
		CFrame.new(SELL_POINT_CENTER + Vector3.new(0, GROUND_Y + 0.15, 0)) * UPRIGHT_CYLINDER,
		false
	)
	ring.Parent = sellPoint

	local outerRing2 = createCylinder(
		"OuterRing2",
		Vector3.new(0.3, 26, 26),
		Color3.fromRGB(0, 255, 120),
		Enum.Material.Neon,
		0.7,
		CFrame.new(SELL_POINT_CENTER + Vector3.new(0, GROUND_Y + 0.15, 0)) * UPRIGHT_CYLINDER,
		false
	)
	outerRing2.Parent = sellPoint

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SellLabel"
	billboard.Size = UDim2.new(4, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = platform

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "SELL"
	label.Font = Enum.Font.GothamBold
	label.TextSize = 24
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = billboard

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "FarmSpawn"
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = true
	spawnLocation.Transparency = 1
	spawnLocation.Size = Vector3.new(10, 1, 10)
	spawnLocation.CFrame = CFrame.lookAt(Vector3.new(0, 5, 60), SELL_POINT_CENTER + Vector3.new(0, 5, 0))
	spawnLocation.Parent = Workspace

	return sellPoint
end

local function createBiomeGate(biomeName: string, biome)
	local dir = biome.center - FARM_CENTER
	local dirUnit = dir.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, 1)
	local gatePos = biome.center - dirUnit * biome.radius

	local gate = createBlock(
		"BiomeGate_" .. biomeName,
		Vector3.new(0.5, 10, 16),
		Color3.fromRGB(150, 80, 200),
		Enum.Material.Neon,
		0,
		CFrame.lookAt(gatePos + Vector3.new(0, GROUND_Y + 5, 0), gatePos + Vector3.new(0, GROUND_Y + 5, 0) + dirUnit),
		true
	)
	gate.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GateLabel"
	billboard.Size = UDim2.new(6, 0, 1.5, 0)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = gate

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = `🔒 {biomeName} — {biome.unlockCost} coins to unlock`
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = billboard

	local trigger = Instance.new("Part")
	trigger.Name = "BiomeTrigger_" .. biomeName
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Size = Vector3.new(4, 8, 16)
	trigger.CFrame = CFrame.lookAt(gatePos - dirUnit * 3, gatePos - dirUnit * 3 + dirUnit)
	trigger.Parent = Workspace

	local debounce: { [number]: boolean } = {}
	trigger.Touched:Connect(function(hitPart: BasePart)
		local character = hitPart:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player or debounce[player.UserId] then
			return
		end
		debounce[player.UserId] = true
		task.delay(2, function()
			debounce[player.UserId] = nil
		end)
		biomeUnlockPromptRemote:FireClient(player, biomeName, biome.unlockCost)
	end)
end

local function createFarmBorder()
	local half = FARM_SIZE / 2
	local wallColor = Color3.fromRGB(100, 60, 160)
	local walls = {
		{ name = "FarmBorder_1", size = Vector3.new(0.5, 15, FARM_SIZE), pos = FARM_CENTER + Vector3.new(half, GROUND_Y + 7.5, 0) },
		{ name = "FarmBorder_2", size = Vector3.new(0.5, 15, FARM_SIZE), pos = FARM_CENTER + Vector3.new(-half, GROUND_Y + 7.5, 0) },
		{ name = "FarmBorder_3", size = Vector3.new(FARM_SIZE, 15, 0.5), pos = FARM_CENTER + Vector3.new(0, GROUND_Y + 7.5, half) },
		{ name = "FarmBorder_4", size = Vector3.new(FARM_SIZE, 15, 0.5), pos = FARM_CENTER + Vector3.new(0, GROUND_Y + 7.5, -half) },
	}
	for _, wall in walls do
		local part = createBlock(wall.name, wall.size, wallColor, Enum.Material.Neon, 0.7, CFrame.new(wall.pos), true)
		part.Parent = Workspace
	end
end

local function createFarmWorld()
	if Workspace:FindFirstChild("SellPoint") then
		return
	end

	createFarmGround()
	createForestDecorations(BIOMES.Forest)
	createWaterfallDecorations(BIOMES.Waterfall)
	createVolcanoDecorations(BIOMES.Volcano)
	createPondDecorations(BIOMES.Pond)
	createSellPoint()

	for biomeName, biome in BIOMES do
		if biome.unlockCost > 0 then
			createBiomeGate(biomeName, biome)
		end
	end

	createFarmBorder()

	print("[PlotSetup] Farm world created")
end

createFarmWorld()
