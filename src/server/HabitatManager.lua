local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Constants = require(ReplicatedStorage.Constants)
local Types = require(ReplicatedStorage.Types)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local PlotManager = require(script.Parent.PlotManager)
local WarehouseManager = require(script.Parent.WarehouseManager)
local HabitatVisuals = require(script.Parent.HabitatVisuals)

export type ActiveHabitatMonster = {
	habitatId: string,
	monster: Types.Monster,
}

local HabitatManager = {}

-- Keyed userId -> habitatId -> Habitat, mirrors WarehouseManager's
-- userId -> instanceId -> Monster dictionary shape.
local playerHabitats: { [number]: { [string]: Types.Habitat } } = {}
local playerInventory: { [number]: { [string]: number } } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateHabitatsRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_HABITATS) :: RemoteEvent

local function generateHabitatId(): string
	return HttpService:GenerateGUID(false):sub(1, 8)
end

local function findBiomeDef(biomeType: string): any
	for _, def in Constants.HABITAT_TYPES do
		if def.biomeType == biomeType then
			return def
		end
	end
	return nil
end

local function countPlaced(userId: number): number
	local habitats = playerHabitats[userId]
	if not habitats then
		return 0
	end
	local count = 0
	for _ in habitats do
		count += 1
	end
	return count
end

local function countTotalOwned(userId: number): number
	local total = countPlaced(userId)
	local inventory = playerInventory[userId]
	if inventory then
		for _, count in inventory do
			total += count
		end
	end
	return total
end

