local sprintf       = require('common.Strings').sprintf
local trim          = require('common.Strings').trim
local count         = require('common.Tables').count
local tableContains = require('common.Tables').Index

local log = require('common.Logger').new('ParamParser')
-- log:SetLogLevel('DEBUG')

local function debugParams(params)
    out = {}
    -- sort keys and iterate on them to have a predictable output
    local keys = {}
    for key, _ in pairs(params) do
        table.insert(keys, key)
    end
    table.sort(keys)
    for _, paramName in pairs(keys) do
        local paramValue = params[paramName]
        table.insert(out, string.format('%s=%s', paramName, paramValue))
    end
    return table.concat(out, ', ')
end

local ParamParser = {}

ParamParser.__index = ParamParser

--- Instantiate a ParamParser with an optional list of validators
---
--- @param validators table   (optional) List of validators
--- @return object            New ParamParser instance
---
function ParamParser:new(validators)
    local self = setmetatable({}, self)
    self.validators = validators
    return self
end

--- Extract parameters from a list of strings, enforce instance's validators
---
--- @param strList table      List of strings to extract params from
--- @return object            New ParamParser instance
---
function ParamParser:parse(strList)
    return ParamParser.extractParams(strList, self.validators)
end

--- Statically instantiate a ParamParser
---
--- @param ... table          Arguments passed to ParamParser:new()
--- @return object            Return value of ParamParser:new()
---
function ParamParser.create(...)
    return ParamParser:new(...)
end

--- Extract parameters from a list of strings, enforce given validators
---
--- @param strList table      List of strings to parse
--- @param validators table   (optional) List of validators
--- @return table             Array of parameter value indexed by parameter name
---
function ParamParser.extractParams(strList, validators)
    local params = {}

    -- parse each string to an array of param value indexed by param name
    for _, str in ipairs(strList) do
        local param = ParamParser.parseParam(str)
        if param ~= nil then
            params[param.name] = param.value
        end
    end

    -- validate the params (wrapped in pcall to catch errors)
    if validators then
        local success, result = pcall(function()
                params = ParamParser.validateParams(params, validators)
            return params
        end)
        if not success then
            -- log validation error, return empty object
            local error = result
            log:Error(sprintf('Parameter validation failed: %s', error))
            return {}
        end
        params = result
    end
    
    -- log parsing result
    local logMsg
    if count(params) <= 0 then
        logMsg = "No parameter found"
    else
        local paramsStr = debugParams(params)
        logMsg = sprintf("Found %s parameter(s): %s", paramsCount, paramsStr)
    end
    log:Debug(logMsg)

    return params
end

--- Parse a string to extract a parameter, no validation
---
--- @param str string         The string to parse
--- @return table             Array with the keys 'name' and 'value' set to the
---                           name and value of the parameter, or nil if parsing
---                           failed
---
function ParamParser.parseParam(str)
    local _, _, paramName, paramValue = string.find(str, "(.+)=(.+)")

    -- soft fail (raise no error/exception) on nil
    if paramName == nil then return nil end
    if paramValue == nil then return nil end
    
    paramName = trim(paramName)
    paramValue = trim(paramValue)

    -- soft fail (raise no error/exception) on empty
    if paramName == '' then return nil end
    if paramValue == '' then return nil end

    return { name=paramName, value=paramValue }
end

--- Validate a list of parameters against an array of validators
---
--- @param params table       Array of parameter value by parameter name
--- @param validators table   List of validators
--- @return table             The list of parameters, potentially mutated
--- @throw error              When a validator function returns nil
--- @todo make a copy to prevent mutation of the passed params array
---
function ParamParser.validateParams(params, validators)
    for _, validator in ipairs(validators) do
        if validator.paramName then
            local initialParamValue = params[validator.paramName]
            if initialParamValue ~= nil then
                local finalParamValue = validator.validates(initialParamValue)

                if finalParamValue == nil then
                    local errorMsgTpl = 'Invalid parameter value for <%s>: %s'
                    if not validator.error then
                        error(sprintf(errorMsgTpl, validator.paramName, initialParamValue), 0)
                    else
                        errorMsg = sprintf(validator.error, initialParamValue)
                        error(sprintf(errorMsgTpl, validator.paramName, errorMsg), 0)
                    end
                end 
                params[validator.paramName] = finalParamValue
            end
        else
            local result = validator.validates(params)
            if result == nil then
                if not validator.error then
                    error('Invalid parameter values, no error set for the validates function', 0)
                else
                    error(validator.error, 0)
                end
            end
            params = result
        end
    end
    return params
end

ParamParser.validators = {}

function ParamParser.validators.integer(min, max)
    return function(value)
        value = tonumber(value)
        if not value then return nil end
        if value ~= math.floor(value) then return nil end
        if min and value < min then return nil end
        if max and value > max then return nil end
        return value
    end
end
function ParamParser.validators.inList(list)
    return function(value)
        if not tableContains(list, value) then return nil end
        return value
    end
end

return ParamParser
