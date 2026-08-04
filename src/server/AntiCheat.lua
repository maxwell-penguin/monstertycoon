local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local Economy = require(script.Parent.Economy)
local HallManager = require(script.Parent.HallManager)
local WarehouseManager = require(script.Parent.WarehouseManager)
local AntiCheatLog = require(script.Parent.AntiCheatLog)

local CONFIG = {
	-- Earn rate
	MAX_COINS_PER_SELL = 1e15, -- 1 quadrillion per deposit, absolute ceiling
	MAX_VIALS_PER_DEPOSIT = 100, -- bag capacity ceiling
	MAX_EARN_RATE_MULTIPLIER = 10000, -- max legitimate earn rate vs baseline

	-- Pickup rate
	MAX_VIAL_PICKUPS_PER_SECOND = 10,
	MAX_CRATE_CLAIMS_PER_MINUTE = 5,
	MAX_SHARD_COLLECTS_PER_SECOND = 5,

	-- Remote spam
	MAX_REMOTE_CALLS_PER_SECOND = 30, -- across all remotes combined
	MAX_ROLL_CALLS_PER_SECOND = 1,
	MAX_MERGE_CALLS_PER_SECOND = 3,

	-- Teleport detection
	MAX_STUD_TRAVEL_PER_SECOND = 60, -- WalkSpeed 16 + 30% boost + buffer

	-- Strike system
	STRIKES_BEFORE_KICK = 3,
	STRIKES_BEFORE_BAN = 5, -- ban = DataStore flag, not Roblox ban
	STRIKE_DECAY_SECONDS = 300, -- strikes decay after 5 min of clean play
}

local MAX_WAREHOUSE = Constants.WAREHOUSE_CAPACITY[5] + 230
local MAX_HALL = Constants.HALL_SLOT_COUNTS[5] + 60
local COIN_CEILING = 1e18

local banStore = DataStoreService:GetDataStore("Bans")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local sanityFailRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SANITY_FAIL) :: RemoteEvent

local AntiCheat = {}

local strikes: { [number]: number } = {}
local lastPositions: { [number]: { position: Vector3, time: number } } = {}

--============================================================
-- Individual checks
--============================================================

function AntiCheat.CheckEarnRate(player: Player): (boolean, string)
	local slots = HallManager.GetSlots(player)
	local earnRate = Economy.GetEarnRate(slots, player.UserId)

	local baseline = Constants.HALL_BASE_SLOTS * Constants.BASE_VIAL_VALUES.Common / 30
	local maxAllowed = CONFIG.MAX_EARN_RATE_MULTIPLIER * baseline

	if earnRate > maxAllowed then
		return false, `earn_rate_exceeded: {earnRate} vs {maxAllowed}`
	end

	return true, ""
end

function AntiCheat.CheckTeleport(player: Player): (boolean, string)
	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if not rootPart then
		return true, ""
	end

	local userId = player.UserId
	local now = os.clock()
	local currentPosition = rootPart.Position
	local last = lastPositions[userId]

	lastPositions[userId] = { position = currentPosition, time = now }

	if not last then
		return true, ""
	end

	local dt = now - last.time
	if dt <= 0 then
		return true, ""
	end

	local distance = (currentPosition - last.position).Magnitude
	local rate = distance / dt

	if rate > CONFIG.MAX_STUD_TRAVEL_PER_SECOND then
		return false, `teleport_detected: {math.floor(distance)} studs in {string.format("%.2f", dt)}s`
	end

	return true, ""
end

function AntiCheat.CheckInventorySize(player: Player): (boolean, string)
	local warehouseCount = select(1, WarehouseManager.GetCapacityInfo(player))
	local hallCount = #HallManager.GetSlots(player)

	if warehouseCount > MAX_WAREHOUSE or hallCount > MAX_HALL then
		return false, `inventory_overflow: warehouse={warehouseCount} hall={hallCount}`
	end

	return true, ""
end

function AntiCheat.CheckCoinIntegrity(player: Player): (boolean, string)
	local data = PlayerManager.GetData(player.UserId)
	if not data then
		return true, ""
	end

	if data.coins < 0 then
		return false, "negative_coins"
	end

	if data.coins > COIN_CEILING then
		return false, `coins_exceeded_ceiling: {data.coins}`
	end

	return true, ""
end

local CHECKS = {
	AntiCheat.CheckEarnRate,
	AntiCheat.CheckTeleport,
	AntiCheat.CheckInventorySize,
	AntiCheat.CheckCoinIntegrity,
}

--============================================================
-- Strikes / violations
--============================================================

function AntiCheat.RecordViolation(player: Player, description: string)
	local userId = player.UserId
	strikes[userId] = (strikes[userId] or 0) + 1
	local strikeCount = strikes[userId]

	warn(`[AntiCheat] UserId={userId} violation={description} strikes={strikeCount}`)

	sanityFailRemote:FireClient(player, { violation = description, strikes = strikeCount })

	AntiCheatLog.LogViolation(userId, player.Name, description, strikeCount)

	if strikeCount >= CONFIG.STRIKES_BEFORE_BAN then
		pcall(function()
			banStore:SetAsync("isBanned_" .. userId, true)
		end)
		-- Soft ban: a DataStore flag CheckBan reads on next join, not a Roblox
		-- moderation action -- never claim a TOS violation here, we don't control that.
		player:Kick("You have been removed from Void Factory.")
	elseif strikeCount >= CONFIG.STRIKES_BEFORE_KICK then
		player:Kick("Void Factory: Unusual activity detected. Rejoin to continue.")
	end
end

function AntiCheat.RunChecks(player: Player)
	for _, check in CHECKS do
		local passing, description = check(player)
		if not passing then
			AntiCheat.RecordViolation(player, description)
		end
	end
end

function AntiCheat.DecayStrikes()
	for userId, count in strikes do
		strikes[userId] = math.max(count - 1, 0)
	end
end

function AntiCheat.GetPlayerRiskLevel(player: Player): string
	local count = strikes[player.UserId] or 0

	if count == 0 then
		return "clean"
	elseif count <= 2 then
		return "suspicious"
	end

	return "flagged"
end

--============================================================
-- Ban check (called from DataStore.server.lua before any setup)
--============================================================

function AntiCheat.CheckBan(player: Player): boolean
	local userId = player.UserId
	local success, isBanned = pcall(function()
		return banStore:GetAsync("isBanned_" .. userId)
	end)

	if success and isBanned then
		player:Kick("You have been removed from Void Factory.")
		return true
	end

	return false
end

--============================================================
-- Lifecycle
--============================================================

function AntiCheat.InitAntiCheat()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				AntiCheat.RunChecks(player)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(CONFIG.STRIKE_DECAY_SECONDS)
			AntiCheat.DecayStrikes()
		end
	end)
end

-- Teleport tracking resets on respawn so a normal death/respawn (new character
-- spawning far from where the old one died) never reads as a teleport; strikes
-- intentionally persist across a single respawn/session (see STRIKES_BEFORE_BAN
-- reachability -- a player who gets kicked at 3 needs to be recognizable as a
-- repeat offender if they're still flagged after rejoining).
Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function()
		lastPositions[player.UserId] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastPositions[player.UserId] = nil
end)

return AntiCheat
