local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local worldEventStartRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.WORLD_EVENT_START) :: RemoteEvent
local worldEventEndRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.WORLD_EVENT_END) :: RemoteEvent
local worldEventCountdownRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.WORLD_EVENT_COUNTDOWN) :: RemoteEvent
local shardSpawnedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SHARD_SPAWNED) :: RemoteEvent
local shardCollectedRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.SHARD_COLLECTED) :: RemoteEvent

local BANNER_COLORS = {
	CrateRace = Color3.fromRGB(255, 210, 60),
	ShardHunt = Color3.fromRGB(60, 220, 230),
	VoidStorm = Color3.fromRGB(150, 60, 220),
}

local SHARD_COLLECT_RADIUS = 8
local SHARD_BOB_HEIGHT = 0.5
local SHARD_BOB_PERIOD = 0.8

shared.EventClient = { nextEventIn = 0 }

--============================================================
-- GUI setup
--============================================================

local gui = Instance.new("ScreenGui")
gui.Name = "EventClientGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = playerGui

local banner = Instance.new("Frame")
banner.Name = "EventBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, -60)
banner.Size = UDim2.new(1, 0, 0, 50)
banner.BackgroundColor3 = Color3.new(1, 1, 1)
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = gui

local bannerLabel = Instance.new("TextLabel")
bannerLabel.Size = UDim2.fromScale(1, 1)
bannerLabel.BackgroundTransparency = 1
bannerLabel.Font = Enum.Font.GothamBold
bannerLabel.TextSize = 24
bannerLabel.TextColor3 = Color3.new(0, 0, 0)
bannerLabel.Text = ""
bannerLabel.Parent = banner

local function showCenterAnnouncement(text: string, duration: number)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.4)
	label.Size = UDim2.new(0, 600, 0, 60)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 32
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 1
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui

	TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()

	task.delay(duration, function()
		local fadeTween = TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 })
		fadeTween:Play()
		fadeTween.Completed:Connect(function()
			label:Destroy()
		end)
	end)
end

--============================================================
-- Shard visuals
--============================================================

local shardParts: { [string]: BasePart } = {}
local pendingCollect: { [string]: boolean } = {}

local function destroyAllShards()
	for _, part in shardParts do
		part:Destroy()
	end
	shardParts = {}
	pendingCollect = {}
end

shardSpawnedRemote.OnClientEvent:Connect(function(shardId: string, position: Vector3)
	local part = Instance.new("Part")
	part.Name = "Shard_" .. shardId
	part.Size = Vector3.new(1.5, 1.5, 1.5)
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(60, 220, 230)
	part.Anchored = true
	part.CanCollide = false
	part.Position = position
	part.Parent = Workspace

	shardParts[shardId] = part

	TweenService:Create(
		part,
		TweenInfo.new(SHARD_BOB_PERIOD, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = position + Vector3.new(0, SHARD_BOB_HEIGHT, 0) }
	):Play()

	if shared.ParticleManager then
		shared.ParticleManager.CreateParticleEmitter(part, "shardSparkle")
	end
end)

shardCollectedRemote.OnClientEvent:Connect(function(shardId: string)
	-- SHARD_COLLECTED is broadcast to every player when anyone collects a shard;
	-- only play the sound if it was this client's own collection attempt (tracked
	-- in pendingCollect below, same-script so no cross-script ordering risk).
	if pendingCollect[shardId] and shared.SoundManager then
		shared.SoundManager.PlaySound("shardCollect")
	end

	local part = shardParts[shardId]
	if part then
		part:Destroy()
		shardParts[shardId] = nil
	end
	pendingCollect[shardId] = nil
end)

task.spawn(function()
	while true do
		task.wait(0.5)

		local character = player.Character
		local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
		if rootPart then
			for shardId, part in shardParts do
				if not pendingCollect[shardId] then
					local distance = (rootPart.Position - part.Position).Magnitude
					if distance <= SHARD_COLLECT_RADIUS then
						pendingCollect[shardId] = true
						shardCollectedRemote:FireServer({ shardId = shardId })
					end
				end
			end
		end
	end
end)

--============================================================
-- Banner + event start/end
--============================================================

local bannerToken = 0

local function tickBanner(token: number, eventType: string, endTime: number)
	if token ~= bannerToken then
		return
	end

	local secondsLeft = math.max(math.floor(endTime - os.time()), 0)
	bannerLabel.Text = `{string.upper(eventType)} EVENT — {secondsLeft}s`

	if secondsLeft <= 0 then
		return
	end

	task.delay(1, function()
		tickBanner(token, eventType, endTime)
	end)
end

worldEventStartRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local eventType = payload.eventType
	local duration = payload.duration or 0

	-- The Crate Race's shared crate visual is already handled by CrateManager's
	-- existing CRATE_SPAWNED fire, which CrateClient.client.lua (Phase 10) already
	-- renders -- no duplicate crate visual is created here, just the banner.
	banner.BackgroundColor3 = BANNER_COLORS[eventType] or Color3.new(1, 1, 1)
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, -60)

	TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 0),
	}):Play()

	bannerToken += 1
	local token = bannerToken
	local endTime = os.time() + duration
	tickBanner(token, eventType, endTime)
end)

worldEventEndRemote.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local eventType = payload.eventType

	bannerToken += 1
	local slideOut = TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0, -60),
	})
	slideOut:Play()
	slideOut.Completed:Connect(function()
		banner.Visible = false
	end)

	if eventType == "CrateRace" then
		local winnerName = payload.winnerName
		showCenterAnnouncement(winnerName and `WINNER: {winnerName}!` or "No one claimed the crate!", 3)

		-- The winner's own EGG_RESULT (from PerformPremiumRoll) doesn't carry
		-- isCrate/crateId, and no other player gets one at all -- this broadcast
		-- is the only signal anyone's client gets to remove the crate visual.
		local crateId = payload.crateId
		if crateId then
			local part = Workspace:FindFirstChild("Crate_" .. crateId)
			if part then
				part:Destroy()
			end
		end
	elseif eventType == "ShardHunt" then
		local results = payload.results
		local myCount = (results and results[player.UserId]) or 0
		showCenterAnnouncement(`You collected {myCount} shard{myCount == 1 and "" or "s"}!`, 3)
		destroyAllShards()
	elseif eventType == "VoidStorm" then
		showCenterAnnouncement("VOID STORM ENDED", 2)
	end
end)

worldEventCountdownRemote.OnClientEvent:Connect(function(secondsUntilNext: number)
	if typeof(secondsUntilNext) == "number" then
		shared.EventClient.nextEventIn = secondsUntilNext
	end
end)
