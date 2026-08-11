local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local pickupVialRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PICKUP_VIAL) :: RemoteEvent
local setMagnetRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SET_MAGNET) :: RemoteEvent
local setAutoPickupRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SET_AUTO_PICKUP) :: RemoteEvent

local MAGNET_RADIUS = 20
local AUTO_PICKUP_RADIUS = 40
local LOOP_INTERVAL = 0.1

-- VialProximity.client.lua owns pendingPickups and publishes it on shared.VialProximity;
-- script start order between LocalScripts isn't guaranteed, so wait briefly for it.
local VIAL_PROXIMITY_WAIT_TIMEOUT = 5
local waited = 0
while not shared.VialProximity and waited < VIAL_PROXIMITY_WAIT_TIMEOUT do
	task.wait(0.1)
	waited += 0.1
end

-- Reusing VialProximity's own pendingPickups table (not a separate one) is what
-- actually prevents duplicate fires -- a vial the magnet just claimed must also
-- be invisible to VialProximity's own walk-into-range loop, and vice versa.
local function getPendingPickups(): { [string]: boolean }
	return (shared.VialProximity and shared.VialProximity.pendingPickups) or {}
end

local magnetEnabled = false
local autoPickupExpiry = 0

shared.MagnetClient = { enabled = false, radius = MAGNET_RADIUS }

setMagnetRemote.OnClientEvent:Connect(function(payload: any)
	local enabled = typeof(payload) == "table" and payload.enabled == true
	magnetEnabled = enabled
	shared.MagnetClient = { enabled = enabled, radius = MAGNET_RADIUS }
end)

--============================================================
-- Auto Pickup HUD (bottom-right countdown)
--============================================================

local gui = Instance.new("ScreenGui")
gui.Name = "AutoPickupGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = playerGui

local hudFrame = Instance.new("Frame")
hudFrame.Name = "AutoPickupHud"
hudFrame.AnchorPoint = Vector2.new(1, 1)
hudFrame.Position = UDim2.new(1, -16, 1, -16)
hudFrame.Size = UDim2.new(0, 230, 0, 40)
hudFrame.BackgroundColor3 = Color3.fromRGB(12, 9, 22)
hudFrame.Visible = false
hudFrame.Parent = gui

local hudCorner = Instance.new("UICorner")
hudCorner.CornerRadius = UDim.new(0, 10)
hudCorner.Parent = hudFrame

local hudStroke = Instance.new("UIStroke")
hudStroke.Thickness = 2
hudStroke.Color = Color3.fromRGB(255, 210, 60)
hudStroke.Parent = hudFrame

local hudLabel = Instance.new("TextLabel")
hudLabel.Name = "Text"
hudLabel.BackgroundTransparency = 1
hudLabel.Size = UDim2.new(1, 0, 1, 0)
hudLabel.Font = Enum.Font.GothamBold
hudLabel.TextSize = 14
hudLabel.TextColor3 = Color3.new(1, 1, 1)
hudLabel.Text = ""
hudLabel.Parent = hudFrame

setAutoPickupRemote.OnClientEvent:Connect(function(expiryTime: any)
	if typeof(expiryTime) ~= "number" then
		return
	end
	autoPickupExpiry = expiryTime
	hudFrame.Visible = expiryTime > os.time()
end)

--============================================================
-- Proximity collection loop
--============================================================

local function collectNearbyVials(radius: number)
	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if not rootPart then
		return
	end

	local pendingPickups = getPendingPickups()

	for _, part in Workspace:GetChildren() do
		if part:IsA("BasePart") and part.Name:sub(1, 5) == "Vial_" then
			local ownerIdValue = part:FindFirstChild("OwnerId")
			local vialIdValue = part:FindFirstChild("VialId")

			if ownerIdValue and vialIdValue and ownerIdValue.Value == tostring(player.UserId) then
				local vialId = vialIdValue.Value

				if not pendingPickups[vialId] then
					local distance = (rootPart.Position - part.Position).Magnitude
					if distance <= radius then
						pendingPickups[vialId] = true
						pickupVialRemote:FireServer(vialId)
					end
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(LOOP_INTERVAL)

		if autoPickupExpiry > 0 then
			local now = os.time()
			if now >= autoPickupExpiry then
				autoPickupExpiry = 0
				hudFrame.Visible = false
			else
				collectNearbyVials(AUTO_PICKUP_RADIUS)
				hudLabel.Text = `⚡ AUTO PICKUP — {autoPickupExpiry - now}s remaining`
			end
		end

		if magnetEnabled then
			collectNearbyVials(MAGNET_RADIUS)
		end
	end
end)
