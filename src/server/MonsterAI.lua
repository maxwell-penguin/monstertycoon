-- MonsterAI: spawns blob models for each slotted monster and makes them roam their biome
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Constants)
local Types = require(ReplicatedStorage.Types)
local BiomeData = require(script.Parent.BiomeData)
local BiomeManager = require(script.Parent.BiomeManager)
local HallManager = require(script.Parent.HallManager)
local VialProducer = require(script.Parent.VialProducer)

type Monster = Types.Monster

type ActiveMonster = {
	model: Model,
	monster: Monster,
	biomeName: string,
	biomeCenter: Vector3,
	biomeRadius: number,
	currentTarget: Vector3,
	isMoving: boolean,
	cancellationFlag: { active: boolean },
	userId: number,
	slotIndex: number,
	lastDropTime: number,
}

local MOVE_SPEED = 6 -- studs per second
local IDLE_MIN = 2
local IDLE_MAX = 4
local VIAL_DROP_INTERVAL = 30
local TARGET_REACHED_THRESHOLD = 0.2

local MonsterAI = {}

local activeMonsters: { [string]: ActiveMonster } = {}

local monsterModelsFolder = Workspace:FindFirstChild("MonsterModels") :: Folder?
if not monsterModelsFolder then
	monsterModelsFolder = Instance.new("Folder")
	monsterModelsFolder.Name = "MonsterModels"
	monsterModelsFolder.Parent = Workspace
end

local groundRaycastParams = RaycastParams.new()
groundRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
groundRaycastParams.FilterDescendantsInstances = { monsterModelsFolder }

local function activeKey(userId: number, slotIndex: number): string
	return userId .. "_" .. slotIndex
end

-- Casts straight down from well above the world and returns where it lands;
-- falls back to 0 (matches the farm's GROUND_Y convention) if nothing is hit.
local function GetGroundY(x: number, z: number): number
	local origin = Vector3.new(x, 100, z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -200, 0), groundRaycastParams)
	if result then
		return result.Position.Y
	end
	return 0
end

local function randomPointInBiome(center: Vector3, radius: number): Vector3
	local angle = math.random() * math.pi * 2
	-- sqrt(random) rather than a bare random() keeps points evenly spread across
	-- the disk's area instead of clustering near the center.
	local dist = math.sqrt(math.random()) * radius
	local x = center.X + math.cos(angle) * dist
	local z = center.Z + math.sin(angle) * dist
	return Vector3.new(x, GetGroundY(x, z), z)
end

--============================================================
-- Blob building
--============================================================

local BODY_DIAMETERS = {
	Common = 2.5,
	Uncommon = 3,
	Rare = 3.5,
	Epic = 4,
	Legendary = 4.5,
	Mythic = 5,
}

local function newPart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, cframe: CFrame): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = true
	part.CFrame = cframe
	return part
end

