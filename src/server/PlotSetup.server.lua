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

local function randomPointInBiome(center: Vector3, radius: number): Vector3
	local angle = decorRng:NextNumber(0, math.pi * 2)
	local dist = decorRng:NextNumber(0, radius * 0.85)
	return center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
end

local function createFarmGround()
	local terrain = Workspace.Terrain
	terrain:FillBlock(CFrame.new(FARM_CENTER), Vector3.new(FARM_SIZE, 4, FARM_SIZE), Enum.Material.Grass)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(90, 130, 70))
	terrain:SetMaterialColor(Enum.Material.Basalt, BIOMES.Volcano.groundColor)
	terrain:SetMaterialColor(Enum.Material.Mud, BIOMES.Pond.groundColor)

	for _, biome in BIOMES do
		terrain:FillCylinder(CFrame.new(biome.center), biome.radius * 2, biome.radius, biome.groundMaterial)
	end
end

local function createForestDecorations(biome)
	local folder = Instance.new("Model")
	folder.Name = "ForestDecorations"
	folder.Parent = Workspace

	for i = 1, 20 do
		local pos = randomPointInBiome(biome.center, biome.radius)
		local glowing = decorRng:NextNumber() < 0.3

		local trunk = createCylinder(
			"Tree_" .. i,
			padSize(1.5, 8),
			Color3.fromRGB(100, 70, 40),
			Enum.Material.SmoothPlastic,
			0,
			CFrame.new(pos + Vector3.new(0, GROUND_Y + 4, 0)) * UPRIGHT_CYLINDER,
			true
		)
		trunk.Parent = folder

		local top = createBall(
			"Tree_" .. i .. "_Top",
			Vector3.new(8, 7, 8),
			glowing and Color3.fromRGB(80, 200, 100) or Color3.fromRGB(60, 140, 70),
			glowing and Enum.Material.Neon or Enum.Material.Grass,
			0,
			pos + Vector3.new(0, GROUND_Y + 11.5, 0)
		)
		top.Parent = folder
	end

	for i = 1, 5 do
		local pos = randomPointInBiome(biome.center, biome.radius)

		local stem = createCylinder(
			"Mushroom_" .. i .. "_Stem",
			padSize(1, 4),
			Color3.fromRGB(200, 180, 220),
			Enum.Material.SmoothPlastic,
			0,
			CFrame.new(pos + Vector3.new(0, GROUND_Y + 2, 0)) * UPRIGHT_CYLINDER,
			true
		)
		stem.Parent = folder

		local cap = createBall(
			"Mushroom_" .. i .. "_Cap",
			Vector3.new(5, 3, 5),
			Color3.fromRGB(180, 120, 220),
			Enum.Material.Neon,
			0.2,
			pos + Vector3.new(0, GROUND_Y + 5.5, 0)
		)
		cap.Parent = folder
	end
end

