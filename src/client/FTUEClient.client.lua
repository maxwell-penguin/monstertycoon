local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local ftueStepRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.FTUE_STEP) :: RemoteEvent
local ftueProgressRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.FTUE_PROGRESS) :: RemoteEvent
local updateBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_BAG) :: RemoteEvent
local depositBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.DEPOSIT_BAG) :: RemoteEvent
local eggResultRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.EGG_RESULT) :: RemoteEvent
local mergeMonstersRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.MERGE_MONSTERS) :: RemoteEvent
local vialSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.VIAL_SPAWNED) :: RemoteEvent

local ALL_PANEL_NAMES = { "HUD", "WarehousePanel", "RollPanel", "HallPanel", "ShopPanel" }
local ARROW_BOB_HEIGHT = 0.5
local ARROW_BOB_PERIOD = 0.8

local currentStep = ""
local firedSteps: { [string]: boolean } = {}
local ftueArrows: { BasePart } = {}
local ftueHighlightTweens: { Tween } = {}
local lastBagCount = 0

--============================================================
-- Progress reporting
--============================================================

local function reportProgress(stepName: string)
	if firedSteps[stepName] then
		return
	end
	firedSteps[stepName] = true
	ftueProgressRemote:FireServer({ stepName = stepName })
end

--============================================================
-- Arrow management
--============================================================

local function destroyAllArrows()
	for _, arrow in ftueArrows do
		arrow:Destroy()
	end
	ftueArrows = {}

	for _, tween in ftueHighlightTweens do
		tween:Cancel()
	end
	ftueHighlightTweens = {}
end

local function createArrow(position: Vector3): WedgePart
	local arrow = Instance.new("WedgePart")
	arrow.Name = "FTUEArrow"
	arrow.Size = Vector3.new(2, 1, 4)
	arrow.Material = Enum.Material.Neon
	arrow.Color = Constants.ELEMENT_COLORS.Thunder
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.Position = position
	arrow.Parent = Workspace

	table.insert(ftueArrows, arrow)

	local bobTween = TweenService:Create(
		arrow,
		TweenInfo.new(ARROW_BOB_PERIOD, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = position + Vector3.new(0, ARROW_BOB_HEIGHT, 0) }
	)
	bobTween:Play()

	return arrow
end

-- Arrows are 3D world Parts; the ROLL/WAREHOUSE buttons they point toward are
-- fixed 2D screen-space HUD elements with no world position, so there's no exact
-- world point to place an arrow "at". This places it near the player as a general
-- "check your UI" cue rather than attempting a screen-to-world projection.
local function createUIPointerArrow()
	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if not rootPart then
		return
	end

	local position = rootPart.Position + rootPart.CFrame.LookVector * 3 + Vector3.new(0, -1, 0)
	createArrow(position)
end

local function findNearestVial(): BasePart?
	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if not rootPart then
		return nil
	end

	local nearest: BasePart? = nil
	local nearestDistance = math.huge

	for _, part in Workspace:GetChildren() do
		if part:IsA("BasePart") and part.Name:sub(1, 5) == "Vial_" then
			local ownerIdValue = part:FindFirstChild("OwnerId")
			if ownerIdValue and ownerIdValue.Value == tostring(player.UserId) then
				local distance = (rootPart.Position - part.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearest = part
				end
			end
		end
	end

	return nearest
end

local function findDropbox(): BasePart?
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end

	for _, plotModel in plotsFolder:GetChildren() do
		local ownerId = plotModel:FindFirstChild("OwnerId")
		if ownerId and ownerId.Value == tostring(player.UserId) then
			local dropbox = plotModel:FindFirstChild("Dropbox")
			if dropbox and dropbox:IsA("BasePart") then
				return dropbox
			end
		end
	end

	return nil
end

--============================================================
-- Hint text
--============================================================

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "FTUEHintGui"
hintGui.IgnoreGuiInset = true
hintGui.ResetOnSpawn = false
hintGui.Parent = playerGui

local hintFrame = Instance.new("Frame")
hintFrame.Name = "FTUEHint"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -80)
hintFrame.Size = UDim2.new(0, 500, 0, 50)
hintFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
hintFrame.BackgroundTransparency = 0.3
hintFrame.BorderSizePixel = 0
hintFrame.Visible = false
hintFrame.Parent = hintGui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 8)
hintCorner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.fromScale(1, 1)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextSize = 20
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextWrapped = true
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local function setHint(text: string)
	hintFrame.Visible = true

	local fadeOut = TweenService:Create(hintLabel, TweenInfo.new(0.2), { TextTransparency = 1 })
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		hintLabel.Text = text
		TweenService:Create(hintLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	end)
end

local function clearHint()
	hintFrame.Visible = false
end

--============================================================
-- Welcome overlay (step "start")
--============================================================

local overlayGui = Instance.new("ScreenGui")
overlayGui.Name = "FTUEOverlayGui"
overlayGui.IgnoreGuiInset = true
overlayGui.ResetOnSpawn = false
overlayGui.Parent = playerGui

