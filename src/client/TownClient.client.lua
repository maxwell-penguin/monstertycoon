local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local RollTable = require(ReplicatedStorage.RollTable)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local townUpdatedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.TOWN_UPDATED) :: RemoteEvent

local FLASH_DURATION = 0.15
local FLOAT_DURATION = 2

local function playLevelUpFlash()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TownLevelUpFlash"
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local tween = TweenService:Create(flash, TweenInfo.new(FLASH_DURATION), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		gui:Destroy()
	end)
end

local function showLevelUpText(newLevel: number)
	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if not rootPart then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TownLevelUpText"
	billboard.Size = UDim2.new(6, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = rootPart
	billboard.Parent = rootPart

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	textLabel.Text = `TOWN LEVEL UP! → {newLevel}`
	textLabel.Parent = billboard

	TweenService:Create(billboard, TweenInfo.new(FLOAT_DURATION), {
		StudsOffset = Vector3.new(0, 8, 0),
	}):Play()

	TweenService:Create(textLabel, TweenInfo.new(FLOAT_DURATION), { TextTransparency = 1 }):Play()

	task.delay(FLOAT_DURATION, function()
		billboard:Destroy()
	end)
end

local lastTownLevel: number? = nil

townUpdatedRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local newLevel = payload.townLevel

	if lastTownLevel and typeof(newLevel) == "number" and newLevel > lastTownLevel then
		playLevelUpFlash()
		showLevelUpText(newLevel)

		if shared.SoundManager then
			shared.SoundManager.PlaySound("townLevelUp")
		end
	end

	lastTownLevel = newLevel

	shared.TownClient = {
		townLevel = payload.townLevel,
		townXP = payload.townXP,
		xpRequired = payload.xpRequired,
		rollProbabilities = payload.rollProbabilities,
	}

	if payload.rollProbabilities then
		print(
			`[TownClient] Town Level {payload.townLevel} probabilities: {RollTable.FormatProbabilities(payload.rollProbabilities)}`
		)
	end
end)
