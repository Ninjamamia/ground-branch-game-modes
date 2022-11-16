local Functions = {}

--- Combine functions in sequence passing each return value to the next function
 --
 -- Provide nicer syntax for nested function calls:
 -- pipe(table.concat, string.uppercase, string.trim, string.reverse)(strTbl)
 -- is the same as:
 -- string.reverse(string.trim(string.uppercase(table.concat(strTbl)))
 --
 -- @param args table   The functions to pipe (variable arg number)
 -- @return             The return value of the last executed function
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
