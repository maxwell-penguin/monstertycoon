local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local sessionRewardRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SESSION_REWARD) :: RemoteEvent

local ICONS = {
	egg = "🥚",
	coins = "💰",
	bagVoucher = "👜",
}

local IN_POSITION = UDim2.new(1, -300, 0.7, 0)
local OUT_POSITION = UDim2.new(1, 300, 0.7, 0)
local HOLD_TIME = 3
local QUEUE_GAP = 0.5

local gui = Instance.new("ScreenGui")
gui.Name = "SessionRewardGui"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 90
gui.Parent = playerGui

local queue: { any } = {}
local processing = false

local function showNext()
	local payload = table.remove(queue, 1)
	if not payload then
		processing = false
		return
	end
	processing = true

	local frame = Instance.new("Frame")
	frame.Name = "SessionRewardCard"
	frame.Size = UDim2.new(0, 280, 0, 70)
	frame.Position = OUT_POSITION
	frame.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
	frame.Parent = gui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextWrapped = true
	label.Text = `{ICONS[payload.type] or "🎁"} SESSION REWARD — {payload.description}`
	label.Parent = frame

	local slideIn = TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = IN_POSITION,
	})

	slideIn.Completed:Connect(function()
		task.delay(HOLD_TIME, function()
			local slideOut = TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Position = OUT_POSITION,
			})
			slideOut.Completed:Connect(function()
				frame:Destroy()
				task.delay(QUEUE_GAP, showNext)
			end)
			slideOut:Play()
		end)
	end)
	slideIn:Play()
end

-- SESSION_REWARD is also used by EventManager.lua for Shard Hunt token pickups
-- ({ type = "eventTokens", amount = N }, handled separately in
-- UIManager.client.lua) -- description is how this handler tells "one of ours"
-- apart from that unrelated payload shape.
sessionRewardRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.description) ~= "string" then
		return
	end

	table.insert(queue, payload)
	if not processing then
		showNext()
	end
end)
