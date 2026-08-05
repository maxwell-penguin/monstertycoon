local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local eggResultRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.EGG_RESULT) :: RemoteEvent

local COMMON_DECOY_NAMES = { "Sparklet", "Weeper", "Ember", "Shiver", "Mote", "Wisp", "Glumpling", "Furon" }

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local RARITY_RANK: { [string]: number } = {}
for i, rarity in RARITY_ORDER do
	RARITY_RANK[rarity] = i
end

local RARITY_COLORS = {
	Common = Color3.fromRGB(190, 190, 190),
	Uncommon = Color3.fromRGB(100, 220, 120),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 60, 120),
}
local GOLD = Color3.fromRGB(255, 215, 80)
local VOID_DARK = Color3.fromRGB(20, 18, 30)

local SLOT_WIDTH = 70
local SLOT_COUNT = 7
local CENTER_INDEX = 4
local STRIP_WIDTH = SLOT_WIDTH * SLOT_COUNT
-- Centers CENTER_INDEX's slot under the box regardless of slot width/count --
-- the spec's literal "-350" landing value doesn't actually land on a slot
-- boundary for a 7x70 strip, so this is computed instead of hardcoded.
local LANDING_OFFSET = -((CENTER_INDEX - 1) * SLOT_WIDTH + SLOT_WIDTH / 2 - STRIP_WIDTH / 2)

local STRIP_START = UDim2.new(0.5, 350, 0.5, 0)
local LOOP_END = STRIP_START - UDim2.new(0, STRIP_WIDTH, 0, 0)
local LOOP_DURATION = 0.4
local DECEL_DURATION = 1.2
local NAME_CYCLE_INTERVAL = 0.15

local SPIN_CYCLE_NAMES =
	{ "Sparklet", "Weeper", "Ember", "Shiver", "Mote", "Wisp", "Glumpling", "Furon", "Soaker", "Scorcher", "Cryo", "Inferno" }

local function rarityColor(rarity: string): Color3
	return RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
end

local function emotionColorForResult(result: any): Color3
	local warehouseClient = shared.WarehouseClient
	local monster = warehouseClient and warehouseClient.monsters and warehouseClient.monsters[result.newInstanceId]
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

-- Only one reveal sequence is ever active. A fresh roll while one is
-- mid-flight destroys the old overlay immediately; revealToken invalidates
-- that old sequence's pending Connect/task.delay callbacks so they no-op
-- instead of mutating an abandoned frame.
local activeFrame: Instance? = nil
local revealToken = 0

local function clearActive()
	if activeFrame then
		activeFrame:Destroy()
		activeFrame = nil
	end
end

