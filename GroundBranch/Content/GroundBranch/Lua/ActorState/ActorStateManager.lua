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
local log              = require('ActorState.ActorStateLogger')
local ParamParser      = require('common.ParamParser')
local sprintf          = require('common.Strings').sprintf
local count            = require('common.Tables').count
local tableIsEmpty     = require('common.Tables').isEmpty
local tableContains    = require('common.Tables').Index
local map              = require('common.Tables').map
local debugTable       = require('common.Tables').debug
local tableNotEmpty    = require('common.Tables').notEmpty
local mergeAssoc       = require('common.Tables').naiveMergeAssocTables
local reduce           = require('common.Tables').reduce
local defaultTable     = require('common.Tables').setDefault
local shuffleTable     = require('common.Tables').ShuffleTable
local default          = require('common.Values').default

local sum = require('common.Tables').sum
local empty = require('common.Tables').isEmpty
local getKeys = require('common.Tables').getKeys
local edgeListToAdjacencyMap = require('common.Graphs').edgeListToAdjacencyMap
local dissolveGraphEdges = require('common.Graphs').dissolveEdges
local isConnectedGraph = require('common.Graphs').isConnected
local connectWithRandomEdges = require('common.Graphs').connectWithRandomEdges

local ActorStateManager = {}

ActorStateManager.__index = ActorStateManager

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

-- function to use with Tables.reduce
local function groupActionArgs(action, result)
    if not action.params.group then
        table.insert(result, { action })
    else
        local groupName = action.params.group
        if result[groupName] == nil then
            result[groupName] = {}
        end
        table.insert(result[groupName], action)
    end
    return result
end

-- function to use with Tables.map
local function mergeActionArgs(actionArgsList)
    -- make a list of targets
    local targets = map(actionArgsList, function(actionArgs)
        return actionArgs.target
    end)
    -- make a list of params and merge them all
    local params = map(actionArgsList, function(actionArgs)
        return actionArgs.params
    end)
    params = mergeAssoc(table.unpack(params))

    return { targets = targets, params = params }
end

local paramValidators = {
    {
        validates = function(params)
            local knownParams = {
                'act', 'prob', 'num', 'min', 'max', 'group', 'with'
            }
            for paramName, _ in pairs(params) do
                if not tableContains(knownParams, paramName) then
                    log:Error(sprintf("Unknown parameter name <%s>",
                        paramName))
                end
            end
            return params
        end,
    }, {
        paramName = 'act',
        validates = ParamParser.validators.inList{'enable', 'disable'},
        error = "'enable' or 'disable' expected, got '%s'",
    }, {
        paramName = 'prob',
        validates = ParamParser.validators.integer(0, 100),
        error = "number between 0 to 100 expected, got '%s'",
    }, {
        paramName = 'num',
        validates = ParamParser.validators.integer(0, 100),
        error = "number greater than or equal to 0 expected, got '%s'",
    }, {
        paramName = 'min',
        validates = ParamParser.validators.integer(0, 100),
        error = "number greater than or equal to 0 expected, got '%s'",
    }, {
        paramName = 'max',
        validates = ParamParser.validators.integer(0, 100),
        error = "number greater than or equal 0 expected, got '%s'",
    }
}

