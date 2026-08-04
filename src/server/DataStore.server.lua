local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local Types = require(ReplicatedStorage.Types)
local PlayerManager = require(script.Parent.PlayerManager)
local EarnRateUpdater = require(script.Parent.EarnRateUpdater)
local PlotManager = require(script.Parent.PlotManager)
local HallManager = require(script.Parent.HallManager)

type PlayerData = Types.PlayerData

local playerDataStore = DataStoreService:GetDataStore("PlayerData")

local SAVE_INTERVAL = 60

local function defaultData(): PlayerData
	return {
		coins = 0,
		lifetimeRolls = 0,
		hallTier = 1,
		warehouseTier = 1,
		bagTier = 1,
		totalPlaytime = 0,
		lastOnlineTime = 0,
		monsterSlots = {},
		warehouse = {
			tier = 0,
			capacity = 0,
			currentCount = 0,
		},
		sessionStartTime = 0,
	}
end

local function getKey(userId: number): string
	return "PlayerData_" .. userId
end

local function loadData(userId: number): PlayerData
	local key = getKey(userId)

	local success, result = pcall(function()
		return playerDataStore:GetAsync(key)
	end)

	if success and result then
		return result :: PlayerData
	end

	if not success then
		warn(`[DataStore] Failed to load data for user {userId}: {result}`)
	end

	return defaultData()
end

local function saveData(userId: number, data: PlayerData): boolean
	local key = getKey(userId)

	local success, err = pcall(function()
		playerDataStore:SetAsync(key, data)
	end)

	if not success then
		warn(`[DataStore] Failed to save data for user {userId}: {err}`)
	end

	return success
end

local function onPlayerAdded(player: Player)
	local data = loadData(player.UserId)
	data.sessionStartTime = os.time()

	PlayerManager.Load(player.UserId, data)
	PlotManager.AssignPlot(player)
	HallManager.InitHall(player)

	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLAYER_DATA_LOADED) :: RemoteEvent
	remote:FireClient(player, data)

	EarnRateUpdater.StartUpdating(player)

	print(`[DataStore] Loaded data for {player.Name}`)
end

local function onPlayerRemoving(player: Player)
	PlotManager.ReleasePlot(player)
	HallManager.ClearHall(player)

	local data = PlayerManager.Unload(player.UserId)
	if not data then
		return
	end

	if saveData(player.UserId, data) then
		print(`[DataStore] Saved data for {player.Name}`)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

task.spawn(function()
	while true do
		task.wait(SAVE_INTERVAL)

		for _, userId in PlayerManager.GetLoadedUserIds() do
			if PlayerManager.IsDirty(userId) then
				local data = PlayerManager.GetData(userId)
				if data and saveData(userId, data) then
					PlayerManager.ClearDirty(userId)
					local player = Players:GetPlayerByUserId(userId)
					if player then
						print(`[DataStore] Saved data for {player.Name}`)
					end
				end
			end
		end
	end
end)
