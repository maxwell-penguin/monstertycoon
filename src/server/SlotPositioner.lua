local PlotManager = require(script.Parent.PlotManager)
local HallManager = require(script.Parent.HallManager)

local COLUMNS = 3
-- HallArea and Origin share the same X/Z (PlotSetup.server.lua), so Origin is
-- already the Hall's center -- the old 12-stud spacing put corner slots (3x3
-- grid) up to sqrt(12^2+12^2) =~ 17 studs from center, well outside pickup range
-- of a player standing near the middle. Halved so the worst case is =~ 8.5 studs.
local COLUMN_SPACING = 6
local ROW_SPACING = 6

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
