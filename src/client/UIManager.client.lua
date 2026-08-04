local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local RollTable = require(ReplicatedStorage.RollTable)
local NumberFormatter = require(ReplicatedStorage.NumberFormatter)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateHallRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_HALL) :: RemoteEvent
local mergeMonstersRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.MERGE_MONSTERS) :: RemoteEvent
local playerDataLoadedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.PLAYER_DATA_LOADED) :: RemoteEvent
local eggResultRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.EGG_RESULT) :: RemoteEvent

-- BindableEvent so UIInput.client.lua (a separate LocalScript, can't be require()'d)
-- can hear about button clicks without UIManager reaching into RemoteEvents itself.
-- Created before any button is wired so the firing side never races the listener.
local actionEvent = Instance.new("BindableEvent")
shared.UIActionEvent = actionEvent

local function fireAction(action: string, payload: any)
	actionEvent:Fire(action, payload)
end

--- Theme ---

local PANEL_BG = Color3.fromRGB(18, 18, 28)
local BUTTON_DEFAULT = Color3.fromRGB(30, 30, 45)
local BUTTON_HOVER = Color3.fromRGB(50, 50, 70)
local GOLD = Color3.fromRGB(255, 210, 60)
local WHITE = Color3.new(1, 1, 1)
local GRAY = Color3.fromRGB(180, 180, 180)
local PURPLE = Color3.fromRGB(140, 100, 255)
local VOID_STORM_COLOR = Color3.fromRGB(150, 60, 220)
local TRACK_COLOR = Color3.fromRGB(40, 40, 55)

--- ScreenGui ---

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VoidFactoryUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local panels: { [string]: Frame } = {}

--- Module-style API ---

local UIManagerAPI = {}
UIManagerAPI.selectedSlot = nil :: number?

function UIManagerAPI.ShowPanel(name: string)
	local panel = panels[name]
	if panel then
		panel.Visible = true
	end
end

function UIManagerAPI.HidePanel(name: string)
	local panel = panels[name]
	if panel then
		panel.Visible = false
	end
end

function UIManagerAPI.UpdateElement(panelName: string, elementName: string, value: any)
	local panel = panels[panelName]
	if not panel then
		return
	end
	local element = panel:FindFirstChild(elementName, true)
	if not element then
		return
	end
	if element:IsA("TextLabel") or element:IsA("TextButton") then
		element.Text = tostring(value)
	end
end

shared.UIManager = UIManagerAPI

--- Helpers ---

local function addCorner(instance: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function addStroke(instance: Instance, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = color or Color3.fromRGB(80, 80, 100)
	stroke.Parent = instance
	return stroke
end

-- Dark-void default, lighter on hover; sets an IsTweening attribute so click
-- handlers (via onActivated below) can refuse input mid-animation.
local function styleButton(button: TextButton)
	button.BackgroundColor3 = BUTTON_DEFAULT
	button.TextColor3 = WHITE
	button.Font = Enum.Font.Gotham
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button:SetAttribute("IsTweening", false)

	addCorner(button, 6)
	addStroke(button)

	local function tweenTo(color: Color3)
		button:SetAttribute("IsTweening", true)
		local tween = TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = color })
		tween.Completed:Connect(function()
			button:SetAttribute("IsTweening", false)
		end)
		tween:Play()
	end

	button.MouseEnter:Connect(function()
		tweenTo(BUTTON_HOVER)
	end)

	button.MouseLeave:Connect(function()
		tweenTo(BUTTON_DEFAULT)
	end)
end

local function onActivated(button: TextButton, callback: () -> ())
	button.MouseButton1Click:Connect(function()
		if button:GetAttribute("IsTweening") then
			return
		end
		callback()
	end)
end

local function createCloseButton(parent: Frame, panelName: string)
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 12)
	closeButton.Size = UDim2.new(0, 28, 0, 28)
	closeButton.Text = "X"
	closeButton.TextSize = 16
	closeButton.Parent = parent
	styleButton(closeButton)

	onActivated(closeButton, function()
		UIManagerAPI.HidePanel(panelName)
	end)
end

local function getBagFillColor(fraction: number): Color3
	local green = Color3.fromRGB(80, 200, 100)
	local yellow = Color3.fromRGB(230, 200, 60)
	local red = Color3.fromRGB(220, 70, 70)

	if fraction <= 0.5 then
		return green:Lerp(yellow, fraction / 0.5)
	end
	return yellow:Lerp(red, (fraction - 0.5) / 0.5)
end

--============================================================
-- HUD Panel
--============================================================

local hud = Instance.new("Frame")
hud.Name = "HUD"
hud.Size = UDim2.fromScale(1, 1)
hud.BackgroundTransparency = 1
hud.Parent = screenGui
panels.HUD = hud

-- Coin counter (top-left)
local coinFrame = Instance.new("Frame")
coinFrame.Name = "CoinCounter"
coinFrame.Position = UDim2.new(0, 16, 0, 16)
coinFrame.Size = UDim2.new(0, 220, 0, 60)
coinFrame.BackgroundColor3 = PANEL_BG
coinFrame.BackgroundTransparency = 0.3
coinFrame.BorderSizePixel = 0
coinFrame.Parent = hud
addCorner(coinFrame, 8)