local function randomDecoyName(): string
	return COMMON_DECOY_NAMES[math.random(1, #COMMON_DECOY_NAMES)]
end

local function randomCycleName(): string
	return SPIN_CYCLE_NAMES[math.random(1, #SPIN_CYCLE_NAMES)]
end

local function createSlotLabel(strip: Frame, index: number, text: string)
	local label = Instance.new("TextLabel")
	label.Name = "Slot" .. index
	label.Size = UDim2.new(0, SLOT_WIDTH, 1, 0)
	label.Position = UDim2.new(0, (index - 1) * SLOT_WIDTH, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = strip
end

local function buildSlotMachineFrame(parent: Instance, boxYScale: number): (Frame, Frame)
	local box = Instance.new("Frame")
	box.Name = "SlotBox"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.new(0.5, 0, boxYScale, 0)
	box.Size = UDim2.new(0, 500, 0, 140)
	box.BackgroundColor3 = VOID_DARK
	box.ClipsDescendants = true
	box.Parent = parent

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.AnchorPoint = Vector2.new(0, 0.5)
	strip.Size = UDim2.new(0, STRIP_WIDTH, 1, 0)
	strip.Position = STRIP_START
	strip.BackgroundTransparency = 1
	strip.Parent = box

	local highlight = Instance.new("Frame")
	highlight.Name = "CenterHighlight"
	highlight.AnchorPoint = Vector2.new(0.5, 0.5)
	highlight.Position = UDim2.fromScale(0.5, 0.5)
	highlight.Size = UDim2.new(0, SLOT_WIDTH, 1, 0)
	highlight.BackgroundTransparency = 1
	highlight.Parent = box

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = GOLD
	stroke.Parent = highlight

	return box, strip
end

-- loopCount full-width loops at constant speed (the "spinning reel" illusion:
-- tween one strip-width left, then instantly snap back to start with no
-- tween and repeat), then one decelerating tween to LANDING_OFFSET. The
-- center slot's text cycles independently via task.delay while looping and
-- freezes on the real result the instant deceleration lands.
local function spinSlotMachine(strip: Frame, resultName: string, loopCount: number, onLanded: () -> ())
	for i = 1, SLOT_COUNT do
		createSlotLabel(strip, i, (i == CENTER_INDEX) and randomCycleName() or randomDecoyName())
	end

	local centerLabel = strip:FindFirstChild("Slot" .. CENTER_INDEX) :: TextLabel
	local spinning = true

	local function cycleName()
		if not spinning then
			return
		end
		centerLabel.Text = randomCycleName()
		task.delay(NAME_CYCLE_INTERVAL, cycleName)
	end
	task.delay(NAME_CYCLE_INTERVAL, cycleName)

	local function runLoop(remaining: number)
		local loopTween = TweenService:Create(strip, TweenInfo.new(LOOP_DURATION, Enum.EasingStyle.Linear), {
			Position = LOOP_END,
		})

		loopTween.Completed:Connect(function()
			strip.Position = STRIP_START

			if remaining > 1 then
				runLoop(remaining - 1)
				return
			end

			spinning = false

			local decelTween = TweenService:Create(strip, TweenInfo.new(DECEL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, LANDING_OFFSET, 0.5, 0),
			})
			decelTween.Completed:Connect(function()
				centerLabel.Text = resultName
				onLanded()
			end)
			decelTween:Play()
		end)
		loopTween:Play()
	end

	strip.Position = STRIP_START
	runLoop(loopCount)
end

-- x1: single spin, big result name below the strip, then a rarity flash.
local function playSlotMachineX1(result: any)
	local token = revealToken
	local gui = getRevealGui()

	local overlay = Instance.new("Frame")
	overlay.Name = "RollOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Parent = gui
	activeFrame = overlay

	local box, strip = buildSlotMachineFrame(overlay, 0.45)

	local resultLabel = Instance.new("TextLabel")
	resultLabel.Name = "ResultLabel"
	resultLabel.AnchorPoint = Vector2.new(0.5, 0)
	resultLabel.Position = UDim2.new(0.5, 0, 1, 20)
	resultLabel.Size = UDim2.new(1, 0, 0, 50)
	resultLabel.BackgroundTransparency = 1
	resultLabel.Font = Enum.Font.GothamBlack
	resultLabel.TextScaled = true
	resultLabel.TextColor3 = emotionColorForResult(result)
	resultLabel.Text = ""
	resultLabel.Parent = box

	spinSlotMachine(strip, result.monsterName, 3, function()
		if token ~= revealToken then
			return
		end

		resultLabel.Text = result.monsterName

		task.delay(0.3, function()
			if token ~= revealToken then
				return
			end

			if shared.SoundManager then
				shared.SoundManager.PlaySound("roll", result.rarity)
			end
			if shared.ScreenEffects then
				shared.ScreenEffects.RarityFlash(result.rarity)
			end

			overlay:Destroy()
			if activeFrame == overlay then
				activeFrame = nil
			end
		end)
	end)
end

local RESULT_CARD_WIDTH = 180
local RESULT_CARD_HEIGHT = 50
local RESULT_CARD_GAP = 55

local function createResultCard(parent: Instance, index: number, result: any): Frame
	local card = Instance.new("Frame")
	card.Name = "ResultCard" .. index
	card.Position = UDim2.new(0, 20, 0, 20 + (index - 1) * RESULT_CARD_GAP)
	card.Size = UDim2.new(0, RESULT_CARD_WIDTH, 0, RESULT_CARD_HEIGHT)
	card.BackgroundColor3 = VOID_DARK
	card.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = rarityColor(result.rarity)
	label.Text = `{result.monsterName} ({result.rarity})`
	label.Parent = card

	return card
end

-- x5: same slot machine at 2 loops per spin (vs. 3 for x1) to keep pace,
-- each landing into a stacking result card.
local function playFiveSpin(results: { any })
	local token = revealToken
	local gui = getRevealGui()

	local overlay = Instance.new("Frame")
	overlay.Name = "RollOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.Parent = gui
	activeFrame = overlay

	local cardsHolder = Instance.new("Frame")
	cardsHolder.Name = "Cards"
	cardsHolder.Size = UDim2.fromScale(1, 1)
	cardsHolder.BackgroundTransparency = 1
	cardsHolder.Parent = overlay

	local function finishAll()
		task.delay(1, function()
			if token ~= revealToken then
				return
			end

			for _, card in cardsHolder:GetChildren() do
				if card:IsA("Frame") then
					TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Position = card.Position + UDim2.new(0, 700, 0, 0),
					}):Play()
				end
			end

			task.delay(0.4, function()
				if token ~= revealToken then
					return
				end
				overlay:Destroy()
				if activeFrame == overlay then
					activeFrame = nil
				end
			end)
		end)
	end

	local function runSpin(index: number)
		if token ~= revealToken then
			return
		end

		if index > #results then
			finishAll()
			return
		end

		local result = results[index]
		local box, strip = buildSlotMachineFrame(overlay, 0.3)

		spinSlotMachine(strip, result.monsterName, 2, function()
			if token ~= revealToken then
				return
			end

			box:Destroy()

			local card = createResultCard(cardsHolder, index, result)
			if (RARITY_RANK[result.rarity] or 0) >= RARITY_RANK.Rare then
				TweenService:Create(
					card,
					TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ BackgroundColor3 = rarityColor(result.rarity) }
				):Play()
			end

			runSpin(index + 1)
		end)
	end

	runSpin(1)
end

local GRID_COLS = 5
local GRID_ROWS = 2
local CARD_W = 120
local CARD_H = 80
local CARD_GAP = 10
local FLIP_LEG_TIME = 0.08
local FLIP_STAGGER = 0.08

-- x10: skips the slot machine, flips a 5x2 grid of face-down cards instead.
local function playGridFlip(results: { any })
	local token = revealToken
	local gui = getRevealGui()

	local overlay = Instance.new("Frame")
	overlay.Name = "RollOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Parent = gui
	activeFrame = overlay

	local gridWidth = GRID_COLS * CARD_W + (GRID_COLS - 1) * CARD_GAP
	local gridHeight = GRID_ROWS * CARD_H + (GRID_ROWS - 1) * CARD_GAP

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.AnchorPoint = Vector2.new(0.5, 0.5)
	grid.Position = UDim2.fromScale(0.5, 0.5)
	grid.Size = UDim2.new(0, gridWidth, 0, gridHeight)
	grid.BackgroundTransparency = 1
	grid.Parent = overlay

	local cardCount = math.min(#results, GRID_COLS * GRID_ROWS)
	local cards: { Frame } = {}

	for i = 1, cardCount do
		local col = (i - 1) % GRID_COLS
		local row = math.floor((i - 1) / GRID_COLS)

		local card = Instance.new("Frame")
		card.Name = "Card" .. i
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.new(0, col * (CARD_W + CARD_GAP) + CARD_W / 2, 0, row * (CARD_H + CARD_GAP) + CARD_H / 2)
		card.Size = UDim2.new(0, CARD_W, 0, CARD_H)
		card.BackgroundColor3 = VOID_DARK
		card.Parent = grid

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = ""
		label.Parent = card

		cards[i] = card
	end

	local flippedCount = 0

	local function allFlippedDone()
		task.delay(2, function()
			if token ~= revealToken then
				return
			end

			local exitTween = TweenService:Create(grid, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, -0.5, 0),
			})
			exitTween.Completed:Connect(function()
				overlay:Destroy()
				if activeFrame == overlay then
					activeFrame = nil
				end
			end)
			exitTween:Play()
		end)
	end

	local function flipOneCard(index: number)
		if token ~= revealToken then
			return
		end

		local card = cards[index]
		local result = results[index]
		local label = card:FindFirstChildOfClass("TextLabel") :: TextLabel?

		local closeTween = TweenService:Create(card, TweenInfo.new(FLIP_LEG_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, CARD_H),
		})

		closeTween.Completed:Connect(function()
			if token ~= revealToken then
				return
			end

			if (RARITY_RANK[result.rarity] or 0) >= RARITY_RANK.Rare then
				card.BackgroundColor3 = rarityColor(result.rarity)
				card.BackgroundTransparency = 0.3
			else
				card.BackgroundColor3 = VOID_DARK
				card.BackgroundTransparency = 0
			end

			if label then
				label.Text = result.monsterName
				label.TextColor3 = rarityColor(result.rarity)
			end

			local openTween = TweenService:Create(card, TweenInfo.new(FLIP_LEG_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, CARD_W, 0, CARD_H),
			})

			openTween.Completed:Connect(function()
				if token ~= revealToken then
					return
				end

				if result.rarity == "Legendary" then
					TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
						BackgroundColor3 = GOLD,
					}):Play()

					task.delay(1, function()
						if token ~= revealToken then
							return
						end
						TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
							BackgroundColor3 = rarityColor("Legendary"),
						}):Play()
					end)
				elseif result.rarity == "Mythic" then
					for otherIndex, otherCard in cards do
						if otherIndex ~= index then
							TweenService:Create(otherCard, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
								BackgroundTransparency = 0.7,
							}):Play()
						end
					end
					TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Size = UDim2.new(0, CARD_W * 1.5, 0, CARD_H * 1.5),
					}):Play()
				end

				flippedCount += 1
				if flippedCount >= cardCount then
					allFlippedDone()
				end
			end)
			openTween:Play()
		end)
		closeTween:Play()
	end

	for i = 1, cardCount do
		task.delay((i - 1) * FLIP_STAGGER, function()
			flipOneCard(i)
		end)
	end
