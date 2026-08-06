local PlotManager = require(script.Parent.PlotManager)
local HallManager = require(script.Parent.HallManager)

local COLUMNS = 3
local COLUMN_SPACING = 12
local ROW_SPACING = 12

local SlotPositioner = {}

function SlotPositioner.GetSlotWorldPosition(player: Player, slotIndex: number): Vector3
	local originCFrame = PlotManager.GetPlotOrigin(player)
	if not originCFrame then
		return Vector3.new(0, 0, 0)
	end

	local totalSlots = #HallManager.GetSlots(player)
	local totalRows = math.max(1, math.ceil(totalSlots / COLUMNS))

	local col = (slotIndex - 1) % COLUMNS
	local row = math.floor((slotIndex - 1) / COLUMNS)

	local colOffset = (col - (COLUMNS - 1) / 2) * COLUMN_SPACING
	local rowOffset = (row - (totalRows - 1) / 2) * ROW_SPACING

	return originCFrame:PointToWorldSpace(Vector3.new(colOffset, 0, rowOffset))
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