local coinAmountLabel = Instance.new("TextLabel")
coinAmountLabel.Name = "CoinAmount"
coinAmountLabel.Size = UDim2.new(1, -16, 0, 34)
coinAmountLabel.Position = UDim2.new(0, 8, 0, 4)
coinAmountLabel.BackgroundTransparency = 1
coinAmountLabel.Font = Enum.Font.GothamBold
coinAmountLabel.TextSize = 28
coinAmountLabel.TextColor3 = GOLD
coinAmountLabel.TextXAlignment = Enum.TextXAlignment.Left
coinAmountLabel.Text = "0"
coinAmountLabel.Parent = coinFrame

local coinScale = Instance.new("UIScale")
coinScale.Scale = 1
coinScale.Parent = coinAmountLabel

local function pulseCoin()
	coinScale.Scale = 1.05
	TweenService:Create(coinScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
end

local earnRateLabel = Instance.new("TextLabel")
earnRateLabel.Name = "EarnRate"
earnRateLabel.Size = UDim2.new(1, -16, 0, 18)
earnRateLabel.Position = UDim2.new(0, 8, 0, 38)
earnRateLabel.BackgroundTransparency = 1
earnRateLabel.Font = Enum.Font.Gotham
earnRateLabel.TextSize = 14
earnRateLabel.TextColor3 = GRAY
earnRateLabel.TextXAlignment = Enum.TextXAlignment.Left
earnRateLabel.Text = "+0/sec"
earnRateLabel.Parent = coinFrame

-- Bag indicator (top-right)
local bagFrame = Instance.new("Frame")
bagFrame.Name = "BagIndicator"
bagFrame.AnchorPoint = Vector2.new(1, 0)
bagFrame.Position = UDim2.new(1, -16, 0, 16)
bagFrame.Size = UDim2.new(0, 160, 0, 60)
bagFrame.BackgroundColor3 = PANEL_BG
bagFrame.BackgroundTransparency = 0.3
bagFrame.BorderSizePixel = 0
bagFrame.Parent = hud
addCorner(bagFrame, 8)

local bagCountLabel = Instance.new("TextLabel")
bagCountLabel.Name = "BagCount"
bagCountLabel.Size = UDim2.new(1, -16, 0, 26)
bagCountLabel.Position = UDim2.new(0, 8, 0, 4)
bagCountLabel.BackgroundTransparency = 1
bagCountLabel.Font = Enum.Font.GothamBold
bagCountLabel.TextSize = 22
bagCountLabel.TextColor3 = WHITE
bagCountLabel.Text = "0/10"
bagCountLabel.Parent = bagFrame

local bagBarTrack = Instance.new("Frame")
bagBarTrack.Name = "BagBarTrack"
bagBarTrack.Size = UDim2.new(1, -16, 0, 10)
bagBarTrack.Position = UDim2.new(0, 8, 1, -18)
bagBarTrack.BackgroundColor3 = TRACK_COLOR
bagBarTrack.BorderSizePixel = 0
bagBarTrack.Parent = bagFrame
addCorner(bagBarTrack, 4)

local bagBarFill = Instance.new("Frame")
bagBarFill.Name = "BagBarFill"
bagBarFill.Size = UDim2.new(0, 0, 1, 0)
bagBarFill.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
bagBarFill.BorderSizePixel = 0
bagBarFill.Parent = bagBarTrack
addCorner(bagBarFill, 4)

local bagPulseTween: Tween? = nil

-- Town level indicator (top-center)
local townFrame = Instance.new("Frame")
townFrame.Name = "TownLevelIndicator"
townFrame.AnchorPoint = Vector2.new(0.5, 0)
townFrame.Position = UDim2.new(0.5, 0, 0, 16)
townFrame.Size = UDim2.new(0, 200, 0, 60)
townFrame.BackgroundColor3 = PANEL_BG
townFrame.BackgroundTransparency = 0.3
townFrame.BorderSizePixel = 0
townFrame.Parent = hud
addCorner(townFrame, 8)

local townLevelLabel = Instance.new("TextLabel")
townLevelLabel.Name = "TownLevel"
townLevelLabel.Size = UDim2.new(1, -16, 0, 34)
townLevelLabel.Position = UDim2.new(0, 8, 0, 4)
townLevelLabel.BackgroundTransparency = 1
townLevelLabel.Font = Enum.Font.GothamBold
townLevelLabel.TextSize = 20
townLevelLabel.TextColor3 = WHITE
townLevelLabel.Text = "TOWN LV.1"
townLevelLabel.Parent = townFrame

local xpBarTrack = Instance.new("Frame")
xpBarTrack.Name = "XPBarTrack"
xpBarTrack.Size = UDim2.new(1, -16, 0, 6)
xpBarTrack.Position = UDim2.new(0, 8, 1, -12)
xpBarTrack.BackgroundColor3 = TRACK_COLOR
xpBarTrack.BorderSizePixel = 0
xpBarTrack.Parent = townFrame
addCorner(xpBarTrack, 3)

local xpBarFill = Instance.new("Frame")
xpBarFill.Name = "XPBarFill"
xpBarFill.Size = UDim2.new(0, 0, 1, 0)
xpBarFill.BackgroundColor3 = PURPLE
xpBarFill.BorderSizePixel = 0
xpBarFill.Parent = xpBarTrack
addCorner(xpBarFill, 3)

-- Boost HUD (bottom-center, hidden when no boost)
local BOOST_HUD_HIDDEN_Y = 90
local BOOST_HUD_SHOWN_Y = -16

local boostHud = Instance.new("Frame")
boostHud.Name = "BoostHud"
boostHud.AnchorPoint = Vector2.new(0.5, 1)
boostHud.Position = UDim2.new(0.5, 0, 1, BOOST_HUD_HIDDEN_Y)
boostHud.Size = UDim2.new(0, 300, 0, 70)
boostHud.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
boostHud.BackgroundTransparency = 0.2
boostHud.BorderSizePixel = 0
boostHud.Visible = false
boostHud.Parent = hud
addCorner(boostHud, 10)

local boostEmotionLabel = Instance.new("TextLabel")
boostEmotionLabel.Name = "BoostEmotion"
boostEmotionLabel.Size = UDim2.new(1, -16, 0, 34)
boostEmotionLabel.Position = UDim2.new(0, 8, 0, 6)
boostEmotionLabel.BackgroundTransparency = 1
boostEmotionLabel.Font = Enum.Font.GothamBold
boostEmotionLabel.TextSize = 24
boostEmotionLabel.TextColor3 = WHITE
boostEmotionLabel.Text = ""
boostEmotionLabel.Parent = boostHud

local boostTimerLabel = Instance.new("TextLabel")
boostTimerLabel.Name = "BoostTimer"
boostTimerLabel.Size = UDim2.new(1, -16, 0, 20)
boostTimerLabel.Position = UDim2.new(0, 8, 0, 40)
boostTimerLabel.BackgroundTransparency = 1
boostTimerLabel.Font = Enum.Font.Gotham
boostTimerLabel.TextSize = 16
boostTimerLabel.TextColor3 = WHITE
boostTimerLabel.Text = "00:00"
boostTimerLabel.Parent = boostHud

-- Boost warning banner (top, hidden normally)
local BOOST_WARNING_HIDDEN_Y = -60
local BOOST_WARNING_SHOWN_Y = 90

local warningBanner = Instance.new("Frame")
warningBanner.Name = "BoostWarningBanner"
warningBanner.AnchorPoint = Vector2.new(0.5, 0)
warningBanner.Position = UDim2.new(0.5, 0, 0, BOOST_WARNING_HIDDEN_Y)
warningBanner.Size = UDim2.new(0, 400, 0, 50)
warningBanner.BackgroundColor3 = WHITE
warningBanner.BorderSizePixel = 0
warningBanner.Visible = false
warningBanner.Parent = hud
addCorner(warningBanner, 8)

local warningLabel = Instance.new("TextLabel")
warningLabel.Name = "WarningText"
warningLabel.Size = UDim2.fromScale(1, 1)
warningLabel.BackgroundTransparency = 1
warningLabel.Font = Enum.Font.GothamBold
warningLabel.TextSize = 18
warningLabel.TextColor3 = WHITE
warningLabel.Text = ""
warningLabel.Parent = warningBanner

-- Bottom-left toggle buttons
local function createToggleButton(label: string, order: number, panelName: string)
	local button = Instance.new("TextButton")
	button.Name = label .. "ToggleButton"
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new(0, 16, 1, -16 - (order * 44))
	button.Size = UDim2.new(0, 110, 0, 36)
	button.Text = label
	button.TextSize = 16
	button.Parent = hud
	styleButton(button)

	onActivated(button, function()
		local panel = panels[panelName]
		if panel then
			panel.Visible = not panel.Visible
		end
	end)
end

createToggleButton("WAREHOUSE", 0, "WarehousePanel")
createToggleButton("ROLL", 1, "RollPanel")
createToggleButton("HALL", 2, "HallPanel")

--============================================================
-- Warehouse Panel
--============================================================

local warehousePanel = Instance.new("Frame")
warehousePanel.Name = "WarehousePanel"
warehousePanel.Position = UDim2.new(0.5, -300, 0.5, -250)
warehousePanel.Size = UDim2.new(0, 600, 0, 500)
warehousePanel.BackgroundColor3 = PANEL_BG
warehousePanel.BorderSizePixel = 0
warehousePanel.Visible = false
warehousePanel.Parent = screenGui
addCorner(warehousePanel, 12)
panels.WarehousePanel = warehousePanel

local warehouseTitle = Instance.new("TextLabel")
warehouseTitle.Name = "Title"
warehouseTitle.Size = UDim2.new(1, -40, 0, 36)
warehouseTitle.Position = UDim2.new(0, 16, 0, 12)
warehouseTitle.BackgroundTransparency = 1
warehouseTitle.Font = Enum.Font.GothamBold
warehouseTitle.TextSize = 20
warehouseTitle.TextColor3 = WHITE
warehouseTitle.TextXAlignment = Enum.TextXAlignment.Left
warehouseTitle.Text = "WAREHOUSE"
warehouseTitle.Parent = warehousePanel

createCloseButton(warehousePanel, "WarehousePanel")

local warehouseCapacityLabel = Instance.new("TextLabel")
warehouseCapacityLabel.Name = "CapacityLabel"
warehouseCapacityLabel.Size = UDim2.new(1, -32, 0, 20)
warehouseCapacityLabel.Position = UDim2.new(0, 16, 0, 48)
warehouseCapacityLabel.BackgroundTransparency = 1
warehouseCapacityLabel.Font = Enum.Font.Gotham
warehouseCapacityLabel.TextSize = 14
warehouseCapacityLabel.TextColor3 = GRAY
warehouseCapacityLabel.TextXAlignment = Enum.TextXAlignment.Left
warehouseCapacityLabel.Text = "0/30"
warehouseCapacityLabel.Parent = warehousePanel

local warehouseCapacityTrack = Instance.new("Frame")
warehouseCapacityTrack.Name = "CapacityTrack"
warehouseCapacityTrack.Size = UDim2.new(1, -32, 0, 8)
warehouseCapacityTrack.Position = UDim2.new(0, 16, 0, 70)
warehouseCapacityTrack.BackgroundColor3 = TRACK_COLOR
warehouseCapacityTrack.BorderSizePixel = 0
warehouseCapacityTrack.Parent = warehousePanel
addCorner(warehouseCapacityTrack, 4)

local warehouseCapacityFill = Instance.new("Frame")
warehouseCapacityFill.Name = "CapacityFill"
warehouseCapacityFill.Size = UDim2.new(0, 0, 1, 0)
warehouseCapacityFill.BackgroundColor3 = Color3.fromRGB(100, 150, 220)
warehouseCapacityFill.BorderSizePixel = 0
warehouseCapacityFill.Parent = warehouseCapacityTrack
addCorner(warehouseCapacityFill, 4)

local warehouseList = Instance.new("ScrollingFrame")
warehouseList.Name = "MonsterList"
warehouseList.Position = UDim2.new(0, 16, 0, 90)
warehouseList.Size = UDim2.new(1, -32, 1, -106)
warehouseList.BackgroundTransparency = 1
warehouseList.BorderSizePixel = 0
warehouseList.ScrollBarThickness = 6
warehouseList.CanvasSize = UDim2.new(0, 0, 0, 0)
warehouseList.Parent = warehousePanel

local warehouseListLayout = Instance.new("UIListLayout")
warehouseListLayout.SortOrder = Enum.SortOrder.LayoutOrder
warehouseListLayout.Padding = UDim.new(0, 4)
warehouseListLayout.Parent = warehouseList

warehouseListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	warehouseList.CanvasSize = UDim2.new(0, 0, 0, warehouseListLayout.AbsoluteContentSize.Y + 8)
end)

