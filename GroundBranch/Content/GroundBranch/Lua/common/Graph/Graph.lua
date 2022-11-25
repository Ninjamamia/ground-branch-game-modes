local tprint = function(tbl, lbl)
    if lbl then
        return print(lbl..' '..require('common.Tables').debug(tbl))
    else
        return print(require('common.Tables').debug(tbl))
    end
end


local edgeListToAdjacencyMap = require('common.Graphs').edgeListToAdjacencyMap
local isConnectedGraph       = require('common.Graphs').isConnected
local getKeys = require('common.Tables').getKeys
local map = require('common.Tables').map
local isEmpty = require('common.Tables').isEmpty
local printf = require('common.Strings').printf
local sprintf = require('common.Strings').sprintf
local tableConcat     = require('common.Tables').ConcatenateTables
local tableMerge     = require('common.Tables').naiveMergeAssocTables
local default = require('common.Values').default
local Set = require('common.Set')


local Graph = {}
Graph.__index = Graph

function Graph.create()
    return Graph:new()
end

function Graph:new()
    local self = setmetatable({}, self)
    self.nodes = Set()
    self.edgeMap = {}
    return self
end

function Graph:addEdge(node1, node2, data)
    -- silently ignore
    if node1 == node2 then return end
    if node1 == nil then error("Graph.addEdge(): argument 'node1' cannot be nil") end
    if node2 == nil then error("Graph.addEdge(): argument 'node2' cannot be nil") end

    data = default(data, {})

    self.nodes.insert(node1)
    self.nodes.insert(node2)
    
    local newEdge = Set({node1, node2})
    local existingEdge = nil
    for edge, _ in pairs(self.edgeMap) do
        if newEdge == edge then
            existingEdge = edge
            break
        end
    end

    if not existingEdge then
        self.edgeMap[newEdge] = data
    else
        self.edgeMap[existingEdge] = tableConcat(self.edgeMap[existingEdge], data)
    end

    return self
end

function Graph:dissolveEdge(node1, node2)

    debugOn = default(debugOn, false)

    if not self.nodes.has(node1) then
       error(sprintf("node '%s' is not part of the graph", node1), 2)
    end
    if not self.nodes.has(node2) then
       error(sprintf("node '%s' is not part of the graph", node2), 2)
    end

    -- remove nodes to merge from node set
    self.nodes.delete(node1)
    self.nodes.delete(node2)
    
    -- add merged node to node set
    local newNode = node1..'+'..node2
    self.nodes.insert(newNode)

    -- update edge map
    local edgeToDissolve = Set({ node1, node2 })
    local uniqueEdgeMap = {}
    local edgeList = getKeys(self.edgeMap)
    local dataFromEdgeToDissolve = nil
    for _, edge in ipairs(edgeList) do

        if edgeToDissolve == edge then
            dataFromEdgeToDissolve = self.edgeMap[edge]
            self.edgeMap[edge] = nil
        else
            local edgesIntersection = edgeToDissolve.intersection(edge)
            if edgesIntersection.size > 0 then
                edgesIntersection.each(edge.delete)
                edge.insert(newNode)
            end
        end
        
        local existingEdge = nil

        for uniqueEdge, _ in pairs(uniqueEdgeMap) do
            if edge == uniqueEdge then
                existingEdge = uniqueEdge
                break
            end
        end

        if not existingEdge then
            uniqueEdgeMap[edge] = self.edgeMap[edge]
        else
            uniqueEdgeMap[existingEdge] = tableConcat(uniqueEdgeMap[existingEdge], self.edgeMap[edge])
        end
    end
    
    self.edgeMap = uniqueEdgeMap

    return dataFromEdgeToDissolve
end

function Graph:isConnected()
    return isConnectedGraph(self:getAdjacencyMap())
end

function Graph:getAdjacencyMap()
    return edgeListToAdjacencyMap(self:getEdgeList())
end

function Graph:getEdgeList()
    return map(getKeys(self.edgeMap), function(edge)
        return edge.list()
    end)
end

function Graph:getRandomEdge()
    local edgeList = self:getEdgeList()
    return table.unpack(edgeList[math.random(1, #edgeList)])
end

function Graph:__tostring()
    local nodeList = self.nodes.list()
    table.sort(nodeList)
    local nodeStringList = map(nodeList, function(node)
        return sprintf('    %s', node)
    end)

    local edgesStringList = {}
    for edge, data in pairs(self.edgeMap) do
        


        table.insert(edgesStringList, sprintf('    %s contains { %s }',
            edge,
            table.concat(map(data, tostring), ', ')
        ))
        
    end

    local nodesString = table.concat(nodeStringList, string.char(10))
    local edgesString = table.concat(edgesStringList, string.char(10))

    return sprintf(
        '<Graph> {'..string.char(10)..
        '  nodes = { '..string.char(10)..
             nodesString..string.char(10)..
        '  }'..string.char(10)..
        '  edges = { '..string.char(10)..
             edgesString..string.char(10)..
        '  }'..string.char(10)..
        '}'
    )
end

return Graph
