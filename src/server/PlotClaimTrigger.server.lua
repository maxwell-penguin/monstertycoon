local Workspace = game:GetService("Workspace")

local PlotClaimManager = require(script.Parent.PlotClaimManager)
local RateLimiter = require(script.Parent.RateLimiter)

local claimLimiter = RateLimiter.CreateLimiter(3, 5)

local function wirePlotClaim(plotModel: Model)
	local plotIndexStr = plotModel.Name:match("^Plot_(%d+)$")
	if not plotIndexStr then
		return
	end
	local plotIndex = tonumber(plotIndexStr)

	local beacon = plotModel:FindFirstChild("ClaimBeacon")
	local clickDetector = beacon and beacon:FindFirstChild("ClaimClickDetector")
	if not clickDetector or not clickDetector:IsA("ClickDetector") then
		return
	end

	clickDetector.MouseClick:Connect(function(player: Player)
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
