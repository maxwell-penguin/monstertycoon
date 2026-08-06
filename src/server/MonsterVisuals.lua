local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Constants)
local PlotManager = require(script.Parent.PlotManager)

local MonsterVisuals = {}

local BODY_SIZES = {
	Common = Vector3.new(2, 2, 2),
	Uncommon = Vector3.new(2.3, 2.3, 2.3),
	Rare = Vector3.new(2.6, 2.6, 2.6),
	Epic = Vector3.new(3, 3, 3),
	Legendary = Vector3.new(3.4, 3.4, 3.4),
	Mythic = Vector3.new(4, 4, 4),
}

-- Keyed by userId.."_"..slotIndex so each player's pedestal is tracked
-- independently even though slot indices repeat across plots.
local activeBlobs: { [string]: Model } = {}
-- Keyed the same way as activeBlobs, but derived from the blob's own
-- hierarchy (Plot_N_MonsterBlob_M) rather than passed around, since
-- StartIdleAnimation's signature only takes (monsterModel, emotion).
local animationCancelled: { [string]: boolean } = {}

local function blobKey(userId: number, slotIndex: number): string
	return userId .. "_" .. slotIndex
end

local function animationKey(monsterModel: Instance): string
	local slotPad = monsterModel.Parent
	local plotModel = slotPad and slotPad.Parent
	return (plotModel and plotModel.Name or "?") .. "_" .. monsterModel.Name
end

local function newPart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, cframe: CFrame): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = true
	part.CFrame = cframe
	return part
end

local function newWedge(name: string, size: Vector3, color: Color3, cframe: CFrame): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Size = size
	wedge.Color = color
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.Anchored = true
	wedge.CanCollide = false
	wedge.CastShadow = true
	wedge.CFrame = cframe
	return wedge
end

