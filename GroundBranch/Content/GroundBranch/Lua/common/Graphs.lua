local DoubleQueue = require('common.DoubleQueue')
local all = require('common.Tables').all
local map = require('common.Tables').map
local shuffleTable = require('common.Tables').ShuffleTable
local sprintf = require('common.Strings').sprintf

local isTrue = function(value)
	if value == true then return true else return false end
end

local Graphs = {}

function Graphs.edgeListToAdjacencyMap(edgeList)
	-- turn the edge list to an adjacency map where each key is a node, and
    -- values are the connected nodes
    local adjacencyMap = {}
    for _, edge in pairs(edgeList) do
    	if nil == adjacencyMap[edge[1]] then adjacencyMap[edge[1]] = {} end
    	if nil == adjacencyMap[edge[2]] then adjacencyMap[edge[2]] = {} end
        table.insert(adjacencyMap[edge[1]], edge[2])
        table.insert(adjacencyMap[edge[2]], edge[1])
    end
    return adjacencyMap
end

function Graphs.traverse(adjacencyMap)
	-- build a list of nodes to visit
	local visited = {}
	for node, _ in pairs(adjacencyMap) do visited[node] = false end

	-- Use a queue to perform breadth first traversal (opposed to depth first)
	local queue = DoubleQueue:new()

	-- get a random first node and add it to the queue
	queue:enqueue(next(adjacencyMap))
	
	-- loop until the end of time - or until queue:pop() returns nil
	while true do
		-- stop if there's no more node to process (pop returned nil)
		local currentNode = queue:pop()		
		if nil == currentNode then break end

		-- skip already visited nodes
		if not visited[currentNode] then
			-- add current node to the list of visited node
			visited[currentNode] = true
			-- add connected (but not yet visited) nodes to the queue
			for _, connectedNode in ipairs(adjacencyMap[currentNode]) do
				if not visited[connectedNode] then queue:enqueue(connectedNode) end
			end
		end
	end

	return visited
end

function Graphs.dissolveEdges(edgeList, number)
	local debugTable = require('common.Tables').debug

	print('edge list: ', debugTable(edgeList))

	
	local rndEdgeList = shuffleTable(edgeList)

	local edgesToDissolve = { table.unpack(rndEdgeList, 1, number) }
	local restingEdges = { table.unpack(rndEdgeList, number + 1) }
	
	-- print(sprintf('Dissolving %s random edges %s', number, debugTable(edgesToDissolve)))

	local replaceMap = {}
	for _, edge in ipairs(edgesToDissolve) do
		print(sprintf('%s merges into %s', edge[2], edge[1]))
		replaceMap[edge[2]] = edge[1]
	end
	print()

	local function rpl(val)
		if not replaceMap[val] then return val end
		return rpl(replaceMap[val])
	end

	print(debugTable(restingEdges))

	local result = map(restingEdges, function(edge)
		edge = map(edge, rpl)
		-- if the edge has both sides to the same node, it's not an edge anymore
		if edge[1] == edge[2] then return nil end
		-- else return the updated edge
		return edge
	end)
	print(debugTable(result))
end

function Graphs.isConnected(adjacencyMap)
	local visited = Graphs.traverse(adjacencyMap)
	return all(visited, isTrue)
end

-- get a random subset of the given edges that allows to connect the graph
function Graphs.connectWithRandomEdges(nodeList, edgeList)
    -- goal is to build a new graph, we start with a list of unlinked nodes,
    -- and will add random connections using the edge list we have until the new
    -- graph is connected
    
    -- create an adjacency map with all nodes but no connections
    local selectedEdges = {}

    -- build a graph with nodes only (map with all keys set to empty lists)
    local newGraph = {}
    for _, key in ipairs(nodeList) do newGraph[key] = {} end

    -- shuffle the edge list to pick edges in random order
    local shuffledEdgeList = shuffleTable(edgeList)

    local isNewGraphConnected = false

    -- add edges from our shuffled edge list until the newGraph is connected
    for _, edge in pairs(shuffledEdgeList) do
        local node1, node2 = edge[1], edge[2]
        table.insert(newGraph[edge[1]], edge[2])
        table.insert(newGraph[edge[2]], edge[1])
        table.insert(selectedEdges, edge)
        if Graphs.isConnected(newGraph) then
            isNewGraphConnected = true
            break
        end
    end
    if not isNewGraphConnected then
        error('graph:connectWithRandomEdges(): Failed to connect graph', 2)
    end

    return selectedEdges
end

return Graphs
