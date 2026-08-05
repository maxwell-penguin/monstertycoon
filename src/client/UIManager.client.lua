local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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
local sessionRewardRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SESSION_REWARD) :: RemoteEvent

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
		if shared.SoundManager then
			shared.SoundManager.PlaySound("panelOpen")
		end
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
		if shared.SoundManager then
			shared.SoundManager.PlaySound("buttonClick")
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

local BRIGHT_GOLD = Color3.fromRGB(255, 255, 180)

-- When earn rate rises (new monster slotted, boost starts) the amount label
-- briefly flares bright gold before fading back to normal gold.
local function flashCoinGold()
	coinAmountLabel.TextColor3 = BRIGHT_GOLD
	TweenService:Create(coinAmountLabel, TweenInfo.new(0.3), { TextColor3 = GOLD }):Play()
end

local lastEarnRate = 0

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
			if panel.Visible then
				UIManagerAPI.HidePanel(panelName)
			else
				UIManagerAPI.ShowPanel(panelName)
			end
		end
	end)
end

createToggleButton("WAREHOUSE", 0, "WarehousePanel")
createToggleButton("ROLL", 1, "RollPanel")
createToggleButton("HALL", 2, "HallPanel")
createToggleButton("SHOP", 3, "ShopPanel")
createToggleButton("EVENT", 4, "EventStationPanel")

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

-- Slow continuous rotation drives eggVisual.Rotation (a native GuiObject
-- property) directly every Heartbeat tick -- no UIRotation instance. The
-- NumberValue tracks the current angle so the jiggle tween below can pause
-- the loop and hand control back without a visible snap.
local eggRotationValue = Instance.new("NumberValue")
eggRotationValue.Value = 0
eggRotationValue.Parent = eggVisual

local EGG_ROTATION_SPEED = 45 -- degrees/second (360 over 8s, matches old tween duration)
local eggJiggling = false

task.spawn(function()
	while true do
		local dt = RunService.Heartbeat:Wait()
		if not eggJiggling then
			eggRotationValue.Value = (eggRotationValue.Value + EGG_ROTATION_SPEED * dt) % 360
			eggVisual.Rotation = eggRotationValue.Value
		end
	end
end)

-- Every 3 seconds, a quick ±5 degree jiggle chained over 0.3s total, tweening
-- eggVisual.Rotation itself. The continuous loop above pauses for the duration
-- so the two don't fight over the same property, then resumes from the
-- jiggle's landing angle (always the pre-jiggle base, since the last leg
-- targets +0).
task.spawn(function()
	while true do
		task.wait(3)

		eggJiggling = true
		local baseRotation = eggVisual.Rotation

		for _, offset in { 5, -5, 0 } do
			local jiggleTween = TweenService:Create(
				eggVisual,
				TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Rotation = baseRotation + offset }
			)
			jiggleTween:Play()
			jiggleTween.Completed:Wait()
		end

		eggRotationValue.Value = eggVisual.Rotation % 360
		eggJiggling = false
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

-- eventTokens is also carried on this same full-snapshot payload; EventRemotes
-- re-fires PLAYER_DATA_LOADED after a purchase so this stays current.
local eventTokens = 0

playerDataLoadedRemote.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end

	if typeof(data.lifetimeRolls) == "number" then
		lifetimeRolls = data.lifetimeRolls
	end

	if typeof(data.eventTokens) == "number" then
		eventTokens = data.eventTokens
	end
end)

sessionRewardRemote.OnClientEvent:Connect(function(reward: any)
	if typeof(reward) == "table" and reward.type == "eventTokens" and typeof(reward.amount) == "number" then
		eventTokens += reward.amount
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

local function dimColor(color: Color3, factor: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), factor)
end

local EMPTY_SLOT_BG = Color3.fromRGB(26, 26, 38)
local EMPTY_SLOT_CORNER_DOT_COLOR = Color3.fromRGB(150, 150, 160)
local EMPTY_SLOT_CORNER_POSITIONS = {
	UDim2.new(0, 2, 0, 2),
	UDim2.new(1, -6, 0, 2),
	UDim2.new(0, 2, 1, -6),
	UDim2.new(1, -6, 1, -6),
}

