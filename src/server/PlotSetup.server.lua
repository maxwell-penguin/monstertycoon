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

local function setupVoidAtmosphere()
	Lighting.Ambient = Color3.fromRGB(20, 15, 35)
	Lighting.OutdoorAmbient = Color3.fromRGB(10, 8, 20)
	Lighting.Brightness = 0.3
	Lighting.ClockTime = 0
	Lighting.FogEnd = 300
	Lighting.FogStart = 150
	Lighting.FogColor = Color3.fromRGB(8, 5, 18)

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.4
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(80, 60, 120)
	atmosphere.Decay = Color3.fromRGB(20, 10, 40)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.5
	atmosphere.Parent = Lighting

	-- Placeholder ids (0) until a real void sky texture is authored and uploaded.
	local sky = Instance.new("Sky")
	sky.SkyboxBk = "rbxassetid://0"
	sky.SkyboxDn = "rbxassetid://0"
	sky.SkyboxFt = "rbxassetid://0"
	sky.SkyboxLf = "rbxassetid://0"
	sky.SkyboxRt = "rbxassetid://0"
	sky.SkyboxUp = "rbxassetid://0"
	sky.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Brightness = -0.05
	colorCorrection.Contrast = 0.1
	colorCorrection.Saturation = -0.1
	colorCorrection.TintColor = Color3.fromRGB(200, 180, 255)
	colorCorrection.Parent = Lighting
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

	-- Sits on the ground (bottom at groundY), top face at groundY + 6.
	local base = createCylinder(
		"Base",
		padSize(3, 6),
		Color3.fromRGB(80, 140, 200),
		Enum.Material.SmoothPlastic,
		isVisible and 0 or 1,
		padCFrame(groundY + 3),
		isVisible
	)
	setCollisionGroup(base)
	base.Parent = slotModel

	local topGlow = createCylinder(
		"TopGlow",
		padSize(2.8, 0.15),
		Color3.fromRGB(100, 180, 255),
		Enum.Material.Neon,
		isVisible and 0.3 or 1,
		padCFrame(groundY + 6.05),
		false
	)
	topGlow.Parent = slotModel

	local ring = createCylinder(
		"Ring",
		padSize(3.6, 0.2),
		GLOW_BLUE,
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

	local slotIndexValue = Instance.new("IntValue")
	slotIndexValue.Name = "SlotIndex"
	slotIndexValue.Value = slotIndex
	slotIndexValue.Parent = slotModel

	local isOccupied = Instance.new("BoolValue")
	isOccupied.Name = "IsOccupied"
	isOccupied.Value = false
	isOccupied.Parent = slotModel
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
	ground.Material = Enum.Material.Granite
	ground.Color = Color3.fromRGB(15, 12, 25)
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

	local warehouseArea = Instance.new("Part")
	warehouseArea.Name = "WarehouseArea"
	warehouseArea.Anchored = true
	warehouseArea.Size = Vector3.new(40, 1, 20)
	warehouseArea.Position = gridPosition + Vector3.new(0, 0.5, 25)
	warehouseArea.Transparency = 0.5
	setCollisionGroup(warehouseArea)
	warehouseArea.Parent = plotModel

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
