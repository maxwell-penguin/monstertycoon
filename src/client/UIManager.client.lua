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

local boostElementLabel = Instance.new("TextLabel")
boostElementLabel.Name = "BoostElement"
boostElementLabel.Size = UDim2.new(1, -16, 0, 34)
boostElementLabel.Position = UDim2.new(0, 8, 0, 6)
boostElementLabel.BackgroundTransparency = 1
boostElementLabel.Font = Enum.Font.GothamBold
boostElementLabel.TextSize = 24
boostElementLabel.TextColor3 = WHITE
boostElementLabel.Text = ""
boostElementLabel.Parent = boostHud

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
createToggleButton("MONSTERS", 2, "HallPanel")
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

	local elementLabel = Instance.new("TextLabel")
	elementLabel.Name = "ElementLabel"
	elementLabel.Size = UDim2.new(0, 80, 1, 0)
	elementLabel.Position = UDim2.new(0.5, 0, 0, 0)
	elementLabel.BackgroundTransparency = 1
	elementLabel.Font = Enum.Font.Gotham
	elementLabel.TextSize = 13
	elementLabel.TextColor3 = Constants.ELEMENT_COLORS[monster.element] or WHITE
	elementLabel.Text = monster.element or ""
	elementLabel.Parent = entry

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
eggVisual.BackgroundColor3 = Constants.ELEMENT_COLORS.Light
eggVisual.BorderSizePixel = 0
eggVisual.Parent = rollPanel
addCorner(eggVisual, 60)

