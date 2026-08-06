local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(script.Parent.BiomeData)
local Constants = require(ReplicatedStorage.Constants)

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

--============================================================
-- Void atmosphere
--============================================================

local function setupVoidAtmosphere()
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(180, 180, 200)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 160, 185)
	Lighting.ClockTime = 0
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 1200
	Lighting.FogStart = 800
	Lighting.FogColor = Color3.fromRGB(10, 8, 20)

	for _, child in ipairs(Lighting:GetChildren()) do
		if
			child:IsA("Sky")
			or child:IsA("Atmosphere")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("BloomEffect")
		then
			child:Destroy()
		end
	end

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 0.99
	bloom.Parent = Lighting

	local voidSky = Instance.new("Model")
	voidSky.Name = "VoidSky"
	voidSky.Parent = Workspace

	local rng = Random.new(42)
	local starColors = {
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(210, 190, 255),
		Color3.fromRGB(180, 200, 255),
		Color3.fromRGB(255, 220, 200),
	}

	for i = 1, 300 do
		local size = rng:NextNumber(0.2, 0.7)
		local theta = rng:NextNumber(0, math.pi * 2)
		local phi = math.acos(rng:NextNumber(-1, 1))
		local radius = rng:NextNumber(400, 600)

		local x = radius * math.sin(phi) * math.cos(theta)
		local y = math.abs(radius * math.cos(phi)) + 100
		local z = radius * math.sin(phi) * math.sin(theta)

		local star = createBall(
			"Star_" .. i,
			Vector3.new(size, size, size),
			starColors[rng:NextInteger(1, #starColors)],
			Enum.Material.Neon,
			0,
			Vector3.new(x, y, z)
		)
		star.CastShadow = false
		star.Locked = true
		star.Parent = voidSky
	end

	local nebulaColors = {
		Color3.fromRGB(60, 20, 100),
		Color3.fromRGB(80, 15, 80),
		Color3.fromRGB(20, 30, 100),
		Color3.fromRGB(40, 10, 70),
		Color3.fromRGB(15, 40, 90),
		Color3.fromRGB(50, 10, 60),
	}

	for i = 1, 6 do
		local size = rng:NextNumber(100, 200)
		local nebula = createBall(
			"Nebula_" .. i,
			Vector3.new(size, size, size),
			nebulaColors[i],
			Enum.Material.Neon,
			rng:NextNumber(0.93, 0.97),
			Vector3.new(rng:NextNumber(-300, 300), rng:NextNumber(150, 350), rng:NextNumber(-300, 300))
		)
		nebula.CastShadow = false
		nebula.Locked = true
		nebula.Parent = voidSky
	end
end

--============================================================
-- Farm world
--============================================================

local function createBaseTerrain()
	local terrain = Workspace.Terrain
	terrain:FillBlock(CFrame.new(0, 0, 0), Vector3.new(220, 2, 220), Enum.Material.Grass)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(45, 85, 35))
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(60, 30, 10))
	terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(15, 25, 35))

	terrain:FillCylinder(CFrame.new(0, 0, 0), 2, 100, Enum.Material.Grass)
	terrain:FillCylinder(CFrame.new(-80, 0, -80), 2, 40, Enum.Material.Basalt)
	terrain:FillCylinder(CFrame.new(80, 0, -80), 2, 40, Enum.Material.Grass)
	terrain:FillCylinder(CFrame.new(0, 0, -70), 2, 35, Enum.Material.Mud)
end