local function getCostForNext(totalOwned: number): number
	for _, threshold in Constants.HABITAT_COST_THRESHOLDS do
		if totalOwned < threshold.maxOwned then
			return threshold.cost
		end
	end
	return Constants.HABITAT_COST_THRESHOLDS[#Constants.HABITAT_COST_THRESHOLDS].cost
end

local function fireUpdate(player: Player)
	local userId = player.UserId
	local habitatsList = {}
	for _, habitat in playerHabitats[userId] or {} do
		table.insert(habitatsList, habitat)
	end

	updateHabitatsRemote:FireClient(player, {
		habitats = habitatsList,
		inventory = playerInventory[userId] or {},
		nextCost = getCostForNext(countTotalOwned(userId)),
	})
end

-- AABB overlap on the XZ plane; footprint is a fixed square so a placement's
-- own rotation never changes its bounding box, keeping this check simple.
local function rectsOverlap(ax: number, az: number, ahw: number, ahd: number, bx: number, bz: number, bhw: number, bhd: number): boolean
	return math.abs(ax - bx) < (ahw + bhw) and math.abs(az - bz) < (ahd + bhd)
end

-- Approximate footprints of the fixed structures PlotSetup.server.lua builds
-- into every plot (Headquarters, the Hall pedestal grid, the Dropbox
-- platform, the Warehouse wall), in plot-local XZ space, with buffer margin.
-- Not pixel-perfect against every decorative part -- just enough to keep
-- placed habitats from visually colliding with the plot's core structures.
local RESERVED_ZONES = {
	{ x = 0, z = 35, halfWidth = 17, halfDepth = 8 }, -- Headquarters
	{ x = 0, z = -10, halfWidth = 22, halfDepth = 18 }, -- Hall pedestal grid
	{ x = 0, z = -30, halfWidth = 10, halfDepth = 10 }, -- Dropbox platform
	{ x = 0, z = 28, halfWidth = 27, halfDepth = 5 }, -- Warehouse wall/doors
}

local BOUNDS_MARGIN = 3

local function validatePlacement(player: Player, x: number, z: number): (boolean, string)
	local plotModel = PlotManager.GetPlayerPlot(player)
	if not plotModel then
		return false, "no_plot"
	end

	local ground = plotModel:FindFirstChild("Ground")
	if not ground or not ground:IsA("BasePart") then
		return false, "no_plot"
	end

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
		return false, "out_of_bounds"
	end

	for _, zone in RESERVED_ZONES do
		if rectsOverlap(x, z, footHalfW, footHalfD, zone.x, zone.z, zone.halfWidth, zone.halfDepth) then
			return false, "reserved_zone"
		end
	end

	for _, habitat in playerHabitats[player.UserId] or {} do
		if
			rectsOverlap(x, z, footHalfW, footHalfD, habitat.placement.x, habitat.placement.z, footHalfW, footHalfD)
		then
			return false, "overlaps_habitat"
		end
	end

	return true, ""
end

function HabitatManager.InitHabitats(player: Player)
	local userId = player.UserId
	playerHabitats[userId] = {}
	playerInventory[userId] = {}

	fireUpdate(player)
end

function HabitatManager.LoadHabitatsFromPlayerData(player: Player)
	local userId = player.UserId
	local data = PlayerManager.GetData(userId)
	if not data then
		return
	end

	local habitats = playerHabitats[userId]
	if not habitats then
		return
	end

	for _, habitat in data.habitats or {} do
		habitats[habitat.habitatId] = habitat
		HabitatVisuals.SpawnHabitat(player, habitat)
		if habitat.monster then
			HabitatVisuals.SpawnMonsterOnHabitat(player, habitat.habitatId, habitat.monster.name, habitat.monster.emotion, habitat.monster.rarity)
		end
	end

	for biomeType, count in data.habitatInventory or {} do
		playerInventory[userId][biomeType] = count
	end

	fireUpdate(player)
end

function HabitatManager.PurchaseHabitat(player: Player, biomeType: string): (boolean, string)
	local userId = player.UserId
	if not playerHabitats[userId] then
		return false, "not_ready"
	end

	if not findBiomeDef(biomeType) then
		return false, "invalid_biome"
	end

	local cost = getCostForNext(countTotalOwned(userId))
	if not PlayerManager.DecrementCoins(userId, cost) then
		return false, "insufficient_coins"
	end

	local inventory = playerInventory[userId]
	inventory[biomeType] = (inventory[biomeType] or 0) + 1

	fireUpdate(player)

	return true, ""
end

function HabitatManager.PlaceHabitat(player: Player, biomeType: string, x: number, z: number, rotationY: number): (boolean, string)
	local userId = player.UserId
	local inventory = playerInventory[userId]
	local habitats = playerHabitats[userId]
	if not inventory or not habitats then
		return false, "not_ready"
	end

	if not findBiomeDef(biomeType) then
		return false, "invalid_biome"
	end

	if (inventory[biomeType] or 0) <= 0 then
		return false, "none_owned"
	end

	if countPlaced(userId) >= Constants.HABITAT_MAX_PER_PLOT then
		return false, "plot_full"
	end

	local valid, reason = validatePlacement(player, x, z)
	if not valid then
		return false, reason
	end

	inventory[biomeType] -= 1

	local habitat: Types.Habitat = {
		habitatId = generateHabitatId(),
		biomeType = biomeType,
		placement = { x = x, z = z, rotationY = rotationY },
		monster = nil,
		isActive = false,
	}

	habitats[habitat.habitatId] = habitat
	HabitatVisuals.SpawnHabitat(player, habitat)

	fireUpdate(player)

	return true, ""
end

function HabitatManager.SlotMonster(player: Player, habitatId: string, instanceId: string): (boolean, string)
	local userId = player.UserId
	local habitats = playerHabitats[userId]
	local habitat = habitats and habitats[habitatId]
	if not habitat then
		return false, "invalid_habitat"
	end

	local biomeDef = findBiomeDef(habitat.biomeType)
	if not biomeDef then
		return false, "invalid_habitat"
	end

	local monster = WarehouseManager.GetMonsterByInstanceId(player, instanceId)
	if not monster then
		return false, "invalid_monster"
	end

	if monster.emotion ~= biomeDef.emotion and monster.emotion ~= "Any" then
		return false, "wrong_biome"
	end

	if habitat.monster then
		return false, "already_occupied"
	end

	habitat.monster = monster
	habitat.isActive = true

	WarehouseManager.RemoveMonster(player, instanceId)

	HabitatVisuals.SpawnMonsterOnHabitat(player, habitatId, monster.name, monster.emotion, monster.rarity)

	fireUpdate(player)

	return true, ""
end

function HabitatManager.UnslotMonster(player: Player, habitatId: string): (boolean, string)
	local userId = player.UserId
	local habitats = playerHabitats[userId]
	local habitat = habitats and habitats[habitatId]
	if not habitat or not habitat.monster then
		return false, "invalid_habitat"
	end

	-- Return the monster to the warehouse rather than discarding it; if the
	-- warehouse has no room, reject the unslot instead of destroying it.
	local added = WarehouseManager.AddMonster(player, habitat.monster.name, habitat.monster.stars)
	if not added then
		return false, "warehouse_full"
	end

	habitat.monster = nil
	habitat.isActive = false

	HabitatVisuals.RemoveMonsterFromHabitat(player, habitatId)

	fireUpdate(player)

	return true, ""
end

function HabitatManager.GetActiveMonsters(player: Player): { ActiveHabitatMonster }
	local habitats = playerHabitats[player.UserId]
	if not habitats then
		return {}
	end

	local active = {}
	for habitatId, habitat in habitats do
		if habitat.isActive and habitat.monster then
			table.insert(active, { habitatId = habitatId, monster = habitat.monster })
		end
	end

	return active
end

function HabitatManager.GetHabitat(player: Player, habitatId: string): Types.Habitat?
	local habitats = playerHabitats[player.UserId]
	return habitats and habitats[habitatId]
end

function HabitatManager.ClearHabitats(player: Player)
	HabitatVisuals.ClearPlayerHabitats(player)
	playerHabitats[player.UserId] = nil
	playerInventory[player.UserId] = nil
end

function HabitatManager.SaveHabitatsToPlayerData(player: Player)
	local userId = player.UserId
	local habitats = playerHabitats[userId]
	if not habitats then
		return
	end

	local habitatsList = {}
	for _, habitat in habitats do
		table.insert(habitatsList, habitat)
	end

	PlayerManager.SetData(userId, "habitats", habitatsList)
	PlayerManager.SetData(userId, "habitatInventory", playerInventory[userId] or {})
end

return HabitatManager