-- Instantiate the ActorStateManager
function ActorStateManager:create()
    local self = setmetatable({}, self)
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
    for index, target in ipairs(shuffleTable(targets)) do
        local reachedNum = index > num

        local shouldEnable = true
        local linkedActorDisabled = false
        
        if linkedActorName then
            if shouldCompleteLinkedActorName then
                local actorName = actor.GetName(target)
                local suffix = actorName:sub(actorName:find("_[^_]*$") + 1)
                linkedActorName = linkedActorName .. suffix
            end
            linkedActorDisabled = not self.stateByActorName[linkedActorName]
            log:Debug(sprintf("  Actor '%s' is enabled: %s", linkedActorName, not linkedActorDisabled))
        end
        
        if linkedActorDisabled then shouldEnable = not shouldEnable end
        if not probRealised    then shouldEnable = not shouldEnable end
        if reachedNum          then shouldEnable = not shouldEnable end
        if reverse             then shouldEnable = not shouldEnable end

        self:enableActor(target, shouldEnable)
        result[actor.GetName(target)] = shouldEnable
    end

    local actStr = reverse and 'enabled' or 'disabled'
    local actCount = sum(map(result, function(shouldEnable)
        if reverse ~= shouldEnable then return 1 else return 0 end
    end))

    log:Info(sprintf('%s %s actors', actStr, actCount))

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

