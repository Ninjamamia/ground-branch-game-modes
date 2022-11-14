local Functions = {}

function Functions.pipe(...)
	local arg = {...}
	return function(...)
		local result = nil
		for _, fn in ipairs(arg) do
			result = fn(result == nil and ... or result)
		end
		return result
	end
end

function Functions.curry(func)
	return function(a)
		return function(b)
			return func(a, b)
		end
	end
end

function Functions.curryReverse(func)
	return function(a)
		return function(b)
			return func(b, a)
		end
	end
end

return Functions
