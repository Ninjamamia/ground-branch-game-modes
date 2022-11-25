--- Double queue can be used either as a queue or a stack
---
--- @source http://www.lua.org/pil/11.4.html
---
local DoubleQueue = {}

DoubleQueue.__index = DoubleQueue

function DoubleQueue.create()
    return DoubleQueue:new()
end

function DoubleQueue:new()
    local self = setmetatable({}, self)
    self.first = 0
    self.last = -1
    return self
end

-- add item to the queue
function DoubleQueue:enqueue(value)
    local first = self.first - 1
    self.first = first
    self[first] = value
end

-- push item on the stack
function DoubleQueue:push(value)
    local last = self.last + 1
    self.last = last
    self[last] = value
end

-- remove last added item from the queue
function DoubleQueue:dequeue()
    local first = self.first
    if first > self.last then return nil end
    local value = self[first]
    self[first] = nil        -- to allow garbage collection
    self.first = first + 1
    return value
end

-- remove item from stack
function DoubleQueue:pop()
    local last = self.last
    if self.first > last then return nil end
    local value = self[last]
    self[last] = nil         -- to allow garbage collection
    self.last = last - 1
    return value
end

return DoubleQueue
