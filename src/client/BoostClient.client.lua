local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local boostWarningRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_WARNING) :: RemoteEvent
local boostStartedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_STARTED) :: RemoteEvent
local boostEndedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.BOOST_ENDED) :: RemoteEvent

local WARNING_SLIDE_DURATION = 0.3
local HUD_FADE_DURATION = 0.5
local FLASH_DURATION = 0.2
local VOID_STORM_COLOR = Color3.fromRGB(150, 60, 220)
local RAINBOW_CYCLE_STEP = 0.05

local gui = Instance.new("ScreenGui")
gui.Name = "BoostGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = playerGui

local warningBanner = Instance.new("Frame")
warningBanner.Name = "WarningBanner"
warningBanner.AnchorPoint = Vector2.new(0.5, 0)
warningBanner.Position = UDim2.new(0.5, 0, 0, -80)
warningBanner.Size = UDim2.new(0.6, 0, 0, 70)
warningBanner.BackgroundColor3 = Color3.new(1, 1, 1)
warningBanner.BorderSizePixel = 0
warningBanner.Visible = false
warningBanner.Parent = gui

local warningLabel = Instance.new("TextLabel")
warningLabel.Size = UDim2.fromScale(1, 1)
warningLabel.BackgroundTransparency = 1
warningLabel.Font = Enum.Font.GothamBlack
warningLabel.TextScaled = true
warningLabel.TextColor3 = Color3.new(1, 1, 1)
warningLabel.Parent = warningBanner

local hud = Instance.new("Frame")
hud.Name = "BoostHud"
hud.AnchorPoint = Vector2.new(0.5, 1)
hud.Position = UDim2.new(0.5, 0, 1, -20)
hud.Size = UDim2.new(0.4, 0, 0, 60)
hud.BackgroundColor3 = Color3.new(0, 0, 0)
hud.BackgroundTransparency = 0.4
hud.BorderSizePixel = 0
hud.Visible = false
hud.Parent = gui

local hudLabel = Instance.new("TextLabel")
hudLabel.Size = UDim2.fromScale(1, 1)
hudLabel.BackgroundTransparency = 1
hudLabel.Font = Enum.Font.GothamBlack
hudLabel.TextScaled = true
hudLabel.TextColor3 = Color3.new(1, 1, 1)
hudLabel.Parent = hud

local flash = Instance.new("ImageLabel")
flash.Name = "BoostFlash"
flash.Size = UDim2.fromScale(1, 1)
flash.Image = ""
flash.ImageTransparency = 1
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

local warningToken = 0
local hudToken = 0

local function dismissWarningBanner()
	warningToken += 1

	if not warningBanner.Visible then
		return
	end

	local tween = TweenService:Create(
		warningBanner,
		TweenInfo.new(WARNING_SLIDE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, 0, 0, -80) }
	)
	tween:Play()
	tween.Completed:Connect(function()
		warningBanner.Visible = false
	end)
end

local function tickWarning(token: number, secondsLeft: number, emotionText: string)
	if token ~= warningToken then
		return
	end

	if secondsLeft <= 0 then
		dismissWarningBanner()
		return
	end

	warningLabel.Text = `INCOMING: {emotionText} SURGE IN {secondsLeft}s`

	task.delay(1, function()
		tickWarning(token, secondsLeft - 1, emotionText)
	end)
end

boostWarningRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local nextEmotion = payload.nextEmotion
	local warningDuration = payload.warningDuration or 60

	warningToken += 1
	local token = warningToken

	local isMystery = nextEmotion == "Mystery"
	warningBanner.BackgroundColor3 = isMystery and Color3.fromHSV(0, 1, 1)
		or (Constants.EMOTION_COLORS[nextEmotion] or Color3.new(1, 1, 1))

	warningBanner.Position = UDim2.new(0.5, 0, 0, -80)
	warningBanner.Visible = true

	TweenService:Create(
		warningBanner,
		TweenInfo.new(WARNING_SLIDE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 20) }
	):Play()

	local emotionText = isMystery and "???" or string.upper(nextEmotion)
	tickWarning(token, warningDuration, emotionText)

	if isMystery then
		task.spawn(function()
			while warningToken == token and warningBanner.Visible do
				warningBanner.BackgroundColor3 = Color3.fromHSV(os.clock() % 1, 1, 1)
				task.wait(RAINBOW_CYCLE_STEP)
			end
		end)
	end
