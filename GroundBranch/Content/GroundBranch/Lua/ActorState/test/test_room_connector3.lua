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
local map             = require('common.Tables').map
local each            = require('common.Tables').each
local empty            = require('common.Tables').isEmpty
local getKeys         = require('common.Tables').getKeys
local shuffleTable    = require('common.Tables').ShuffleTable
local printf          = require('common.Strings').printf
local doubleQueue     = require('common.DoubleQueue')
local tableConcat     = require('common.Tables').ConcatenateTables
local ParamParser     = require('common.ParamParser')
local Graph           = require('common.Graph.Graph')

local tprint = function(tbl, lbl)
    if lbl then
        return print(lbl..' '..require('common.Tables').debug(tbl))
    else
        return print(require('common.Tables').debug(tbl))
    end
end

-- square building of 4 rooms, 2 actors per edge
--  ___ ___
-- | A | B |
-- |___|___|
-- | D | C |
-- |___|___|


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

-- create a graph and link actors to their corresponding edge
local graph = Graph.create()
each(actorsAndParams, function(item)
    graph:addEdge(
        item.params.room1,
        item.params.room2,
        { item.actor }
    )
end)

-- check graph is connected
print(graph)
print('Graph is connected: '..tostring(graph:isConnected()))
print()

-- merge random nodes and hide all of the linked actors
print("Dissolving random edge...")
local actorsToHide = graph:dissolveEdge(graph:getRandomEdge())
tprint(actorsToHide, 'Actors to hide')

-- merge more random nodes but only hide one actor in 12
-- do this until the graph is a single node (meaning every room is connected)
print("Dissolving random edge...")
local actorsToHide = graph:dissolveEdge(graph:getRandomEdge())
tprint(actorsToHide, 'Actors to hide')

print(graph)
