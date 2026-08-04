local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

-- All sound IDs are placeholder rbxassetid://0 -- expected and correct, real
-- assets get assigned after upload to Roblox. Pitch/volume values are final.
local SOUNDS = {
	vialDrop = {
		Joy = { id = "rbxassetid://0", pitch = 1.2, volume = 0.6 },
		Sadness = { id = "rbxassetid://0", pitch = 0.8, volume = 0.5 },
		Rage = { id = "rbxassetid://0", pitch = 0.7, volume = 0.8 },
		Dread = { id = "rbxassetid://0", pitch = 0.5, volume = 0.7 },
		Nostalgia = { id = "rbxassetid://0", pitch = 1.0, volume = 0.5 },
		Void = { id = "rbxassetid://0", pitch = 0.3, volume = 0.6 },
		default = { id = "rbxassetid://0", pitch = 1.0, volume = 0.5 },
	},
	vialPickup = { id = "rbxassetid://0", pitch = 1.3, volume = 0.4 },
	deposit = {
		small = { id = "rbxassetid://0", pitch = 1.0, volume = 0.7 },
		medium = { id = "rbxassetid://0", pitch = 1.0, volume = 0.8 },
		large = { id = "rbxassetid://0", pitch = 0.9, volume = 1.0 },
	},
	coinTick = { id = "rbxassetid://0", pitch = 1.0, volume = 0.2 },
	milestone = { id = "rbxassetid://0", pitch = 1.0, volume = 0.8 },
	roll = {
		Common = { id = "rbxassetid://0", pitch = 1.2, volume = 0.6 },
		Uncommon = { id = "rbxassetid://0", pitch = 1.1, volume = 0.7 },
		Rare = { id = "rbxassetid://0", pitch = 1.0, volume = 0.8 },
		Epic = { id = "rbxassetid://0", pitch = 0.9, volume = 0.9 },
		Legendary = { id = "rbxassetid://0", pitch = 0.8, volume = 1.0 },
		Mythic = { id = "rbxassetid://0", pitch = 0.7, volume = 1.0 },
	},
	merge = {
		evolve = { id = "rbxassetid://0", pitch = 1.0, volume = 0.9 },
		star = { id = "rbxassetid://0", pitch = 1.2, volume = 1.0 },
	},
	boost = {
		warning = { id = "rbxassetid://0", pitch = 1.0, volume = 0.7 },
		start = { id = "rbxassetid://0", pitch = 1.0, volume = 0.9 },
		end_ = { id = "rbxassetid://0", pitch = 0.9, volume = 0.6 },
	},
	crateDrop = { id = "rbxassetid://0", pitch = 1.0, volume = 0.8 },
	crateOpen = { id = "rbxassetid://0", pitch = 1.0, volume = 0.9 },
	townLevelUp = { id = "rbxassetid://0", pitch = 1.0, volume = 1.0 },
	buttonClick = { id = "rbxassetid://0", pitch = 1.1, volume = 0.3 },
	panelOpen = { id = "rbxassetid://0", pitch = 1.0, volume = 0.3 },
	shardCollect = { id = "rbxassetid://0", pitch = 1.4, volume = 0.5 },
}

local SoundManager = {}

local soundsFolder: Folder? = nil

local function createSoundInstance(name: string, config: any, parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = config.id
	sound.Pitch = config.pitch
	sound.Volume = config.volume
	sound.RollOffMode = Enum.RollOffMode.Linear
	-- Stored so PlaySound can compute pitch*pitchMod fresh each call instead of
	-- compounding onto whatever Pitch was left at after the previous call.
	sound:SetAttribute("BasePitch", config.pitch)
	sound.Parent = parent
	return sound
end

function SoundManager.InitSounds()
	local folder = Instance.new("Folder")
	folder.Name = "GameSounds"
	folder.Parent = SoundService

	for categoryName, categoryConfig in SOUNDS do
		if categoryConfig.id then
			createSoundInstance(categoryName, categoryConfig, folder)
		else
			local categoryFolder = Instance.new("Folder")
			categoryFolder.Name = categoryName
			categoryFolder.Parent = folder

			for key, subConfig in categoryConfig do
				createSoundInstance(key, subConfig, categoryFolder)
			end
		end
	end

	soundsFolder = folder
end

-- category/key lookup shared by PlaySound (pre-created instances) and
-- PlaySoundAtPosition (raw config, since it builds a temporary Sound itself).
local function resolveSoundConfig(category: string, key: string?): any
	local categoryConfig = SOUNDS[category]
	if not categoryConfig then
		return nil
	end

	if categoryConfig.id then
		return categoryConfig
	end

	if key and categoryConfig[key] then
		return categoryConfig[key]
	end

	return categoryConfig.default
end

-- pitchMod is an optional multiplier on the config's base pitch. For vialDrop,
-- callers should compute pitchMod = 1 + (monsterLevel - 1) * 0.1 so higher-level
-- monsters drop slightly higher-pitched vials.
function SoundManager.PlaySound(category: string, key: string?, pitchMod: number?)
	if not soundsFolder then
		return
	end

	local categoryInstance = soundsFolder:FindFirstChild(category)
	if not categoryInstance then
		return
	end

	local sound: Sound? = nil
	if categoryInstance:IsA("Sound") then
		sound = categoryInstance :: Sound
	else
		sound = (key and categoryInstance:FindFirstChild(key)) :: Sound?
		if not sound then
			sound = categoryInstance:FindFirstChild("default") :: Sound?
		end
	end

	if not sound then
		return
	end

	local basePitch = sound:GetAttribute("BasePitch") :: number
	sound.Pitch = pitchMod and (basePitch * pitchMod) or basePitch
	sound:Play()
end

function SoundManager.PlaySoundAtPosition(category: string, key: string?, position: Vector3, pitchMod: number?)
	local config = resolveSoundConfig(category, key)
	if not config then
		return
	end

	local part = Instance.new("Part")
	part.Name = "TempSoundAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.SoundId = config.id
	sound.Pitch = pitchMod and (config.pitch * pitchMod) or config.pitch
	sound.Volume = config.volume
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.Parent = part

	sound.Ended:Connect(function()
		part:Destroy()
	end)

	sound:Play()
end

SoundManager.InitSounds()

shared.SoundManager = SoundManager
