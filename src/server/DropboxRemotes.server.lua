local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DropboxManager = require(script.Parent.DropboxManager)

local DEPOSIT_TOUCH_COOLDOWN = 2

local lastTouchDeposit: { [number]: number } = {}

local function connectSellPointTouch(sellPoint: Model)
	local platform = sellPoint:FindFirstChild("SellPlatform")
	if not platform or not platform:IsA("BasePart") then
		return
	end

	platform.Touched:Connect(function(hitPart: BasePart)
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
		local last = lastTouchDeposit[userId]
		if last and (now - last) < DEPOSIT_TOUCH_COOLDOWN then
			return
		end
		lastTouchDeposit[userId] = now

		DropboxManager.ProcessDeposit(player)
	end)
end

local sellPoint = Workspace:WaitForChild("SellPoint") :: Model
connectSellPointTouch(sellPoint)

Players.PlayerRemoving:Connect(function(player: Player)
	lastTouchDeposit[player.UserId] = nil
end)
