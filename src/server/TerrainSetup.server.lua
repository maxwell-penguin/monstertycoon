local Workspace = game:GetService("Workspace")

-- Replaces the old flat grey Baseplate Part (removed from default.project.json)
-- with real Roblox Terrain.
--
-- A Part with Material = Grass is still just a block wearing a grass texture.
-- Terrain grass renders as an actual surface and, with Terrain.Decoration on,
-- grows real 3D grass blades -- which is what makes ground read as a lawn
-- rather than a green slab.
local TERRAIN_SIZE = 700

-- Grass sits 2 studs below the walking surface of everything built on it.
--
-- At -1 the surface came up level with the 1-stud plot slabs and swallowed
-- them, and grass decoration blades are roughly a stud tall on top of that, so
-- they poked straight through plot floors. 2 studs of clearance keeps blades
-- below the floors while staying inside a Humanoid's automatic step height, so
-- players still walk from grass onto a plot without having to jump.
--
-- Every platform that meets the grass (plot Ground slabs, hub plaza, walkway,
-- merchant platform) is thickened DOWNWARD to span this gap, keeping its top
-- face at its original height so no gameplay code that assumes Y=0 moves.
local TERRAIN_TOP_Y = -2
local TERRAIN_DEPTH = 20

-- Filled in chunks rather than one 700x700 block. Terrain writes are bounded,
-- and a single oversized FillBlock that gets rejected leaves the entire map
-- with no ground at all; per-chunk calls keep each write small and let a
-- partial failure still produce a walkable world.
local CHUNK_SIZE = 100

local GRASS_COLOR = Color3.fromRGB(78, 118, 58)
local GROUND_COLOR = Color3.fromRGB(84, 68, 48)
local ROCK_COLOR = Color3.fromRGB(88, 86, 96)

local terrain = Workspace.Terrain

-- Rojo's live sync does not delete instances that were removed from the
-- project file, so a Studio place that was already open still has the old
-- Baseplate Part sitting at Y=-0.1 -- almost a full stud ABOVE the terrain
-- surface, hiding every bit of grass behind a grey slab.
local function removeLegacyBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
		print("[TerrainSetup] Removed leftover Baseplate that was covering the terrain")
	end
end

-- Ground first, looks second, each guarded independently. Previously the
-- Decoration/SetMaterialColor calls ran BEFORE the fill, so if any of them
-- threw, FillBlock never executed and the map had no floor -- a cosmetic
-- setting must never be able to delete the ground out from under the player.
local function fillGround(): number
	local half = TERRAIN_SIZE / 2
	local chunkCount = math.ceil(TERRAIN_SIZE / CHUNK_SIZE)
	local centerY = TERRAIN_TOP_Y - TERRAIN_DEPTH / 2
	local chunkVolume = Vector3.new(CHUNK_SIZE, TERRAIN_DEPTH, CHUNK_SIZE)

	local filled = 0
	local firstError: string? = nil

	for ix = 0, chunkCount - 1 do
		for iz = 0, chunkCount - 1 do
			local cx = -half + CHUNK_SIZE / 2 + ix * CHUNK_SIZE
			local cz = -half + CHUNK_SIZE / 2 + iz * CHUNK_SIZE

			local ok, err = pcall(function()
				terrain:FillBlock(CFrame.new(cx, centerY, cz), chunkVolume, Enum.Material.Grass)
			end)

			if ok then
				filled += 1
			elseif not firstError then
				firstError = tostring(err)
			end
		end
	end

	if firstError then
		warn(`[TerrainSetup] {chunkCount * chunkCount - filled} chunk(s) failed to fill: {firstError}`)
	end

	return filled
end

local function applyGrassLook()
	-- Decoration is what grows the 3D blades. Guarded on its own so that if it
	-- is ever unavailable the ground still exists, just flat-shaded.
	local ok, err = pcall(function()
		terrain.Decoration = true
	end)
	if not ok then
		warn(`[TerrainSetup] Could not enable grass Decoration: {err}`)
	end

	for material, color in
		{
			[Enum.Material.Grass] = GRASS_COLOR,
			[Enum.Material.Ground] = GROUND_COLOR,
			[Enum.Material.Rock] = ROCK_COLOR,
		}
	do
		pcall(function()
			terrain:SetMaterialColor(material, color)
		end)
	end
end

-- Last resort so a terrain failure can never drop players into the void.
local function buildFallbackFloor()
	local floor = Instance.new("Part")
	floor.Name = "FallbackFloor"
	floor.Size = Vector3.new(TERRAIN_SIZE, TERRAIN_DEPTH, TERRAIN_SIZE)
	floor.Position = Vector3.new(0, TERRAIN_TOP_Y - TERRAIN_DEPTH / 2, 0)
	floor.Anchored = true
	floor.Locked = true
	floor.Material = Enum.Material.Grass
	floor.Color = GRASS_COLOR
	floor.Parent = Workspace

	warn("[TerrainSetup] Terrain fill produced nothing; fell back to a grass Part floor")
end

if not Workspace:FindFirstChild("TerrainReady") then
	removeLegacyBaseplate()

	local filled = fillGround()

	if filled > 0 then
		applyGrassLook()
	else
		buildFallbackFloor()
	end

	local ready = Instance.new("BoolValue")
	ready.Name = "TerrainReady"
	ready.Value = true
	ready.Parent = Workspace

	-- MaxExtents is the bounding region of non-empty terrain, so a non-degenerate
	-- box here is proof the fill actually landed.
	print(
		`[TerrainSetup] Filled {filled} chunk(s); extents={terrain.MaxExtents}, Decoration={terrain.Decoration}`
	)
end
