local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local Types = require(ReplicatedStorage.Types)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local plotUpdatedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLOT_UPDATED) :: RemoteEvent

plotUpdatedRemote.OnClientEvent:Connect(function(plot: Types.Plot)
	shared.PlotClient = plot
	print(`[PlotClient] Plot tier updated: {plot.hallTier}`)
end)
