local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotManager = require(script.Parent.PlotManager)
local HallManager = require(script.Parent.HallManager)
local Constants = require(ReplicatedStorage.Constants)

local COLUMNS = 3
local COLUMN_SPACING = 10
local ROW_SPACING = 10
-- Must match PlotSetup.server.lua's SlotPad_N grid exactly: same spacing, same
-- -10 stud Z offset from PlotOrigin, and the same FIXED (max-tier) row count --
-- not the player's current tier -- so positions never shift on hall upgrade
-- and vials always spawn on the correct visual pad.
local HALL_ORIGIN_OFFSET = Vector3.new(0, 0, -10)
local TOTAL_SLOTS = Constants.HALL_SLOT_COUNTS[5]
local TOTAL_ROWS = math.ceil(TOTAL_SLOTS / COLUMNS)

local SlotPositioner = {}

function SlotPositioner.GetSlotWorldPosition(player: Player, slotIndex: number): Vector3
	local originCFrame = PlotManager.GetPlotOrigin(player)
	if not originCFrame then
		return Vector3.new(0, 0, 0)
	end

	local col = (slotIndex - 1) % COLUMNS
	local row = math.floor((slotIndex - 1) / COLUMNS)

	local colOffset = (col - (COLUMNS - 1) / 2) * COLUMN_SPACING
	local rowOffset = (row - (TOTAL_ROWS - 1) / 2) * ROW_SPACING

	return originCFrame:PointToWorldSpace(HALL_ORIGIN_OFFSET + Vector3.new(colOffset, 0, rowOffset))
end

function SlotPositioner.GetAllSlotPositions(player: Player): { Vector3 }
	local slots = HallManager.GetSlots(player)
	local positions = {}

	for _, slot in slots do
		positions[slot.slotIndex] = SlotPositioner.GetSlotWorldPosition(player, slot.slotIndex)
	end

	return positions
end

return SlotPositioner
