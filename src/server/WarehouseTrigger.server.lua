-- Disabled: warehouse trigger now handled by proximity to SellPoint area
do
	return
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlotManager = require(script.Parent.PlotManager)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local openWarehouseRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.OPEN_WAREHOUSE) :: RemoteEvent

local TOUCH_COOLDOWN = 2
local lastTouchOpen: { [number]: number } = {}

local function getOwningPlayerFromTouch(hitPart: BasePart, plotModel: Model): Player?
	local character = hitPart:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return nil
	end

	if PlotManager.GetPlayerPlot(player) ~= plotModel then
		return nil
	end

	return player
end

local function connectWarehouseTrigger(plotModel: Model)
	local trigger = plotModel:FindFirstChild("WarehouseTrigger")
	if not trigger or not trigger:IsA("BasePart") then
		return
	end

	trigger.Touched:Connect(function(hitPart: BasePart)
		local player = getOwningPlayerFromTouch(hitPart, plotModel)
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

		openWarehouseRemote:FireClient(player)
	end)
end

local plotsFolder = Workspace:WaitForChild("Plots")
for _, plotModel in plotsFolder:GetChildren() do
	if plotModel:IsA("Model") then
		connectWarehouseTrigger(plotModel)
	end
end
plotsFolder.ChildAdded:Connect(function(child: Instance)
	if child:IsA("Model") then
		connectWarehouseTrigger(child)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastTouchOpen[player.UserId] = nil
end)
