local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local NumberFormatter = require(ReplicatedStorage.NumberFormatter)

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local depositBagRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.DEPOSIT_BAG) :: RemoteEvent

-- BagClient.client.lua owns UPDATE_BAG and publishes shared.BagClient; its script may
-- not have run its top-level code yet when this script starts, so poll briefly.
local BAG_CLIENT_WAIT_TIMEOUT = 5
local waited = 0
while not shared.BagClient and waited < BAG_CLIENT_WAIT_TIMEOUT do
	task.wait(0.1)
	waited += 0.1
end

local function getBagCount(): number
	return (shared.BagClient and shared.BagClient.count) or 0
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

local function getOrCreateHint(dropbox: BasePart): (BillboardGui, TextLabel)
	local existing = dropbox:FindFirstChild("DepositHint")
	if existing and existing:IsA("BillboardGui") then
		return existing, existing:FindFirstChild("Text") :: TextLabel
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DepositHint"
	billboard.Size = UDim2.new(4, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = dropbox

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.Parent = billboard

	return billboard, textLabel
end

local function playCoinBurst(position: Vector3)
	for i = 1, 8 do
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(0.5, 0.5, 0.5)
		part.Color = Color3.fromRGB(255, 215, 0)
		part.Anchored = true
		part.CanCollide = false
		part.Position = position
		part.Parent = Workspace

		local angle = (i / 8) * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0.5, math.sin(angle))
		local targetPosition = position + direction * 4

		local tween = TweenService:Create(
			part,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = targetPosition, Transparency = 1 }
		)
		tween:Play()

		task.delay(0.5, function()
			part:Destroy()
		end)
	end
end

local function showEarnedText(position: Vector3, totalEarned: number)
	local anchor = Instance.new("Part")
	anchor.Name = "EarnedTextAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Position = position
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(4, 0, 2, 0)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.Text = "+" .. NumberFormatter.Format(totalEarned)
	textLabel.Parent = billboard

	local moveTween = TweenService:Create(
		anchor,
		TweenInfo.new(1, Enum.EasingStyle.Linear),
		{ Position = position + Vector3.new(0, 4, 0) }
	)
	moveTween:Play()

	local fadeTween = TweenService:Create(textLabel, TweenInfo.new(1, Enum.EasingStyle.Linear), { TextTransparency = 1 })
	fadeTween:Play()

	task.delay(1, function()
		anchor:Destroy()
	end)
end

local LARGE_DEPOSIT_THRESHOLD = 1e6

local function getDepositSizeCategory(vialCount: number): string
	if vialCount < 10 then
		return "small"
	elseif vialCount <= 50 then
		return "medium"
	end
	return "large"
end

depositBagRemote.OnClientEvent:Connect(function(totalEarned: number, vialCount: number)
	local dropbox = findDropbox()
	if not dropbox then
		return
	end

	playCoinBurst(dropbox.Position)
	showEarnedText(dropbox.Position, totalEarned)

	if shared.SoundManager then
		shared.SoundManager.PlaySound("deposit", getDepositSizeCategory(vialCount))
	end

	if shared.ParticleManager then
		shared.ParticleManager.EmitBurst("coinBurst", dropbox.Position, vialCount * 2)
	end

	if totalEarned > LARGE_DEPOSIT_THRESHOLD and shared.ScreenEffects then
		shared.ScreenEffects.CoinFlash(totalEarned)
	end
end)

while true do
	task.wait(0.5)

	local dropbox = findDropbox()
	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)

	if dropbox and rootPart then
		local distance = (rootPart.Position - dropbox.Position).Magnitude
		local billboard, textLabel = getOrCreateHint(dropbox)
		local inRange = distance <= Constants.DROPBOX_RADIUS

		billboard.Enabled = inRange

		if inRange then
			local bagCount = getBagCount()
			textLabel.Text = `DEPOSIT ({bagCount})`

			if bagCount > 0 then
				depositBagRemote:FireServer()
			end
		end
	end
end
