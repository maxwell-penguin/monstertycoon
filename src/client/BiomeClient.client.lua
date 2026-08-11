local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local NumberFormatter = require(ReplicatedStorage.NumberFormatter)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local biomeUnlockPromptRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BIOME_UNLOCK_PROMPT) :: RemoteEvent
local biomeUnlockedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BIOME_UNLOCKED) :: RemoteEvent
local unlockBiomeRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UNLOCK_BIOME) :: RemoteEvent
local playerDataLoadedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLAYER_DATA_LOADED) :: RemoteEvent

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- PlotSetup/BiomeData live server-side only, so the client keeps its own copy
-- of the display metadata (icon + accent color) it can't reach otherwise.
local BIOME_VISUALS = {
	Volcano = { icon = "🌋", color = Color3.fromRGB(255, 80, 20) },
	Waterfall = { icon = "💧", color = Color3.fromRGB(80, 160, 255) },
	Pond = { icon = "🌊", color = Color3.fromRGB(40, 80, 100) },
	Forest = { icon = "🌲", color = Color3.fromRGB(60, 140, 60) },
}

local GRAY = Color3.fromRGB(150, 150, 160)
local GOLD = Color3.fromRGB(255, 215, 0)
local RED = Color3.fromRGB(255, 90, 90)

local unlockedBiomes: { string } = {}

local function publishBiomeClient()
	shared.BiomeClient = { unlockedBiomes = unlockedBiomes }
end

publishBiomeClient()

--============================================================
-- Unlock popup
--============================================================

local gui = Instance.new("ScreenGui")
gui.Name = "BiomeUnlockGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = playerGui

local popup = Instance.new("Frame")
popup.Name = "BiomeUnlockPopup"
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.Position = UDim2.new(0.5, 0, 0.5, 0)
popup.Size = isMobile and UDim2.new(0.9, 0, 0, 280) or UDim2.new(0, 400, 0, 300)
popup.BackgroundColor3 = Color3.fromRGB(12, 9, 22)
popup.Visible = false
popup.Parent = gui

local popupCorner = Instance.new("UICorner")
popupCorner.CornerRadius = UDim.new(0, 16)
popupCorner.Parent = popup

local popupStroke = Instance.new("UIStroke")
popupStroke.Thickness = 2
popupStroke.Color = Color3.fromRGB(150, 150, 150)
popupStroke.Parent = popup

local popupScale = Instance.new("UIScale")
popupScale.Scale = 0.8
popupScale.Parent = popup

local iconLabel = Instance.new("TextLabel")
iconLabel.Name = "Icon"
iconLabel.BackgroundTransparency = 1
iconLabel.Position = UDim2.new(0, 0, 0, 12)
iconLabel.Size = UDim2.new(1, 0, 0, 44)
iconLabel.Font = Enum.Font.GothamBold
iconLabel.TextSize = 40
iconLabel.Text = ""
iconLabel.Parent = popup

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "BiomeName"
nameLabel.BackgroundTransparency = 1
nameLabel.Position = UDim2.new(0, 0, 0, 56)
nameLabel.Size = UDim2.new(1, 0, 0, 28)
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextSize = 24
nameLabel.TextColor3 = Color3.new(1, 1, 1)
nameLabel.Text = ""
nameLabel.Parent = popup

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Position = UDim2.new(0, 0, 0, 84)
subtitleLabel.Size = UDim2.new(1, 0, 0, 16)
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.TextSize = 13
subtitleLabel.TextColor3 = GRAY
subtitleLabel.Text = "LOCKED BIOME"
subtitleLabel.Parent = popup

local monsterLabel = Instance.new("TextLabel")
monsterLabel.Name = "MonsterLabel"
monsterLabel.BackgroundTransparency = 1
monsterLabel.Position = UDim2.new(0, 16, 0, 112)
monsterLabel.Size = UDim2.new(1, -32, 0, 16)
monsterLabel.Font = Enum.Font.Gotham
monsterLabel.TextSize = 12
monsterLabel.TextColor3 = GRAY
monsterLabel.TextXAlignment = Enum.TextXAlignment.Left
monsterLabel.Text = "Monsters found here:"
monsterLabel.Parent = popup

local chipRow = Instance.new("Frame")
chipRow.Name = "ChipRow"
chipRow.BackgroundTransparency = 1
chipRow.Position = UDim2.new(0, 16, 0, 132)
chipRow.Size = UDim2.new(1, -32, 0, 24)
chipRow.Parent = popup

local chipLayout = Instance.new("UIListLayout")
chipLayout.FillDirection = Enum.FillDirection.Horizontal
chipLayout.Padding = UDim.new(0, 6)
chipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
chipLayout.Parent = chipRow