-- Parse actors tags for simple state - return list of actions
function ActorStateManager:parseActors()
    local flagTag = 'ActorState'
    
    log:Info(sprintf("Gathering actors with tag '%s'...", flagTag))
    
    local targets = gameplaystatics.GetAllActorsWithTag(flagTag)

    log:Info(sprintf("  Found %s actor(s)", #targets))

    -- extract params and store them along their corresponding actor (target)
    local paramParser = ParamParser:new(paramValidators)
    local actionArgs = map(targets, function(target)
        return {
            target = target,
            params = paramParser:parse(actor.GetTags(target))
        }
    end)

    log:Info("Creating action list...")
    
    local grouped = reduce(actionArgs, groupActionArgs, {})
    local actions = map(grouped, mergeActionArgs)
    
    log:Info(sprintf("  Created %s action(s)",  #actions))

    return actions
end

-- Parse actors tags for graph - return list of actions
function ActorStateManager:parseActorsGraphConnector()
    local flagTag = 'GraphConnector'
    -- the actors have tags allowing to build an edge list, a common
    -- representation for a graph, each edge is connecting exactly two nodes    

    -- get actors wearing the flag tag
    log:Info(sprintf("Gathering actors with tag '%s'...", flagTag))
    local actorList = gameplaystatics.GetAllActorsWithTag(flagTag)
    for _, act in pairs(actorList) do
        log:Debug(sprintf('  Found actor: %s', actor.GetName(act)))
    end
    log:Debug(sprintf('  Found %s actors', #actorList))
    
    -- stop here if no actors were found
    if empty(actorList) then
        log:Info('No actors found, nothing to do')
        return {}
    end
    
    -- parsing actors params from their tags
    log:Info('Parsing actors parameters...')
    local paramParser = ParamParser:new({
        {
            error = "Parameters 'room1' and 'room2' are required",
            validates = function(params)
                if not params.room1 then return nil end
                if not params.room2 then return nil end
                return params
            end
        }, {
            error = "Parameters 'room1' and 'room2' cannot be equal",
            validates = function(params)
                if params.room1 == params.room2 then return nil end
                return params
            end
        }})
    local actorsAndParams = map(actorList, function(actorItem) return {
        actor = actorItem,
        params = paramParser:parse(actor.GetTags(actorItem))
    } end)

    -- build a map of actors per edges
    local actorsPerEdges = {}
    for _, data in ipairs(actorsAndParams) do
        -- Create a 2 dimensional array containing lists of actors. Allows to
        -- retrieve a list of actors for a given couple of nodes, ie. an edge.
        -- Unfortunately the order of the nodes in the couple cannot be
        -- predicted, so we have to test both [node1][node2] and [node2][node1].
        
        --- @todo might be a nice to implement a set and use it here

        if not data.params.room1 or not data.params.room2 then break end

        local node1 = data.params.room1
        local node2 = data.params.room2

        -- we have to try both ways [node1][node2] and [node2][node1]
        if actorsPerEdges[node1] and actorsPerEdges[node1][node2] then
            -- if edge is already in the map, append actor
            table.insert(actorsPerEdges[node1][node2], data.actor)

        elseif actorsPerEdges[node2] and actorsPerEdges[node2][node1] then
            -- if edge is already in the map, append actor
            table.insert(actorsPerEdges[node2][node1], data.actor)

        else
            -- if not, create a new list with the actor
            if not actorsPerEdges[node1] then actorsPerEdges[node1] = {} end
            actorsPerEdges[node1][node2] = { data.actor }
        end
    end

    -- build a proper edge list
    log:Info('Building edge list...')
    -- create a proper edge list from the 3D array
    local edgeList = {}
    for node1, subActorsPerEdges in pairs(actorsPerEdges) do
        for node2, actors in pairs(subActorsPerEdges) do
            local edge = { node1, node2 }
            table.sort(edge)
            table.insert(edgeList, edge)
            log:Debug(sprintf('  Found edge: %s / %s (%s actors)', node1, node2, #actors))
        end
    end
    log:Debug(sprintf('  Found %s edges', #edgeList))
    -- stop here if no edges were found
    if empty(edgeList) then
        log:Warn('No edges found, aborting process')
        return {}
    end




    -- turn edge list to adjacency map
    log:Info('Building adjacency map...')
    local adjacencyMap = edgeListToAdjacencyMap(edgeList)
    for node,_ in pairs(adjacencyMap) do
        log:Debug(sprintf('  Found node: %s', node))
    end
    log:Debug(sprintf('  Found %s nodes', count(adjacencyMap)))

    -- extract a proper node list (sorted)
    local nodeList = getKeys(adjacencyMap)
    table.sort(nodeList)


    print()


    -- pick random number of edges to dissolve
    local numberOfEdgesToDissolve = math.random(0, #edgeList)
    dissolveGraphEdges(edgeList, 3)
    -- dissolve a number of edges from the top of the list

    print()






    -- check if graph is connected
    local isGraphConnected = isConnectedGraph(adjacencyMap)

    -- log basic graph data
    log:Info(sprintf(
        'Found graph: %s nodes, %s potential edges, %s (%s actors)',
        #edgeList,
        count(adjacencyMap),
        isGraphConnected and 'connectable' or 'non-connectable',
        #actorList
    ))
    
    -- only process connected graph
    if not isGraphConnected then
        log:Error('Graph is NOT connectable, abort processing')
        return nil
    end

    -- select random edges to create a connected graph
    log:Debug('Connecting graph with random edges...')
    local selectedEdgeList = connectWithRandomEdges(nodeList, edgeList)
    for _, edge in pairs(selectedEdgeList) do
        local node1, node2 = edge[1], edge[2]
        log:Debug(sprintf('  Selected edge: %s / %s', node1, node2))
    end
    log:Info(sprintf('Selected %s of the potential edges for the final graph', #selectedEdgeList))
    
    -- arrange the actors of the selected edges in a list actor state groups
    log:Debug('Creating actor state groups...')
    local actorStateGroups = map(selectedEdgeList, function(nodes)
        
        local groupName = sprintf('graph_edge_%s/%s', nodes[1], nodes[2])
        local targets = actorsPerEdges[nodes[1]][nodes[2]]
        
        local prob = math.random(1,100)
        local params = { group=groupName, act='disable' }
        
        if 60 >= prob then
            -- 60% probability to have one opening only
            params.num = 1
            log:Debug(sprintf('  Created group: %s with 1 actor disabled', groupName))
        elseif 65 >= prob then
            -- 5% probability to have two openings
            params.num = 2
            log:Debug(sprintf('  Created group: %s with 2 actors disabled', groupName))
        else
            -- 35% probability to have wall completely open
            log:Debug(sprintf('  Created group: %s with all actors disabled', groupName))
        end

        return {
            targets = targets,
            params = params,
        }
    end)
    log:Info(sprintf('Created %s actor state groups', #actorStateGroups))

    -- return a list of actor state groups
    return actorStateGroups
end

return ActorStateManager