local function addEmotionDetail(model: Model, emotion: string, eyeL: BasePart, eyeR: BasePart, bodyRadius: number)
	if emotion == "Sadness" then
		local tear = newPart(
			"Teardrop",
			Enum.PartType.Ball,
			Vector3.new(0.2, 0.3, 0.2),
			Color3.fromRGB(80, 140, 230),
			CFrame.new(eyeL.Position + Vector3.new(0, -0.5, -0.1))
		)
		tear.Parent = model
	elseif emotion == "Rage" then
		local browColor = Color3.fromRGB(220, 40, 40)
		local browSize = Vector3.new(0.2, 0.4, 0.2)

		local browL = newWedge(
			"BrowL",
			browSize,
			browColor,
			CFrame.new(eyeL.Position + Vector3.new(0.1, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(-25))
		)
		browL.Parent = model

		local browR = newWedge(
			"BrowR",
			browSize,
			browColor,
			CFrame.new(eyeR.Position + Vector3.new(-0.1, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(25))
		)
		browR.Parent = model
	elseif emotion == "Joy" then
		local mouthColor = Color3.fromRGB(255, 210, 60)
		local mouthSize = Vector3.new(0.15, 0.15, 0.15)
		local frontZ = -(bodyRadius * 0.85)

		-- Upward-curved arc (smile): center dips lowest, ends sit higher.
		local arc = {
			Vector3.new(-0.25, -0.15, frontZ),
			Vector3.new(0, -0.3, frontZ),
			Vector3.new(0.25, -0.15, frontZ),
		}
		for i, offset in arc do
			local dot = newPart("Mouth" .. i, Enum.PartType.Ball, mouthSize, mouthColor, CFrame.new(offset))
			dot.Parent = model
		end
	elseif emotion == "Dread" then
		local handColor = Color3.fromRGB(60, 60, 65)
		local handSize = Vector3.new(0.5, 0.5, 0.5)

		local handL = newPart("HandL", Enum.PartType.Ball, handSize, handColor, CFrame.new(eyeL.Position + Vector3.new(0, 0, -0.3)))
		handL.Parent = model

		local handR = newPart("HandR", Enum.PartType.Ball, handSize, handColor, CFrame.new(eyeR.Position + Vector3.new(0, 0, -0.3)))
		handR.Parent = model
	elseif emotion == "Nostalgia" then
		-- Cylinder's axis runs along local X by default -- unrotated, that's
		-- already a horizontal bar, exactly what a mustache needs.
		local mustache = newPart(
			"Mustache",
			Enum.PartType.Cylinder,
			Vector3.new(0.6, 0.15, 0.15),
			Color3.fromRGB(220, 170, 220),
			CFrame.new(0, 0, -(bodyRadius * 0.9))
		)
		mustache.Parent = model
	end
	-- Void: no extra parts -- pupils are inverted to white where they're created.
end

function MonsterVisuals.BuildBlob(emotion: string, rarity: string): Model
	local model = Instance.new("Model")
	model.Name = "Blob"

	local bodySize = BODY_SIZES[rarity] or BODY_SIZES.Common
	local bodyRadius = bodySize.X / 2
	local emotionColor = Constants.EMOTION_COLORS[emotion] or Color3.new(1, 1, 1)

	local body = newPart("Body", Enum.PartType.Ball, bodySize, emotionColor, CFrame.new(0, 0, 0))
	body.Parent = model

	local eyeSize = Vector3.new(0.5, 0.5, 0.5)
	local eyeColor = Color3.fromRGB(255, 255, 255)
	local frontZ = -(bodyRadius * 0.9)

	local eyeL = newPart("EyeL", Enum.PartType.Ball, eyeSize, eyeColor, CFrame.new(body.Position + Vector3.new(-0.4, 0.3, frontZ)))
	eyeL.Parent = model

	local eyeR = newPart("EyeR", Enum.PartType.Ball, eyeSize, eyeColor, CFrame.new(body.Position + Vector3.new(0.4, 0.3, frontZ)))
	eyeR.Parent = model

	local pupilColor = if emotion == "Void" then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(10, 10, 10)
	local pupilSize = Vector3.new(0.25, 0.25, 0.25)

	local pupilL = newPart("PupilL", Enum.PartType.Ball, pupilSize, pupilColor, CFrame.new(eyeL.Position + Vector3.new(0, 0, -0.15)))
	pupilL.Parent = model

	local pupilR = newPart("PupilR", Enum.PartType.Ball, pupilSize, pupilColor, CFrame.new(eyeR.Position + Vector3.new(0, 0, -0.15)))
	pupilR.Parent = model

	addEmotionDetail(model, emotion, eyeL, eyeR, bodyRadius)

	local light = Instance.new("PointLight")
	light.Brightness = 0.8
	light.Range = 10
	light.Color = emotionColor
	light.Parent = body

	model.PrimaryPart = body

	return model
end

-- Bob/shake/rotation are driven through separate NumberValues, each tweened
-- independently, and composed into a single body.CFrame write -- if several
-- tweens targeted body.CFrame directly at the same time (e.g. bob + Rage's
-- simultaneous shake), whichever one updates last each frame would silently
-- overwrite the other's contribution instead of combining with it.
function MonsterVisuals.StartIdleAnimation(monsterModel: Model, emotion: string)
	local body = monsterModel.PrimaryPart :: BasePart?
	if not body then
		return
	end

	local key = animationKey(monsterModel)
	animationCancelled[key] = false

	local basePivot = body.CFrame
	local bobY = Instance.new("NumberValue")
	local shakeX = Instance.new("NumberValue")
	local rotY = Instance.new("NumberValue")

	local function apply()
		if not body.Parent then
			return
		end
		body.CFrame = basePivot * CFrame.new(shakeX.Value, bobY.Value, 0) * CFrame.Angles(0, math.rad(rotY.Value), 0)
	end

	bobY:GetPropertyChangedSignal("Value"):Connect(apply)
	shakeX:GetPropertyChangedSignal("Value"):Connect(apply)
	rotY:GetPropertyChangedSignal("Value"):Connect(apply)

	local function loopTween(target: NumberValue, legs: { number }, legDuration: number)
		task.spawn(function()
			local index = 0
			while not animationCancelled[key] and body.Parent do
				index = (index % #legs) + 1
				local tween = TweenService:Create(
					target,
					TweenInfo.new(legDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ Value = legs[index] }
				)
				tween:Play()
				tween.Completed:Wait()
			end
		end)
	end

	-- All emotions: slow bob, 2 second full period (1s up leg + 1s down leg).
	local downTarget = (emotion == "Sadness") and -0.4 or -0.3
	loopTween(bobY, { 0.3, downTarget }, 1)

	if emotion == "Rage" then
		-- Rapid shake, 0.1 second full period, simultaneous with the bob above.
		loopTween(shakeX, { 0.05, -0.05 }, 0.05)
	elseif emotion == "Joy" then
		-- Slight rotation, 1 second full period, simultaneous with the bob above.
		loopTween(rotY, { 5, -5 }, 0.5)
	end
end

function MonsterVisuals.SpawnMonsterOnPad(player: Player, slotIndex: number, monsterName: string, emotion: string, rarity: string)
	if true then
		return
	end -- Disabled: monsters now roam freely, MonsterAI handles placement

	local plotModel = PlotManager.GetPlayerPlot(player)
	if not plotModel then
		return
	end

	local slotPad = plotModel:FindFirstChild("SlotPad_" .. slotIndex)
	if not slotPad then
		return
	end

	local base = slotPad:FindFirstChild("Base")
	if not base or not base:IsA("BasePart") then
		return
	end

	-- Defensive: clears out any stale blob left over from re-slotting into
	-- this slot without an intervening UnslotMonster call.
	MonsterVisuals.RemoveMonsterFromPad(player, slotIndex)

	local topPosition = base.Position + Vector3.new(0, 3, 0)

	local blob = MonsterVisuals.BuildBlob(emotion, rarity)
	blob.Name = "MonsterBlob_" .. slotIndex
	blob:PivotTo(CFrame.new(topPosition))
	blob.Parent = slotPad

	activeBlobs[blobKey(player.UserId, slotIndex)] = blob

	MonsterVisuals.StartIdleAnimation(blob, emotion)
end

function MonsterVisuals.RemoveMonsterFromPad(player: Player, slotIndex: number)
	if true then
		return
	end -- Disabled: monsters now roam freely, MonsterAI handles placement

	local key = blobKey(player.UserId, slotIndex)
	local blob = activeBlobs[key]
	if not blob then
		return
	end

	animationCancelled[animationKey(blob)] = true
	blob:Destroy()
	activeBlobs[key] = nil
end

return MonsterVisuals
