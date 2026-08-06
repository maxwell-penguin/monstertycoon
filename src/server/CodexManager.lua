local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local MonsterData = require(script.Parent.MonsterData)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local codexDiscoveryRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.CODEX_DISCOVERY) :: RemoteEvent

local TOTAL_MONSTER_COUNT = 0
for _, monsterDef in MonsterData do
	if not monsterDef.isEventExclusive then
		TOTAL_MONSTER_COUNT += 1
	end
end

local CodexManager = {}

-- Keyed by userId, each value the player's discoveredMonsters list (same
-- shape as PlayerData.discoveredMonsters -- a list of MonsterData keys).
local playerCodex: { [number]: { string } } = {}

function CodexManager.InitCodex(player: Player)
	local data = PlayerManager.GetData(player.UserId)
	playerCodex[player.UserId] = (data and data.discoveredMonsters) or {}
end

function CodexManager.RecordDiscovery(player: Player, monsterName: string): boolean
	local userId = player.UserId
	local discovered = playerCodex[userId]
	if not discovered then
		return false
	end

	if table.find(discovered, monsterName) then
		return false
	end

	local monsterDef = MonsterData[monsterName]
	if not monsterDef then
		return false
	end

	table.insert(discovered, monsterName)
	PlayerManager.SetData(userId, "discoveredMonsters", discovered)

	codexDiscoveryRemote:FireClient(player, monsterName, monsterDef)

	return true
end

function CodexManager.GetDiscoveredCount(player: Player): (number, number)
	local discovered = playerCodex[player.UserId]
	return discovered and #discovered or 0, TOTAL_MONSTER_COUNT
end

function CodexManager.ClearCodex(player: Player)
	playerCodex[player.UserId] = nil
end

return CodexManager
