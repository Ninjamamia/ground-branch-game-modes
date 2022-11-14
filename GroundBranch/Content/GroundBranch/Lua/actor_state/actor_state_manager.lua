---
--- ActorStateManager 
 --
 -- Used to set the state of actors based on parameters provided using tags on
 -- the actors. Parameters are parsed from actors having a special "flag tag"
 -- set. The default flag tag is "ActorState".
 --
 -- Supported parameters to control actors visibility:
 --
 -- <act> String 'enable' or 'disable', defaults to 'enable'
 --     The state we want the targets to be set to. All targets not set to
 --     this state (because of the impact of other parameters) will be set
 --     to the opposite state.
 -- 
 -- <prob> Integer between 0 and 100, defaults to 100
 --     Defines the probability (in percent) that the <state> is set to the
 --     the targets.
 -- 
 -- <num> Integer greater than 0, defaults to the number of targets
 --     Number of targets to apply the <state> to. Selected targets are
 --     chosen randomly (math.random). If provided, <max> and <min> will be
 --     disregarded. 
 -- 
 -- <min> Integer greater than 0, defaults to 0
 --     Minimum number of targets to apply the <state> to. The number of
 --     selected targets is chosen randomly, then targets are chosen
 --     randomly. Disregarded when <num> is provided.
 --
 -- <max> Integer greater than 0, defaults to the number of targets
 --     Maximum number of targets to apply the <state> to. The number of
 --     selected targets is chosen randomly, then targets are chosen
 --     randomly. Disregarded when <num> is provided. 
---
local log              = require('actor_state.actor_state_logger')
local default          = require('common.Values').default
local sprintf          = require("common.Strings").sprintf
local concatTables     = require('common.Tables').ConcatenateTables
local count            = require('common.Tables').count
local filter           = require('common.Tables').filter
local filterNot        = require('common.Tables').filterNot
local tableIsEmpty     = require('common.Tables').isEmpty
local map              = require('common.Tables').map
local tableNotEmpty    = require('common.Tables').notEmpty
local mergeAssoc       = require('common.Tables').naiveMergeAssocTables
local reduce           = require('common.Tables').reduce
local defaultTable     = require('common.Tables').setDefault
local shuffleTable     = require('common.Tables').ShuffleTable

local ActorStateManager = {}

local function validateInt(value, min, max)
    intValue = tonumber(value)

    if intValue == nil then return nil end
    if min ~= nil and intValue < min then return nil end
    if max ~= nil and intValue > max then return nil end
    
    return intValue
end

local function validateParam(paramName, paramValue)
    paramName = paramName:lower(paramName)
    if paramName == 'act' then
        if paramValue ~= 'enable' and paramValue ~= 'disable' then
            error(string.format(
                "Invalid parameter value for <%s>: 'enable' or 'disable' expected, got '%s'",
                paramName, paramValue
            ))
        end
        finalParamValue = paramValue
    elseif paramName == 'group' then
        finalParamValue = paramValue
    elseif paramName == 'with' then
        finalParamValue = paramValue
    elseif paramName == 'prob' then
        finalParamValue = validateInt(paramValue, 0, 100)
        if finalParamValue == nil then
            error(string.format(
                "Invalid parameter value for <%s>: number between 0 to 100 expected, got '%s'",
                paramName, paramValue
            ))
        end
    elseif paramName == 'num' then
        finalParamValue = validateInt(paramValue, 0)
        if finalParamValue == nil then
            error(string.format(
                "Invalid parameter value for <%s>: number greater than or equal to 0 expected, got '%s'",
                paramName, paramValue
            ))
        end
    elseif paramName == 'min' then
        finalParamValue = validateInt(paramValue, 0)
        if finalParamValue == nil then
            error(string.format(
                "Invalid parameter value for <%s>: number greater than or equal to 0 expected, got '%s'",
                paramName, paramValue
            ))
        end
    elseif paramName == 'max' then
        finalParamValue = validateInt(paramValue, 0)
        if finalParamValue == nil then
            error(string.format(
                "Invalid parameter value for <%s>: number greater than or equal 0 expected, got '%s'",
                paramName, paramValue
            ))
        end 
    else
        error(string.format("Unknown parameter name <%s>", paramName, paramValue))
    end

    return { name=paramName, value=finalParamValue }
end

local function parseTag(tag)
    local finalParamValue
    local _, _, paramName, paramValue = string.find(tag, "(%a+)%s*=%s*(.+)")
    
    -- soft fail on empty name or value
    if paramName == nil or paramName == '' then return nil end
    if paramValue == nil or paramValue == '' then return nil end
    
    -- check value is valid for known parameters
    return validateParam(paramName, paramValue)
