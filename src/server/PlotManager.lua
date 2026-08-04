local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Constants = require(ReplicatedStorage.Constants)
local Types = require(ReplicatedStorage.Types)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)

local PLOT_COUNT = 10

local PlotManager = {}

local playerPlots: { [number]: Model } = {}

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local plotUpdatedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLOT_UPDATED) :: RemoteEvent

-- Plots grow via parts tagged "PlotExpansion_N" (CollectionService); PlotSetup creates none by
-- default, so these scans are no-ops until such parts are tagged onto a plot in Studio.
local function setPlotExpansionTier(plotModel: Model, tier: number)
	local size = Constants.PLOT_SIZES[tier]
	if not size then
		return
	end

	local tag = "PlotExpansion_" .. tier
	for _, part in CollectionService:GetTagged(tag) do
		if part:IsA("BasePart") and part:IsDescendantOf(plotModel) then
			part.Size = Vector3.new(size.width, part.Size.Y, size.depth)
			part.Transparency = 0
			part.CanCollide = true
		end
	end
end

local function hidePlotExpansions(plotModel: Model)
	for tier = 2, #Constants.PLOT_SIZES do
		local tag = "PlotExpansion_" .. tier
		for _, part in CollectionService:GetTagged(tag) do
			if part:IsA("BasePart") and part:IsDescendantOf(plotModel) then
				part.Transparency = 1
				part.CanCollide = false
			end
		end
	end
end

function PlotManager.AssignPlot(player: Player): Types.Plot?
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		warn("[PlotManager] Plots folder not found in Workspace")
		return nil
	end

	for i = 1, PLOT_COUNT do
		local plotModel = plotsFolder:FindFirstChild("Plot_" .. i)
		if plotModel then
			local isOccupied = plotModel:FindFirstChild("IsOccupied") :: BoolValue
			if isOccupied and not isOccupied.Value then
				isOccupied.Value = true

				local ownerId = plotModel:FindFirstChild("OwnerId") :: StringValue
				ownerId.Value = tostring(player.UserId)

				playerPlots[player.UserId] = plotModel

				local data = PlayerManager.GetData(player.UserId)
				local hallTier = (data and data.hallTier) or 1
				local warehouseTier = (data and data.warehouseTier) or 1

				setPlotExpansionTier(plotModel, hallTier)

				return {
					playerId = player.UserId,
					hallTier = hallTier,
					warehouseTier = warehouseTier,
					plotLevel = hallTier,
				}
			end
		end
	end

	warn(`[PlotManager] No available plots for {player.Name}`)
	return nil
end

function PlotManager.ReleasePlot(player: Player)
	local plotModel = playerPlots[player.UserId]
	if not plotModel then
		return
	end

	local ownerId = plotModel:FindFirstChild("OwnerId") :: StringValue
	if ownerId then
		ownerId.Value = ""
	end

	local isOccupied = plotModel:FindFirstChild("IsOccupied") :: BoolValue
	if isOccupied then
		isOccupied.Value = false
	end

	hidePlotExpansions(plotModel)

	playerPlots[player.UserId] = nil
end

function PlotManager.GetPlayerPlot(player: Player): Model?
	return playerPlots[player.UserId]
end

function PlotManager.GetPlotOrigin(player: Player): CFrame?
	local plotModel = playerPlots[player.UserId]
	if not plotModel then
		return nil
	end

	local origin = plotModel:FindFirstChild("Origin")
	if not origin or not origin:IsA("BasePart") then
		return nil
	end

	return origin.CFrame
end

function PlotManager.UpgradePlot(player: Player): boolean
	local userId = player.UserId
	local plotModel = playerPlots[userId]
	if not plotModel then
		return false
	end

	local data = PlayerManager.GetData(userId)
	if not data then
		return false
	end

	local currentTier = data.hallTier
	local maxTier = #Constants.HALL_UPGRADE_COSTS
	if currentTier >= maxTier then
		return false
	end

	local newTier = currentTier + 1

	setPlotExpansionTier(plotModel, newTier)

	PlayerManager.SetData(userId, "hallTier", newTier)

	local updatedData = PlayerManager.GetData(userId)

	local plot: Types.Plot = {
		playerId = userId,
		hallTier = newTier,
		warehouseTier = (updatedData and updatedData.warehouseTier) or data.warehouseTier,
		plotLevel = newTier,
	}

	plotUpdatedRemote:FireClient(player, plot)

	return true
end

return PlotManager
