local Values = {}

--- Force a value to a boolean type
---
--- @param value mixed      The value to cast to boolean
--- @return boolean         True for any value but nil and false afaik
---
function Values.toboolean(value)
    return not not value
end

--- Get a default value for a nil value
---
--- @param value mixed          The value we want a default for
--- @param defaultvalue mixed   The value we want to default to
--- @return mixed               The default value when original value is nil, or
---                             the original value if it's not nil
---
function Values.default(value, defaultValue)
    if value == nil then
        return defaultValue else
        return value
    end
end

return Values