local function getMonsterGroupKey(monster: any): string
	return `{monster.name}|{monster.rarity}|{monster.level}|{monster.stars}`
end

local function computeMergeGroups(monsters: { [string]: any }): { [string]: { string } }
	local groups: { [string]: { string } } = {}
	for instanceId, monster in monsters do
		local key = getMonsterGroupKey(monster)
		if not groups[key] then
			groups[key] = {}
		end
		table.insert(groups[key], instanceId)
	end
	return groups
end

local function createMonsterEntry(instanceId: string, monster: any, mergeGroupIds: { string }?): Frame
	local entry = Instance.new("Frame")
	entry.Name = "Entry_" .. instanceId
	entry.Size = UDim2.new(1, 0, 0, 48)
	entry.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
	entry.BorderSizePixel = 0
	addCorner(entry, 6)

	local stars = string.rep("★", monster.stars or 0)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0.5, -8, 1, 0)
	nameLabel.Position = UDim2.new(0, 8, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 14
	nameLabel.TextColor3 = WHITE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = `{monster.name} ({monster.rarity}) {stars}`
	nameLabel.Parent = entry

	local emotionLabel = Instance.new("TextLabel")
	emotionLabel.Name = "EmotionLabel"
	emotionLabel.Size = UDim2.new(0, 80, 1, 0)
	emotionLabel.Position = UDim2.new(0.5, 0, 0, 0)
	emotionLabel.BackgroundTransparency = 1
	emotionLabel.Font = Enum.Font.Gotham
	emotionLabel.TextSize = 13
	emotionLabel.TextColor3 = Constants.EMOTION_COLORS[monster.emotion] or WHITE
	emotionLabel.Text = monster.emotion or ""
	emotionLabel.Parent = entry

	local slotButton = Instance.new("TextButton")
	slotButton.Name = "SLOT"
	slotButton.Size = UDim2.new(0, 60, 0, 32)
	slotButton.Position = UDim2.new(1, -140, 0.5, -16)
	slotButton.Text = "SLOT"
	slotButton.TextSize = 13
	slotButton.Parent = entry
	styleButton(slotButton)

	onActivated(slotButton, function()
		local selectedSlot = UIManagerAPI.selectedSlot
		if not selectedSlot then
			return
		end
		fireAction("SLOT_MONSTER", { slotIndex = selectedSlot, instanceId = instanceId })
	end)

	if mergeGroupIds and #mergeGroupIds >= 3 then
		local mergeButton = Instance.new("TextButton")
		mergeButton.Name = "MERGE"
		mergeButton.Size = UDim2.new(0, 60, 0, 32)
		mergeButton.Position = UDim2.new(1, -72, 0.5, -16)
		mergeButton.Text = "MERGE"
		mergeButton.TextSize = 13
		mergeButton.Parent = entry
		styleButton(mergeButton)

		onActivated(mergeButton, function()
			fireAction("MERGE_MONSTERS", { instanceIds = { mergeGroupIds[1], mergeGroupIds[2], mergeGroupIds[3] } })
		end)
	end

	return entry
end

local function rebuildWarehouseList()
	for _, child in warehouseList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local warehouseState = shared.WarehouseClient
	if not warehouseState then
		return
	end

	local groups = computeMergeGroups(warehouseState.monsters)
	local order = 0

	for instanceId, monster in warehouseState.monsters do
		local key = getMonsterGroupKey(monster)
		local entry = createMonsterEntry(instanceId, monster, groups[key])
		entry.LayoutOrder = order
		entry.Parent = warehouseList
		order += 1
	end
end

--============================================================
-- Roll Panel
--============================================================

local rollPanel = Instance.new("Frame")
rollPanel.Name = "RollPanel"
rollPanel.Position = UDim2.new(0.5, -200, 0.5, -200)
rollPanel.Size = UDim2.new(0, 400, 0, 400)
rollPanel.BackgroundColor3 = PANEL_BG
rollPanel.BorderSizePixel = 0
rollPanel.Visible = false
rollPanel.Parent = screenGui
addCorner(rollPanel, 12)
panels.RollPanel = rollPanel

local rollTitle = Instance.new("TextLabel")
rollTitle.Name = "Title"
rollTitle.Size = UDim2.new(1, -40, 0, 36)
rollTitle.Position = UDim2.new(0, 16, 0, 12)
rollTitle.BackgroundTransparency = 1
rollTitle.Font = Enum.Font.GothamBold
rollTitle.TextSize = 20
rollTitle.TextColor3 = WHITE
rollTitle.TextXAlignment = Enum.TextXAlignment.Left
rollTitle.Text = "EGG MACHINE"
rollTitle.Parent = rollPanel

createCloseButton(rollPanel, "RollPanel")

local eggVisual = Instance.new("Frame")
eggVisual.Name = "EggVisual"
eggVisual.AnchorPoint = Vector2.new(0.5, 0)
eggVisual.Position = UDim2.new(0.5, 0, 0, 56)
eggVisual.Size = UDim2.new(0, 120, 0, 120)
eggVisual.BackgroundColor3 = Constants.EMOTION_COLORS.Joy
eggVisual.BorderSizePixel = 0
eggVisual.Parent = rollPanel
addCorner(eggVisual, 60)

task.spawn(function()
	local colorCycle = {
		Constants.EMOTION_COLORS.Rage,
		Constants.EMOTION_COLORS.Void,
		Constants.EMOTION_COLORS.Joy,
		Constants.EMOTION_COLORS.Dread,
		Constants.EMOTION_COLORS.Sadness,
		Constants.EMOTION_COLORS.Nostalgia,
	}
	local index = 1
	while true do
		index = (index % #colorCycle) + 1
		local tween =
			TweenService:Create(eggVisual, TweenInfo.new(2, Enum.EasingStyle.Sine), { BackgroundColor3 = colorCycle[index] })
		tween:Play()
		tween.Completed:Wait()
	end
end)

local rollCostLabel = Instance.new("TextLabel")
rollCostLabel.Name = "RollCost"
rollCostLabel.Position = UDim2.new(0, 16, 0, 188)
rollCostLabel.Size = UDim2.new(1, -32, 0, 24)
rollCostLabel.BackgroundTransparency = 1
rollCostLabel.Font = Enum.Font.Gotham
rollCostLabel.TextSize = 16
rollCostLabel.TextColor3 = WHITE
rollCostLabel.Text = "Cost: 500 coins"
rollCostLabel.Parent = rollPanel

local function createRollButton(label: string, count: number, xPos: number)
	local button = Instance.new("TextButton")
	button.Name = "Roll" .. count
	button.Size = UDim2.new(0, 110, 0, 40)
	button.Position = UDim2.new(0, xPos, 0, 224)
	button.Text = label
	button.TextSize = 15
	button.Parent = rollPanel
	styleButton(button)

	onActivated(button, function()
		fireAction("ROLL_EGG", { count = count })
	end)
end

createRollButton("ROLL x1", 1, 20)
createRollButton("ROLL x5", 5, 145)
createRollButton("ROLL x10", 10, 270)

local probabilityLabel = Instance.new("TextLabel")
probabilityLabel.Name = "ProbabilityDisplay"
probabilityLabel.Position = UDim2.new(0, 16, 0, 280)
probabilityLabel.Size = UDim2.new(1, -32, 0, 90)
probabilityLabel.BackgroundTransparency = 1
probabilityLabel.Font = Enum.Font.Gotham
probabilityLabel.TextSize = 12
probabilityLabel.TextColor3 = GRAY
probabilityLabel.TextWrapped = true
probabilityLabel.TextYAlignment = Enum.TextYAlignment.Top
probabilityLabel.Text = ""
probabilityLabel.Parent = rollPanel

-- Mirrors Economy.GetRollCost server-side; Economy.lua is a ServerScriptService
-- module and isn't client-reachable, so this reads the same shared threshold table
-- the server uses rather than inventing a separate cost rule. lifetimeRolls is
-- seeded from PLAYER_DATA_LOADED and incremented locally on each observed roll.
local lifetimeRolls = 0

playerDataLoadedRemote.OnClientEvent:Connect(function(data: any)
	if typeof(data) == "table" and typeof(data.lifetimeRolls) == "number" then
		lifetimeRolls = data.lifetimeRolls
	end
end)

eggResultRemote.OnClientEvent:Connect(function(result: any)
	if typeof(result) == "table" and result.success and not result.isPremium and not result.isCrate then
		lifetimeRolls += 1
	end
end)

local function getRollCost(): number
	for _, threshold in Constants.ROLL_COST_THRESHOLDS do
		if lifetimeRolls < threshold.maxRolls then
			return math.max(threshold.cost, 500)
		end
	end
	return 500
end

--============================================================
-- Hall Panel
--============================================================

local hallPanel = Instance.new("Frame")
hallPanel.Name = "HallPanel"
hallPanel.Position = UDim2.new(0, 16, 0.5, -200)
hallPanel.Size = UDim2.new(0, 300, 0, 400)
hallPanel.BackgroundColor3 = PANEL_BG
hallPanel.BorderSizePixel = 0
hallPanel.Visible = false
hallPanel.Parent = screenGui
addCorner(hallPanel, 12)
panels.HallPanel = hallPanel

local hallTitle = Instance.new("TextLabel")
hallTitle.Name = "Title"
hallTitle.Size = UDim2.new(1, -40, 0, 36)
hallTitle.Position = UDim2.new(0, 16, 0, 12)
hallTitle.BackgroundTransparency = 1
hallTitle.Font = Enum.Font.GothamBold
hallTitle.TextSize = 20
hallTitle.TextColor3 = WHITE
hallTitle.TextXAlignment = Enum.TextXAlignment.Left
hallTitle.Text = "MONSTER HALL"
hallTitle.Parent = hallPanel

createCloseButton(hallPanel, "HallPanel")

local hallGrid = Instance.new("ScrollingFrame")
hallGrid.Name = "SlotGrid"
hallGrid.Position = UDim2.new(0, 12, 0, 48)
hallGrid.Size = UDim2.new(1, -24, 1, -100)
hallGrid.BackgroundTransparency = 1
hallGrid.BorderSizePixel = 0
hallGrid.ScrollBarThickness = 6
hallGrid.CanvasSize = UDim2.new(0, 0, 0, 0)
hallGrid.Parent = hallPanel

local hallGridLayout = Instance.new("UIGridLayout")
hallGridLayout.CellSize = UDim2.new(0, 80, 0, 80)
hallGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
hallGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
hallGridLayout.Parent = hallGrid

hallGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	hallGrid.CanvasSize = UDim2.new(0, 0, 0, hallGridLayout.AbsoluteContentSize.Y + 8)
end)

local upgradeHallButton = Instance.new("TextButton")
upgradeHallButton.Name = "UpgradeHallButton"
upgradeHallButton.AnchorPoint = Vector2.new(0.5, 1)
upgradeHallButton.Position = UDim2.new(0.5, 0, 1, -12)
upgradeHallButton.Size = UDim2.new(1, -24, 0, 36)
upgradeHallButton.Text = "UPGRADE HALL"
upgradeHallButton.TextSize = 14
upgradeHallButton.Parent = hallPanel
styleButton(upgradeHallButton)

onActivated(upgradeHallButton, function()
	if upgradeHallButton:GetAttribute("Disabled") then
		return
	end
	fireAction("UPGRADE_HALL", nil)
end)

local hallSlots: { any } = {}
local currentHallTier = 1

local function inferHallTier(slotCount: number): number
	for tier, count in Constants.HALL_SLOT_COUNTS do
		if count == slotCount then
			return tier
		end
	end
	return 1
end

local function createHallSlotFrame(slot: any): Frame
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = "Slot_" .. slot.slotIndex
	slotFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
	slotFrame.BorderSizePixel = 0
	addCorner(slotFrame, 6)

	local stroke = addStroke(slotFrame, Color3.fromRGB(60, 60, 80))
	stroke.Thickness = 2

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = WHITE
	label.TextWrapped = true
	label.Text = slot.monster and slot.monster.name or "EMPTY"
	label.Parent = slotFrame

	local clickCatcher = Instance.new("TextButton")
	clickCatcher.Name = "ClickCatcher"
	clickCatcher.BackgroundTransparency = 1
	clickCatcher.Size = UDim2.fromScale(1, 1)
	clickCatcher.Text = ""
	clickCatcher.Parent = slotFrame

	clickCatcher.MouseButton1Click:Connect(function()
		if slot.monster then
			fireAction("UNSLOT_MONSTER", { slotIndex = slot.slotIndex })
		else
			UIManagerAPI.selectedSlot = slot.slotIndex
		end
	end)

	return slotFrame
end

local function rebuildHallGrid()
	for _, child in hallGrid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, slot in hallSlots do
		local slotFrame = createHallSlotFrame(slot)
		slotFrame.LayoutOrder = slot.slotIndex
		slotFrame.Parent = hallGrid
	end
end

updateHallRemote.OnClientEvent:Connect(function(slots: any)
	hallSlots = slots or {}
	currentHallTier = inferHallTier(#hallSlots)
	shared.HallClient = { slots = hallSlots, hallTier = currentHallTier }
	rebuildHallGrid()
end)

--============================================================
-- Merge notification (transient, not a toggle panel)
--============================================================

local function showMergeNotification(monsterName: string, stars: number?, color: Color3)
	local notif = Instance.new("Frame")
	notif.Name = "MergeNotification"
	notif.AnchorPoint = Vector2.new(0.5, 0.5)
	notif.Position = UDim2.new(0.5, 0, 0.5, 0)
	notif.Size = UDim2.new(0, 360, 0, 100)
	notif.BackgroundColor3 = color
	notif.BackgroundTransparency = 0.1
	notif.BorderSizePixel = 0
	notif.Parent = screenGui
	addCorner(notif, 12)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.8
	scale.Parent = notif

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 26
	label.TextColor3 = WHITE
	label.TextWrapped = true
	local starsText = (stars and stars > 0) and (" " .. string.rep("★", stars)) or ""
	label.Text = `EVOLVED! {monsterName}{starsText}`
	label.Parent = notif

	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.delay(2.5, function()
		local outTween = TweenService:Create(scale, TweenInfo.new(0.5), { Scale = 0.8 })
		local fadeTween = TweenService:Create(notif, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		outTween:Play()
		fadeTween:Play()
		fadeTween.Completed:Connect(function()
			notif:Destroy()
		end)
	end)
end

mergeMonstersRemote.OnClientEvent:Connect(function(result: any)
	if typeof(result) ~= "table" or not result.success then
		return
	end

	local color = WHITE
	local warehouseState = shared.WarehouseClient
	local monster = warehouseState and warehouseState.monsters and warehouseState.monsters[result.newInstanceId]
	if monster and monster.emotion then
		color = Constants.EMOTION_COLORS[monster.emotion] or WHITE
	end

	showMergeNotification(result.resultMonsterName, result.resultStars, color)
end)

--============================================================
-- Shared-state polling loop (every 0.1s)
--============================================================

local lastCoinFormatted: string? = nil
local lastWarehouseCountPolled = -1

task.spawn(function()
	while true do
		task.wait(0.1)

		-- Coin counter
		local coinState = shared.CoinDisplay
		if coinState then
			if coinState.formatted ~= lastCoinFormatted then
				lastCoinFormatted = coinState.formatted
				coinAmountLabel.Text = coinState.formatted
				pulseCoin()
			end
			earnRateLabel.Text = `+{NumberFormatter.Format(coinState.earnRate or 0)}/sec`
		end

		-- Bag indicator
		local bagState = shared.BagClient
		if bagState then
			bagCountLabel.Text = `{NumberFormatter.Format(bagState.count or 0)}/{NumberFormatter.Format(bagState.capacity or 0)}`

			local fraction = 0
			if bagState.capacity and bagState.capacity > 0 and bagState.capacity ~= math.huge then
				fraction = math.clamp((bagState.count or 0) / bagState.capacity, 0, 1)
			end
			bagBarFill.Size = UDim2.new(fraction, 0, 1, 0)

			if bagState.isFull then
				if not bagPulseTween then
					bagBarFill.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
					bagPulseTween = TweenService:Create(
						bagBarFill,
						TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{ BackgroundColor3 = Color3.fromRGB(110, 20, 20) }
					)
					bagPulseTween:Play()
				end
			else
				if bagPulseTween then
					bagPulseTween:Cancel()
					bagPulseTween = nil
				end
				bagBarFill.BackgroundColor3 = getBagFillColor(fraction)
			end
		end

		-- Town level
		local townState = shared.TownClient
		if townState then
			townLevelLabel.Text = `TOWN LV.{townState.townLevel or 1}`

			local xpFraction = 0
			if townState.xpRequired == math.huge then
				xpFraction = 1
			elseif townState.xpRequired and townState.xpRequired > 0 then
				xpFraction = math.clamp((townState.townXP or 0) / townState.xpRequired, 0, 1)
			end

			if math.abs(xpBarFill.Size.X.Scale - xpFraction) > 0.001 then
				TweenService:Create(xpBarFill, TweenInfo.new(0.3), { Size = UDim2.new(xpFraction, 0, 1, 0) }):Play()
			end

			if townState.rollProbabilities then
				probabilityLabel.Text = RollTable.FormatProbabilities(townState.rollProbabilities)
			end
		end

		-- Boost warning banner
		local warningState = shared.BoostWarning
		if warningState and warningState.isActive then
			local secondsLeft = math.max(math.floor(warningState.endTime - os.time()), 0)
			local emotionText = warningState.emotion == "Mystery" and "???" or string.upper(warningState.emotion or "")
			warningLabel.Text = `INCOMING: {emotionText} SURGE IN {secondsLeft}s`

			local color = warningState.emotion == "Mystery" and Color3.fromHSV(os.clock() % 1, 1, 1)
				or (Constants.EMOTION_COLORS[warningState.emotion] or WHITE)
			warningBanner.BackgroundColor3 = color

			if not warningBanner.Visible then
				warningBanner.Visible = true
				warningBanner.Position = UDim2.new(0.5, 0, 0, BOOST_WARNING_HIDDEN_Y)
				TweenService:Create(warningBanner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.new(0.5, 0, 0, BOOST_WARNING_SHOWN_Y),
				}):Play()
			end
		elseif warningBanner.Visible then
			local tween =
				TweenService:Create(warningBanner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, 0, BOOST_WARNING_HIDDEN_Y),
				})
			tween:Play()
			tween.Completed:Connect(function()
				warningBanner.Visible = false
			end)
		end

		-- Boost HUD
		local boostState = shared.BoostClient
		if boostState and boostState.isActive then
			local color
			if boostState.emotions then
				color = Constants.EMOTION_COLORS[boostState.emotions[1]] or WHITE
			elseif boostState.emotion == "All" then
				color = VOID_STORM_COLOR
			elseif boostState.emotion == "Mystery" then
				color = Color3.fromHSV(os.clock() % 1, 1, 1)
			else
				color = Constants.EMOTION_COLORS[boostState.emotion] or WHITE
			end
			boostHud.BackgroundColor3 = color

			local text
			if boostState.emotions then
				text = `{string.upper(boostState.emotions[1])} + {string.upper(boostState.emotions[2])} SURGE — {boostState.multiplier}x`
			elseif boostState.emotion == "Mystery" then
				text = `??? SURGE — {boostState.multiplier}x`
			elseif boostState.emotion == "All" then
				text = `VOID STORM — {boostState.multiplier}x ALL`
			else
				text = `{string.upper(boostState.emotion or "")} SURGE — {boostState.multiplier}x`
			end
			boostEmotionLabel.Text = text

			local secondsLeft = math.max(math.floor(boostState.endTime - os.time()), 0)
			boostTimerLabel.Text = string.format("%02d:%02d", math.floor(secondsLeft / 60), secondsLeft % 60)

			if not boostHud.Visible then
				boostHud.Visible = true
				boostHud.Position = UDim2.new(0.5, 0, 1, BOOST_HUD_HIDDEN_Y)
				TweenService:Create(boostHud, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.new(0.5, 0, 1, BOOST_HUD_SHOWN_Y),
				}):Play()
			end
		elseif boostHud.Visible then
			local tween = TweenService:Create(boostHud, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 1, BOOST_HUD_HIDDEN_Y),
			})
			tween:Play()
			tween.Completed:Connect(function()
				boostHud.Visible = false
			end)
		end

		-- Warehouse
		local warehouseState = shared.WarehouseClient
		if warehouseState then
			if warehouseState.count ~= lastWarehouseCountPolled then
				lastWarehouseCountPolled = warehouseState.count
				rebuildWarehouseList()
			end

			warehouseCapacityLabel.Text = `{warehouseState.count}/{warehouseState.capacity}`
			local fraction = warehouseState.capacity > 0
				and math.clamp(warehouseState.count / warehouseState.capacity, 0, 1)
				or 0
			warehouseCapacityFill.Size = UDim2.new(fraction, 0, 1, 0)

			if warehousePanel.Visible then
				for _, entry in warehouseList:GetChildren() do
					if entry:IsA("Frame") then
						local slotButton = entry:FindFirstChild("SLOT")
						if slotButton and slotButton:IsA("TextButton") then
							slotButton.TextTransparency = UIManagerAPI.selectedSlot and 0 or 0.5
						end
					end
				end
			end
		end

		-- Roll cost
		rollCostLabel.Text = `Cost: {NumberFormatter.Format(getRollCost())} coins`

		-- Hall upgrade button + selected-slot highlight
		local nextTierCost = Constants.HALL_UPGRADE_COSTS[currentHallTier + 1]
		local coinsAvailable = (shared.CoinDisplay and shared.CoinDisplay.displayCoins) or 0

		if not nextTierCost then
			upgradeHallButton.Text = "MAX TIER"
			upgradeHallButton:SetAttribute("Disabled", true)
		else
			upgradeHallButton.Text = `UPGRADE HALL - {NumberFormatter.Format(nextTierCost)}`
			upgradeHallButton:SetAttribute("Disabled", coinsAvailable < nextTierCost)
		end

		for _, slotFrame in hallGrid:GetChildren() do
			if slotFrame:IsA("Frame") then
				local stroke = slotFrame:FindFirstChildOfClass("UIStroke")
				if stroke then
					local slotIndexStr = slotFrame.Name:match("Slot_(%d+)")
					local slotIndex = slotIndexStr and tonumber(slotIndexStr)
					if slotIndex and slotIndex == UIManagerAPI.selectedSlot then
						stroke.Color = GOLD
						stroke.Thickness = 3
					else
						stroke.Color = Color3.fromRGB(60, 60, 80)
						stroke.Thickness = 2
					end
				end
			end
		end
	end
end)