end

local function startReveal(results: { any })
	local successResults = {}
	for _, result in results do
		if result.success then
			table.insert(successResults, result)
		end
	end

	if #successResults == 0 then
		return
	end

	revealToken += 1
	clearActive()

	if #successResults == 1 then
		playSlotMachineX1(successResults[1])
	elseif #successResults <= 5 then
		playFiveSpin(successResults)
	else
		playGridFlip(successResults)
	end
end

-- The server fires one EGG_RESULT per roll, back to back with no yields
-- between them for a batch (RollManager.PerformBatchRoll loops PerformRoll,
-- which fires its own event each call) -- there's no single "batch" event.
-- This debounce groups whatever arrives within a short window into one batch
-- before deciding which reveal (x1/x5/x10) to play.
local pendingBatch: { any } = {}
local batchGeneration = 0
local BATCH_DEBOUNCE = 0.12

eggResultRemote.OnClientEvent:Connect(function(result: any)
	if typeof(result) ~= "table" then
		return
	end

	shared.RollClient = {
		lastResult = result,
		lastResultTime = os.clock(),
	}

	table.insert(pendingBatch, result)
	batchGeneration += 1
	local generation = batchGeneration

	task.delay(BATCH_DEBOUNCE, function()
		if generation ~= batchGeneration then
			return
		end
		local results = pendingBatch
		pendingBatch = {}
		startReveal(results)
	end)
end)
