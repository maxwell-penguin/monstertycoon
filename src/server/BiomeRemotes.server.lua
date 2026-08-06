local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local BiomeData = require(script.Parent.BiomeData)

local PROMPT_COOLDOWN = 3

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local biomeUnlockPromptRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BIOME_UNLOCK_PROMPT) :: RemoteEvent
local biomeUnlockedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BIOME_UNLOCKED) :: RemoteEvent
local unlockBiomeRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UNLOCK_BIOME) :: RemoteEvent

-- Keyed by userId, then by biomeName -- so standing on one trigger doesn't
-- also suppress a prompt for a different biome's trigger.
local lastPromptTime: { [number]: { [string]: number } } = {}

local function biomeNameFromTriggerName(triggerName: string): string?
	local prefix = "BiomeTrigger_"
	if triggerName:sub(1, #prefix) ~= prefix then
		return nil
	end
	return triggerName:sub(#prefix + 1)
end

local function connectBiomeTrigger(trigger: BasePart)
	local biomeName = biomeNameFromTriggerName(trigger.Name)
	if not biomeName then
		return
	end

	local biome = BiomeData.BIOMES[biomeName]
	if not biome then
		return
	end

	trigger.Touched:Connect(function(hitPart: BasePart)
		local character = hitPart:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local userId = player.UserId
		local perPlayer = lastPromptTime[userId]
		if not perPlayer then
			perPlayer = {}
			lastPromptTime[userId] = perPlayer
		end

		local now = os.clock()
		local last = perPlayer[biomeName]
		if last and (now - last) < PROMPT_COOLDOWN then
			return
		end
		perPlayer[biomeName] = now

		biomeUnlockPromptRemote:FireClient(player, {
			biomeName = biomeName,
			cost = biome.unlockCost,
			emotions = biome.emotions,
		})
	end)
end

for _, descendant in Workspace:GetDescendants() do
	if descendant:IsA("BasePart") and descendant.Name:sub(1, 13) == "BiomeTrigger_" then
		connectBiomeTrigger(descendant)
	end
end

-- Defensive: biome triggers may not exist in Workspace yet at server start
-- depending on world-build script order, so pick up any created later too.
Workspace.DescendantAdded:Connect(function(descendant: Instance)
	if descendant:IsA("BasePart") and descendant.Name:sub(1, 13) == "BiomeTrigger_" then
		connectBiomeTrigger(descendant)
	end
end)

unlockBiomeRemote.OnServerEvent:Connect(function(player: Player, biomeName: any)
	if typeof(biomeName) ~= "string" then
		return
	end

	local biome = BiomeData.BIOMES[biomeName]
	if not biome then
		return
	end

	local userId = player.UserId
	local data = PlayerManager.GetData(userId)
	if not data then
		return
	end

	local unlocked = data.unlockedBiomes or {}
	if table.find(unlocked, biomeName) then
		return
	end

	if data.coins < biome.unlockCost then
		return
	end

	if not PlayerManager.DecrementCoins(userId, biome.unlockCost) then
		return
	end

	local newUnlocked = table.clone(unlocked)
	table.insert(newUnlocked, biomeName)
	PlayerManager.SetData(userId, "unlockedBiomes", newUnlocked)

	local gate = Workspace:FindFirstChild("BiomeGate_" .. biomeName)
	if gate then
		gate:Destroy()
	end

	biomeUnlockedRemote:FireClient(player, biomeName)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastPromptTime[player.UserId] = nil
end)
