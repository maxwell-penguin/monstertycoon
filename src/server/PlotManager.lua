local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)
local Types = require(ReplicatedStorage.Types)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)

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

-- The ClaimGate (built by PlotSetup.server.lua) is the gateway a player walks
-- through to claim a plot. The gateway structure itself always stays -- it is
-- the plot's entrance either way -- so claiming only switches off the "WALK IN
-- TO CLAIM" sign, dims its lamp, and stops the trigger listening.
--
-- CanTouch = false is what actually closes the claim: .Touched simply stops
-- firing, so PlotClaimTrigger.server.lua's handler never runs on an owned plot
-- and there is no need to disconnect or rebuild anything.
local function setClaimGateActive(plotModel: Model, visible: boolean)
	local gate = plotModel:FindFirstChild("ClaimGate")
	if not gate then
		return
	end

	local trigger = gate:FindFirstChild("ClaimTrigger")
	if trigger and trigger:IsA("BasePart") then
		trigger.CanTouch = visible
	end

	local sign = gate:FindFirstChild("GateSign")
	local billboard = sign and sign:FindFirstChild("ClaimLabel")
	if billboard and billboard:IsA("BillboardGui") then
		billboard.Enabled = visible
	end

	local lamp = gate:FindFirstChild("GateLamp")
	if lamp and lamp:IsA("BasePart") then
		-- Unclaimed gates glow gold to draw players in; a claimed one fades to
		-- plain timber so only the free plots advertise themselves.
		lamp.Color = visible and Color3.fromRGB(255, 214, 92) or Color3.fromRGB(120, 104, 72)
		lamp.Material = visible and Enum.Material.Neon or Enum.Material.Wood

		local light = lamp:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = visible
		end
	end
end

-- An unclaimed plot sits dim with its SELL/WAREHOUSE billboards switched off,
-- so the grid reads as a row of dormant, unlabeled lots rather than 10 fully
-- lit copies of the same base shouting the same labels at once. Claiming
-- "powers up" that plot: its floor glow and border light come up and its own
-- station labels switch on.
local POWER_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Colour, not Transparency. Every one of these parts is opaque now (see the
-- notes in PlotSetup.server.lua) because semi-transparent parts don't write
-- depth and visibly re-sort as the camera moves; fading them back in would
-- reintroduce exactly the shimmer that removing them fixed. GROUND_GLOW.off
-- must match GROUND_GLOW_UNPOWERED_COLOR in PlotSetup.server.lua.
-- Natural farm palette. These were the old void purples, which would have
-- turned a claimed plot's timber fence violet the moment it was claimed. The
-- "off" values must match what PlotSetup.server.lua builds the parts as
-- (GROUND_GLOW_UNPOWERED_COLOR, TIMBER_DARK and TIMBER_LIGHT respectively), or
-- a plot would visibly jump colour on release.
local GROUND_GLOW_COLOR = {
	on = Color3.fromRGB(126, 170, 90),
	off = Color3.fromRGB(96, 132, 72),
}
local BORDER_POST_COLOR = {
	on = Color3.fromRGB(126, 88, 56),
	off = Color3.fromRGB(92, 63, 40),
}
local BORDER_WALL_COLOR = {
	on = Color3.fromRGB(166, 122, 78),
	off = Color3.fromRGB(126, 88, 56),
}

local function tweenColor(part: BasePart?, color: Color3)
	if part and part:IsA("BasePart") then
		TweenService:Create(part, POWER_TWEEN, { Color = color }):Play()
	end
end

local function setLabelEnabled(parent: Instance?, labelName: string, enabled: boolean)
	local billboard = parent and parent:FindFirstChild(labelName)
	if billboard and billboard:IsA("BillboardGui") then
		billboard.Enabled = enabled
	end
end

local function setPlotPowered(plotModel: Model, powered: boolean)
	local key = powered and "on" or "off"

	tweenColor(plotModel:FindFirstChild("GroundGlow") :: BasePart?, GROUND_GLOW_COLOR[key])

	for i = 1, 4 do
		tweenColor(plotModel:FindFirstChild("BorderPost_" .. i) :: BasePart?, BORDER_POST_COLOR[key])
		tweenColor(plotModel:FindFirstChild("BorderWall_" .. i) :: BasePart?, BORDER_WALL_COLOR[key])
	end

	setLabelEnabled(plotModel:FindFirstChild("Dropbox"), "SellLabel", powered)
	setLabelEnabled(plotModel:FindFirstChild("WarehouseDoorGlow"), "WarehouseLabel", powered)
end

-- Plots start empty; a player claims a specific one by walking through its
-- ClaimGate (see PlotClaimTrigger.server.lua) rather than being auto-assigned
-- the first free plot on join.
function PlotManager.ClaimPlot(player: Player, plotIndex: number): Types.Plot?
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		warn("[PlotManager] Plots folder not found in Workspace")
		return nil
	end

	local plotModel = plotsFolder:FindFirstChild("Plot_" .. plotIndex)
	if not plotModel then
		return nil
	end

	local isOccupied = plotModel:FindFirstChild("IsOccupied") :: BoolValue
	if not isOccupied or isOccupied.Value then
		return nil
	end

	isOccupied.Value = true

	local ownerId = plotModel:FindFirstChild("OwnerId") :: StringValue
	ownerId.Value = tostring(player.UserId)

	playerPlots[player.UserId] = plotModel
	setClaimGateActive(plotModel, false)
	setPlotPowered(plotModel, true)

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
	setClaimGateActive(plotModel, true)
	setPlotPowered(plotModel, false)

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
	local maxTier = #Constants.ENVIRONMENT_UPGRADE_COSTS
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
