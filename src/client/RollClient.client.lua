local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local eggResultRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.EGG_RESULT) :: RemoteEvent

local function getResultColor(newInstanceId: string): Color3
	local warehouseClient = shared.WarehouseClient
	local monster = warehouseClient and warehouseClient.monsters and warehouseClient.monsters[newInstanceId]
	if monster and monster.emotion then
		return Constants.EMOTION_COLORS[monster.emotion] or Color3.new(1, 1, 1)
	end
	return Color3.new(1, 1, 1)
end

local function getRevealGui(): ScreenGui
	local existing = playerGui:FindFirstChild("RollRevealGui")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "RollRevealGui"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = playerGui
	return gui
end

local function createNameLabel(gui: ScreenGui, text: string, color: Color3, strokeThickness: number): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.8, 0.3)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = strokeThickness
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label

	return label
end

local function playPlaceholderSound()
	local sound = Instance.new("Sound")
	sound.Name = "RollRevealSound"
	sound.Volume = 0.5
	sound.Parent = SoundService
	sound:Play()

	task.delay(2, function()
		sound:Destroy()
	end)
end

local function shakeCamera(duration: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local startTime = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if os.clock() - startTime >= duration then
			connection:Disconnect()
			return
		end

		local offset = CFrame.new((math.random() * 2 - 1) * 0.3, (math.random() * 2 - 1) * 0.3, 0)
		camera.CFrame = camera.CFrame * offset
	end)
end

local function revealCommon(color: Color3, monsterName: string)
	local gui = getRevealGui()

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.5
	flash.BorderSizePixel = 0
	flash.Parent = gui

	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	createNameLabel(gui, monsterName, color, 2)

	task.delay(1, function()
		gui:Destroy()
	end)
end

local function revealRare(color: Color3, monsterName: string)
	local gui = getRevealGui()

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 14
	stroke.Color = color
	stroke.Parent = frame

	createNameLabel(gui, monsterName, color, 3)

	task.delay(2, function()
		gui:Destroy()
	end)
end

local function revealEpic(color: Color3, monsterName: string)
	local gui = getRevealGui()

	local vignette = Instance.new("Frame")
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = color
	vignette.BackgroundTransparency = 0.6
	vignette.BorderSizePixel = 0
	vignette.Parent = gui

	createNameLabel(gui, monsterName, Color3.new(1, 1, 1), 5)

	task.delay(3, function()
		gui:Destroy()
	end)
end

local function revealLegendary(color: Color3, monsterName: string)
	local gui = getRevealGui()

	local dark = Instance.new("Frame")
	dark.Size = UDim2.fromScale(1, 1)
	dark.BackgroundColor3 = Color3.new(0, 0, 0)
	dark.BackgroundTransparency = 0.15
	dark.BorderSizePixel = 0
	dark.Parent = gui

	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	local light: PointLight? = nil
	if rootPart then
		light = Instance.new("PointLight")
		light.Color = color
		light.Range = 30
		light.Brightness = 5
		light.Parent = rootPart
	end

	createNameLabel(gui, monsterName, color, 6)
	playPlaceholderSound()

	task.delay(4, function()
		if light then
			light:Destroy()
		end
		gui:Destroy()
	end)
end

local function revealMythic(color: Color3, monsterName: string)
	local gui = getRevealGui()

	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 0
	black.BorderSizePixel = 0
	black.Parent = gui

	task.delay(1, function()
		local label = createNameLabel(gui, monsterName, color, 6)
		label.Size = UDim2.fromScale(0, 0)

		TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.8, 0.3),
		}):Play()

		TweenService:Create(black, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()

		shakeCamera(0.3)
		playPlaceholderSound()

		task.delay(2, function()
			gui:Destroy()
		end)
	end)
end

local RARITY_HANDLERS = {
	Common = revealCommon,
	Uncommon = revealCommon,
	Rare = revealRare,
	Epic = revealEpic,
	Legendary = revealLegendary,
	Mythic = revealMythic,
}

eggResultRemote.OnClientEvent:Connect(function(result: any)
	if typeof(result) ~= "table" then
		return
	end

	shared.RollClient = {
		lastResult = result,
		lastResultTime = os.clock(),
	}

	if not result.success then
		return
	end

	local color = getResultColor(result.newInstanceId)
	local handler = RARITY_HANDLERS[result.rarity]
	if handler then
		handler(color, result.monsterName)
	end
end)
