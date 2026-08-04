local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Types)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local Constants = require(ReplicatedStorage.Constants)
local MergeRules = require(ReplicatedStorage.MergeRules)
local WarehouseManager = require(script.Parent.WarehouseManager)
local TownManager = require(script.Parent.TownManager)
local PlayerManager = require(script.Parent.PlayerManager)

local MAX_AUTO_MERGES = 50

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local mergeMonstersRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.MERGE_MONSTERS) :: RemoteEvent

local MergeManager = {}

function MergeManager.ValidateMerge(player: Player, instanceIds: any): (boolean, string)
	if typeof(instanceIds) ~= "table" or #instanceIds ~= 3 then
		return false, "invalid_count"
	end

	if instanceIds[1] == instanceIds[2] or instanceIds[1] == instanceIds[3] or instanceIds[2] == instanceIds[3] then
		return false, "invalid_count"
	end

	local monsters: { Types.Monster } = {}
	for i = 1, 3 do
		local monster = WarehouseManager.GetMonsterByInstanceId(player, instanceIds[i])
		if not monster then
			return false, "not_found"
		end
		monsters[i] = monster
	end

	local first = monsters[1]
	for i = 2, 3 do
		local monster = monsters[i]
		if
			monster.name ~= first.name
			or monster.rarity ~= first.rarity
			or monster.level ~= first.level
			or monster.stars ~= first.stars
		then
			return false, "mismatch"
		end
	end

	if not MergeRules.CanMerge(first.name, first.stars) then
		return false, "cannot_merge"
	end

	return true, ""
end

function MergeManager.ExecuteMerge(player: Player, instanceIds: any): (boolean, string, Types.Monster?)
	local valid, reason = MergeManager.ValidateMerge(player, instanceIds)
	if not valid then
		mergeMonstersRemote:FireClient(player, { success = false, reason = reason })
		return false, reason, nil
	end

	local sourceMonster = WarehouseManager.GetMonsterByInstanceId(player, instanceIds[1]) :: Types.Monster
	local resultName, resultStars = MergeRules.GetMergeResult(sourceMonster.name, sourceMonster.stars)

	if not resultName or not resultStars then
		mergeMonstersRemote:FireClient(player, { success = false, reason = "cannot_merge" })
		return false, "cannot_merge", nil
	end

	for i = 1, 3 do
		WarehouseManager.RemoveMonster(player, instanceIds[i])
	end

	local added, newInstanceId = WarehouseManager.AddMonster(player, resultName, resultStars)
	if not added then
		mergeMonstersRemote:FireClient(player, { success = false, reason = newInstanceId })
		return false, newInstanceId, nil
	end

	local newMonster = WarehouseManager.GetMonsterByInstanceId(player, newInstanceId)

	local rule = MergeRules[sourceMonster.name]
	if rule and rule.isMaxLevel then
		TownManager.AddXP(player, Constants.XP_REWARDS.mergeStar)
	else
		TownManager.AddXP(player, Constants.XP_REWARDS.mergeEvolve)
	end

	-- Merges have no coin cost yet, so this is a no-op in practice -- just wiring
	-- the check and decrement so Phase 19 can add merge costs without touching
	-- this file. Free merges from MergeBoost skip whatever cost eventually lands.
	local data = PlayerManager.GetData(player.UserId)
	if data and data.freeMerges and data.freeMerges > 0 then
		PlayerManager.SetData(player.UserId, "freeMerges", data.freeMerges - 1)
	end

	mergeMonstersRemote:FireClient(player, {
		success = true,
		resultMonsterName = resultName,
		resultStars = resultStars,
		newInstanceId = newInstanceId,
		consumedInstanceIds = instanceIds,
	})

	return true, newInstanceId, newMonster
end

function MergeManager.AutoMerge(player: Player): number
	local mergeCount = 0

	while mergeCount < MAX_AUTO_MERGES do
		local groups = WarehouseManager.GetMergeableGroups(player)
		if #groups == 0 then
			break
		end

		local mergedThisPass = false

		for _, group in groups do
			local ids = { group.instanceIds[1], group.instanceIds[2], group.instanceIds[3] }
			local success = MergeManager.ExecuteMerge(player, ids)
			if success then
				mergeCount += 1
				mergedThisPass = true
				break
			end
		end

		if not mergedThisPass then
			break
		end
	end

	return mergeCount
end

return MergeManager
