local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Types)

type PlayerData = Types.PlayerData

local PlayerManager = {}

local playerData: { [number]: PlayerData } = {}
local dirtyFlags: { [number]: boolean } = {}

local function deepCopy(original: { [any]: any }): { [any]: any }
	local copy = {}
	for key, value in original do
		if typeof(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

function PlayerManager.Load(userId: number, data: PlayerData)
	playerData[userId] = data
	dirtyFlags[userId] = false
end

function PlayerManager.Unload(userId: number): PlayerData?
	local data = playerData[userId]
	playerData[userId] = nil
	dirtyFlags[userId] = nil
	return data
end

function PlayerManager.GetData(userId: number): PlayerData?
	local data = playerData[userId]
	if not data then
		return nil
	end
	return deepCopy(data) :: PlayerData
end

function PlayerManager.SetData(userId: number, key: string, value: any): boolean
	local data = playerData[userId]
	if not data then
		return false
	end
	(data :: any)[key] = value
	dirtyFlags[userId] = true
	return true
end

function PlayerManager.IncrementCoins(userId: number, amount: number): boolean
	if typeof(amount) ~= "number" or amount <= 0 then
		return false
	end
	local data = playerData[userId]
	if not data then
		return false
	end
	data.coins += amount
	dirtyFlags[userId] = true
	return true
end

function PlayerManager.DecrementCoins(userId: number, amount: number): boolean
	if typeof(amount) ~= "number" or amount <= 0 then
		return false
	end
	local data = playerData[userId]
	if not data then
		return false
	end
	if data.coins < amount then
		return false
	end
	data.coins -= amount
	dirtyFlags[userId] = true
	return true
end

-- TEMP: remove before launch
function PlayerManager.GiveTestCoins(player: Player)
	local userId = player.UserId
	local data = playerData[userId]
	if not data then
		return
	end
	data.coins = 999999999999
	dirtyFlags[userId] = true
end

function PlayerManager.IsDirty(userId: number): boolean
	return dirtyFlags[userId] == true
end

function PlayerManager.ClearDirty(userId: number)
	dirtyFlags[userId] = false
end

function PlayerManager.GetLoadedUserIds(): { number }
	local ids = {}
	for userId in playerData do
		table.insert(ids, userId)
	end
	return ids
end

return PlayerManager
