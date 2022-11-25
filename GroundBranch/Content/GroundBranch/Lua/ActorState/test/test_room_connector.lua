-- add path to the  GB 'Lua' directory to package.path (used for requires)
if not _G['gbLuaDirInPath'] then
    local DIR_SEP = package.config:sub(1,1)
    local currentScriptPath = arg[0]
    local workingDir = os.getenv('CWD') or
                       os.getenv('PWD') or
                       os.getenv('WD') or
                       os.getenv('CD')
    if currentScriptPath ~= nil and workingDir ~= nil then
        local fullPath = workingDir..DIR_SEP..currentScriptPath
        local substrIndex = fullPath:find('[\\/]GroundBranch[\\/]Lua[\\/]')
        if substrIndex ~= nil then
            local gbLuaDir = fullPath:sub(1, substrIndex+17)
            package.path = gbLuaDir .. "?.lua;" .. package.path
            _G['gbLuaDirInPath'] = true
        end
    end
end

actor                 = require('test.mocks').Actor
local ParamParser     = require('common.ParamParser')
local map             = require('common.Tables').map
local each            = require('common.Tables').each
local empty            = require('common.Tables').isEmpty
local getKeys         = require('common.Tables').getKeys
local shuffleTable    = require('common.Tables').ShuffleTable
local printf          = require('common.Strings').printf
local doubleQueue     = require('common.DoubleQueue')
local tableConcat     = require('common.Tables').ConcatenateTables

local tprint = function(tbl, lbl)
    if lbl then
        return print(lbl..' '..require('common.Tables').debug(tbl))
    else
        return print(require('common.Tables').debug(tbl))
    end
end

local actorList = {
    actor.create('edge_AB_1'):SetTags({ 'GraphConnector', 'room1=A', 'room2=B' }),
    actor.create('edge_AB_2'):SetTags({ 'GraphConnector', 'room1=A', 'room2=B' }),
    actor.create('edge_BC_1'):SetTags({ 'GraphConnector', 'room1=B', 'room2=C' }),
    actor.create('edge_BC_2'):SetTags({ 'GraphConnector', 'room1=B', 'room2=C' }),
    actor.create('edge_CD_1'):SetTags({ 'GraphConnector', 'room1=C', 'room2=D' }),
    actor.create('edge_CD_2'):SetTags({ 'GraphConnector', 'room1=C', 'room2=D' }),
    actor.create('edge_DA_1'):SetTags({ 'GraphConnector', 'room1=D', 'room2=A' }),
    actor.create('edge_DA_2'):SetTags({ 'GraphConnector', 'room1=D', 'room2=A' }),
}

-- parsing actors params from their tags
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
    }
})

local actorsAndParams = map(actorList, function(actorItem) return {
    actor = actorItem,
    params = paramParser:parse(actor.GetTags(actorItem))
} end)

-- tprint(actorList)
-- tprint(actorsAndParams)

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

-- tprint(actorsPerEdges, 'actorsPerEdges')

-- build a proper edge list (ordered)
local edgeList = {}

local lvl1Keys = getKeys(actorsPerEdges)
table.sort(lvl1Keys)

for _, node1 in ipairs(lvl1Keys) do

    local lvl2Keys = getKeys(actorsPerEdges[node1])
    table.sort(lvl2Keys)
    
    for _, node2 in ipairs(lvl2Keys) do
        
        local actors = actorsPerEdges[node1][node2]
        local edge = { node1, node2 }

        table.sort(edge)
        table.insert(edgeList, edge)
        printf('Found edge: %s / %s (%s actors)', node1, node2, #actors)
    end
end
print()
-- printf('Found %s edges', #edgeList)

local shuffledEdgeList = shuffleTable(edgeList)

-- tprint(edgeList)
-- tprint(shuffledEdgeList, 'shuffledEdgeList')


local numberOfEdgesToDissolve = 1
local edgeQueue = doubleQueue.create()

for i=1, numberOfEdgesToDissolve do
    edgeQueue:push(shuffledEdgeList[i])
end

tprint(actorsPerEdges, 'actorsPerEdges')

-- build a list of actors to disable and update the actorsPerEdges map
-- again a set would make it easier, here we have to check both directions
local actorsToDisable = {}
for i=1, numberOfEdgesToDissolve do
    local edge = edgeQueue:pop()
    local node1, node2 = table.unpack(edge)
    printf('Dissolving edge %s / %s <=> merge node %s in %s',
        node1, node2, node2, node1)

    -- remove the edge from actorsPerEdges, and store away the related actors

    if actorsPerEdges[node1][node2] then
        edgeActors = actorsPerEdges[node1][node2]
        actorsPerEdges[node1][node2] = nil
        if empty(actorsPerEdges[node1]) then actorsPerEdges[node1] = nil end

    elseif actorsPerEdges[node2][node1] then
        edgeActors = actorsPerEdges[node2][node1]
        actorsPerEdges[node2][node1] = nil
        if empty(actorsPerEdges[node2]) then actorsPerEdges[node2] = nil end

    else
        error('Edge not found')

    end

    -- replace references to the merged node in actorsPerEdges
    if actorsPerEdges[node2] then
        if not actorsPerEdges[node1] then actorsPerEdges[node1] = {} end
        
        for node, actors in actorsPerEdges[node2] do
            actorsPerEdges[node1][node] = actors
        end
    end

    for node1, subActorsPerEdges in pairs(actorsPerEdges) do
        for node2, actors in pairs(subActorsPerEdges) do
        end
    end

    actorsToDisable = tableConcat(actorsPerEdges, edgeActors)
end

-- tprint(actorsToDisable, 'actorsToDisable')
tprint(actorsPerEdges, 'actorsPerEdges')
