local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

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
	ground.Size = Vector3.new(60, 1, 80)
	ground.Position = gridPosition + Vector3.new(0, -0.5, 0)
	ground.Color = Constants.EMOTION_COLORS.Void
	setCollisionGroup(ground)
	ground.Parent = plotModel

	local dropbox = Instance.new("Part")
	dropbox.Name = "Dropbox"
	dropbox.Anchored = true
	dropbox.Size = Vector3.new(6, 4, 6)
	dropbox.Position = gridPosition + Vector3.new(0, 2, -30)
	dropbox.BrickColor = BrickColor.new("Bright green")
	setCollisionGroup(dropbox)
	dropbox.Parent = plotModel

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SellLabel"
	billboard.Size = UDim2.new(4, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
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

	local hallArea = Instance.new("Part")
	hallArea.Name = "HallArea"
	hallArea.Anchored = true
	hallArea.Size = Vector3.new(40, 1, 30)
	hallArea.Position = gridPosition + Vector3.new(0, 0.5, 0)
	hallArea.Transparency = 0.5
	setCollisionGroup(hallArea)
	hallArea.Parent = plotModel

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

for i = 1, PLOT_COUNT do
	if not plotsFolder:FindFirstChild("Plot_" .. i) then
		createPlot(i, plotsFolder)
	end
end

print(`[PlotSetup] Created {PLOT_COUNT} plots`)