local costLabel = Instance.new("TextLabel")
costLabel.Name = "CostLabel"
costLabel.BackgroundTransparency = 1
costLabel.Position = UDim2.new(0, 0, 0, 168)
costLabel.Size = UDim2.new(1, 0, 0, 28)
costLabel.Font = Enum.Font.GothamBold
costLabel.TextSize = 22
costLabel.Text = ""
costLabel.Parent = popup

local balanceLabel = Instance.new("TextLabel")
balanceLabel.Name = "BalanceLabel"
balanceLabel.BackgroundTransparency = 1
balanceLabel.Position = UDim2.new(0, 0, 0, 198)
balanceLabel.Size = UDim2.new(1, 0, 0, 16)
balanceLabel.Font = Enum.Font.Gotham
balanceLabel.TextSize = 12
balanceLabel.TextColor3 = GRAY
balanceLabel.Text = ""
balanceLabel.Parent = popup

local unlockButton = Instance.new("TextButton")
unlockButton.Name = "UnlockButton"
unlockButton.AnchorPoint = Vector2.new(0, 1)
unlockButton.Position = UDim2.new(0.05, 0, 1, -16)
unlockButton.Size = UDim2.new(0.45, 0, 0, 44)
unlockButton.Font = Enum.Font.GothamBold
unlockButton.TextSize = 16
unlockButton.TextColor3 = Color3.new(1, 1, 1)
unlockButton.AutoButtonColor = true
unlockButton.Parent = popup

local unlockButtonCorner = Instance.new("UICorner")
unlockButtonCorner.CornerRadius = UDim.new(0, 10)
unlockButtonCorner.Parent = unlockButton

local cancelButton = Instance.new("TextButton")
cancelButton.Name = "CancelButton"
cancelButton.AnchorPoint = Vector2.new(1, 1)
cancelButton.Position = UDim2.new(0.95, 0, 1, -16)
cancelButton.Size = UDim2.new(0.45, 0, 0, 44)
cancelButton.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
cancelButton.Font = Enum.Font.GothamBold
cancelButton.TextSize = 16
cancelButton.TextColor3 = Color3.new(1, 1, 1)
cancelButton.Text = "CANCEL"
cancelButton.Parent = popup

local cancelButtonCorner = Instance.new("UICorner")
cancelButtonCorner.CornerRadius = UDim.new(0, 10)
cancelButtonCorner.Parent = cancelButton

local currentBiomeName: string? = nil
local unlockConnection: RBXScriptConnection? = nil

local function closePopup()
	if not popup.Visible then
		return
	end

	currentBiomeName = nil

	local tween = TweenService:Create(popupScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.8 })
	tween:Play()
	tween.Completed:Connect(function()
		popup.Visible = false
	end)
end

cancelButton.MouseButton1Click:Connect(closePopup)

local function openPopup(biomeName: string, cost: number, elements: { string })
	currentBiomeName = biomeName

	local visuals = BIOME_VISUALS[biomeName] or { icon = "❓", color = Color3.fromRGB(150, 150, 150) }

	popupStroke.Color = visuals.color
	iconLabel.Text = visuals.icon
	nameLabel.Text = string.upper(biomeName)

	for _, child in chipRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, element in elements do
		local elementColor = Constants.ELEMENT_COLORS[element] or Color3.new(1, 1, 1)

		local chip = Instance.new("Frame")
		chip.Name = "Chip_" .. element
		chip.BackgroundColor3 = elementColor
		chip.BackgroundTransparency = 0.75
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.new(0, 0, 1, 0)
		chip.Parent = chipRow

		local chipCorner = Instance.new("UICorner")
		chipCorner.CornerRadius = UDim.new(0, 6)
		chipCorner.Parent = chip

		local chipPadding = Instance.new("UIPadding")
		chipPadding.PaddingLeft = UDim.new(0, 8)
		chipPadding.PaddingRight = UDim.new(0, 8)
		chipPadding.Parent = chip

		local chipLabel = Instance.new("TextLabel")
		chipLabel.BackgroundTransparency = 1
		chipLabel.Size = UDim2.new(1, 0, 1, 0)
		chipLabel.Font = Enum.Font.Gotham
		chipLabel.TextSize = 11
		chipLabel.TextColor3 = Color3.new(1, 1, 1)
		chipLabel.Text = element
		chipLabel.Parent = chip
	end

	local balance = (shared.CoinDisplay and shared.CoinDisplay.displayCoins) or 0
	local canAfford = balance >= cost

	costLabel.Text = `💰 {NumberFormatter.Format(cost)}`
	costLabel.TextColor3 = canAfford and GOLD or RED
	balanceLabel.Text = `Your coins: {NumberFormatter.Format(balance)}`

	if unlockConnection then
		unlockConnection:Disconnect()
		unlockConnection = nil
	end

	if canAfford then
		unlockButton.BackgroundColor3 = visuals.color
		unlockButton.Text = "UNLOCK"
		unlockButton.Active = true
		unlockConnection = unlockButton.MouseButton1Click:Connect(function()
			unlockBiomeRemote:FireServer(biomeName)
			closePopup()
		end)
	else
		unlockButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
		unlockButton.Text = "NOT ENOUGH COINS"
		unlockButton.Active = false
	end

	popup.Visible = true
	popupScale.Scale = 0.8
	TweenService:Create(popupScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

biomeUnlockPromptRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	if typeof(payload.biomeName) ~= "string" then
		return
	end

	openPopup(payload.biomeName, payload.cost or 0, payload.elements or {})
end)

