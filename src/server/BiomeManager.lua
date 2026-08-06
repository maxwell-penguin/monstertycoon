local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local BiomeData = require(script.Parent.BiomeData)

local BIOMES = BiomeData.BIOMES

local BiomeManager = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local biomeUnlockedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BIOME_UNLOCKED) :: RemoteEvent

function BiomeManager.GetUnlockedBiomes(player: Player): { string }
	local data = PlayerManager.GetData(player.UserId)
	if not data or not data.unlockedBiomes or #data.unlockedBiomes == 0 then
		return { "Forest" }
	end
	return data.unlockedBiomes
end

function BiomeManager.UnlockBiome(player: Player, biomeName: string): (boolean, string)
	local biome = BIOMES[biomeName]
	if not biome then
		return false, "Unknown biome"
	end

	local unlocked = BiomeManager.GetUnlockedBiomes(player)
	if table.find(unlocked, biomeName) then
		return false, "Already unlocked"
	end

	local userId = player.UserId
	local data = PlayerManager.GetData(userId)
	if not data or data.coins < biome.unlockCost then
		return false, "Not enough coins"
	end

	if not PlayerManager.DecrementCoins(userId, biome.unlockCost) then
		return false, "Not enough coins"
	end

	local newUnlocked = table.clone(unlocked)
	table.insert(newUnlocked, biomeName)
	PlayerManager.SetData(userId, "unlockedBiomes", newUnlocked)

	local gate = Workspace:FindFirstChild("BiomeGate_" .. biomeName)
	if gate then
		gate:Destroy()
	end

	biomeUnlockedRemote:FireClient(player, biomeName)

	return true, "Unlocked"
end

function BiomeManager.IsInBiome(position: Vector3, biomeName: string): boolean
	local biome = BIOMES[biomeName]
	if not biome then
		return false
	end
	return (position - biome.center).Magnitude <= biome.radius
end

function BiomeManager.GetBiomeForEmotion(emotion: string): string?
	for biomeName, biome in BIOMES do
		if table.find(biome.emotions, emotion) then
			return biomeName
		end
	end
	return nil
end

return BiomeManager