local overlayFrame = Instance.new("Frame")
overlayFrame.Name = "Overlay"
overlayFrame.Size = UDim2.fromScale(1, 1)
overlayFrame.BackgroundColor3 = Color3.new(0, 0, 0)
overlayFrame.BackgroundTransparency = 1
overlayFrame.BorderSizePixel = 0
overlayFrame.Visible = false
overlayFrame.Parent = overlayGui

local overlayText = Instance.new("TextLabel")
overlayText.AnchorPoint = Vector2.new(0.5, 0.5)
overlayText.Position = UDim2.fromScale(0.5, 0.5)
overlayText.Size = UDim2.new(0, 700, 0, 60)
overlayText.BackgroundTransparency = 1
overlayText.Font = Enum.Font.GothamBold
overlayText.TextSize = 32
overlayText.TextColor3 = Color3.new(1, 1, 1)
overlayText.TextTransparency = 1
overlayText.Text = "Welcome to Void Factory"
overlayText.Parent = overlayFrame

local function removeOverlay()
	overlayFrame.Visible = false
	overlayFrame.BackgroundTransparency = 1
	overlayText.TextTransparency = 1
end

--============================================================
-- Warehouse merge-button highlight (step "merge_tutorial")
--============================================================

local function highlightSparkletMergeButtons()
	local screenGui = playerGui:FindFirstChild("VoidFactoryUI")
	local warehousePanel = screenGui and screenGui:FindFirstChild("WarehousePanel")
	local monsterList = warehousePanel and warehousePanel:FindFirstChild("MonsterList")
	local warehouseState = shared.WarehouseClient

	if not monsterList or not warehouseState then
		return
	end

	for instanceId, monster in warehouseState.monsters do
		if monster.name == "Sparklet" then
			local entry = monsterList:FindFirstChild("Entry_" .. instanceId)
			local mergeButton = entry and entry:FindFirstChild("MERGE")
			if mergeButton and not mergeButton:FindFirstChildOfClass("UIStroke") then
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.fromRGB(255, 210, 60)
				stroke.Thickness = 3
				stroke.Parent = mergeButton

				local pulseTween = TweenService:Create(
					stroke,
					TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Thickness = 1 }
				)
				pulseTween:Play()
				table.insert(ftueHighlightTweens, pulseTween)
			end
		end
	end
end

--============================================================
-- Completion celebration (step "complete")
--============================================================

