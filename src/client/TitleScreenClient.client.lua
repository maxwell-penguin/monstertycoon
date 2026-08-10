local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 210, 60)
local WHITE = Color3.new(1, 1, 1)
local GRAY = Color3.fromRGB(180, 180, 180)
local PANEL_BG = Color3.fromRGB(12, 9, 22)
local PANEL_STROKE = Color3.fromRGB(80, 50, 140)
local PLAY_BG = Color3.fromRGB(150, 60, 200)
local PLAY_HOVER = Color3.fromRGB(180, 90, 230)
local TOGGLE_ON = Color3.fromRGB(80, 200, 120)
local TOGGLE_OFF = Color3.fromRGB(200, 80, 80)

--============================================================
-- Small local UI helpers (mirrors the styling conventions in
-- UIManager.client.lua, but kept local since those helpers aren't exported)
--============================================================

local function addCorner(instance: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function addStroke(instance: Instance, color: Color3, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Parent = instance
	return stroke
end

local function styleButtonHover(button: GuiButton, defaultColor: Color3, hoverColor: Color3)
	button.AutoButtonColor = false
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = hoverColor }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = defaultColor }):Play()
	end)
end

local function onActivated(button: GuiButton, callback: () -> ())
	button.MouseButton1Click:Connect(function()
		if shared.SoundManager then
			shared.SoundManager.PlaySound("buttonClick")
		end
		callback()
	end)
end

--============================================================
-- Root GUI
--============================================================

local titleGui = Instance.new("ScreenGui")
titleGui.Name = "TitleScreenGui"
titleGui.IgnoreGuiInset = true
titleGui.ResetOnSpawn = false
titleGui.DisplayOrder = 200
titleGui.Parent = playerGui

-- CanvasGroup lets the whole title screen (logo, button, panels) fade out
-- together via one GroupTransparency tween instead of animating every
-- descendant's transparency individually. World stays live/interactable
-- behind it the whole time -- this container has no background of its own
-- and never sets Active, so it doesn't intercept camera/movement input.
local root = Instance.new("CanvasGroup")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = titleGui

--============================================================
-- Logo
--============================================================

local logoTitle = Instance.new("TextLabel")
logoTitle.Name = "LogoTitle"
logoTitle.AnchorPoint = Vector2.new(0.5, 0)
logoTitle.Position = UDim2.new(0.5, 0, 0.12, 0)
logoTitle.Size = UDim2.new(0, 700, 0, 70)
logoTitle.BackgroundTransparency = 1
logoTitle.Font = Enum.Font.GothamBlack
logoTitle.TextSize = 56
logoTitle.TextColor3 = GOLD
logoTitle.Text = "VOID FACTORY"
logoTitle.Parent = root

addStroke(logoTitle, Color3.new(0, 0, 0), 2)

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.new(0.5, 0, 0.12, 74)
subtitle.Size = UDim2.new(0, 700, 0, 30)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 20
subtitle.TextColor3 = WHITE
subtitle.Text = "Roll. Merge. Sell."
subtitle.Parent = root

addStroke(subtitle, Color3.new(0, 0, 0), 1)

--============================================================
-- PLAY button
--============================================================

local playButton = Instance.new("TextButton")
playButton.Name = "PlayButton"
playButton.AnchorPoint = Vector2.new(0.5, 0.5)
playButton.Position = UDim2.new(0.5, 0, 0.55, 0)
playButton.Size = UDim2.new(0, 260, 0, 64)
playButton.BackgroundColor3 = PLAY_BG
playButton.BorderSizePixel = 0
playButton.Font = Enum.Font.GothamBold
playButton.TextSize = 28
playButton.TextColor3 = WHITE
playButton.Text = "PLAY"
playButton.Parent = root

addCorner(playButton, 16)
styleButtonHover(playButton, PLAY_BG, PLAY_HOVER)

local function dismissTitleScreen()
	local fade = TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
	fade:Play()
	fade.Completed:Connect(function()
		titleGui.Enabled = false
	end)
end

onActivated(playButton, dismissTitleScreen)

--============================================================
-- Updates panel
--============================================================

local updatesPanel = Instance.new("Frame")
updatesPanel.Name = "UpdatesPanel"
updatesPanel.AnchorPoint = Vector2.new(0, 1)
updatesPanel.Position = UDim2.new(0, 20, 1, -20)
updatesPanel.Size = UDim2.new(0, 320, 0, 170)
updatesPanel.BackgroundColor3 = PANEL_BG
updatesPanel.BackgroundTransparency = 0.05
updatesPanel.BorderSizePixel = 0
updatesPanel.Parent = root

addCorner(updatesPanel, 16)
addStroke(updatesPanel, PANEL_STROKE)

local updatesLayout = Instance.new("UIListLayout")
updatesLayout.Padding = UDim.new(0, 4)
updatesLayout.SortOrder = Enum.SortOrder.LayoutOrder
updatesLayout.Parent = updatesPanel

local updatesPadding = Instance.new("UIPadding")
updatesPadding.PaddingTop = UDim.new(0, 12)
updatesPadding.PaddingBottom = UDim.new(0, 12)
updatesPadding.PaddingLeft = UDim.new(0, 14)
updatesPadding.PaddingRight = UDim.new(0, 14)
updatesPadding.Parent = updatesPanel

local updatesHeader = Instance.new("TextLabel")
updatesHeader.Name = "Header"
updatesHeader.LayoutOrder = 0
updatesHeader.Size = UDim2.new(1, 0, 0, 22)
updatesHeader.BackgroundTransparency = 1
updatesHeader.Font = Enum.Font.GothamBold
updatesHeader.TextSize = 18
updatesHeader.TextColor3 = GOLD
updatesHeader.TextXAlignment = Enum.TextXAlignment.Left
updatesHeader.Text = "UPDATES"
updatesHeader.Parent = updatesPanel

