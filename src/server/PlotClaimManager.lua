local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local PlotManager = require(script.Parent.PlotManager)
local HallManager = require(script.Parent.HallManager)
local HabitatManager = require(script.Parent.HabitatManager)
local VialProducer = require(script.Parent.VialProducer)
local DropboxManager = require(script.Parent.DropboxManager)
local CrateManager = require(script.Parent.CrateManager)
local FTUEManager = require(script.Parent.FTUEManager)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local plotUpdatedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLOT_UPDATED) :: RemoteEvent

local PlotClaimManager = {}

-- Everything plot-bound (Hall pedestals, Habitats, vial production, Dropbox,
-- Crates) stays uninitialized until a player actually claims a specific
-- plot -- DataStore.server.lua's onPlayerAdded only sets up account-level
-- state (coins, bag, warehouse, town) immediately; this is the deferred
-- "your plot is ready" half, triggered by PlotClaimTrigger.server.lua.
-- Cheap ownership check for PlotClaimTrigger.server.lua, whose .Touched handler
-- fires continuously while a player stands in a gateway and wants to bail out
-- before doing any rate-limit bookkeeping.
function PlotClaimManager.HasPlot(player: Player): boolean
	return PlotManager.GetPlayerPlot(player) ~= nil
end

function PlotClaimManager.ClaimPlot(player: Player, plotIndex: number): boolean
	if PlotManager.GetPlayerPlot(player) then
		return false
	end

	local plot = PlotManager.ClaimPlot(player, plotIndex)
	if not plot then
		return false
	end

	HallManager.InitHall(player)
	HabitatManager.InitHabitats(player)
	HabitatManager.LoadHabitatsFromPlayerData(player)
	VialProducer.StartProduction(player)
	DropboxManager.InitDropbox(player)
	CrateManager.StartCrateLoop(player)

	plotUpdatedRemote:FireClient(player, plot)

	-- FTUE's starter-monster tutorial auto-slots into the Hall and waits for a
	-- vial to be collected, so it can't run until the Hall/plot actually exist.
	task.spawn(FTUEManager.StartFTUE, player)

	return true
end

return PlotClaimManager