local function playCompletionCelebration(firstBoostActive: boolean)
	removeOverlay()
	destroyAllArrows()
	clearHint()

	local gui = Instance.new("ScreenGui")
	gui.Name = "FTUECelebrationGui"
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
	flash.BackgroundTransparency = 0
	flash.BorderSizePixel = 0
	flash.Parent = gui
	TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()

	local titleLabel = Instance.new("TextLabel")
	titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	titleLabel.Position = UDim2.new(0.5, 0, 0.4, 0)
	titleLabel.Size = UDim2.new(0, 700, 0, 80)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 48
	titleLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
	titleLabel.Text = "VOID FACTORY"
	titleLabel.Parent = gui

	local titleScale = Instance.new("UIScale")
	titleScale.Scale = 0.5
	titleScale.Parent = titleLabel
	TweenService:Create(titleScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitleLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	subtitleLabel.Size = UDim2.new(0, 700, 0, 40)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextSize = 24
	subtitleLabel.TextColor3 = Color3.new(1, 1, 1)
	subtitleLabel.TextTransparency = 1
	subtitleLabel.Text = "Your factory is open!"
	subtitleLabel.Parent = gui

	task.delay(0.5, function()
		TweenService:Create(subtitleLabel, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	end)

	local boostLabel: TextLabel? = nil
	if firstBoostActive then
		boostLabel = Instance.new("TextLabel")
		boostLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		boostLabel.Position = UDim2.new(0.5, 0, 0.58, 0)
		boostLabel.Size = UDim2.new(0, 700, 0, 32)
		boostLabel.BackgroundTransparency = 1
		boostLabel.Font = Enum.Font.GothamBold
		boostLabel.TextSize = 20
		boostLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
		boostLabel.TextTransparency = 1
		boostLabel.Text = "JOY SURGE ACTIVE — 3x earnings!"
		boostLabel.Parent = gui

		task.delay(0.8, function()
			TweenService:Create(boostLabel :: TextLabel, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		end)
	end

	task.delay(3, function()
		local fadeOuts = {
			TweenService:Create(titleLabel, TweenInfo.new(0.5), { TextTransparency = 1 }),
			TweenService:Create(subtitleLabel, TweenInfo.new(0.5), { TextTransparency = 1 }),
		}
		if boostLabel then
			table.insert(fadeOuts, TweenService:Create(boostLabel, TweenInfo.new(0.5), { TextTransparency = 1 }))
		end

		for _, tween in fadeOuts do
			tween:Play()
		end

		task.delay(0.5, function()
			gui:Destroy()
		end)
	end)

	if shared.UIManager then
		shared.UIManager.ShowPanel("HUD")
	end

	shared.FTUEClient = { isComplete = true }
end

--============================================================
-- Step dispatch
--============================================================

local function handleStart()
	if shared.UIManager then
		for _, panelName in ALL_PANEL_NAMES do
			shared.UIManager.HidePanel(panelName)
		end
	end

	overlayFrame.Visible = true
	overlayFrame.BackgroundTransparency = 1
	overlayText.TextTransparency = 1

	TweenService:Create(overlayFrame, TweenInfo.new(0.3), { BackgroundTransparency = 0.3 }):Play()
	TweenService:Create(overlayText, TweenInfo.new(1), { TextTransparency = 0 }):Play()

	task.delay(2, function()
		local fadeOverlay = TweenService:Create(overlayFrame, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		local fadeText = TweenService:Create(overlayText, TweenInfo.new(0.5), { TextTransparency = 1 })
		fadeOverlay:Play()
		fadeText:Play()

		fadeOverlay.Completed:Connect(function()
			overlayFrame.Visible = false

			-- HUD (and the ROLL/WAREHOUSE/HALL toggle buttons that live inside it)
			-- needs to come back so the rest of the tutorial is actually usable;
			-- the spec only calls out re-showing it at "complete" but that would
			-- leave the player unable to click anything for the whole sequence.
			if shared.UIManager then
				shared.UIManager.ShowPanel("HUD")
			end
		end)
	end)
end

local function handleMonstersPlaced()
	destroyAllArrows()
	setHint("Collect the vials!")

	local existingVial = findNearestVial()
	if existingVial then
		createArrow(existingVial.Position + Vector3.new(0, 3, 0))
	end
end

-- These next three steps' arrow/hint were already created by the corresponding
-- client-detection handler below (vial_collected/vial_sold/egg_rolled fire before
-- the server's next official step arrives) -- only fall back to creating one here
-- if it's somehow missing, and otherwise just reinforce the hint text.
local function handleSellNow()
	setHint("Walk into the SELL box to deposit!")

	if #ftueArrows == 0 then
		local dropbox = findDropbox()
		if dropbox then
			createArrow(dropbox.Position + Vector3.new(0, 3, 0))
		end
	end
end

local function handleRollNow()
	setHint("Press ROLL to get a new monster!")

	if #ftueArrows == 0 then
		createUIPointerArrow()
	end
end

local function handleMergeTutorial()
	setHint("Open your Warehouse and merge 3 matching monsters!")

	if #ftueArrows == 0 then
		createUIPointerArrow()
	end

	if shared.UIManager then
		shared.UIManager.ShowPanel("WarehousePanel")
	end

	task.spawn(function()
		while currentStep == "merge_tutorial" do
			highlightSparkletMergeButtons()
			task.wait(0.5)
		end
	end)
end

local function handleComplete(payload: any)
	destroyAllArrows()
	clearHint()
	playCompletionCelebration(payload.firstBoostActive == true)
end

local STEP_HANDLERS: { [string]: (any) -> () } = {
	start = handleStart,
	monsters_placed = handleMonstersPlaced,
	sell_now = handleSellNow,
	roll_now = handleRollNow,
	merge_tutorial = handleMergeTutorial,
	complete = handleComplete,
}

ftueStepRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local stepName = payload.stepName
	currentStep = stepName

	local handler = STEP_HANDLERS[stepName]
	if handler then
		handler(payload)
	end
end)

--============================================================
-- Client-side step detection
--============================================================

vialSpawnedRemote.OnClientEvent:Connect(function(_vialId: string, position: Vector3)
	if currentStep == "monsters_placed" and #ftueArrows == 0 then
		createArrow(position + Vector3.new(0, 3, 0))
	end
end)

updateBagRemote.OnClientEvent:Connect(function(bagState: any)
	if typeof(bagState) ~= "table" then
		return
	end

	local newCount = bagState.currentCount or 0

	if currentStep == "monsters_placed" and lastBagCount == 0 and newCount > 0 then
		reportProgress("vial_collected")

		destroyAllArrows()
		setHint("Bring them to the SELL box!")

		local dropbox = findDropbox()
		if dropbox then
			createArrow(dropbox.Position + Vector3.new(0, 3, 0))
		end
	end

	lastBagCount = newCount
end)

depositBagRemote.OnClientEvent:Connect(function(_totalEarned: number, _vialCount: number)
	if currentStep == "sell_now" then
		reportProgress("vial_sold")

		destroyAllArrows()
		setHint("You earned coins! Now roll for a monster!")
		createUIPointerArrow()
	end
end)

eggResultRemote.OnClientEvent:Connect(function(result: any)
	if currentStep == "roll_now" and typeof(result) == "table" and result.success then
		reportProgress("egg_rolled")

		destroyAllArrows()
		setHint("You got a monster! Now merge 3 of the same type!")
		createUIPointerArrow()
	end
end)

mergeMonstersRemote.OnClientEvent:Connect(function(result: any)
	if currentStep == "merge_tutorial" and typeof(result) == "table" and result.success then
		reportProgress("merge_complete")

		destroyAllArrows()
		clearHint()
	end
end)