local latestNote = Constants.UPDATE_NOTES and Constants.UPDATE_NOTES[1]
if latestNote then
	local dateLabel = Instance.new("TextLabel")
	dateLabel.Name = "Date"
	dateLabel.LayoutOrder = 1
	dateLabel.Size = UDim2.new(1, 0, 0, 18)
	dateLabel.BackgroundTransparency = 1
	dateLabel.Font = Enum.Font.GothamBold
	dateLabel.TextSize = 14
	dateLabel.TextColor3 = GRAY
	dateLabel.TextXAlignment = Enum.TextXAlignment.Left
	dateLabel.Text = latestNote.date
	dateLabel.Parent = updatesPanel

	for i, line in latestNote.lines do
		local lineLabel = Instance.new("TextLabel")
		lineLabel.Name = "Line_" .. i
		lineLabel.LayoutOrder = 1 + i
		lineLabel.Size = UDim2.new(1, 0, 0, 18)
		lineLabel.BackgroundTransparency = 1
		lineLabel.Font = Enum.Font.Gotham
		lineLabel.TextSize = 14
		lineLabel.TextColor3 = WHITE
		lineLabel.TextWrapped = true
		lineLabel.TextXAlignment = Enum.TextXAlignment.Left
		lineLabel.Text = "- " .. line
		lineLabel.Parent = updatesPanel
	end
end

--============================================================
-- Settings (gear button + popup)
--============================================================

local gearButton = Instance.new("TextButton")
gearButton.Name = "GearButton"
gearButton.Position = UDim2.new(0, 20, 0, 20)
gearButton.Size = UDim2.new(0, 44, 0, 44)
gearButton.BackgroundColor3 = PANEL_BG
gearButton.BorderSizePixel = 0
gearButton.Font = Enum.Font.SourceSansBold
gearButton.TextSize = 26
gearButton.TextColor3 = WHITE
gearButton.Text = "\u{2699}"
gearButton.Parent = root

addCorner(gearButton, 8)
addStroke(gearButton, PANEL_STROKE)
styleButtonHover(gearButton, PANEL_BG, Color3.fromRGB(30, 24, 50))

local settingsPopup = Instance.new("Frame")
settingsPopup.Name = "SettingsPopup"
settingsPopup.AnchorPoint = Vector2.new(0.5, 0.5)
settingsPopup.Position = UDim2.new(0.5, 0, 0.5, 0)
settingsPopup.Size = UDim2.new(0, 300, 0, 140)
settingsPopup.BackgroundColor3 = PANEL_BG
settingsPopup.BorderSizePixel = 0
settingsPopup.Visible = false
settingsPopup.Parent = root

addCorner(settingsPopup, 16)
addStroke(settingsPopup, PANEL_STROKE)

local settingsHeader = Instance.new("TextLabel")
settingsHeader.Position = UDim2.new(0, 16, 0, 12)
settingsHeader.Size = UDim2.new(1, -32, 0, 24)
settingsHeader.BackgroundTransparency = 1
settingsHeader.Font = Enum.Font.GothamBold
settingsHeader.TextSize = 20
settingsHeader.TextColor3 = GOLD
settingsHeader.TextXAlignment = Enum.TextXAlignment.Left
settingsHeader.Text = "SETTINGS"
settingsHeader.Parent = settingsPopup

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 12)
closeButton.Size = UDim2.new(0, 28, 0, 28)
closeButton.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.TextColor3 = WHITE
closeButton.Text = "X"
closeButton.Parent = settingsPopup

addCorner(closeButton, 6)
styleButtonHover(closeButton, Color3.fromRGB(30, 30, 45), Color3.fromRGB(50, 50, 70))

local sfxLabel = Instance.new("TextLabel")
sfxLabel.Position = UDim2.new(0, 16, 0, 60)
sfxLabel.Size = UDim2.new(0, 160, 0, 32)
sfxLabel.BackgroundTransparency = 1
sfxLabel.Font = Enum.Font.Gotham
sfxLabel.TextSize = 16
sfxLabel.TextColor3 = WHITE
sfxLabel.TextXAlignment = Enum.TextXAlignment.Left
sfxLabel.Text = "Sound Effects"
sfxLabel.Parent = settingsPopup

local sfxToggle = Instance.new("TextButton")
sfxToggle.AnchorPoint = Vector2.new(1, 0)
sfxToggle.Position = UDim2.new(1, -16, 0, 60)
sfxToggle.Size = UDim2.new(0, 80, 0, 32)
sfxToggle.BorderSizePixel = 0
sfxToggle.Font = Enum.Font.GothamBold
sfxToggle.TextSize = 16
sfxToggle.TextColor3 = WHITE
sfxToggle.Parent = settingsPopup

addCorner(sfxToggle, 8)

local function refreshSfxToggle()
	local enabled = (shared.SoundManager and shared.SoundManager.IsSFXEnabled()) ~= false
	sfxToggle.BackgroundColor3 = enabled and TOGGLE_ON or TOGGLE_OFF
	sfxToggle.Text = enabled and "ON" or "OFF"
end

refreshSfxToggle()

onActivated(sfxToggle, function()
	if not shared.SoundManager then
		return
	end
	shared.SoundManager.SetSFXEnabled(not shared.SoundManager.IsSFXEnabled())
	refreshSfxToggle()
end)

onActivated(gearButton, function()
	refreshSfxToggle()
	settingsPopup.Visible = true
end)

onActivated(closeButton, function()
	settingsPopup.Visible = false
end)
