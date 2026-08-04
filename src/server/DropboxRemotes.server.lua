local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DropboxManager = require(script.Parent.DropboxManager)

local DEPOSIT_TOUCH_COOLDOWN = 2

local lastTouchDeposit: { [number]: number } = {}

-- Confirms the touching part belongs to a character, that character belongs to a
-- player, and that player owns this specific plot (OwnerId check) -- server-side,
-- so nothing here trusts the client.
local function getOwningPlayerFromTouch(hitPart: BasePart, plotModel: Model): Player?
	local character = hitPart:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return nil
	end

	local ownerId = plotModel:FindFirstChild("OwnerId") :: StringValue?
	if not ownerId or ownerId.Value ~= tostring(player.UserId) then
		return nil
	end

	return player
end

local function connectDropboxTouch(plotModel: Model)
	local dropbox = plotModel:FindFirstChild("Dropbox")
	if not dropbox or not dropbox:IsA("BasePart") then
		return
	end

	dropbox.Touched:Connect(function(hitPart: BasePart)
		local player = getOwningPlayerFromTouch(hitPart, plotModel)
		if not player then
			return
		end

		local userId = player.UserId
		local now = os.clock()
		local last = lastTouchDeposit[userId]
		if last and (now - last) < DEPOSIT_TOUCH_COOLDOWN then
			return
		end
		lastTouchDeposit[userId] = now

		DropboxManager.ProcessDeposit(player)
	end)
end

local plotsFolder = Workspace:WaitForChild("Plots")

for _, plotModel in plotsFolder:GetChildren() do
	if plotModel:IsA("Model") then
		connectDropboxTouch(plotModel)
	end
end

-- Defensive: plots are all pre-created by PlotSetup.server.lua at server start, so
-- this shouldn't normally fire, but costs nothing to guard against script-order
-- edge cases.
plotsFolder.ChildAdded:Connect(function(child: Instance)
	if child:IsA("Model") then
		connectDropboxTouch(child)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastTouchDeposit[player.UserId] = nil
end)
