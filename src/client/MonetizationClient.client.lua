local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local setWalkSpeedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SET_WALK_SPEED) :: RemoteEvent
local luckBoostActiveRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.LUCK_BOOST_ACTIVE) :: RemoteEvent
local promptPurchaseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PROMPT_PURCHASE) :: RemoteEvent
local playerDataLoadedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLAYER_DATA_LOADED) :: RemoteEvent

local DEFAULT_WALK_SPEED = 16
local currentWalkSpeed = DEFAULT_WALK_SPEED

local function applyWalkSpeed(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = currentWalkSpeed
	end
end

setWalkSpeedRemote.OnClientEvent:Connect(function(speed: any)
	if typeof(speed) ~= "number" then
		return
	end

	currentWalkSpeed = speed

	if player.Character then
		applyWalkSpeed(player.Character)
	end
end)

player.CharacterAdded:Connect(applyWalkSpeed)

if player.Character then
	applyWalkSpeed(player.Character)
end

shared.MonetizationClient = {
	hasLuckBoost = false,
	luckBoostExpiry = 0,
	ownedGamepasses = {},
}

-- Client never calls MarketplaceService directly; this just forwards intent to the
-- server, which validates the id and prompts on the player's behalf.
function shared.MonetizationClient.PromptPurchase(purchaseType: string, id: number)
	promptPurchaseRemote:FireServer({ purchaseType = purchaseType, productId = id })
end

luckBoostActiveRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	shared.MonetizationClient.hasLuckBoost = payload.hasLuckBoost or false
	shared.MonetizationClient.luckBoostExpiry = payload.luckBoostExpiry or 0
end)

-- MonetizationManager re-fires this same full-snapshot channel after CheckGamepasses
-- resolves and after any live gamepass purchase, so this is the one place that keeps
-- ownedGamepasses current for the Shop Panel's "OWNED" labels.
playerDataLoadedRemote.OnClientEvent:Connect(function(data: any)
	if typeof(data) == "table" and typeof(data.ownedGamepasses) == "table" then
		shared.MonetizationClient.ownedGamepasses = data.ownedGamepasses
	end
end)
