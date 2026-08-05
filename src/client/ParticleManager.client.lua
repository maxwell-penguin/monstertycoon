local Workspace = game:GetService("Workspace")

local PARTICLES = {
	vialGlow = {
		LightEmission = 0.8,
		LightInfluence = 0.5,
		Rate = 5,
		Lifetime = NumberRange.new(0.3, 0.6),
		Size = NumberSequence.new(0.2),
		Speed = NumberRange.new(1, 2),
	},
	coinBurst = {
		Rate = 0,
		EmitCount = 20,
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 210, 60)),
		Lifetime = NumberRange.new(0.3, 0.8),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(360, 360),
	},
	mergeFlash = {
		Rate = 0,
		EmitCount = 30,
		LightEmission = 1,
		Lifetime = NumberRange.new(0.2, 0.5),
		Size = NumberSequence.new(0.4),
		Speed = NumberRange.new(5, 12),
		SpreadAngle = Vector2.new(360, 360),
	},
	mythicAura = {
		Rate = 15,
		LightEmission = 1,
		Lifetime = NumberRange.new(0.5, 1.0),
		Size = NumberSequence.new(0.3),
		Speed = NumberRange.new(2, 4),
	},
	puddleSwirl = {
		Rate = 8,
		LightEmission = 0.6,
		Lifetime = NumberRange.new(0.4, 0.8),
		Size = NumberSequence.new(0.15),
		Speed = NumberRange.new(0.5, 1.5),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(15, 15),
	},
	shardSparkle = {
		Rate = 8,
		LightEmission = 0.9,
		Color = ColorSequence.new(Color3.fromRGB(0, 255, 220)),
		Lifetime = NumberRange.new(0.2, 0.4),
		Size = NumberSequence.new(0.15),
		Speed = NumberRange.new(1, 3),
	},
}

local BURST_PART_LIFETIME = 2

-- EmitCount isn't a real ParticleEmitter property (setting it directly throws) --
-- it's config-only data that EmitBurst's own count parameter is meant to carry.
local NON_EMITTER_PROPERTIES = { EmitCount = true }

local ParticleManager = {}

local function applyConfig(emitter: ParticleEmitter, config: any)
	for property, value in config do
		if not NON_EMITTER_PROPERTIES[property] then
			(emitter :: any)[property] = value
		end
	end
end

function ParticleManager.CreateParticleEmitter(parent: Instance, configName: string): ParticleEmitter?
	local config = PARTICLES[configName]
	if not config then
		return nil
	end

	local emitter = Instance.new("ParticleEmitter")
	applyConfig(emitter, config)
	emitter.Parent = parent

	return emitter
end

function ParticleManager.EmitBurst(configName: string, position: Vector3, count: number)
	local config = PARTICLES[configName]
	if not config then
		return
	end

	local part = Instance.new("Part")
	part.Name = "ParticleBurstAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	applyConfig(emitter, config)
	emitter.Parent = part

	emitter:Emit(count)

	task.delay(BURST_PART_LIFETIME, function()
		part:Destroy()
	end)
end

shared.ParticleManager = ParticleManager