local function createSellPoint()
	local sellPoint = Instance.new("Model")
	sellPoint.Name = "SellPoint"
	sellPoint.Parent = Workspace

	local platform = createCylinder(
		"SellPlatform",
		padSize(18, 2),
		Color3.fromRGB(0, 220, 100),
		Enum.Material.Neon,
		0,
		CFrame.new(0, 1, 40) * UPRIGHT_CYLINDER,
		true
	)
	platform.Parent = sellPoint

	local ring = createCylinder(
		"OuterRing",
		padSize(22, 0.3),
		Color3.fromRGB(0, 255, 120),
		Enum.Material.Neon,
		0.4,
		CFrame.new(0, 0.15, 40) * UPRIGHT_CYLINDER,
		false
	)
	ring.Parent = sellPoint

	local ring2 = createCylinder(
		"OuterRing2",
		padSize(26, 0.3),
		Color3.fromRGB(0, 255, 120),
		Enum.Material.Neon,
		0.7,
		CFrame.new(0, 0.15, 40) * UPRIGHT_CYLINDER,
		false
	)
	ring2.Parent = sellPoint

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SellLabel"
	billboard.Size = UDim2.new(4, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
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
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.Position = Vector3.new(0, 1, 60)
	spawnLocation.Parent = Workspace
end

local function createForestDecorations()
	local folder = Instance.new("Model")
	folder.Name = "ForestDecorations"
	folder.Parent = Workspace

	local rng = Random.new(123)

	local TREE_VARIANTS = {
		{ trunkDiameter = 1.2, trunkHeight = 12, topSize = Vector3.new(4, 5, 4), topColor = Color3.fromRGB(50, 130, 60) },
		{ trunkDiameter = 2, trunkHeight = 6, topSize = Vector3.new(6, 4, 6), topColor = Color3.fromRGB(70, 150, 50) },
		{ trunkDiameter = 1.5, trunkHeight = 9, topSize = Vector3.new(5, 5, 5), topColor = Color3.fromRGB(40, 120, 55) },
	}
	local TRUNK_COLOR = Color3.fromRGB(90, 65, 35)

	local spawned = 0
	while spawned < 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(85, 98)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius

		if (x * x + z * z) < (85 * 85) then
			continue
		end

		spawned += 1

		local variant = TREE_VARIANTS[rng:NextInteger(1, #TREE_VARIANTS)]

		local trunk = createCylinder(
			"Tree_" .. spawned,
			padSize(variant.trunkDiameter, variant.trunkHeight),
			TRUNK_COLOR,
			Enum.Material.SmoothPlastic,
			0,
			CFrame.new(x, 1 + variant.trunkHeight / 2, z) * UPRIGHT_CYLINDER,
			true
		)
		trunk.Parent = folder

		local top = createBall(
			"Tree_" .. spawned .. "_Top",
			variant.topSize,
			variant.topColor,
			Enum.Material.Grass,
			0,
			Vector3.new(x, 1 + variant.trunkHeight + variant.topSize.Y / 2, z)
		)
		top.Parent = folder
	end

	for i = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(60, 90)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius

		local stem = createCylinder(
			"Mushroom_" .. i .. "_Stem",
			padSize(1.2, 5),
			Color3.fromRGB(210, 190, 230),
			Enum.Material.SmoothPlastic,
			0,
			CFrame.new(x, 1 + 2.5, z) * UPRIGHT_CYLINDER,
			true
		)
		stem.Parent = folder

		local cap = createBall(
			"Mushroom_" .. i .. "_Cap",
			Vector3.new(6, 4, 6),
			Color3.fromRGB(190, 130, 230),
			Enum.Material.Neon,
			0.15,
			Vector3.new(x, 1 + 5 + 2, z)
		)
		cap.Parent = folder

		local light = Instance.new("PointLight")
		light.Brightness = 1.5
		light.Range = 15
		light.Color = Color3.fromRGB(180, 100, 255)
		light.Parent = cap
	end
end

-- Gate/trigger sit along the straight line from the farm center (0,0,0) toward
-- the biome's own center, `biome.radius` studs out from that center -- i.e.
-- the point where a straight walk from spawn first reaches the biome edge.
local function createBiomeGate(biomeName: string, biome, gateColor: Color3)
	local dir = biome.center
	local dirUnit = dir.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, 1)
	local gatePos = biome.center - dirUnit * biome.radius

	local gate = createBlock(
		"BiomeGate_" .. biomeName,
		Vector3.new(0.5, 10, 16),
		gateColor,
		Enum.Material.Neon,
		0,
		CFrame.lookAt(gatePos + Vector3.new(0, 5, 0), gatePos + Vector3.new(0, 5, 0) + dirUnit),
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
	label.TextSize = 14
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
end

local function createVolcano()
	local folder = Instance.new("Model")
	folder.Name = "VolcanoDecorations"
	folder.Parent = Workspace

	local center = Vector3.new(-80, 0, -80)
	local basaltColor = Color3.fromRGB(60, 30, 10)

	local segments = {
		{ size = Vector3.new(8, 30, 30), y = 15 },
		{ size = Vector3.new(8, 22, 22), y = 30 },
		{ size = Vector3.new(8, 16, 14), y = 43 },
		{ size = Vector3.new(8, 10, 7), y = 53 },
	}

	for i, segment in segments do
		local part = createCylinder(
			"VolcanoSegment_" .. i,
			segment.size,
			basaltColor,
			Enum.Material.Basalt,
			0,
			CFrame.new(center + Vector3.new(0, segment.y, 0)) * UPRIGHT_CYLINDER,
			true
		)
		part.Parent = folder
	end

	local peakY = segments[#segments].y

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

	for i = 1, 4 do
		local y = peakY - (i - 1) * 12
		local flow = createBlock(
			"LavaFlow_" .. i,
			Vector3.new(0.2, 8, 2),
			Color3.fromRGB(255, 100, 0),
			Enum.Material.Neon,
			0.3,
			CFrame.new(center + Vector3.new(0, y, 12)),
			false
		)
		flow.Parent = folder
	end

	createBiomeGate("Volcano", BiomeData.BIOMES.Volcano, Color3.fromRGB(255, 80, 20))
end

local function createWaterfall()
	local folder = Instance.new("Model")
	folder.Name = "WaterfallDecorations"
	folder.Parent = Workspace

	local center = Vector3.new(80, 0, -80)

	local cliff = createBlock(
		"Cliff",
		Vector3.new(8, 35, 25),
		Color3.fromRGB(90, 100, 80),
		Enum.Material.SmoothPlastic,
		0,
		CFrame.new(80, 17, -95),
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
			CFrame.new(80, 2 + (i - 1) * 4, -95 + 4 + i * 0.4),
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
		Vector3.new(80, 2, -83)
	)
	mist.Parent = folder

	local pool = createCylinder(
		"Pool",
		padSize(18, 0.5),
		Color3.fromRGB(80, 160, 220),
		Enum.Material.Neon,
		0.45,
		CFrame.new(center + Vector3.new(0, 0.25, 0)) * UPRIGHT_CYLINDER,
		false
	)
	pool.Parent = folder

	local poolLight = Instance.new("PointLight")
	poolLight.Brightness = 2
	poolLight.Range = 30
	poolLight.Color = Color3.fromRGB(100, 180, 255)
	poolLight.Parent = pool

	createBiomeGate("Waterfall", BiomeData.BIOMES.Waterfall, Color3.fromRGB(80, 160, 255))
end

local function createPond()
	local folder = Instance.new("Model")
	folder.Name = "PondDecorations"
	folder.Parent = Workspace

	local center = Vector3.new(0, 0, -70)
	local rng = Random.new(7)

	local water = createCylinder(
		"MurkyPond",
		padSize(22, 0.5),
		Color3.fromRGB(15, 25, 35),
		Enum.Material.Neon,
		0.5,
		CFrame.new(center + Vector3.new(0, 0.25, 0)) * UPRIGHT_CYLINDER,
		false
	)
	water.Parent = folder

	for i = 1, 6 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(0, 15)
		local pos = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

		local lily = createCylinder(
			"LilyPad_" .. i,
			padSize(3, 0.2),
			Color3.fromRGB(40, 100, 50),
			Enum.Material.Neon,
			0.3,
			CFrame.new(pos + Vector3.new(0, 0.35, 0)) * UPRIGHT_CYLINDER,
			false
		)
		lily.Parent = folder
	end

	for i = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(20, 35)
		local pos = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local tiltX = rng:NextNumber(-0.2, 0.2)
		local tiltZ = rng:NextNumber(-0.2, 0.2)

		local tree = createCylinder(
			"DeadTree_" .. i,
			padSize(1.5, 6),
			Color3.fromRGB(35, 30, 25),
			Enum.Material.SmoothPlastic,
			0,
			CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(tiltX, 0, tiltZ) * UPRIGHT_CYLINDER,
			true
		)
		tree.Parent = folder
	end

	for i = 1, 3 do
		local angle = (i / 3) * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * 10, 0, math.sin(angle) * 10)

		local fog = createBall(
			"Fog_" .. i,
			Vector3.new(15, 5, 15),
			Color3.fromRGB(60, 80, 70),
			Enum.Material.Neon,
			0.9,
			pos + Vector3.new(0, 4, 0)
		)
		fog.Parent = folder
	end

	createBiomeGate("Pond", BiomeData.BIOMES.Pond, Color3.fromRGB(40, 80, 100))
end

local function createFarmBorder()
	local wallColor = Color3.fromRGB(100, 60, 160)
	local walls = {
		{ name = "FarmBorder_1", size = Vector3.new(0.5, 15, 220), pos = Vector3.new(-110, 7.5, 0) },
		{ name = "FarmBorder_2", size = Vector3.new(0.5, 15, 220), pos = Vector3.new(110, 7.5, 0) },
		{ name = "FarmBorder_3", size = Vector3.new(220, 15, 0.5), pos = Vector3.new(0, 7.5, -110) },
		{ name = "FarmBorder_4", size = Vector3.new(220, 15, 0.5), pos = Vector3.new(0, 7.5, 110) },
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

	createBaseTerrain()
	createSellPoint()
	createForestDecorations()
	createVolcano()
	createWaterfall()
	createPond()
	createFarmBorder()
end

setupVoidAtmosphere()
createFarmWorld()
print("[PlotSetup] Farm world created")
