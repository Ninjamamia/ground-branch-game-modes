--
-- Bunch of useful functions
--

local Tables = require('Common.Tables')
local functions = {}

function functions.toboolean(value)
	return not not value
end

function functions.printf(...)
	print(sprintf(...))
end

function functions.sprintf(...)
	return string.format(...)
end

function functions.debugTable(tbl, label)
	if label ~= nil then
		print(label .. Tables.debug(tbl))
	else
		print(Tables.debug(tbl))
	end
end

function functions.default(value, defaultValue)
	if value == nil then return defaultValue end
	return value
end

return functions
