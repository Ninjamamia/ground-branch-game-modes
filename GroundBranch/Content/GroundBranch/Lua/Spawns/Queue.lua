
local Queue = {
    SpawnQueue = {},
    CurrSpawnItem = nil,
    tiSpawnQueue = 0,
    Timer = {
        Name = 'SpawnQueue',
        TimeStep = 0.25,
    },
}

Queue.__index = Queue

---Creates a new spawn queue object.
---@return table Queue Newly create Queue object.
function Queue:Create()
    local self = setmetatable({}, Queue)
    self.SpawnQueue = {}
	self.CurrSpawnItem = nil
	self.tiSpawnQueue = 0
    return self
end

function Queue:Reset()
	self.tiSpawnQueue = 0
	self.SpawnQueue = {}
	self.CurrSpawnItem = nil
end

function Queue:Enqueue(delay, duration, count, spawnPoints, spawnTag, postSpawnCallback, postSpawnCallbackTarget)
	local NewItem = {
		tiSpawn = self.tiSpawnQueue + delay,
		duration = duration,
		count = count,
		spawnPoints = spawnPoints,
		spawnTag = spawnTag,
		postSpawnCallback = postSpawnCallback or nil,
		postSpawnCallbackTarget = postSpawnCallbackTarget or nil
	}
	if #self.SpawnQueue == 0 then
		table.insert(self.SpawnQueue, NewItem)
	else
		for i, CurrItem in ipairs(self.SpawnQueue) do
			if CurrItem.tiSpawn > NewItem.tiSpawn then
				table.insert(self.SpawnQueue, i, NewItem)
				return
			end
		end
		table.insert(self.SpawnQueue, NewItem)
	end
end

function Queue:OnSpawnQueueTick()
	self.tiSpawnQueue = self.tiSpawnQueue + self.Timer.TimeStep
	if #self.SpawnQueue <= 0 then
		return
	end
	if self.CurrSpawnItem == nil then
		self.CurrSpawnItem = self.SpawnQueue[1]
		print('SpawnQueue: Will Spawn ' .. self.CurrSpawnItem.count .. ' ' .. self.CurrSpawnItem.spawnTag .. ' in ' .. self.CurrSpawnItem.tiSpawn - self.tiSpawnQueue .. 's')
	end
	if self.tiSpawnQueue >= self.CurrSpawnItem.tiSpawn then
		print('SpawnQueue: Spawning ' .. self.CurrSpawnItem.count .. ' ' .. self.CurrSpawnItem.spawnTag .. ' frozen for ' .. self.CurrSpawnItem.duration .. 's')
		table.remove(self.SpawnQueue, 1)
        for i, spawnPoint in ipairs(self.CurrSpawnItem.spawnPoints) do
			if i > self.CurrSpawnItem.count then
				break
			end
            ai.Create(spawnPoint, self.CurrSpawnItem.spawnTag, self.CurrSpawnItem.duration)
        end
		if self.CurrSpawnItem.postSpawnCallback ~= nil and self.CurrSpawnItem.postSpawnCallbackTarget ~= nil then
			self.CurrSpawnItem.postSpawnCallback(self.CurrSpawnItem.postSpawnCallbackTarget)
		end
		self.CurrSpawnItem = nil
	end
end

---Must be called every time the timers have been reset globally
function Queue:Start()
	timer.Set(
				self.Timer.Name,
				self,
				self.OnSpawnQueueTick,
				self.Timer.TimeStep,
				true
			)
end

return Queue