local function createHallSlotFrame(slot: any): Frame
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = "Slot_" .. slot.slotIndex
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

	if slot.monster then
		local emotionColor = Constants.EMOTION_COLORS[slot.monster.emotion] or EMPTY_SLOT_BG
		slotFrame.BackgroundColor3 = dimColor(emotionColor, 0.6)

		local dot = Instance.new("Frame")
		dot.Name = "EmotionDot"
		dot.AnchorPoint = Vector2.new(1, 0)
		dot.Position = UDim2.new(1, -2, 0, 2)
		dot.Size = UDim2.new(0, 8, 0, 8)
		dot.BackgroundColor3 = emotionColor
		dot.BorderSizePixel = 0
		dot.Parent = slotFrame
		addCorner(dot, 4)

		if slot.monster.rarity == "Mythic" then
			slotFrame.BackgroundTransparency = 0.1
			TweenService:Create(
				slotFrame,
				TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ BackgroundTransparency = 0.3 }
			):Play()
		end
	else
		slotFrame.BackgroundColor3 = EMPTY_SLOT_BG

		-- Roblox UIStroke has no native dashed style; simulate one with 4 small
		-- corner-dot Frames instead.
		for _, cornerPosition in EMPTY_SLOT_CORNER_POSITIONS do
			local cornerDot = Instance.new("Frame")
			cornerDot.Name = "CornerDot"
			cornerDot.Size = UDim2.new(0, 4, 0, 4)
			cornerDot.Position = cornerPosition
			cornerDot.BackgroundColor3 = EMPTY_SLOT_CORNER_DOT_COLOR
			cornerDot.BorderSizePixel = 0
			cornerDot.Parent = slotFrame
		end
	end

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
-- Shop Panel
--============================================================

type ShopItem = {
	name: string,
	desc: string,
	icon: string,
	priceText: string,
	kind: "coins" | "product" | "gamepass",
	key: string?,
	targetTier: number?,
}

local SHOP_TAB_ORDER = { "EGGS", "BOOSTS", "UPGRADES", "PASSES", "VOID PASS" }
local SHOP_TAB_COLORS: { [string]: Color3 } = {
	EGGS = Color3.fromRGB(200, 150, 50),
	BOOSTS = Color3.fromRGB(100, 200, 100),
	UPGRADES = Color3.fromRGB(80, 150, 220),
	PASSES = Color3.fromRGB(150, 80, 220),
	["VOID PASS"] = Color3.fromRGB(200, 100, 200),
}