local function addElementDetail(model: Model, element: string, eyeL: BasePart, eyeR: BasePart, bodyRadius: number)
	if element == "Water" then
		local tear = newPart(
			"Teardrop",
			Enum.PartType.Ball,
			Vector3.new(0.2, 0.3, 0.2),
			Color3.fromRGB(80, 140, 230),
			CFrame.new(eyeL.Position + Vector3.new(0, -0.5, -0.1))
		)
		tear.Parent = model
	elseif element == "Fire" then
		local browColor = Color3.fromRGB(220, 40, 40)
		local browSize = Vector3.new(0.2, 0.4, 0.2)

		local browL = newPart(
			"BrowL",
			Enum.PartType.Block,
			browSize,
			browColor,
			CFrame.new(eyeL.Position + Vector3.new(0.1, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(-25))
		)
		browL.Parent = model

		local browR = newPart(
			"BrowR",
			Enum.PartType.Block,
			browSize,
			browColor,
			CFrame.new(eyeR.Position + Vector3.new(-0.1, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(25))
		)
		browR.Parent = model
	elseif element == "Nature" then
		local mouthColor = Color3.fromRGB(255, 210, 60)
		local mouthSize = Vector3.new(0.15, 0.15, 0.15)
		local frontZ = -(bodyRadius * 0.85)

		local arc = {
			Vector3.new(-0.25, -0.15, frontZ),
			Vector3.new(0, -0.3, frontZ),
			Vector3.new(0.25, -0.15, frontZ),
		}
		for i, offset in arc do
			local dot = newPart("Mouth" .. i, Enum.PartType.Ball, mouthSize, mouthColor, CFrame.new(offset))
			dot.Parent = model
		end
	elseif element == "Void" then
		local handColor = Color3.fromRGB(60, 60, 65)
		local handSize = Vector3.new(0.5, 0.5, 0.5)

		local handL = newPart("HandL", Enum.PartType.Ball, handSize, handColor, CFrame.new(eyeL.Position + Vector3.new(0, 0, -0.3)))
		handL.Parent = model

		local handR = newPart("HandR", Enum.PartType.Ball, handSize, handColor, CFrame.new(eyeR.Position + Vector3.new(0, 0, -0.3)))
		handR.Parent = model
	elseif element == "Galaxy" then
		local mustache = newPart(
			"Mustache",
			Enum.PartType.Cylinder,
			Vector3.new(0.6, 0.15, 0.15),
			Color3.fromRGB(220, 170, 220),
			CFrame.new(0, 0, -(bodyRadius * 0.9))
		)
		mustache.Parent = model
	end
	-- All other elements: no extra parts.
end

function MonsterAI.BuildBlob(element: string, rarity: string): Model
	local model = Instance.new("Model")
	model.Name = "Blob"

	local bodyDiameter = BODY_DIAMETERS[rarity] or BODY_DIAMETERS.Common
	local bodySize = Vector3.new(bodyDiameter, bodyDiameter, bodyDiameter)
	local bodyRadius = bodyDiameter / 2
	local elementColor = Constants.ELEMENT_COLORS[element] or Color3.new(1, 1, 1)

	local body = newPart("HumanoidRootPart", Enum.PartType.Ball, bodySize, elementColor, CFrame.new(0, 0, 0))
	body.Parent = model

	local eyeSize = Vector3.new(0.6, 0.6, 0.6)
	local eyeColor = Color3.fromRGB(255, 255, 255)
	local frontZ = -(bodyRadius * 0.9)

	local eyeL = newPart("EyeL", Enum.PartType.Ball, eyeSize, eyeColor, CFrame.new(body.Position + Vector3.new(-0.4, 0.3, frontZ)))
	eyeL.Parent = model

	local eyeR = newPart("EyeR", Enum.PartType.Ball, eyeSize, eyeColor, CFrame.new(body.Position + Vector3.new(0.4, 0.3, frontZ)))
	eyeR.Parent = model

	local pupilSize = Vector3.new(0.3, 0.3, 0.3)
	local pupilColor = Color3.fromRGB(10, 10, 10)

	local pupilL = newPart("PupilL", Enum.PartType.Ball, pupilSize, pupilColor, CFrame.new(eyeL.Position + Vector3.new(0, 0, -0.15)))
	pupilL.Parent = model

	local pupilR = newPart("PupilR", Enum.PartType.Ball, pupilSize, pupilColor, CFrame.new(eyeR.Position + Vector3.new(0, 0, -0.15)))
	pupilR.Parent = model

	addElementDetail(model, element, eyeL, eyeR, bodyRadius)

	local light = Instance.new("PointLight")
	light.Brightness = 1
	light.Range = 12
	light.Color = elementColor
	light.Parent = body

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model

	model.PrimaryPart = body

	return model
end

local function addNameTag(model: Model, name: string, element: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(0, 120, 0, 20)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = model.PrimaryPart

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = Constants.ELEMENT_COLORS[element] or Color3.new(1, 1, 1)
	label.Text = name
	label.Parent = billboard
end

--============================================================
-- Vial production
--============================================================

function MonsterAI.CheckVialProduction(key: string)
	local entry = activeMonsters[key]
	if not entry then
		return
	end

	local now = os.time()
	if now - entry.lastDropTime < VIAL_DROP_INTERVAL then
		return
	end
	entry.lastDropTime = now

	local player = Players:GetPlayerByUserId(entry.userId)
	if not player then
		return
	end

	local slot: Types.MonsterSlot = {
		slotIndex = entry.slotIndex,
		monster = entry.monster,
		isActive = true,
	}

	local worldPosition = entry.model:GetPivot().Position + Vector3.new(0, 1, 0)
	VialProducer.SpawnVial(player, slot, worldPosition)
end

--============================================================
-- Roaming
--============================================================

local function pickNextTarget(key: string)
	local entry = activeMonsters[key]
	if not entry or not entry.cancellationFlag.active then
		return
	end

	local target = randomPointInBiome(entry.biomeCenter, entry.biomeRadius)
	if not BiomeData.IsInBiome(target, entry.biomeName) then
		target = entry.biomeCenter
	end

	entry.currentTarget = target
	entry.isMoving = true
end

-- One persistent Heartbeat connection per monster for its whole lifetime; it
-- self-disconnects once cancellationFlag.active goes false or the model is
-- gone. No while loop drives the movement itself.
function MonsterAI.RoamLoop(key: string)
	local entry = activeMonsters[key]
	if not entry then
		return
	end

	local flag = entry.cancellationFlag
	pickNextTarget(key)

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		local liveEntry = activeMonsters[key]
		if not flag.active or not liveEntry or not liveEntry.model.Parent then
			connection:Disconnect()
			return
		end

		if not liveEntry.isMoving then
			return
		end

		local model = liveEntry.model
		local currentPosition = model:GetPivot().Position
		local toTarget = liveEntry.currentTarget - currentPosition
		local distance = toTarget.Magnitude

		if distance <= TARGET_REACHED_THRESHOLD then
			liveEntry.isMoving = false
			MonsterAI.CheckVialProduction(key)

			task.delay(IDLE_MIN + math.random() * (IDLE_MAX - IDLE_MIN), function()
				pickNextTarget(key)
			end)
			return
		end

		local step = math.min(MOVE_SPEED * dt, distance)
		local direction = toTarget.Unit
		local newPosition = currentPosition + direction * step
		local lookTarget = newPosition + Vector3.new(direction.X, 0, direction.Z)

		model:PivotTo(CFrame.lookAt(newPosition, lookTarget))
	end)
end

--============================================================
-- Spawn / despawn
--============================================================

function MonsterAI.SpawnMonster(player: Player, slotIndex: number, monster: Monster): boolean
	local biomeName = BiomeData.GetBiomeForElement(monster.element)
	if not biomeName then
		return false
	end

	local unlocked = BiomeManager.GetUnlockedBiomes(player)
	if not table.find(unlocked, biomeName) then
		warn(`[MonsterAI] {player.Name}'s monster in slot {slotIndex} belongs to locked biome {biomeName} -- not spawning`)
		return false
	end

	-- Defensive: clears any stale model left over from re-slotting into this
	-- slot without an intervening DespawnMonster call.
	MonsterAI.DespawnMonster(player, slotIndex)

	local biome = BiomeData.BIOMES[biomeName]
	local bodyDiameter = BODY_DIAMETERS[monster.rarity] or BODY_DIAMETERS.Common
	local spawnPosition = randomPointInBiome(biome.center, biome.radius)

	local model = MonsterAI.BuildBlob(monster.element, monster.rarity)
	model.Name = `Monster_{player.UserId}_{slotIndex}`
	model:PivotTo(CFrame.new(spawnPosition + Vector3.new(0, bodyDiameter / 2, 0)))
	addNameTag(model, monster.name, monster.element)
	model.Parent = monsterModelsFolder

	local key = activeKey(player.UserId, slotIndex)
	activeMonsters[key] = {
		model = model,
		monster = monster,
		biomeName = biomeName,
		biomeCenter = biome.center,
		biomeRadius = biome.radius,
		currentTarget = spawnPosition,
		isMoving = false,
		cancellationFlag = { active = true },
		userId = player.UserId,
		slotIndex = slotIndex,
		lastDropTime = os.time(),
	}

	MonsterAI.RoamLoop(key)

	return true
end

function MonsterAI.DespawnMonster(player: Player, slotIndex: number)
	local key = activeKey(player.UserId, slotIndex)
	local entry = activeMonsters[key]
	if not entry then
		return
	end

	entry.cancellationFlag.active = false
	entry.model:Destroy()
	activeMonsters[key] = nil
end

function MonsterAI.SpawnAllMonsters(player: Player)
	for _, slot in HallManager.GetSlots(player) do
		if slot.isActive and slot.monster then
			MonsterAI.SpawnMonster(player, slot.slotIndex, slot.monster)
		end
	end
end

function MonsterAI.DespawnAllMonsters(player: Player)
	local userId = player.UserId
	-- Removing the current key mid-traversal is well-defined in Lua/Luau (only
	-- adding new keys during a `for...in` traversal is unsafe).
	for key, entry in activeMonsters do
		if entry.userId == userId then
			entry.cancellationFlag.active = false
			entry.model:Destroy()
			activeMonsters[key] = nil
		end
	end
end

function MonsterAI.UpdateRoster(player: Player)
	local userId = player.UserId
	local slottedByIndex: { [number]: Types.MonsterSlot } = {}

	for _, slot in HallManager.GetSlots(player) do
		if slot.isActive and slot.monster then
			slottedByIndex[slot.slotIndex] = slot
		end
	end

	for key, entry in activeMonsters do
		if entry.userId == userId and not slottedByIndex[entry.slotIndex] then
			entry.cancellationFlag.active = false
			entry.model:Destroy()
			activeMonsters[key] = nil
		end
	end

	for slotIndex, slot in slottedByIndex do
		local key = activeKey(userId, slotIndex)
		if not activeMonsters[key] then
			MonsterAI.SpawnMonster(player, slotIndex, slot.monster :: Monster)
		end
	end
end

return MonsterAI
