local Functions = {}

--- Create a function that combine multiple functions in sequence providing
--- return values of the firsts to the laters
 -- 
 -- Easy way to understand is if you want to avoid this kind of nested calls:
 --    string.reverse(string.trim(string.uppercase(table.concat(myStrTable)))
 --
 -- You can rewrite it:
 --    fn = pipe(table.concat, string.uppercase, string.trim, string.reverse)
 --    fn(myStrTable)
 --
 -- @param args,... function - variable arg number
 -- @return The return value of the last executed function
 --
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
