local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local eggResultRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.EGG_RESULT) :: RemoteEvent

local function getResultColor(newInstanceId: string): Color3
	local warehouseClient = shared.WarehouseClient
	local monster = warehouseClient and warehouseClient.monsters and warehouseClient.monsters[newInstanceId]
	if monster and monster.element then
		return Constants.ELEMENT_COLORS[monster.element] or Color3.new(1, 1, 1)
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

-- The full-screen flash/vignette/darken portion of each reveal used to be built
-- inline here; Phase 19 centralizes that in ScreenEffects.RarityFlash. What's left
-- in each reveal* function below is the parts specific to the roll reveal itself
-- (name label, spotlight, camera shake) that aren't just "a screen flash".
local function revealCommon(color: Color3, monsterName: string)
	local gui = getRevealGui()
	createNameLabel(gui, monsterName, color, 2)

	task.delay(1, function()
		gui:Destroy()
	end)
end

local function revealRare(color: Color3, monsterName: string)
	local gui = getRevealGui()
	createNameLabel(gui, monsterName, color, 3)

	task.delay(2, function()
		gui:Destroy()
	end)
end

local function revealEpic(_color: Color3, monsterName: string)
	local gui = getRevealGui()
	createNameLabel(gui, monsterName, Color3.new(1, 1, 1), 5)

	task.delay(3, function()
		gui:Destroy()
	end)
end

local function revealLegendary(color: Color3, monsterName: string)
	local gui = getRevealGui()

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

	task.delay(4, function()
		if light then
			light:Destroy()
		end
		gui:Destroy()
	end)
end

local function revealMythic(color: Color3, monsterName: string)
	local gui = getRevealGui()

	task.delay(1, function()
		local label = createNameLabel(gui, monsterName, color, 6)
		label.Size = UDim2.fromScale(0, 0)

		TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.8, 0.3),
		}):Play()

		shakeCamera(0.3)

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

	if shared.SoundManager then
		shared.SoundManager.PlaySound("roll", result.rarity)
	end

	if shared.ScreenEffects then
		shared.ScreenEffects.RarityFlash(result.rarity)
	end

	local color = getResultColor(result.newInstanceId)
	local handler = RARITY_HANDLERS[result.rarity]
	if handler then
		handler(color, result.monsterName)
	end
end)