local function createWaterfallDecorations(biome)
	local folder = Instance.new("Model")
	folder.Name = "WaterfallDecorations"
	folder.Parent = Workspace

	local cliffPos = biome.center + Vector3.new(0, 0, -biome.radius * 0.6)
	local cliff = createBlock(
		"Cliff",
		Vector3.new(8, 20, 30),
		Color3.fromRGB(100, 110, 90),
		Enum.Material.SmoothPlastic,
		0,
		CFrame.new(cliffPos + Vector3.new(0, GROUND_Y + 10, 0)),
		true
	)
	cliff.Parent = folder

	for i = 1, 5 do
		local strip = createBlock(
			"WaterfallStrip_" .. i,
			Vector3.new(6, 4, 0.5),
			Color3.fromRGB(100, 180, 255),
			Enum.Material.Neon,
			0.3,
			CFrame.new(cliffPos + Vector3.new(0, GROUND_Y + 2 + (i - 1) * 4, 4 + i * 0.3)),
			false
		)
		strip.Parent = folder
	end

	local pond = createCylinder(
		"Pond",
		padSize(20, 0.5),
		Color3.fromRGB(60, 140, 200),
		Enum.Material.Neon,
		0.4,
		CFrame.new(biome.center + Vector3.new(0, GROUND_Y + 0.25, 0)) * UPRIGHT_CYLINDER,
		false
	)
	pond.Parent = folder

	local flowerColors = {
		Color3.fromRGB(255, 180, 220),
		Color3.fromRGB(180, 220, 255),
		Color3.fromRGB(255, 240, 180),
		Color3.fromRGB(210, 180, 255),
	}
	for i = 1, 8 do
		local pos = randomPointInBiome(biome.center, 12)
		local flower = createBall(
			"Flower_" .. i,
			Vector3.new(1, 1, 1),
			flowerColors[decorRng:NextInteger(1, #flowerColors)],
			Enum.Material.Neon,
			0,
			pos + Vector3.new(0, GROUND_Y + 0.5, 0)
		)
		flower.Parent = folder
	end
end

local function createVolcanoDecorations(biome)
	local folder = Instance.new("Model")
	folder.Name = "VolcanoDecorations"
	folder.Parent = Workspace

	local center = biome.center

	local base = createCylinder(
		"VolcanoBase",
		Vector3.new(8, 20, 20),
		Color3.fromRGB(70, 35, 15),
		Enum.Material.Basalt,
		0,
		CFrame.new(center + Vector3.new(0, GROUND_Y + 4, 0)) * UPRIGHT_CYLINDER,
		true
	)
	base.Parent = folder

	local mid = createCylinder(
		"VolcanoMid",
		Vector3.new(8, 15, 13),
		Color3.fromRGB(70, 35, 15),
		Enum.Material.Basalt,
		0,
		CFrame.new(center + Vector3.new(0, GROUND_Y + 12, 0)) * UPRIGHT_CYLINDER,
		true
	)
	mid.Parent = folder

	local top = createCylinder(
		"VolcanoTop",
		Vector3.new(8, 10, 7),
		Color3.fromRGB(70, 35, 15),
		Enum.Material.Basalt,
		0,
		CFrame.new(center + Vector3.new(0, GROUND_Y + 20, 0)) * UPRIGHT_CYLINDER,
		true
	)
	top.Parent = folder

	local crater = createBall(
		"CraterGlow",
		Vector3.new(6, 6, 6),
		Color3.fromRGB(255, 80, 20),
		Enum.Material.Neon,
		0.3,
		center + Vector3.new(0, GROUND_Y + 24, 0)
	)
	crater.Parent = folder

	for i = 1, 12 do
		local pos = randomPointInBiome(center, biome.radius)
		local size = Vector3.new(decorRng:NextNumber(2, 5), decorRng:NextNumber(1, 3), decorRng:NextNumber(2, 5))
		local rock = createBlock(
			"LavaRock_" .. i,
			size,
			Color3.fromRGB(60, 30, 10),
			Enum.Material.Basalt,
			0,
			CFrame.new(pos + Vector3.new(0, GROUND_Y + size.Y / 2, 0)) * CFrame.Angles(0, decorRng:NextNumber(0, math.pi * 2), 0),
			true
		)
		rock.Parent = folder
	end

	for i = 1, 6 do
		local pos = randomPointInBiome(center, biome.radius)
		local crack = createBlock(
			"LavaCrack_" .. i,
			Vector3.new(8, 0.2, 0.2),
			Color3.fromRGB(255, 100, 0),
			Enum.Material.Neon,
			0.4,
			CFrame.new(pos + Vector3.new(0, GROUND_Y + 0.15, 0)) * CFrame.Angles(0, decorRng:NextNumber(0, math.pi * 2), 0),
			false
		)
		crack.Parent = folder
	end
end

local function createPondDecorations(biome)
	local folder = Instance.new("Model")
	folder.Name = "PondDecorations"
	folder.Parent = Workspace

	local water = createCylinder(
		"MurkyPond",
		padSize(25, 0.5),
		Color3.fromRGB(20, 30, 40),
		Enum.Material.Neon,
		0.5,
		CFrame.new(biome.center + Vector3.new(0, GROUND_Y + 0.25, 0)) * UPRIGHT_CYLINDER,
		false
	)
	water.Parent = folder

	for i = 1, 8 do
		local pos = randomPointInBiome(biome.center, biome.radius)
		local tilt = decorRng:NextNumber(-0.2, 0.2)
		local tree = createCylinder(
			"DeadTree_" .. i,
			padSize(1.2, 7),
			Color3.fromRGB(40, 35, 30),
			Enum.Material.SmoothPlastic,
			0,
			CFrame.new(pos + Vector3.new(0, GROUND_Y + 3.5, 0)) * CFrame.Angles(tilt, 0, tilt) * UPRIGHT_CYLINDER,
			true
		)
		tree.Parent = folder
	end

	for i = 1, 6 do
		local pos = randomPointInBiome(biome.center, biome.radius)
		local size = Vector3.new(decorRng:NextNumber(2, 4), decorRng:NextNumber(1, 2), decorRng:NextNumber(2, 4))
		local stone = createBlock(
			"FogStone_" .. i,
			size,
			Color3.fromRGB(50, 50, 60),
			Enum.Material.SmoothPlastic,
			0,
			CFrame.new(pos + Vector3.new(0, GROUND_Y + size.Y / 2, 0)),
			true
		)
		stone.Parent = folder
	end
end

local function createSellPoint()
	local sellPoint = Instance.new("Model")
	sellPoint.Name = "SellPoint"
	sellPoint.Parent = Workspace

	local platform = createCylinder(
		"SellPlatform",
		padSize(16, 2),
		Color3.fromRGB(0, 220, 100),
		Enum.Material.Neon,
		0,
		CFrame.new(FARM_CENTER + Vector3.new(0, GROUND_Y + 1, 0)) * UPRIGHT_CYLINDER,
		true
	)
	platform.Parent = sellPoint

	local ring = createCylinder(
		"OuterRing",
		padSize(20, 0.5),
		Color3.fromRGB(0, 255, 120),
		Enum.Material.Neon,
		0.5,
		CFrame.new(FARM_CENTER + Vector3.new(0, GROUND_Y + 0.25, 0)) * UPRIGHT_CYLINDER,
		false
	)
	ring.Parent = sellPoint

	local pillarOffsets = { Vector3.new(7, 0, 7), Vector3.new(7, 0, -7), Vector3.new(-7, 0, 7), Vector3.new(-7, 0, -7) }
	for i, offset in pillarOffsets do
		local pillar = createCylinder(
			"Pillar_" .. i,
			padSize(1.5, 12),
			Color3.fromRGB(0, 200, 80),
			Enum.Material.Neon,
			0,
			CFrame.new(FARM_CENTER + offset + Vector3.new(0, GROUND_Y + 6, 0)) * UPRIGHT_CYLINDER,
			false
		)
		pillar.Parent = sellPoint
	end

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
	spawnLocation.Position = FARM_CENTER + Vector3.new(0, GROUND_Y + 2.5, -16)
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
