local Values = {}

function Values.toboolean(value)
	return not not value
end

function Values.default(value, defaultValue)
	if value == nil then return defaultValue end
	return value
end

return Values
