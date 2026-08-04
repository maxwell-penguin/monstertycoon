local Types = require(script.Parent.Types)

local BoostState = {}

local currentBoost: Types.BoostState = {
	emotion = "",
	multiplier = 1,
	endTime = 0,
	isActive = false,
}

function BoostState.GetCurrentBoost(): Types.BoostState
	return currentBoost
end

function BoostState.GetMultiplierForEmotion(emotion: string): number
	if not currentBoost.isActive or currentBoost.emotion ~= emotion then
		return 1
	end
	return currentBoost.multiplier
end

return BoostState
