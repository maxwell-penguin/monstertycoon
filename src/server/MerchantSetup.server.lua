local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local COLLISION_GROUP = "PlotGround" -- reuse PlotSetup.server.lua's walkable-ground group

pcall(function()
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
end)

-- Must stay clear of the plot grid PlotSetup.server.lua builds (5 columns x
-- 110 studs, 2 rows x 130 studs, columns centered on world X=0) -- placed
-- well before row 0 (negative Z) so it never overlaps a plot.
--
-- Offset to -70 on X so the stall sits *beside* HubSetup.server.lua's spawn
-- walkway (14 studs wide, centered on X=0) rather than on top of it -- the
-- counter is CanCollide and would otherwise wall off the path from spawn to
-- the plots.
local HUB_CENTER_X = -70
local HUB_Z = -90

local STALL_COLOR = Color3.fromRGB(90, 60, 140)
local ACCENT_COLOR = Color3.fromRGB(140, 100, 220)
local NPC_COLOR = Color3.fromRGB(200, 170, 255)

local function setCollisionGroup(part: BasePart)
	part.CollisionGroup = COLLISION_GROUP
end

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material, cframe: CFrame, canCollide: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = canCollide
	part.CFrame = cframe
	return part
end

local function buildMerchant(): Model
	local model = Instance.new("Model")
	model.Name = "Merchant"

	local base = Vector3.new(HUB_CENTER_X, 0, HUB_Z)

	local platform = newPart("Platform", Vector3.new(20, 1, 16), Color3.fromRGB(20, 16, 35), Enum.Material.SmoothPlastic, CFrame.new(base + Vector3.new(0, 0.5, 0)), true)
	setCollisionGroup(platform)
	platform.Parent = model
	model.PrimaryPart = platform

	local counter = newPart("Counter", Vector3.new(8, 3, 3), STALL_COLOR, Enum.Material.SmoothPlastic, CFrame.new(base + Vector3.new(0, 2.5, -3)), true)
	setCollisionGroup(counter)
	counter.Parent = model

	local counterTop = newPart("CounterTop", Vector3.new(8.4, 0.3, 3.4), ACCENT_COLOR, Enum.Material.Neon, CFrame.new(base + Vector3.new(0, 4.15, -3)), false)
	counterTop.Parent = model

	local roofPost1 = newPart("RoofPost_L", Vector3.new(0.6, 6, 0.6), STALL_COLOR, Enum.Material.SmoothPlastic, CFrame.new(base + Vector3.new(-4, 4, -4.4)), false)
	roofPost1.Parent = model
	local roofPost2 = newPart("RoofPost_R", Vector3.new(0.6, 6, 0.6), STALL_COLOR, Enum.Material.SmoothPlastic, CFrame.new(base + Vector3.new(4, 4, -4.4)), false)
	roofPost2.Parent = model

	local roof = newPart("Roof", Vector3.new(9, 0.6, 4.5), ACCENT_COLOR, Enum.Material.Neon, CFrame.new(base + Vector3.new(0, 7, -4.4)) * CFrame.Angles(math.rad(-10), 0, 0), false)
	roof.Parent = model

	-- Simple blocky NPC standing behind the counter.
	local torso = newPart("NPCTorso", Vector3.new(2, 2.4, 1.2), NPC_COLOR, Enum.Material.SmoothPlastic, CFrame.new(base + Vector3.new(0, 3.2, -4.2)), false)
	torso.Parent = model

	local head = newPart("NPCHead", Vector3.new(1.4, 1.4, 1.4), NPC_COLOR, Enum.Material.SmoothPlastic, CFrame.new(base + Vector3.new(0, 5, -4.2)), false)
	head.Parent = model

	local eyeL = newPart("NPCEyeL", Vector3.new(0.3, 0.3, 0.1), Color3.new(1, 1, 1), Enum.Material.Neon, CFrame.new(base + Vector3.new(-0.3, 5.1, -3.5)), false)
	eyeL.Parent = model
	local eyeR = newPart("NPCEyeR", Vector3.new(0.3, 0.3, 0.1), Color3.new(1, 1, 1), Enum.Material.Neon, CFrame.new(base + Vector3.new(0.3, 5.1, -3.5)), false)
	eyeR.Parent = model

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 20
	light.Color = ACCENT_COLOR
	light.Parent = counterTop

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MerchantLabel"
	billboard.Size = UDim2.new(0, 170, 0, 26)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "HABITAT MERCHANT"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	-- Invisible touch trigger in front of the counter; MerchantTrigger.server.lua
	-- owns the actual .Touched wiring, matching the Dropbox/Warehouse split.
	local trigger = Instance.new("Part")
	trigger.Name = "MerchantTrigger"
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Size = Vector3.new(9, 6, 6)
	trigger.CFrame = CFrame.new(base + Vector3.new(0, 3, 0))
	trigger.Parent = model

	return model
end

if not Workspace:FindFirstChild("Merchant") then
	local merchant = buildMerchant()
	merchant.Parent = Workspace
	print("[MerchantSetup] Created merchant NPC")
end
