local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local playerDataLoadedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLAYER_DATA_LOADED) :: RemoteEvent
local codexDiscoveryRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.CODEX_DISCOVERY) :: RemoteEvent

-- Must match CODEX_ORDER's entry count in UIManager.client.lua (6 emotion
-- lineages x 5 rarities + 3 standalone Mythic entries) -- the client can't
-- reach MonsterData (ServerScriptService-only) to compute this itself.
local TOTAL_MONSTER_COUNT = 33

local IN_POSITION = UDim2.new(1, -320, 0.5, -40)
local OUT_POSITION = UDim2.new(1, 20, 0.5, -40)
local HOLD_TIME = 3
local QUEUE_GAP = 0.3

local gui = Instance.new("ScreenGui")
gui.Name = "CodexDiscoveryGui"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 95
gui.Parent = playerGui

local discovered: { [string]: boolean } = {}

local function publishState()
	local count = 0
	for _ in discovered do
		count += 1
	end

	shared.CodexClient = {
		discovered = discovered,
		totalCount = TOTAL_MONSTER_COUNT,
		discoveredCount = count,
	}
end
publishState()

playerDataLoadedRemote.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" or typeof(data.discoveredMonsters) ~= "table" then
		return
	end

	for _, monsterName in data.discoveredMonsters do
		discovered[monsterName] = true
	end
	publishState()
end)

local queue: { { monsterName: string, monsterData: any } } = {}
local processing = false

local function showNext()
	local entry = table.remove(queue, 1)
	if not entry then
		processing = false
		return
	end
	processing = true

	local monsterData = entry.monsterData
	local emotionColor = Constants.EMOTION_COLORS[monsterData.emotion] or Color3.new(1, 1, 1)

	local frame = Instance.new("Frame")
	frame.Name = "DiscoveryCard"
	frame.Size = UDim2.new(0, 300, 0, 80)
	frame.Position = OUT_POSITION
	frame.BackgroundColor3 = Color3.fromRGB(20, 15, 40)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = emotionColor
	stroke.Parent = frame

	local headerLabel = Instance.new("TextLabel")
	headerLabel.Name = "Header"
	headerLabel.Size = UDim2.new(1, -16, 0, 24)
	headerLabel.Position = UDim2.new(0, 8, 0, 10)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextSize = 14
	headerLabel.TextColor3 = emotionColor
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.Text = "NEW DISCOVERY"
	headerLabel.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "MonsterName"
	nameLabel.Size = UDim2.new(1, -16, 0, 20)
	nameLabel.Position = UDim2.new(0, 8, 0, 40)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = `{monsterData.name} ({monsterData.rarity})`
	nameLabel.Parent = frame

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

codexDiscoveryRemote.OnClientEvent:Connect(function(monsterName: any, monsterData: any)
	if typeof(monsterName) ~= "string" or typeof(monsterData) ~= "table" then
		return
	end

	discovered[monsterName] = true
	publishState()

	table.insert(queue, { monsterName = monsterName, monsterData = monsterData })
	if not processing then
		showNext()
	end
end)