end)

local function updateHudText(emotion: string, emotions: { string }?, multiplier: number, secondsLeft: number)
	if emotions then
		hudLabel.Text = `{string.upper(emotions[1])} + {string.upper(emotions[2])} SURGE — {multiplier}x — {secondsLeft}s`
	elseif emotion == "Mystery" then
		hudLabel.Text = `??? SURGE — {multiplier}x — {secondsLeft}s`
	elseif emotion == "All" then
		hudLabel.Text = `VOID STORM — {multiplier}x ALL — {secondsLeft}s`
	else
		hudLabel.Text = `{string.upper(emotion)} SURGE — {multiplier}x — {secondsLeft}s`
	end
end

local function tickHud(token: number, endTime: number, emotion: string, emotions: { string }?, multiplier: number)
	if token ~= hudToken then
		return
	end

	local secondsLeft = math.max(math.floor(endTime - os.time()), 0)
	updateHudText(emotion, emotions, multiplier, secondsLeft)

	if secondsLeft <= 0 then
		return
	end

	task.delay(1, function()
		tickHud(token, endTime, emotion, emotions, multiplier)
	end)
end

local function playFlash(color: Color3)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.8
	TweenService:Create(flash, TweenInfo.new(FLASH_DURATION), { BackgroundTransparency = 1 }):Play()
end

boostStartedRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	dismissWarningBanner()

	local emotion = payload.emotion
	local emotions = payload.emotions :: { string }?
	local multiplier = payload.multiplier
	local durationSeconds = payload.durationSeconds or 0

	local color
	if emotions then
		color = Constants.EMOTION_COLORS[emotions[1]] or Color3.new(1, 1, 1)
	elseif emotion == "All" then
		color = VOID_STORM_COLOR
	elseif emotion == "Mystery" then
		color = Color3.fromHSV(os.clock() % 1, 1, 1)
	else
		color = Constants.EMOTION_COLORS[emotion] or Color3.new(1, 1, 1)
	end

	playFlash(color)

	hud.BackgroundColor3 = color
	hud.BackgroundTransparency = 0.4
	hudLabel.TextTransparency = 0
	hud.Visible = true

	local endTime = os.time() + durationSeconds

	shared.BoostClient = {
		isActive = true,
		emotion = emotion,
		emotions = emotions,
		multiplier = multiplier,
		endTime = endTime,
	}

	hudToken += 1
	local token = hudToken

	tickHud(token, endTime, emotion, emotions, multiplier)

	if emotion == "Mystery" then
		task.spawn(function()
			while hudToken == token and hud.Visible do
				hud.BackgroundColor3 = Color3.fromHSV(os.clock() % 1, 1, 1)
				task.wait(RAINBOW_CYCLE_STEP)
			end
		end)
	end
end)

boostEndedRemote.OnClientEvent:Connect(function()
	hudToken += 1

	shared.BoostClient = {
		isActive = false,
		emotion = "",
		emotions = nil,
		multiplier = 1,
		endTime = 0,
	}

	local hudTween = TweenService:Create(hud, TweenInfo.new(HUD_FADE_DURATION), { BackgroundTransparency = 1 })
	local labelTween = TweenService:Create(hudLabel, TweenInfo.new(HUD_FADE_DURATION), { TextTransparency = 1 })
	hudTween:Play()
	labelTween:Play()

	hudTween.Completed:Connect(function()
		hud.Visible = false
		hud.BackgroundTransparency = 0.4
		hudLabel.TextTransparency = 0
	end)
end)