local SHOP_ITEMS: { [string]: { ShopItem } } = {
	EGGS = {
		{
			name = "Rare Egg",
			desc = "Guaranteed Rare or better",
			icon = "🥚",
			priceText = "149 R$",
			kind = "product",
			key = "RareEgg",
		},
		{
			name = "Epic Egg",
			desc = "Guaranteed Epic or better",
			icon = "🥚",
			priceText = "349 R$",
			kind = "product",
			key = "EpicEgg",
		},
		{
			name = "Legendary Egg",
			desc = "Guaranteed Legendary or better",
			icon = "🥚",
			priceText = "699 R$",
			kind = "product",
			key = "LegendaryEgg",
		},
		{
			name = "Mythic Egg",
			desc = "Guaranteed Mythic monster",
			icon = "🥚",
			priceText = "1999 R$",
			kind = "product",
			key = "MythicEgg",
		},
		{
			name = "Starter Pack",
			desc = "Infinite Bag + Luck Boost + Rare Egg",
			icon = "🎁",
			priceText = "299 R$",
			kind = "product",
			key = "StarterPack",
		},
		{
			name = "Void Pack",
			desc = "Epic Egg + Luck Boost + Speed Boots",
			icon = "🎁",
			priceText = "599 R$",
			kind = "product",
			key = "VoidPack",
		},
	},
	BOOSTS = {
		{
			name = "Luck Boost",
			desc = "+50% egg odds for 15 min",
			icon = "🍀",
			priceText = "99 R$",
			kind = "product",
			key = "LuckBoost",
		},
		{
			name = "Merge Boost",
			desc = "Next 5 merges free",
			icon = "⚡",
			priceText = "59 R$",
			kind = "product",
			key = "MergeBoost",
		},
		{
			name = "Server Boost",
			desc = "Whole server 1.5x earnings 10 min",
			icon = "🌐",
			priceText = "199 R$",
			kind = "product",
			key = "ServerBoost",
		},
		{
			name = "2x Income",
			desc = "Permanent 2x all earnings",
			icon = "💰",
			priceText = "GAMEPASS",
			kind = "gamepass",
			key = "Income2x",
		},
		{
			name = "3x Income",
			desc = "Permanent 3x all earnings",
			icon = "💰",
			priceText = "GAMEPASS",
			kind = "gamepass",
			key = "Income3x",
		},
		{
			name = "5x Income",
			desc = "Permanent 5x all earnings",
			icon = "💰",
			priceText = "GAMEPASS",
			kind = "gamepass",
			key = "Income5x",
		},
		{
			name = "7x Income",
			desc = "Permanent 7x all earnings",
			icon = "💰",
			priceText = "GAMEPASS",
			kind = "gamepass",
			key = "Income7x",
		},
		{
			name = "10x Income",
			desc = "Permanent 10x all earnings",
			icon = "💰",
			priceText = "GAMEPASS",
			kind = "gamepass",
			key = "Income10x",
		},
	},
	UPGRADES = {
		{
			name = "Satchel",
			desc = "25 vial bag capacity",
			icon = "👜",
			priceText = `{NumberFormatter.Format(500)} coins`,
			kind = "coins",
			targetTier = 2,
		},
		{
			name = "Backpack",
			desc = "50 vial bag capacity",
			icon = "👜",
			priceText = `{NumberFormatter.Format(3000)} coins`,
			kind = "coins",
			targetTier = 3,
		},
		{
			name = "Vault Pack",
			desc = "100 vial bag capacity",
			icon = "👜",
			priceText = `{NumberFormatter.Format(15000)} coins`,
			kind = "coins",
			targetTier = 4,
		},
		{
			name = "Void Carrier",
			desc = "250 vial bag capacity",
			icon = "👜",
			priceText = "199 R$",
			kind = "gamepass",
			key = "VoidCarrier",
		},
		{
			name = "Infinite Bag",
			desc = "Unlimited vial carry",
			icon = "👜",
			priceText = "499 R$",
			kind = "gamepass",
			key = "InfiniteBag",
		},
		{
			name = "Speed Boots",
			desc = "+30% walk speed permanently",
			icon = "👟",
			priceText = "149 R$",
			kind = "gamepass",
			key = "SpeedBoots",
		},
		{
			name = "Extra Plot",
			desc = "Second monster plot slot",
			icon = "🏭",
			priceText = "399 R$",
			kind = "gamepass",
			key = "ExtraPlot",
		},
		{
			name = "Boost Insider",
			desc = "See next boost 15s early",
			icon = "👁",
			priceText = "299 R$",
			kind = "gamepass",
			key = "BoostInsider",
		},
	},
	PASSES = {
		{
			name = "Infinite Bag",
			desc = "Unlimited vial carry forever",
			icon = "👜",
			priceText = "499 R$",
			kind = "gamepass",
			key = "InfiniteBag",
		},
		{
			name = "Speed Boots",
			desc = "+30% walk speed forever",
			icon = "👟",
			priceText = "149 R$",
			kind = "gamepass",
			key = "SpeedBoots",
		},
		{
			name = "Boost Insider",
			desc = "Preview next boost early",
			icon = "👁",
			priceText = "299 R$",
			kind = "gamepass",
			key = "BoostInsider",
		},
		{
			name = "Extra Plot",
			desc = "Second monster plot",
			icon = "🏭",
			priceText = "399 R$",
			kind = "gamepass",
			key = "ExtraPlot",
		},
		{
			name = "Auto Merge",
			desc = "Warehouse auto-merges monsters",
			icon = "⚙",
			priceText = "299 R$",
			kind = "gamepass",
			key = "AutoMerge",
		},
	},
}

local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.Position = UDim2.new(0.5, -320, 0.5, -280)
shopPanel.Size = UDim2.new(0, 640, 0, 560)
shopPanel.BackgroundColor3 = Color3.fromRGB(12, 9, 22)
shopPanel.BackgroundTransparency = 0
shopPanel.BorderSizePixel = 0
-- Header/tab bar below sit flush against the panel edges with square corners
-- of their own; without this they'd visibly poke out past the panel's own
-- rounded UICorner instead of being clipped to match it.
shopPanel.ClipsDescendants = true
shopPanel.Visible = false
shopPanel.Parent = screenGui
addCorner(shopPanel, 16)
local shopStroke = addStroke(shopPanel, Color3.fromRGB(80, 50, 140))
shopStroke.Thickness = 1
panels.ShopPanel = shopPanel

-- Header
local shopHeader = Instance.new("Frame")
shopHeader.Name = "Header"
shopHeader.Size = UDim2.new(1, 0, 0, 50)
shopHeader.BackgroundColor3 = Color3.fromRGB(18, 14, 32)
shopHeader.BorderSizePixel = 0
shopHeader.Parent = shopPanel

