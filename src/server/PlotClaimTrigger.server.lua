local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PlotClaimManager = require(script.Parent.PlotClaimManager)
local RateLimiter = require(script.Parent.RateLimiter)

local claimLimiter = RateLimiter.CreateLimiter(3, 5)

-- A plot is claimed by walking through its gateway, not by clicking a beacon.
-- This script owns only the .Touched wiring; PlotSetup.server.lua builds the
-- gate geometry, matching how the Dropbox and Warehouse triggers are split.
--
-- .Touched fires many times per second while a character stands in the trigger,
-- so the work has to be cheap and idempotent: PlotClaimManager.ClaimPlot
-- already returns false immediately if the player owns a plot or this plot is
-- taken, and claimLimiter caps repeat attempts per player.
local function wirePlotClaim(plotModel: Model)
	local gate = plotModel:FindFirstChild("ClaimGate")
	local trigger = gate and gate:FindFirstChild("ClaimTrigger")
	if not trigger or not trigger:IsA("BasePart") then
		return
	end

	local plotIndexValue = gate:FindFirstChild("PlotIndex")
	local plotIndex = plotIndexValue and plotIndexValue.Value
	if not plotIndex then
		-- Fall back to the model name if the gate predates the PlotIndex value.
		local parsed = plotModel.Name:match("^Plot_(%d+)$")
		plotIndex = parsed and tonumber(parsed)
	end
	if not plotIndex then
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

		-- Cheapest rejection first: someone walking back out through their own
		-- gate shouldn't burn a rate-limit slot on every touch event.
		if PlotClaimManager.HasPlot(player) then
			return
		end

		local userId = player.UserId
		RateLimiter.TrackRemoteCall(userId)

		if not claimLimiter:Check(userId) then
			return
		end

		PlotClaimManager.ClaimPlot(player, plotIndex)
	end)
end

local plotsFolder = Workspace:WaitForChild("Plots")
for _, plotModel in plotsFolder:GetChildren() do
	if plotModel:IsA("Model") then
		wirePlotClaim(plotModel)
	end
end
plotsFolder.ChildAdded:Connect(function(child: Instance)
	if child:IsA("Model") then
		wirePlotClaim(child)
	end
end)
