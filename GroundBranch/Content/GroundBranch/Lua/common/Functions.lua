--
-- Bunch of useful functions
--

local Tables = require('common.Tables')
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

function functions.pipe(...)
	local arg = {...}

	return function(...)
		local result = nil

		for _, fn in ipairs(arg) do
			result = fn(result == nil and ... or result)
		end

		return result
	end
end

function functions.curry(func)
	return function(a)
		return function(b)
			return func(a, b)
		end
	end
end

function functions.curryReverse(func)
	return function(a)
		return function(b)
			return func(b, a)
		end
	end
end

return functions