local shopTitle = Instance.new("TextLabel")
shopTitle.Name = "Title"
shopTitle.Size = UDim2.new(1, -80, 1, 0)
shopTitle.BackgroundTransparency = 1
shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextSize = 20
shopTitle.TextColor3 = WHITE
shopTitle.Text = "VOID SHOP"
shopTitle.Parent = shopHeader

createCloseButton(shopHeader, "ShopPanel")

-- Tab bar
local shopTabBar = Instance.new("Frame")
shopTabBar.Name = "TabBar"
shopTabBar.Size = UDim2.new(1, 0, 0, 44)
shopTabBar.Position = UDim2.new(0, 0, 0, 50)
shopTabBar.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
shopTabBar.BorderSizePixel = 0
shopTabBar.Parent = shopPanel

local shopTabButtons: { [string]: TextButton } = {}

for i, tabName in SHOP_TAB_ORDER do
	local tabButton = Instance.new("TextButton")
	tabButton.Name = "Tab_" .. tabName:gsub("%s", "")
	tabButton.Size = UDim2.new(1 / #SHOP_TAB_ORDER, 0, 1, 0)
	tabButton.Position = UDim2.new((i - 1) / #SHOP_TAB_ORDER, 0, 0, 0)
	tabButton.BackgroundColor3 = Color3.fromRGB(30, 22, 50)
	tabButton.BackgroundTransparency = 1
	tabButton.BorderSizePixel = 0
	tabButton.AutoButtonColor = false
	tabButton.Font = Enum.Font.GothamBold
	tabButton.TextSize = 13
	tabButton.TextColor3 = SHOP_TAB_COLORS[tabName]
	tabButton.Text = tabName
	tabButton.Parent = shopTabBar

	local bottomBorder = Instance.new("Frame")
	bottomBorder.Name = "BottomBorder"
	bottomBorder.AnchorPoint = Vector2.new(0, 1)
	bottomBorder.Position = UDim2.new(0, 0, 1, 0)
	bottomBorder.Size = UDim2.new(1, 0, 0, 2)
	bottomBorder.BackgroundColor3 = SHOP_TAB_COLORS[tabName]
	bottomBorder.BorderSizePixel = 0
	bottomBorder.Visible = false
	bottomBorder.Parent = tabButton

	shopTabButtons[tabName] = tabButton
end

local function updateShopTabVisuals(active: string)
	for tabName, button in shopTabButtons do
		local isActive = tabName == active
		button.BackgroundTransparency = isActive and 0 or 1
		local border = button:FindFirstChild("BottomBorder")
		if border then
			border.Visible = isActive
		end
	end
end

-- Grid content (EGGS/BOOSTS/UPGRADES/PASSES)
local shopContent = Instance.new("ScrollingFrame")
shopContent.Name = "Content"
shopContent.Size = UDim2.new(1, -20, 1, -114)
shopContent.Position = UDim2.new(0, 10, 0, 104)
shopContent.BackgroundTransparency = 1
shopContent.BorderSizePixel = 0
shopContent.ScrollBarThickness = 6
shopContent.CanvasSize = UDim2.new(0, 0, 0, 0)
shopContent.Parent = shopPanel

-- CanvasGroup so the whole grid can fade as one unit on tab switch (Group-
-- Transparency composites all descendants together); AutomaticSize keeps it
-- exactly as tall as its content so nothing gets clipped by the CanvasGroup
-- itself -- the outer ScrollingFrame above handles the real viewport/scroll.
local shopCardCanvas = Instance.new("CanvasGroup")
shopCardCanvas.Name = "CardCanvas"
shopCardCanvas.Size = UDim2.new(1, 0, 0, 0)
shopCardCanvas.AutomaticSize = Enum.AutomaticSize.Y
shopCardCanvas.BackgroundTransparency = 1
shopCardCanvas.BorderSizePixel = 0
shopCardCanvas.Parent = shopContent

local shopGridLayout = Instance.new("UIGridLayout")
shopGridLayout.CellSize = UDim2.new(0, 190, 0, 120)
shopGridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
shopGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopGridLayout.Parent = shopCardCanvas

shopGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	shopContent.CanvasSize = UDim2.new(0, 0, 0, shopGridLayout.AbsoluteContentSize.Y + 8)
end)

local OWNED_COLOR = Color3.fromRGB(60, 60, 60)
local ROBUX_TAG_COLOR = Color3.fromRGB(0, 180, 80)
local COIN_TAG_COLOR = Color3.fromRGB(180, 140, 0)

local function isShopItemOwned(item: ShopItem): boolean
	if item.kind ~= "gamepass" or not item.key then
		return false
	end
	local monetization = shared.MonetizationClient
	return monetization ~= nil and monetization.ownedGamepasses[item.key] == true
end

local function buyShopItem(item: ShopItem)
	if item.kind == "coins" then
		fireAction("UPGRADE_BAG", { targetTier = item.targetTier })
	elseif item.kind == "product" then
		shared.MonetizationClient.PromptPurchase("product", Constants.PRODUCT_IDS[item.key])
	elseif item.kind == "gamepass" then
		shared.MonetizationClient.PromptPurchase("gamepass", Constants.GAMEPASS_IDS[item.key])
	end
end

local function createShopItemCard(item: ShopItem, tabName: string, tabColor: Color3): (Frame, () -> ())
	local card = Instance.new("Frame")
	card.Name = "Card_" .. item.name:gsub("%s", "")
	card.Size = UDim2.new(0, 190, 0, 120)
	card.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
	card.BorderSizePixel = 0
	card:SetAttribute("Tab", tabName)
	addCorner(card, 10)
	local cardStroke = addStroke(card, Color3.fromRGB(60, 40, 100))
	cardStroke.Thickness = 0.5

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 32, 0, 32)
	icon.Position = UDim2.new(0, 8, 0, 8)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 24
	icon.Text = item.icon
	icon.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -48, 0, 18)
	nameLabel.Position = UDim2.new(0, 44, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = WHITE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = item.name
	nameLabel.Parent = card

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescriptionLabel"
	descLabel.Size = UDim2.new(1, -16, 0, 40)
	descLabel.Position = UDim2.new(0, 8, 0, 44)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 11
	descLabel.TextColor3 = Color3.fromRGB(160, 140, 200)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.Text = item.desc
	descLabel.Parent = card

	local priceTag = Instance.new("Frame")
	priceTag.Name = "PriceTag"
	priceTag.AnchorPoint = Vector2.new(1, 0)
	priceTag.Position = UDim2.new(1, -8, 0, 8)
	priceTag.Size = UDim2.new(0, 74, 0, 16)
	priceTag.BorderSizePixel = 0
	addCorner(priceTag, 4)
	priceTag.Parent = card

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.fromScale(1, 1)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextSize = 11
	priceLabel.TextColor3 = WHITE
	priceLabel.Parent = priceTag

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.Size = UDim2.new(1, -16, 0, 28)
	buyButton.Position = UDim2.new(0, 8, 1, -36)
	buyButton.AutoButtonColor = false
	buyButton.BorderSizePixel = 0
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 12
	buyButton.TextColor3 = WHITE
	addCorner(buyButton, 6)
	buyButton.Parent = card

	local function refresh()
		if isShopItemOwned(item) then
			priceTag.BackgroundColor3 = OWNED_COLOR
			priceLabel.Text = "OWNED"
			buyButton.BackgroundColor3 = OWNED_COLOR
			buyButton.Text = "OWNED"
			buyButton.Active = false
		else
			priceTag.BackgroundColor3 = (item.kind == "coins") and COIN_TAG_COLOR or ROBUX_TAG_COLOR
			priceLabel.Text = item.priceText
			buyButton.BackgroundColor3 = tabColor
			buyButton.Text = "BUY"
			buyButton.Active = true
		end
	end
	refresh()

	buyButton.MouseButton1Click:Connect(function()
		if not buyButton.Active then
			return
		end
		if shared.SoundManager then
			shared.SoundManager.PlaySound("buttonClick")
		end
		buyShopItem(item)
	end)

	return card, refresh
end

local shopCardRefreshers: { () -> () } = {}
local shopCardOrder = 0

for _, tabName in { "EGGS", "BOOSTS", "UPGRADES", "PASSES" } do
	local tabColor = SHOP_TAB_COLORS[tabName]
	for _, item in SHOP_ITEMS[tabName] do
		local card, refresh = createShopItemCard(item, tabName, tabColor)
		card.LayoutOrder = shopCardOrder
		shopCardOrder += 1
		card.Visible = tabName == "EGGS"
		card.Parent = shopCardCanvas
		table.insert(shopCardRefreshers, refresh)
	end
end

playerDataLoadedRemote.OnClientEvent:Connect(function()
	for _, refresh in shopCardRefreshers do
		refresh()
	end
end)

-- VOID PASS content -- single featured layout, not the item grid above.
local voidPassContent = Instance.new("Frame")
voidPassContent.Name = "VoidPassContent"
voidPassContent.Size = UDim2.new(1, -20, 1, -114)
voidPassContent.Position = UDim2.new(0, 10, 0, 104)
voidPassContent.BackgroundTransparency = 1
voidPassContent.BorderSizePixel = 0
voidPassContent.Visible = false
voidPassContent.Parent = shopPanel

local voidPassCanvas = Instance.new("CanvasGroup")
voidPassCanvas.Name = "VoidPassCanvas"
voidPassCanvas.Size = UDim2.fromScale(1, 1)
voidPassCanvas.BackgroundTransparency = 1
voidPassCanvas.BorderSizePixel = 0
voidPassCanvas.Parent = voidPassContent

local voidFeaturedCard = Instance.new("Frame")
voidFeaturedCard.Name = "FeaturedCard"
voidFeaturedCard.Size = UDim2.new(1, 0, 0, 160)
voidFeaturedCard.BackgroundColor3 = Color3.fromRGB(40, 15, 60)
voidFeaturedCard.BorderSizePixel = 0
addCorner(voidFeaturedCard, 12)
voidFeaturedCard.Parent = voidPassCanvas

local voidGradient = Instance.new("UIGradient")
voidGradient.Color = ColorSequence.new(Color3.fromRGB(60, 25, 90), Color3.fromRGB(30, 10, 50))
voidGradient.Rotation = 90
voidGradient.Parent = voidFeaturedCard

local voidPassTitle = Instance.new("TextLabel")
voidPassTitle.Name = "Title"
voidPassTitle.Size = UDim2.new(1, -32, 0, 40)
voidPassTitle.Position = UDim2.new(0, 16, 0, 16)
voidPassTitle.BackgroundTransparency = 1
voidPassTitle.Font = Enum.Font.GothamBlack
voidPassTitle.TextSize = 28
voidPassTitle.TextColor3 = WHITE
voidPassTitle.TextXAlignment = Enum.TextXAlignment.Left
voidPassTitle.Text = "VOID PASS"
voidPassTitle.Parent = voidFeaturedCard

local voidPassPrice = Instance.new("TextLabel")
voidPassPrice.Name = "Price"
voidPassPrice.Size = UDim2.new(1, -32, 0, 24)
voidPassPrice.Position = UDim2.new(0, 16, 0, 60)
voidPassPrice.BackgroundTransparency = 1
voidPassPrice.Font = Enum.Font.GothamBold
voidPassPrice.TextSize = 18
voidPassPrice.TextColor3 = Color3.fromRGB(220, 180, 255)
voidPassPrice.TextXAlignment = Enum.TextXAlignment.Left
voidPassPrice.Text = "99 R$ / month"
voidPassPrice.Parent = voidFeaturedCard

local voidBenefitsList = Instance.new("Frame")
voidBenefitsList.Name = "Benefits"
voidBenefitsList.Size = UDim2.new(1, 0, 0, 110)
voidBenefitsList.Position = UDim2.new(0, 0, 0, 176)
voidBenefitsList.BackgroundTransparency = 1
voidBenefitsList.Parent = voidPassCanvas

local voidBenefitsLayout = Instance.new("UIListLayout")
voidBenefitsLayout.SortOrder = Enum.SortOrder.LayoutOrder
voidBenefitsLayout.Padding = UDim.new(0, 4)
voidBenefitsLayout.Parent = voidBenefitsList

local VOID_PASS_BENEFITS = {
	"✓ 1 free daily egg roll",
	"✓ Exclusive monthly monster skin",
	"✓ VIP server tag",
	"✓ Global trade board access",
}

for i, text in VOID_PASS_BENEFITS do
	local benefitLabel = Instance.new("TextLabel")
	benefitLabel.Name = "Benefit_" .. i
	benefitLabel.Size = UDim2.new(1, 0, 0, 20)
	benefitLabel.BackgroundTransparency = 1
	benefitLabel.Font = Enum.Font.Gotham
	benefitLabel.TextSize = 13
	benefitLabel.TextColor3 = Color3.fromRGB(210, 200, 230)
	benefitLabel.TextXAlignment = Enum.TextXAlignment.Left
	benefitLabel.LayoutOrder = i
	benefitLabel.Text = text
	benefitLabel.Parent = voidBenefitsList
end

local voidPassBuyButton = Instance.new("TextButton")
voidPassBuyButton.Name = "VoidPassBuyButton"
voidPassBuyButton.Size = UDim2.new(1, 0, 0, 44)
voidPassBuyButton.Position = UDim2.new(0, 0, 0, 300)
voidPassBuyButton.BackgroundColor3 = Color3.fromRGB(150, 60, 200)
voidPassBuyButton.AutoButtonColor = false
voidPassBuyButton.BorderSizePixel = 0
voidPassBuyButton.Font = Enum.Font.GothamBold
voidPassBuyButton.TextSize = 16
voidPassBuyButton.TextColor3 = WHITE
voidPassBuyButton.Text = "BUY"
addCorner(voidPassBuyButton, 8)
voidPassBuyButton.Parent = voidPassCanvas

voidPassBuyButton.MouseButton1Click:Connect(function()
	if shared.SoundManager then
		shared.SoundManager.PlaySound("buttonClick")
	end
	shared.MonetizationClient.PromptPurchase("gamepass", Constants.GAMEPASS_IDS.VoidPass)
end)

-- Tab switching: fade the outgoing canvas out, swap which cards/content are
-- visible while invisible, then fade the (possibly different) incoming
-- canvas back in.
local shopActiveTab = "EGGS"
updateShopTabVisuals(shopActiveTab)

local function setShopActiveTab(newTab: string)
	if newTab == shopActiveTab then
		return
	end

	local outgoingCanvas = (shopActiveTab == "VOID PASS") and voidPassCanvas or shopCardCanvas

	local fadeOut = TweenService:Create(outgoingCanvas, TweenInfo.new(0.1), { GroupTransparency = 1 })
	fadeOut.Completed:Connect(function()
		shopContent.Visible = newTab ~= "VOID PASS"
		voidPassContent.Visible = newTab == "VOID PASS"

		if newTab ~= "VOID PASS" then
			for _, card in shopCardCanvas:GetChildren() do
				if card:IsA("Frame") and card:GetAttribute("Tab") then
					card.Visible = card:GetAttribute("Tab") == newTab
				end
			end
		end

		shopActiveTab = newTab
		updateShopTabVisuals(shopActiveTab)

		local incomingCanvas = (shopActiveTab == "VOID PASS") and voidPassCanvas or shopCardCanvas
		incomingCanvas.GroupTransparency = 1
		TweenService:Create(incomingCanvas, TweenInfo.new(0.1), { GroupTransparency = 0 }):Play()
	end)
	fadeOut:Play()
end

for tabName, button in shopTabButtons do
	button.MouseButton1Click:Connect(function()
		if shared.SoundManager then
			shared.SoundManager.PlaySound("buttonClick")
		end
		setShopActiveTab(tabName)
	end)
end

-- Generic list-row builder. Used to belong to the old Shop Panel; kept here
-- since Event Station below still builds its token-purchase rows with it.
local function createShopEntry(itemName: string, description: string, priceText: string, onBuy: () -> ()): Frame
	local entry = Instance.new("Frame")
	entry.Name = "ShopEntry_" .. (itemName:gsub("%s", ""))
	entry.Size = UDim2.new(1, 0, 0, 70)
	entry.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
	entry.BorderSizePixel = 0
	addCorner(entry, 6)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0.6, -8, 0, 22)
	nameLabel.Position = UDim2.new(0, 8, 0, 6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 15
	nameLabel.TextColor3 = WHITE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = itemName
	nameLabel.Parent = entry

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescriptionLabel"
	descLabel.Size = UDim2.new(0.6, -8, 0, 34)
	descLabel.Position = UDim2.new(0, 8, 0, 28)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 12
	descLabel.TextColor3 = GRAY
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Text = description
	descLabel.Parent = entry

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.new(0, 90, 0, 18)
	priceLabel.Position = UDim2.new(1, -180, 0, 10)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Font = Enum.Font.Gotham
	priceLabel.TextSize = 13
	priceLabel.TextColor3 = GOLD
	priceLabel.Text = priceText
	priceLabel.Parent = entry

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BUY"
	buyButton.Size = UDim2.new(0, 80, 0, 32)
	buyButton.Position = UDim2.new(1, -90, 0.5, -16)
	buyButton.Text = "BUY"
	buyButton.TextSize = 14
	buyButton.Parent = entry
	styleButton(buyButton)

	onActivated(buyButton, function()
		if buyButton:GetAttribute("Disabled") then
			return
		end
		onBuy()
	end)

	return entry
end

--============================================================
-- Event Station Panel
--============================================================

local eventStationPanel = Instance.new("Frame")
eventStationPanel.Name = "EventStationPanel"
eventStationPanel.Position = UDim2.new(0.5, -200, 0.5, -250)
eventStationPanel.Size = UDim2.new(0, 400, 0, 500)
eventStationPanel.BackgroundColor3 = PANEL_BG
eventStationPanel.BorderSizePixel = 0
eventStationPanel.Visible = false
eventStationPanel.Parent = screenGui
addCorner(eventStationPanel, 12)
panels.EventStationPanel = eventStationPanel

local eventStationTitle = Instance.new("TextLabel")
eventStationTitle.Name = "Title"
eventStationTitle.Size = UDim2.new(1, -40, 0, 36)
eventStationTitle.Position = UDim2.new(0, 16, 0, 12)
eventStationTitle.BackgroundTransparency = 1
eventStationTitle.Font = Enum.Font.GothamBold
eventStationTitle.TextSize = 20
eventStationTitle.TextColor3 = WHITE
eventStationTitle.TextXAlignment = Enum.TextXAlignment.Left
eventStationTitle.Text = "EVENT STATION"
eventStationTitle.Parent = eventStationPanel

createCloseButton(eventStationPanel, "EventStationPanel")

local eventTokenLabel = Instance.new("TextLabel")
eventTokenLabel.Name = "TokenCount"
eventTokenLabel.Size = UDim2.new(1, -32, 0, 24)
eventTokenLabel.Position = UDim2.new(0, 16, 0, 48)
eventTokenLabel.BackgroundTransparency = 1
eventTokenLabel.Font = Enum.Font.GothamBold
eventTokenLabel.TextSize = 16
eventTokenLabel.TextColor3 = GOLD
eventTokenLabel.TextXAlignment = Enum.TextXAlignment.Left
eventTokenLabel.Text = "Event Tokens: 0"
eventTokenLabel.Parent = eventStationPanel

local nextEventLabel = Instance.new("TextLabel")
nextEventLabel.Name = "NextEventTimer"
nextEventLabel.Size = UDim2.new(1, -32, 0, 20)
nextEventLabel.Position = UDim2.new(0, 16, 0, 72)
nextEventLabel.BackgroundTransparency = 1
nextEventLabel.Font = Enum.Font.Gotham
nextEventLabel.TextSize = 13
nextEventLabel.TextColor3 = GRAY
nextEventLabel.TextXAlignment = Enum.TextXAlignment.Left
nextEventLabel.Text = "NEXT EVENT IN: --"
nextEventLabel.Parent = eventStationPanel

local eventMonsterList = Instance.new("ScrollingFrame")
eventMonsterList.Name = "EventMonsterList"
eventMonsterList.Position = UDim2.new(0, 16, 0, 100)
eventMonsterList.Size = UDim2.new(1, -32, 1, -116)
eventMonsterList.BackgroundTransparency = 1
eventMonsterList.BorderSizePixel = 0
eventMonsterList.ScrollBarThickness = 6
eventMonsterList.CanvasSize = UDim2.new(0, 0, 0, 0)
eventMonsterList.Parent = eventStationPanel

local eventMonsterListLayout = Instance.new("UIListLayout")
eventMonsterListLayout.SortOrder = Enum.SortOrder.LayoutOrder
eventMonsterListLayout.Padding = UDim.new(0, 6)
eventMonsterListLayout.Parent = eventMonsterList

eventMonsterListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	eventMonsterList.CanvasSize = UDim2.new(0, 0, 0, eventMonsterListLayout.AbsoluteContentSize.Y + 8)
end)

for i, item in Constants.EVENT_MONSTERS do
	local entry = createShopEntry(
		item.name,
		`{item.emotion} • {item.rarity}`,
		`{item.tokenCost} token{item.tokenCost == 1 and "" or "s"}`,
		function()
			fireAction("EVENT_STATION_PURCHASE", { monsterName = item.name })
		end
	)
	entry.LayoutOrder = i
	entry.Parent = eventMonsterList
end

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
			local currentEarnRate = coinState.earnRate or 0
			if currentEarnRate > lastEarnRate then
				flashCoinGold()
			end
			lastEarnRate = currentEarnRate

			earnRateLabel.Text = `+{NumberFormatter.Format(currentEarnRate)}/sec`
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

		-- Event Station: token count + next event countdown
		eventTokenLabel.Text = `Event Tokens: {eventTokens}`

		local eventState = shared.EventClient
		if eventState and typeof(eventState.nextEventIn) == "number" then
			local minutes = math.floor(eventState.nextEventIn / 60)
			local seconds = eventState.nextEventIn % 60
			nextEventLabel.Text = string.format("NEXT EVENT IN: %02d:%02d", minutes, seconds)
		end
	end
end)