--============================================================
-- Celebration notification
--============================================================

local celebrationGui = Instance.new("ScreenGui")
celebrationGui.Name = "BiomeCelebrationGui"
celebrationGui.IgnoreGuiInset = true
celebrationGui.ResetOnSpawn = false
celebrationGui.Parent = playerGui

local celebrationFrame = Instance.new("Frame")
celebrationFrame.Name = "Celebration"
celebrationFrame.AnchorPoint = Vector2.new(0.5, 0)
celebrationFrame.Position = UDim2.new(0.5, 0, 0, -140)
celebrationFrame.Size = UDim2.new(0, 420, 0, 90)
celebrationFrame.BackgroundColor3 = Color3.fromRGB(12, 9, 22)
celebrationFrame.Visible = false
celebrationFrame.Parent = celebrationGui

local celebrationCorner = Instance.new("UICorner")
celebrationCorner.CornerRadius = UDim.new(0, 14)
celebrationCorner.Parent = celebrationFrame

local celebrationStroke = Instance.new("UIStroke")
celebrationStroke.Thickness = 2
celebrationStroke.Parent = celebrationFrame

local celebrationTitle = Instance.new("TextLabel")
celebrationTitle.BackgroundTransparency = 1
celebrationTitle.Position = UDim2.new(0, 0, 0, 14)
celebrationTitle.Size = UDim2.new(1, 0, 0, 30)
celebrationTitle.Font = Enum.Font.GothamBold
celebrationTitle.TextSize = 22
celebrationTitle.Text = ""
celebrationTitle.Parent = celebrationFrame

local celebrationSubtitle = Instance.new("TextLabel")
celebrationSubtitle.BackgroundTransparency = 1
celebrationSubtitle.Position = UDim2.new(0, 0, 0, 48)
celebrationSubtitle.Size = UDim2.new(1, 0, 0, 24)
celebrationSubtitle.Font = Enum.Font.Gotham
celebrationSubtitle.TextSize = 14
celebrationSubtitle.TextColor3 = Color3.new(1, 1, 1)
celebrationSubtitle.Text = "New monsters are now roaming your farm!"
celebrationSubtitle.Parent = celebrationFrame

local CELEBRATION_HOLD = 3
local celebrationToken = 0

local function showCelebration(biomeName: string)
	local visuals = BIOME_VISUALS[biomeName] or { color = Color3.fromRGB(150, 150, 150) }

	celebrationToken += 1
	local myToken = celebrationToken

	celebrationStroke.Color = visuals.color
	celebrationTitle.TextColor3 = visuals.color
	celebrationTitle.Text = `{string.upper(biomeName)} UNLOCKED!`

	celebrationFrame.Position = UDim2.new(0.5, 0, 0, -140)
	celebrationFrame.Visible = true

	TweenService:Create(celebrationFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 24),
	}):Play()

	task.delay(CELEBRATION_HOLD, function()
		if myToken ~= celebrationToken then
			return
		end

		local tween = TweenService:Create(celebrationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -140),
		})
		tween:Play()
		tween.Completed:Connect(function()
			if myToken == celebrationToken then
				celebrationFrame.Visible = false
			end
		end)
	end)
end

--============================================================
-- Gate removal + unlocked-biome bookkeeping
--============================================================

local function destroyGate(biomeName: string)
	local gate = Workspace:FindFirstChild("BiomeGate_" .. biomeName)
	if gate then
		gate:Destroy()
	end
end

biomeUnlockedRemote.OnClientEvent:Connect(function(biomeName: any)
	if typeof(biomeName) ~= "string" then
		return
	end

	if currentBiomeName then
		closePopup()
	end

	showCelebration(biomeName)
	destroyGate(biomeName)

	if not table.find(unlockedBiomes, biomeName) then
		table.insert(unlockedBiomes, biomeName)
	end
	publishBiomeClient()
end)

playerDataLoadedRemote.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end

	local loaded = data.unlockedBiomes
	if typeof(loaded) ~= "table" then
		loaded = {}
	end

	unlockedBiomes = table.clone(loaded)

	for _, biomeName in unlockedBiomes do
		destroyGate(biomeName)
	end

	publishBiomeClient()
end)
