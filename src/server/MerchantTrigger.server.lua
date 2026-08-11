local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local openMerchantRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.OPEN_MERCHANT) :: RemoteEvent

local TOUCH_COOLDOWN = 2
local lastTouchOpen: { [number]: number } = {}

local merchant = Workspace:WaitForChild("Merchant")
local trigger = merchant:WaitForChild("MerchantTrigger") :: BasePart

-- Shared hub NPC, not owned by any one plot, so unlike Dropbox/Warehouse
-- triggers there's no plot-ownership check -- any player touching it may open it.
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
	local now = os.clock()
	local last = lastTouchOpen[userId]
	if last and (now - last) < TOUCH_COOLDOWN then
		return
	end
	lastTouchOpen[userId] = now

	openMerchantRemote:FireClient(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastTouchOpen[player.UserId] = nil
end)
