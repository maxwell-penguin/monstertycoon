local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local RollTable = require(ReplicatedStorage.RollTable)
local PlayerManager = require(script.Parent.PlayerManager)
local PlotManager = require(script.Parent.PlotManager)
local WarehouseManager = require(script.Parent.WarehouseManager)
local TownManager = require(script.Parent.TownManager)

export type CrateData = {
	crateId: string,
	playerId: number,
	position: Vector3,
	spawnTime: number,
	claimed: boolean,
}

local CRATE_CLAIM_RADIUS = 15
local CRATE_EDGE_MARGIN = 5
local GROUND_Y = 0
local SPAWN_HEIGHT = 60

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local crateSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.CRATE_SPAWNED) :: RemoteEvent
local eggResultRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.EGG_RESULT) :: RemoteEvent

local CrateManager = {}

local activeLoops: { [number]: boolean } = {}
local playerCrates: { [number]: { [string]: CrateData } } = {}

local function boostRarityTier(rarity: string): string
	local order = RollTable.RARITY_ORDER
	local index = table.find(order, rarity)
	if not index then
		return rarity
	end
	return order[math.min(index + 1, #order)]
end

function CrateManager.SpawnCrate(player: Player): string
	local userId = player.UserId
	local origin = PlotManager.GetPlotOrigin(player)
	if not origin then
		return ""
	end

	local data = PlayerManager.GetData(userId)
	local hallTier = (data and data.hallTier) or 1
	local plotSize = Constants.PLOT_SIZES[hallTier] or Constants.PLOT_SIZES[1]

	local originPosition = origin.Position
	local offsetX = (math.random() * 2 - 1) * (plotSize.width / 2 - CRATE_EDGE_MARGIN)
	local offsetZ = (math.random() * 2 - 1) * (plotSize.depth / 2 - CRATE_EDGE_MARGIN)

	local landingX = originPosition.X + offsetX
	local landingZ = originPosition.Z + offsetZ
	local position = Vector3.new(landingX, GROUND_Y + SPAWN_HEIGHT, landingZ)
	local landingPosition = Vector3.new(landingX, GROUND_Y, landingZ)

	local crateId = HttpService:GenerateGUID(false)

	local crates = playerCrates[userId]
	if not crates then
		crates = {}
		playerCrates[userId] = crates
	end

	crates[crateId] = {
		crateId = crateId,
		playerId = userId,
		position = position,
		spawnTime = os.time(),
		claimed = false,
	}

	crateSpawnedRemote:FireClient(player, crateId, position, landingPosition)

	return crateId
end

function CrateManager.StartCrateLoop(player: Player)
	local userId = player.UserId
	if activeLoops[userId] then
		return
	end

	activeLoops[userId] = true
	playerCrates[userId] = playerCrates[userId] or {}

	task.spawn(function()
		while activeLoops[userId] do
			local data = PlayerManager.GetData(userId)
			local hallTier = (data and data.hallTier) or 1
			local cooldown = Constants.CRATE_COOLDOWNS[hallTier] or Constants.CRATE_COOLDOWNS[1]

			task.wait(cooldown)

			if not activeLoops[userId] then
				break
			end

			CrateManager.SpawnCrate(player)
		end
	end)
end

function CrateManager.StopCrateLoop(player: Player)
	activeLoops[player.UserId] = nil
end

function CrateManager.ClaimCrate(player: Player, crateId: string): (boolean, string, string)
	local userId = player.UserId
	local crates = playerCrates[userId]
	local crate = crates and crates[crateId]

	if not crate or crate.claimed then
		return false, "not_found", ""
	end

	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if not rootPart then
		return false, "out_of_range", ""
	end

	local landingPosition = Vector3.new(crate.position.X, GROUND_Y, crate.position.Z)
	local distance = (rootPart.Position - landingPosition).Magnitude
	if distance > CRATE_CLAIM_RADIUS then
		return false, "out_of_range", ""
	end

	crate.claimed = true

	-- TownManager is the live authority on town level during a session; PlayerManager's
	-- copy is only synced at save time, so it lags behind mid-session XP-driven level-ups.
	local townLevel = TownManager.GetTownLevel(player)

	local rarity = RollTable.RollRarity(townLevel)
	local boostedRarity = boostRarityTier(rarity)
	local monsterName = RollTable.RollMonsterOfRarity(boostedRarity)

	local added, newInstanceId = WarehouseManager.AddMonster(player, monsterName)
	if not added then
		eggResultRemote:FireClient(player, { success = false, reason = "full", isCrate = true, crateId = crateId })
		return false, "full", ""
	end

	TownManager.AddXP(player, TownManager.GetEggOpenXP(boostedRarity))

	eggResultRemote:FireClient(player, {
		success = true,
		monsterName = monsterName,
		rarity = boostedRarity,
		newInstanceId = newInstanceId,
		isCrate = true,
		crateId = crateId,
	})

	return true, monsterName, boostedRarity
end

function CrateManager.CleanupCrates(player: Player)
	playerCrates[player.UserId] = nil
	CrateManager.StopCrateLoop(player)
end

return CrateManager
