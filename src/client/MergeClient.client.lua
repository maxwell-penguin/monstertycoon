local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local mergeMonstersRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.MERGE_MONSTERS) :: RemoteEvent

local MOVE_DURATION = 0.6
local FLASH_DURATION = 0.15
local RESULT_DISPLAY_DURATION = 2

-- Monster visuals don't exist yet (Phase 19); if a placeholder happens to be
-- in the world under this name convention we animate it, otherwise we spawn one.
local function findConsumedVisual(instanceId: string): BasePart?
	local found = Workspace:FindFirstChild("Monster_" .. instanceId, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

local function getResultColor(newInstanceId: string): Color3
	local warehouseClient = shared.WarehouseClient
	local monster = warehouseClient and warehouseClient.monsters and warehouseClient.monsters[newInstanceId]
	if monster and monster.emotion then
		return Constants.EMOTION_COLORS[monster.emotion] or Color3.new(1, 1, 1)
	end
	return Color3.new(1, 1, 1)
end

local function getCenterPosition(): Vector3
	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if rootPart then
		return rootPart.Position + rootPart.CFrame.LookVector * 5 + Vector3.new(0, 2, 0)
	end
	return Vector3.new(0, 5, 0)
end

local function showResultBillboard(position: Vector3, monsterName: string, stars: number)
	local anchor = Instance.new("Part")
	anchor.Name = "MergeResultAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Position = position
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(6, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.Text = stars > 0 and `{monsterName} {string.rep("★", stars)}` or monsterName
	textLabel.Parent = billboard

	task.delay(RESULT_DISPLAY_DURATION, function()
		anchor:Destroy()
	end)
end

local function playMergeAnimation(
	consumedInstanceIds: { string },
	resultMonsterName: string,
	resultStars: number,
	newInstanceId: string
)
	local center = getCenterPosition()
	local color = getResultColor(newInstanceId)
	local spawned = {}

	for i, instanceId in consumedInstanceIds do
		local part = findConsumedVisual(instanceId)
		local isTemp = false

		if not part then
			part = Instance.new("Part")
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.new(2, 2, 2)
			part.Anchored = true
			part.CanCollide = false
			part.Color = color

			local angle = (i / #consumedInstanceIds) * math.pi * 2
			part.Position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 4
			part.Parent = Workspace
			isTemp = true
		end

		table.insert(spawned, { part = part, isTemp = isTemp })

		local moveTween = TweenService:Create(
			part,
			TweenInfo.new(MOVE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = center }
		)
		moveTween:Play()
	end

	task.delay(MOVE_DURATION, function()
		for _, entry in spawned do
			TweenService:Create(entry.part, TweenInfo.new(FLASH_DURATION, Enum.EasingStyle.Linear), {
				Color = Color3.new(1, 1, 1),
			}):Play()
		end

		task.delay(FLASH_DURATION, function()
			for _, entry in spawned do
				if entry.isTemp then
					entry.part:Destroy()
				end
			end

			showResultBillboard(center, resultMonsterName, resultStars)
		end)
	end)
end

mergeMonstersRemote.OnClientEvent:Connect(function(result: any)
	if typeof(result) ~= "table" then
		return
	end

	shared.MergeClient = {
		lastResult = result,
		lastResultTime = os.clock(),
	}

	if result.success then
		-- A star-merge always resets stars to 0 for an evolution (name change) and
		-- only ever produces stars > 0 for a max-level star-add (MergeRules.
		-- GetMergeResult), so resultStars alone reliably distinguishes the two here.
		local isStarMerge = (result.resultStars or 0) > 0

		if shared.SoundManager then
			shared.SoundManager.PlaySound("merge", isStarMerge and "star" or "evolve")
		end

		playMergeAnimation(result.consumedInstanceIds or {}, result.resultMonsterName, result.resultStars, result.newInstanceId)

		if shared.ParticleManager then
			shared.ParticleManager.EmitBurst("mergeFlash", getCenterPosition(), 30)
		end
	else
		print(`[MergeClient] Merge failed: {result.reason}`)
	end
end)
