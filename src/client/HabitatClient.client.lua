local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local placeHabitatRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLACE_HABITAT) :: RemoteEvent
local unslotHabitatMonsterRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UNSLOT_HABITAT_MONSTER) :: RemoteEvent

local VALID_COLOR = Color3.fromRGB(80, 220, 120)
local INVALID_COLOR = Color3.fromRGB(220, 80, 80)
local BOUNDS_MARGIN = 3
local ROTATE_STEP = math.rad(15)

-- Mirrors HabitatManager.lua's RESERVED_ZONES/validatePlacement on the server
-- -- this copy is UX-only (instant ghost color feedback); PlaceHabitat always
-- re-validates authoritatively server-side regardless of what this says.
local RESERVED_ZONES = {
	{ x = 0, z = 35, halfWidth = 17, halfDepth = 8 },
	{ x = 0, z = -10, halfWidth = 22, halfDepth = 18 },
	{ x = 0, z = -30, halfWidth = 10, halfDepth = 10 },
	{ x = 0, z = 28, halfWidth = 27, halfDepth = 5 },
}

local function rectsOverlap(ax: number, az: number, ahw: number, ahd: number, bx: number, bz: number, bhw: number, bhd: number): boolean
	return math.abs(ax - bx) < (ahw + bhw) and math.abs(az - bz) < (ahd + bhd)
end

local function findPlayerPlot(): Model?
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end

	for _, plotModel in plotsFolder:GetChildren() do
		local ownerId = plotModel:FindFirstChild("OwnerId")
		if ownerId and ownerId.Value == tostring(player.UserId) then
			return plotModel :: Model
		end
	end

	return nil
end

local function isValidPlacementLocal(x: number, z: number, ground: BasePart): boolean
	local footprint = Constants.HABITAT_FOOTPRINT
	local footHalfW = footprint.width / 2
	local footHalfD = footprint.depth / 2

	local boundHalfWidth = ground.Size.X / 2 - BOUNDS_MARGIN
	local boundHalfDepth = ground.Size.Z / 2 - BOUNDS_MARGIN

	if
		x - footHalfW < -boundHalfWidth
		or x + footHalfW > boundHalfWidth
		or z - footHalfD < -boundHalfDepth
		or z + footHalfD > boundHalfDepth
	then
		return false
	end

	for _, zone in RESERVED_ZONES do
		if rectsOverlap(x, z, footHalfW, footHalfD, zone.x, zone.z, zone.halfWidth, zone.halfDepth) then
			return false
		end
	end

	local habitatState = shared.HabitatState
	if habitatState then
		for _, habitat in habitatState.habitats do
			if rectsOverlap(x, z, footHalfW, footHalfD, habitat.placement.x, habitat.placement.z, footHalfW, footHalfD) then
				return false
			end
		end
	end

	return true
end

local function findBiomeDef(biomeType: string): any
	for _, def in Constants.HABITAT_TYPES do
		if def.biomeType == biomeType then
			return def
		end
	end
	return nil
end

--============================================================
-- Placement mode
--============================================================

local placementBiome: string? = nil
local ghost: BasePart? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local currentX, currentZ, currentRotation = 0, 0, 0
local currentValid = false

local HabitatClientAPI = {}

local function destroyGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

function HabitatClientAPI.CancelPlacementMode()
	placementBiome = nil
	destroyGhost()
end

function HabitatClientAPI.EnterPlacementMode(biomeType: string)
	local biomeDef = findBiomeDef(biomeType)
	if not biomeDef then
		return
	end

	local habitatState = shared.HabitatState
	if not habitatState or (habitatState.inventory[biomeType] or 0) <= 0 then
		return
	end

	HabitatClientAPI.CancelPlacementMode()

	placementBiome = biomeType
	currentRotation = 0

	if shared.UIManager then
		shared.UIManager.HidePanel("MerchantPanel")
	end

	local footprint = Constants.HABITAT_FOOTPRINT
	local color = Constants.EMOTION_COLORS[biomeDef.emotion] or Color3.new(1, 1, 1)

	local part = Instance.new("Part")
	part.Name = "HabitatGhost"
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.ForceField
	part.Color = color
	part.Transparency = 0.4
	part.Size = Vector3.new(footprint.width, 1, footprint.depth)
	part.Parent = Workspace
	ghost = part

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		local plotModel = findPlayerPlot()
		local ground = plotModel and (plotModel:FindFirstChild("Ground") :: BasePart?)
		local origin = plotModel and (plotModel:FindFirstChild("Origin") :: BasePart?)
		if not ground or not origin or not ghost then
			return
		end

		local mouseLocation = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { ground }

		local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		if not result then
			return
		end

		local localPoint = origin.CFrame:PointToObjectSpace(result.Position)
		currentX, currentZ = localPoint.X, localPoint.Z
		currentValid = isValidPlacementLocal(currentX, currentZ, ground)

		ghost.CFrame = origin.CFrame * CFrame.new(currentX, 0.5, currentZ) * CFrame.Angles(0, currentRotation, 0)
		ghost.Color = currentValid and VALID_COLOR or INVALID_COLOR
	end)
end

shared.HabitatClient = HabitatClientAPI

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if not placementBiome then
		return
	end

	if input.KeyCode == Enum.KeyCode.R then
		currentRotation += ROTATE_STEP
		return
	end

	if gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		HabitatClientAPI.CancelPlacementMode()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		if not currentValid then
			return
		end
		placeHabitatRemote:FireServer(placementBiome, currentX, currentZ, currentRotation)
		HabitatClientAPI.CancelPlacementMode()
	end
end)

--============================================================
-- Clicking a placed habitat: unslot if occupied, else open the picker
--============================================================

local wiredModels: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function findHabitatById(habitatId: string): any
	local habitatState = shared.HabitatState
	if not habitatState then
		return nil
	end
	for _, habitat in habitatState.habitats do
		if habitat.habitatId == habitatId then
			return habitat
		end
	end
	return nil
end

local function wireHabitatModel(model: Model)
	if wiredModels[model] then
		return
	end
	wiredModels[model] = true

	local habitatId = model.Name:match("^Habitat_(%w+)$")
	if not habitatId then
		return
	end

	local pad = model:FindFirstChild("Pad")
	local clickDetector = pad and pad:FindFirstChild("AssignClickDetector")
	if not clickDetector or not clickDetector:IsA("ClickDetector") then
		return
	end

	clickDetector.MouseClick:Connect(function()
		local habitat = findHabitatById(habitatId)
		if habitat and habitat.monster then
			unslotHabitatMonsterRemote:FireServer(habitatId)
			return
		end

		local uiManager = shared.UIManager :: any
		if uiManager then
			uiManager.selectedHabitatId = habitatId
			uiManager.selectedSlot = nil
			uiManager.ShowPanel("WarehousePanel")
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(1)

		local plotModel = findPlayerPlot()
		if plotModel then
			for _, child in plotModel:GetChildren() do
				if child:IsA("Model") and child.Name:match("^Habitat_") then
					wireHabitatModel(child)
				end
			end
		end
	end
end)