task.spawn(function()
	local colorCycle = {
		Constants.ELEMENT_COLORS.Fire,
		Constants.ELEMENT_COLORS.Void,
		Constants.ELEMENT_COLORS.Nature,
		Constants.ELEMENT_COLORS.Water,
		Constants.ELEMENT_COLORS.Thunder,
		Constants.ELEMENT_COLORS.Galaxy,
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

-- Slow continuous rotation via NumberValues driving eggVisual.Rotation directly
-- (rather than tweening a Rotation property whose repeat would otherwise snap
-- back to 0 visibly -- 360 and 0 look identical, so the wrap via modulo is
-- seamless).
local eggBaseRotationValue = Instance.new("NumberValue")
eggBaseRotationValue.Value = 0
eggBaseRotationValue.Parent = eggVisual

local eggJiggleValue = Instance.new("NumberValue")
eggJiggleValue.Value = 0
eggJiggleValue.Parent = eggVisual

local function updateEggRotation()
	eggVisual.Rotation = (eggBaseRotationValue.Value % 360) + eggJiggleValue.Value
end

eggBaseRotationValue:GetPropertyChangedSignal("Value"):Connect(updateEggRotation)
eggJiggleValue:GetPropertyChangedSignal("Value"):Connect(updateEggRotation)

TweenService:Create(
	eggBaseRotationValue,
	TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
	{ Value = 360 }
):Play()

-- Every 3 seconds, a quick ±5 degree jiggle chained over 0.3s total, layered on
-- top of the continuous rotation via the separate jiggle value.
task.spawn(function()
	while true do
		task.wait(3)

		for _, target in { 5, -5, 0 } do
			local jiggleTween =
				TweenService:Create(eggJiggleValue, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Value = target,
				})
			jiggleTween:Play()
			jiggleTween.Completed:Wait()
		end
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
hallPanel.Position = UDim2.new(0, 16, 0.5, -230)
hallPanel.Size = UDim2.new(0, 300, 0, 460)
hallPanel.BackgroundColor3 = PANEL_BG
hallPanel.BorderSizePixel = 0
hallPanel.Visible = false
hallPanel.Parent = screenGui
addCorner(hallPanel, 12)
panels.HallPanel = hallPanel

local hallTitle = Instance.new("TextLabel")
hallTitle.Name = "Title"
hallTitle.Size = UDim2.new(1, -40, 0, 24)
hallTitle.Position = UDim2.new(0, 16, 0, 12)
hallTitle.BackgroundTransparency = 1
hallTitle.Font = Enum.Font.GothamBold
hallTitle.TextSize = 20
hallTitle.TextColor3 = WHITE
hallTitle.TextXAlignment = Enum.TextXAlignment.Left
hallTitle.Text = "MONSTER ENVIRONMENT"
hallTitle.Parent = hallPanel

local hallCapacitySubtitle = Instance.new("TextLabel")
hallCapacitySubtitle.Name = "CapacitySubtitle"
hallCapacitySubtitle.Size = UDim2.new(1, -40, 0, 16)
hallCapacitySubtitle.Position = UDim2.new(0, 16, 0, 38)
hallCapacitySubtitle.BackgroundTransparency = 1
hallCapacitySubtitle.Font = Enum.Font.Gotham
hallCapacitySubtitle.TextSize = 12
hallCapacitySubtitle.TextColor3 = Color3.fromRGB(150, 150, 160)
hallCapacitySubtitle.TextXAlignment = Enum.TextXAlignment.Left
hallCapacitySubtitle.Text = "Capacity: 0/0 monsters"
hallCapacitySubtitle.Parent = hallPanel

createCloseButton(hallPanel, "HallPanel")

local hallGrid = Instance.new("ScrollingFrame")
hallGrid.Name = "SlotGrid"
hallGrid.Position = UDim2.new(0, 12, 0, 60)
hallGrid.Size = UDim2.new(1, -24, 0, 232)
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

-- BiomeData lives server-only, so this is the client's own copy of which
-- elements belong to which biome, matching BiomeClient.client.lua's approach.
local BIOME_ORDER = { "Forest", "Waterfall", "Volcano", "Pond" }
local BIOME_ICONS = { Forest = "🌲", Waterfall = "💧", Volcano = "🌋", Pond = "🌊" }
local BIOME_ELEMENTS = {
	Forest = { "Nature", "Poison" },
	Waterfall = { "Water", "Ice" },
	Volcano = { "Fire", "Magma" },
	Pond = { "Void", "Galaxy" },
}

local function getBiomeForElement(element: string): string?
	for biomeName, elements in BIOME_ELEMENTS do
		if table.find(elements, element) then
			return biomeName
		end
	end
	return nil
end

local biomeSection = Instance.new("Frame")
biomeSection.Name = "BiomeBreakdown"
biomeSection.Position = UDim2.new(0, 12, 0, 300)
biomeSection.Size = UDim2.new(1, -24, 0, 90)
biomeSection.BackgroundTransparency = 1
biomeSection.Parent = hallPanel

local biomeHeader = Instance.new("TextLabel")
biomeHeader.Name = "Header"
biomeHeader.BackgroundTransparency = 1
biomeHeader.Size = UDim2.new(1, 0, 0, 14)
biomeHeader.Font = Enum.Font.GothamBold
biomeHeader.TextSize = 11
biomeHeader.TextColor3 = Color3.fromRGB(150, 150, 160)
biomeHeader.TextXAlignment = Enum.TextXAlignment.Left
biomeHeader.Text = "BIOME DISTRIBUTION"
biomeHeader.Parent = biomeSection

local biomeRowsFrame = Instance.new("Frame")
biomeRowsFrame.Name = "Rows"
biomeRowsFrame.BackgroundTransparency = 1
biomeRowsFrame.Position = UDim2.new(0, 0, 0, 16)
biomeRowsFrame.Size = UDim2.new(1, 0, 1, -16)
biomeRowsFrame.Parent = biomeSection

local biomeRowsLayout = Instance.new("UIListLayout")
biomeRowsLayout.Padding = UDim.new(0, 2)
biomeRowsLayout.Parent = biomeRowsFrame

local biomeRowLabels: { [string]: TextLabel } = {}
for _, biomeName in BIOME_ORDER do
	local row = Instance.new("TextLabel")
	row.Name = "Row_" .. biomeName
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 16)
	row.Font = Enum.Font.Gotham
	row.TextSize = 12
	row.TextColor3 = WHITE
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = `{BIOME_ICONS[biomeName]} {biomeName}: 0 monsters`
	row.Parent = biomeRowsFrame
	biomeRowLabels[biomeName] = row
end

local function rebuildBiomeBreakdown(slots: { any })
	local counts: { [string]: number } = {}
	for _, slot in slots do
		if slot.isActive and slot.monster then
			local biomeName = getBiomeForElement(slot.monster.element)
			if biomeName then
				counts[biomeName] = (counts[biomeName] or 0) + 1
			end
		end
	end

	local unlocked = (shared.BiomeClient and shared.BiomeClient.unlockedBiomes) or { "Forest" }

	for _, biomeName in BIOME_ORDER do
		local row = biomeRowLabels[biomeName]
		if table.find(unlocked, biomeName) then
			row.TextColor3 = WHITE
			row.Text = `{BIOME_ICONS[biomeName]} {biomeName}: {counts[biomeName] or 0} monsters`
		else
			row.TextColor3 = Color3.fromRGB(110, 110, 120)
			row.Text = `🔒 {biomeName}`
		end
	end
end

local upgradeHallButton = Instance.new("TextButton")
upgradeHallButton.Name = "UpgradeHallButton"
upgradeHallButton.AnchorPoint = Vector2.new(0.5, 1)
upgradeHallButton.Position = UDim2.new(0.5, 0, 1, -12)
upgradeHallButton.Size = UDim2.new(1, -24, 0, 36)
upgradeHallButton.Text = "UPGRADE ENVIRONMENT"
upgradeHallButton.TextSize = 14
upgradeHallButton.Parent = hallPanel
styleButton(upgradeHallButton)

onActivated(upgradeHallButton, function()
	if upgradeHallButton:GetAttribute("Disabled") then
		return
	end
	fireAction("UPGRADE_ENVIRONMENT", nil)
end)

local hallSlots: { any } = {}
local currentHallTier = 1

local function inferHallTier(slotCount: number): number
	for tier, count in Constants.ENVIRONMENT_CAPACITY do
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
		local elementColor = Constants.ELEMENT_COLORS[slot.monster.element] or EMPTY_SLOT_BG
		slotFrame.BackgroundColor3 = dimColor(elementColor, 0.6)

		local dot = Instance.new("Frame")
		dot.Name = "ElementDot"
		dot.AnchorPoint = Vector2.new(1, 0)
		dot.Position = UDim2.new(1, -2, 0, 2)
		dot.Size = UDim2.new(0, 8, 0, 8)
		dot.BackgroundColor3 = elementColor
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

local function countOccupiedSlots(slots: { any }): number
	local occupied = 0
	for _, slot in slots do
		if slot.isActive and slot.monster then
			occupied += 1
		end
	end
	return occupied
end

updateHallRemote.OnClientEvent:Connect(function(slots: any)
	hallSlots = slots or {}
	currentHallTier = inferHallTier(#hallSlots)
	shared.HallClient = { slots = hallSlots, environmentTier = currentHallTier }
	rebuildHallGrid()
	hallCapacitySubtitle.Text = `Capacity: {countOccupiedSlots(hallSlots)}/{#hallSlots} monsters`
	rebuildBiomeBreakdown(hallSlots)
end)

--============================================================
-- Shop Panel
--============================================================

local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.Position = UDim2.new(0.5, -250, 0.5, -300)
shopPanel.Size = UDim2.new(0, 500, 0, 600)
shopPanel.BackgroundColor3 = PANEL_BG
shopPanel.BorderSizePixel = 0
shopPanel.Visible = false
shopPanel.Parent = screenGui
addCorner(shopPanel, 12)
panels.ShopPanel = shopPanel

local shopTitle = Instance.new("TextLabel")
shopTitle.Name = "Title"
shopTitle.Size = UDim2.new(1, -40, 0, 36)
shopTitle.Position = UDim2.new(0, 16, 0, 12)
shopTitle.BackgroundTransparency = 1
shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextSize = 20
shopTitle.TextColor3 = WHITE
shopTitle.TextXAlignment = Enum.TextXAlignment.Left
shopTitle.Text = "SHOP"
shopTitle.Parent = shopPanel

createCloseButton(shopPanel, "ShopPanel")

local shopList = Instance.new("ScrollingFrame")
shopList.Name = "ShopList"
shopList.Position = UDim2.new(0, 16, 0, 56)
shopList.Size = UDim2.new(1, -32, 1, -72)
shopList.BackgroundTransparency = 1
shopList.BorderSizePixel = 0
shopList.ScrollBarThickness = 6
shopList.CanvasSize = UDim2.new(0, 0, 0, 0)
shopList.Parent = shopPanel

local shopListLayout = Instance.new("UIListLayout")
shopListLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopListLayout.Padding = UDim.new(0, 6)
shopListLayout.Parent = shopList

shopListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	shopList.CanvasSize = UDim2.new(0, 0, 0, shopListLayout.AbsoluteContentSize.Y + 8)
end)

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

local shopEntryOrder = 0

local function addShopEntry(entry: Frame)
	entry.LayoutOrder = shopEntryOrder
	shopEntryOrder += 1
	entry.Parent = shopList
end

local GAMEPASS_SHOP_ITEMS = {
	{ key = "InfiniteBag", name = "Infinite Bag", description = "Unlimited bag capacity, forever." },
	{ key = "VoidCarrier", name = "Void Carrier", description = "250 bag capacity, forever." },
	{ key = "SpeedBoots", name = "Speed Boots", description = "+30% walk speed." },
	{ key = "BoostInsider", name = "Boost Insider", description = "Insider perks during boosts." },
	{ key = "ExtraPlot", name = "Extra Plot", description = "An additional plot (coming soon)." },
	{ key = "Income2x", name = "2x Income", description = "Double coin earnings." },
	{ key = "Income3x", name = "3x Income", description = "Triple coin earnings." },
	{ key = "Income5x", name = "5x Income", description = "5x coin earnings." },
	{ key = "Income7x", name = "7x Income", description = "7x coin earnings." },
	{ key = "Income10x", name = "10x Income", description = "10x coin earnings." },
	{ key = "Magnet", name = "Magnet", description = "Auto-collect vials within 20 studs." },
}

for _, item in GAMEPASS_SHOP_ITEMS do
	local entry = createShopEntry(item.name, item.description, "ROBUX", function()
		shared.MonetizationClient.PromptPurchase("gamepass", Constants.GAMEPASS_IDS[item.key])
	end)
	entry:SetAttribute("GamepassKey", item.key)
	addShopEntry(entry)
end

local PRODUCT_SHOP_ITEMS = {
	{ key = "LuckBoost", name = "Luck Boost", description = "+50% egg odds for 15 minutes." },
	{ key = "MergeBoost", name = "Merge Boost", description = "5 free merges." },
	{ key = "ServerBoost", name = "Server Boost", description = "1.5x server-wide earnings for 10 minutes." },
	{ key = "RareEgg", name = "Rare Egg", description = "Guaranteed Rare or better monster." },
	{ key = "EpicEgg", name = "Epic Egg", description = "Guaranteed Epic or better monster." },
	{ key = "LegendaryEgg", name = "Legendary Egg", description = "Guaranteed Legendary or better monster." },
	{ key = "MythicEgg", name = "Mythic Egg", description = "Guaranteed Mythic monster." },
	{ key = "StarterPack", name = "Starter Pack", description = "Infinite Bag + Luck Boost + Rare Egg." },
	{ key = "VoidPack", name = "Void Pack", description = "Epic Egg + Luck Boost + Speed Boots." },
	{ key = "AutoPickup", name = "Auto Pickup", description = "Auto-collect all vials for 10 minutes." },
}

for _, item in PRODUCT_SHOP_ITEMS do
	local entry = createShopEntry(item.name, item.description, "ROBUX", function()
		shared.MonetizationClient.PromptPurchase("product", Constants.PRODUCT_IDS[item.key])
	end)
	addShopEntry(entry)
end

for tier = 2, #Constants.BAG_TIERS do
	local tierDef = Constants.BAG_TIERS[tier]
	local priceText: string
	local onBuy: () -> ()

	if tierDef.robux then
		priceText = "ROBUX"
		local gamepassKey = (tier == 5) and "VoidCarrier" or "InfiniteBag"
		onBuy = function()
			shared.MonetizationClient.PromptPurchase("gamepass", Constants.GAMEPASS_IDS[gamepassKey])
		end
	else
		priceText = `{NumberFormatter.Format(tierDef.cost)} coins`
		onBuy = function()
			fireAction("UPGRADE_BAG", { targetTier = tier })
		end
	end

	local entry = createShopEntry(
		`Bag: {tierDef.name}`,
		`Upgrade bag to {NumberFormatter.Format(tierDef.capacity)} capacity.`,
		priceText,
		onBuy
	)
	addShopEntry(entry)
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
		`{item.element} • {item.rarity}`,
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
	if monster and monster.element then
		color = Constants.ELEMENT_COLORS[monster.element] or WHITE
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
			local elementText = warningState.element == "Mystery" and "???" or string.upper(warningState.element or "")
			warningLabel.Text = `INCOMING: {elementText} SURGE IN {secondsLeft}s`

			local color = warningState.element == "Mystery" and Color3.fromHSV(os.clock() % 1, 1, 1)
				or (Constants.ELEMENT_COLORS[warningState.element] or WHITE)
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
			if boostState.elements then
				color = Constants.ELEMENT_COLORS[boostState.elements[1]] or WHITE
			elseif boostState.element == "All" then
				color = VOID_STORM_COLOR
			elseif boostState.element == "Mystery" then
				color = Color3.fromHSV(os.clock() % 1, 1, 1)
			else
				color = Constants.ELEMENT_COLORS[boostState.element] or WHITE
			end
			boostHud.BackgroundColor3 = color

			local text
			if boostState.elements then
				text = `{string.upper(boostState.elements[1])} + {string.upper(boostState.elements[2])} SURGE — {boostState.multiplier}x`
			elseif boostState.element == "Mystery" then
				text = `??? SURGE — {boostState.multiplier}x`
			elseif boostState.element == "All" then
				text = `VOID STORM — {boostState.multiplier}x ALL`
			else
				text = `{string.upper(boostState.element or "")} SURGE — {boostState.multiplier}x`
			end
			boostElementLabel.Text = text

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
		local nextTierCost = Constants.ENVIRONMENT_UPGRADE_COSTS[currentHallTier + 1]
		local coinsAvailable = (shared.CoinDisplay and shared.CoinDisplay.displayCoins) or 0

		if not nextTierCost then
			upgradeHallButton.Text = "MAX TIER"
			upgradeHallButton:SetAttribute("Disabled", true)
		else
			upgradeHallButton.Text = `UPGRADE ENVIRONMENT - {NumberFormatter.Format(nextTierCost)}`
			upgradeHallButton:SetAttribute("Disabled", coinsAvailable < nextTierCost)
		end

		-- Live-refresh biome lock state (BiomeClient publishes shared.BiomeClient
		-- independently of hallSlots updates, e.g. right after an unlock).
		rebuildBiomeBreakdown(hallSlots)

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

		-- Shop "OWNED" labels
		local monetizationState = shared.MonetizationClient
		local ownedGamepasses = monetizationState and monetizationState.ownedGamepasses
		if ownedGamepasses then
			for _, entry in shopList:GetChildren() do
				if entry:IsA("Frame") then
					local gamepassKey = entry:GetAttribute("GamepassKey")
					if gamepassKey then
						local buyButton = entry:FindFirstChild("BUY")
						if buyButton and buyButton:IsA("TextButton") then
							if ownedGamepasses[gamepassKey] then
								buyButton.Text = "OWNED"
								buyButton:SetAttribute("Disabled", true)
							else
								buyButton.Text = "BUY"
								buyButton:SetAttribute("Disabled", false)
							end
						end
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
