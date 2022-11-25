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

local Graph           = require('common.Graph.Graph')

local tprint = function(tbl, lbl)
    if lbl then
        return print(lbl..' '..require('common.Tables').debug(tbl))
    else
        return print(require('common.Tables').debug(tbl))
    end
end

-- edge list for a square building of 4 rooms
--  ___ ___
-- | A | B |
-- |___|___|
-- | D | C |
-- |___|___|

local edgeList = {
    { 'A', 'B' },
    { 'A', 'B' },
    { 'B', 'C' },
    { 'B', 'C' },
    { 'C', 'D' },
    { 'C', 'D' },
    { 'D', 'A' },
    { 'D', 'A' },
}

local graph = Graph.create()
     :addEdge('B', 'A', { 01, 02, 03 })
     :addEdge('B', 'C', { 24, 25, 26 })
     :addEdge('C', 'D', { 37, 38, 39 })
     :addEdge('D', 'A', { 40, 41, 42 })
     -- :addEdge('A', '0', { 'W_A1', 'W_A2' })
     -- :addEdge('B', '0', { 'W_B1', 'W_B2' })
     -- :addEdge('0', 'C', { 'W_C1', 'W_C2' })
     -- :addEdge('D', '0', { 'W_D1', 'W_D2' })

-- print()
print(graph)
print('Graph is connected: '..tostring(graph:isConnected()))

print()

-- print("dissolving edge { 'A', 'B' }...")
-- graph:dissolveEdge('A', 'B')
-- print("dissolving edge { 'A+B', 'C' }...")
-- graph:dissolveEdge('A+B', 'C')

print("dissolving random edge...")
graph:dissolveEdge(graph:getRandomEdge())

print("dissolving random edge...")
graph:dissolveEdge(graph:getRandomEdge())

print()

print(graph)
print('Graph is connected: '..tostring(graph:isConnected()))