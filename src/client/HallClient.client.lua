local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)
local RemoteEvents = require(ReplicatedStorage.RemoteEvents)
local Types = require(ReplicatedStorage.Types)

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local updateHallRemote = remotesFolder:WaitForChild(RemoteEvents.EVENTS.UPDATE_HALL) :: RemoteEvent

local DIM_PURPLE = Color3.fromRGB(60, 40, 100)
local TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

-- slotIndex -> the monster occupying it as of the last UPDATE_HALL, so a
-- fresh fire (e.g. from a hall upgrade adding empty slots) only animates
-- slots that actually changed, not the whole grid.
local lastMonsterBySlot: { [number]: Types.Monster? } = {}

local function findPlayerPlot(): Model?
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end

	for _, plotModel in plotsFolder:GetChildren() do
		local ownerId = plotModel:FindFirstChild("OwnerId")
		if ownerId and ownerId.Value == tostring(player.UserId) then
			return plotModel :: Model
		end
	end

	return nil
end

local function updateSlotPad(
	slotIndex: number,
	color: Color3,
	topGlowTransparency: number,
	ringTransparency: number,
	occupied: boolean
)
	local plotModel = findPlayerPlot()
	if not plotModel then
		return
	end

	local slotPad = plotModel:FindFirstChild("SlotPad_" .. slotIndex)
	if not slotPad then
		return
	end

	local topGlow = slotPad:FindFirstChild("TopGlow")
	local ring = slotPad:FindFirstChild("Ring")

	if topGlow and topGlow:IsA("BasePart") then
		TweenService:Create(topGlow, TWEEN_INFO, { Color = color, Transparency = topGlowTransparency }):Play()
	end

	if ring and ring:IsA("BasePart") then
		TweenService:Create(ring, TWEEN_INFO, { Color = color, Transparency = ringTransparency }):Play()
	end

	local isOccupied = slotPad:FindFirstChild("IsOccupied")
	if isOccupied and isOccupied:IsA("BoolValue") then
		isOccupied.Value = occupied
	end

	local base = slotPad:FindFirstChild("Base")
	local billboard = base and base:FindFirstChild("SlotLabel")
	if billboard and billboard:IsA("BillboardGui") then
		billboard.Enabled = not occupied
	end
end

updateHallRemote.OnClientEvent:Connect(function(slots: { Types.MonsterSlot })
	for _, slot in slots do
		local previousMonster = lastMonsterBySlot[slot.slotIndex]

		if not previousMonster and slot.monster then
			local color = Constants.EMOTION_COLORS[slot.monster.emotion] or DIM_PURPLE
			updateSlotPad(slot.slotIndex, color, 0.1, 0.3, true)
		elseif previousMonster and not slot.monster then
			updateSlotPad(slot.slotIndex, DIM_PURPLE, 0.3, 0.5, false)
		end

		lastMonsterBySlot[slot.slotIndex] = slot.monster
	end
end)