end

local function parseTags(tags)
    local params = {}
    for _, tag in ipairs(tags) do
        local param = parseTag(tag)
        if param ~= nil then            
            params[param.name] = param.value
        end
    end
    return params
end

local function debugParams(params)
    if params == nil then return '(nil)' end
    if tableIsEmpty(params) then return '(none)' end

    local out = {}
    -- order of params (just for predictable output during tests)
    local paramsIndex = { 'group', 'act', 'prob', 'num', 'min', 'max', 'with' }
    for _, paramName in ipairs(paramsIndex) do
        local paramValue = params[paramName]
        if paramValue ~= nil then
            table.insert(out, string.format('%s=%s', paramName, paramValue))
        end
    end
    return table.concat(out, ', ')
end

local function genericDebugParams(params)
    out = {}
    for paramName, paramValue in pairs(params) do
        table.insert(out, string.format('%s=%s', paramName, paramValue))
    end
    return table.concat(out, ', ')
end

local function extractParams(anActor)
    log:Debug(sprintf("Parsing parameters for actor '%s'...",
        actor.GetName(anActor)))

    local success, result = pcall(function()
        -- returns for the inline function, not extractParams
        return parseTags(actor.GetTags(anActor))
    end)
    
    if not success then
        local error = result
        log:Error(sprintf("Parameter parsing failed for actor '%s': %s",
            actor.GetName(anActor), error))
        return {}
    end
    
    local params = result
    
    log:Debug(sprintf("  Found %s parameter(s): %s",
        count(params), genericDebugParams(params)))
    return params
end

-- Set visibility and or collision of an actor according to the given state
local function setGBActorState(target, state)
    local out = {}
    if state.visible ~= nil then
        actor.SetHidden(target, not state.visible)
        table.insert(out, sprintf("visible=%s", state.visible))
    end
    if state.collide ~= nil then
        actor.SetEnableCollision(target, state.collide)
        table.insert(out, sprintf("collide=%s", state.collide))
    end
    local actorStateStr
    if tableNotEmpty(out) then
        actorStateStr = table.concat(out, ', ') else
        actorStateStr = '(no change)' end

    log:Debug(sprintf("  Actor '%s' new state: %s", actor.GetName(target), actorStateStr))
end

-- function to use with Tables.filter
local function hasGroupParam(tbl)
    return tbl.params ~= nil and tbl.params.group ~= nil
end

-- function to use with Tables.reduce
local function groupActionArgs(action, result)
    local groupName = action.params.group
    if result[groupName] == nil then
        result[groupName] = {}
    end
    table.insert(result[groupName], action)
    return result
end

-- function to use with Tables.map
local function mergeGroupedActionArgsList(actionArgsList)
    -- make a list of targets
    local targets = map(actionArgsList, function(actionArgs)
        return actionArgs.targets[1]
    end)
    -- make a list of params and merge them all
    local params = map(actionArgsList, function(actionArgs)
        return actionArgs.params
    end)
    params = mergeAssoc(table.unpack(params))

    return { targets = targets, params = params }
end

-- Instantiate the ActorStateManager
function ActorStateManager:create()
    self.__index = self
    local self = setmetatable({}, self)
    self.flagTag = default('ActorState')
    self.stateByActorName = defaultTable({}, true)
    -- ^ this is a map of actor states by actor name. Used when we need to
    -- decide the state of an actor based on the state of other actors. Enmpty
    -- index returns true (enabled).

    log:Info('ActorStateManager instantiated')
    return self
end

-- Enable or disable an actor using the setActorState method
function ActorStateManager:enableActor(target, shouldEnable)
    setGBActorState(target, {
        visible = shouldEnable,
        collide = shouldEnable,
    })
   
    self.stateByActorName[actor.GetName(target)] = shouldEnable
end

--- Enable or disable the given actors based on the given parameters
 -- 
 -- @param  targets Table - optional, defaults to empty table
 --     List of actors (as returned by the GB API).
 --
 -- @param  params Table - optional, defaults to empty table
 --     Map of parameters by parameter name.
 --
 -- @return Table
 --     Map of actor states by actor name. The states that have been set by this
 --     call. Keys are the actors names, values are the corresponding states.
 --
