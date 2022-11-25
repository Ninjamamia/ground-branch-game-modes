local each = require('common.Tables').each
local map = require('common.Tables').map
local count = require('common.Tables').count
local default = require('common.Values').default
local log = require('common.Logger').new('RoomConnector')
local sprintf = require('common.Strings').sprintf
local ParamParser = require('common.ParamParser')
local getKeys = require('common.Tables').getKeys
local edgeListToAdjacencyMap = require('common.Graphs').edgeListToAdjacencyMap
local isConnectedGraph = require('common.Graphs').isConnected
local connectWithRandomEdges = require('common.Graphs').connectWithRandomEdges

local RoomConnector = {}

RoomConnector.__index = RoomConnector

-- Instantiate the RoomConnector
function RoomConnector:new()
    local self = setmetatable({}, self)
    self.flagTag = default('RoomConnector')
    -- log:SetLogLevel('INFO')
    log:SetLogLevel('DEBUG')
    log:Info('RoomConnector instantiated')
    return self
end

function RoomConnector:parseActors()
    -- the actors have tags allowing to build an edge list, a common
    -- representation for a graph, each edge is connecting exactly two nodes    

    -- get actors wearing the flag tag
    log:Debug(sprintf("Gathering actors with tag '%s'...", self.flagTag))
    local actorList = gameplaystatics.GetAllActorsWithTag(self.flagTag)
    for _, act in pairs(actorList) do
        log:Debug(sprintf('  Found actor: %s', actor.GetName(act)))
    end
    log:Debug(sprintf('  Found %s actors', #actorList))
    
    -- parsing actors params from their tags
    local paramParser = ParamParser:new({
        {
            error = "Parameters 'room1' and 'room2' are required",
            validates = function(params)
                if not params.room1 then return false end
                if not params.room2 then return false end
                return params
            end
        }, {
            error = "Parameters 'room1' and 'room2' cannot be equal",
            validates = function(params)
                if params.room1 == params.room2 then return false end
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
    log:Debug('Creating edge list...')
    -- create a proper edge list from the 3D array
    local edgeList = {}
    for node1, subActorsPerEdges in pairs(actorsPerEdges) do
        for node2, actors in pairs(subActorsPerEdges) do
            table.insert(edgeList, {node1, node2})
            log:Debug(sprintf('  Found edge: %s / %s (%s actors)', node1, node2, #actors))
        end
    end
    log:Debug(sprintf('  Found %s edges', #edgeList))

    -- turn edge list to adjacency map
    log:Debug('Creating adjacency map...')
    local adjacencyMap = edgeListToAdjacencyMap(edgeList)
    for node,_ in pairs(adjacencyMap) do
        log:Debug(sprintf('  Found node: %s', node))
    end
    log:Debug(sprintf('  Found %s nodes', count(adjacencyMap)))

    -- extract a proper node list
    local nodeList = getKeys(adjacencyMap)

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
        log:Debug(sprintf('  Created group: %s', groupName))
        return {
            targets = targets,
            params = { group=groupName, act='disable', min=1, max=2 },
        }
    end)
    log:Info(sprintf('Created %s actor state groups', #actorStateGroups))

    -- return a list of actor state groups
    return actorStateGroups
end

return RoomConnector
