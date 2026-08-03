local Constants = require(script.Parent.Constants)

local NumberFormatter = {}

function NumberFormatter.Format(number: number): string
	local negative = number < 0
	local magnitude = math.abs(number)

	if magnitude == math.huge then
		return (negative and "-" or "") .. "∞"
	end

	if magnitude < 1000 then
		return (negative and "-" or "") .. tostring(math.floor(magnitude))
	end

	local suffixes = Constants.NUMBER_SUFFIXES
	local suffixIndex = 0

	while magnitude >= 1000 and suffixIndex < #suffixes do
		magnitude /= 1000
		suffixIndex += 1
	end

	if tonumber(string.format("%.2f", magnitude)) >= 1000 and suffixIndex < #suffixes then
		magnitude /= 1000
		suffixIndex += 1
	end

	local formatted = (string.format("%.2f", magnitude):gsub("0+$", ""):gsub("%.$", ""))
	return (negative and "-" or "") .. formatted .. suffixes[suffixIndex]
end

return NumberFormatter