function ActorStateManager:setState(targets, params)
    local result = {}
    local targetCount = #targets
    if targetCount == 0 then return result end
    
    params = default(params, {})

    -- print what we are processing (group, named group or single actor)
    if targetCount > 1 then
        if params.group then
            log:Info(sprintf("Processing '%s' actor group...", params.group)) else
            log:Info(sprintf("Processing unnamed actor group..."))
        end
    else
        log:Info(sprintf("Processing single actor '%s'...",
            actor.GetName(targets[1])))
    end

    -- debug given params
    log:Debug(sprintf('  Given params: %s', debugParams(params)))
    

    -- the three variables we need to execute are probRealised, num and reverse
    local reverse = params.act == 'disable'
    local prob = params.prob or 100
    local probRealised = math.random(100) <= prob
    local num
    -- compute a num value
    -- If neither num, min or max is provided num then num defaults to target count.
    -- If num is not provided but we have either a min or a max, compute a
    -- random num value between min and max.
    if params.num == nil and
       params.min == nil and
       params.max == nil
    then
        num = targetCount
    elseif params.num ~= nil then
        num = params.num
    else
        -- set default values for min and max
        local min = default(params.min, 0)
        local max = default(params.max, targetCount)
        -- force enableMin between 0 and targetCount
        min = math.max(0, math.min(min, targetCount))
        -- force max between min and targetCount
        max = math.max(min, math.min(max, targetCount))
        -- pick a random number of targets to enable
        num = math.random(min, max)
        -- print(string.format('min: %s, max: %s, computed num: %s', min, max, num))
    end
    local linkedActorName = params.with
    local shouldCompleteLinkedActorName
    -- special case to when the linkedActorName ends with _, we  use the actor's
    -- name suffix to complete linkedActorName
    if linkedActorName then
        shouldCompleteLinkedActorName = linkedActorName:sub(-1) == '_'
    end

    -- debug computed params
    log:Debug(sprintf('  Effective params: probRealised=%s, num=%s, with=%s, reverse=%s', probRealised, num, linkedActorName, reverse))
    
    -- process the targets
    local countTargets = 0
    for index, target in ipairs(shuffleTable(targets)) do
        local reachedNum = index > num

        local shouldEnable = true
        if linkedActorName then
            if shouldCompleteLinkedActorName then
                local actorName = actor.GetName(target)
                local suffix = actorName:sub(actorName:find("_[^_]*$") + 1)
                linkedActorName = linkedActorName .. suffix
            end
            local isLinkedActorEnabled = self.stateByActorName[linkedActorName]
            log:Debug(sprintf("  Actor '%s' is enabled: %s", linkedActorName, isLinkedActorEnabled))
            if not self.stateByActorName[linkedActorName] then
                shouldEnable = not shouldEnable
            end
        end
        if not probRealised then shouldEnable = not shouldEnable end
        if reachedNum       then shouldEnable = not shouldEnable end
        if reverse          then shouldEnable = not shouldEnable end



        self:enableActor(target, shouldEnable)
        result[actor.GetName(target)] = shouldEnable
    end

    return result
end

-- Call :setState() for each target group while delaying some as needed
function ActorStateManager:setStateFromList(actions)
    -- delay actions having the "with" param since they depend on other actions
    local delayedActions = {}
    
    for _, action in pairs(actions) do
        if action.params and action.params.with ~= nil
            then table.insert(delayedActions, action)
            else self:setState(action.targets, action.params)
        end
    end

    for _, action in pairs(delayedActions) do
        self:setState(action.targets, action.params)
    end
end

-- Parse actors tags to create a list of actions
function ActorStateManager:parseActors(flagTag)
    flagTag = default(flagTag, self.flagTag)
    log:Info(sprintf("Gathering actors with tag '%s'...", flagTag))
    local targets = gameplaystatics.GetAllActorsWithTag(flagTag)
    log:Info(sprintf("  Found %s actor(s)", #targets))

    -- extract params and store them along their corresponding actor
    -- to create a table accepted by the exec method
    local actionArgsList = map(targets, function(target)
        return {
            targets = { target },
            params = extractParams(target)
        }
    end)

    log:Info("Creating action list...")
    
    -- extract actions on single actor (no group)
    local loneActionArgsList = filterNot(actionArgsList, hasGroupParam)

    -- extract actions with a group parameter, group and merge them
    local actionArgsToGroup = filter(actionArgsList, hasGroupParam)
    local groupedActionArgs = reduce(actionArgsToGroup, groupActionArgs, {})
    local groupActionArgsList = map(groupedActionArgs, mergeGroupedActionArgsList)

    -- concatenate both ActionArgsList
    local actorStateActionArgList = concatTables(
        loneActionArgsList,
        groupActionArgsList
    )

    -- create list of actions to process with ActorStateManager:setStateFromList()
    local actions = actorStateActionArgList
    
    log:Info(sprintf("  Created %s action(s)",  #actions))

    return actions
end

return ActorStateManager
