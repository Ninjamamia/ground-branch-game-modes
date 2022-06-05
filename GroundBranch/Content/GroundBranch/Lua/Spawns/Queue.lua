
local Queue = {
    SpawnQueue = {},
    CurrSpawnItem = nil,
    tiSpawnQueue = 0,
    tiSpawnDurationLast = 0,
    Timer = {
        Name = 'SpawnQueue',
        TimeStep = 0.5,
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
	self.tiSpawnDurationLast = 0
    return self
end

function Queue:Enqueue(delay, duration, count, spawnPoints, spawnTag, postSpawnCallback, postSpawnCallbackTarget)
	table.insert(self.SpawnQueue, {
		delay = delay,
		duration = duration,
		count = count,
		spawnPoints = spawnPoints,
		spawnTag = spawnTag,
		postSpawnCallback = postSpawnCallback or nil,
		postSpawnCallbackTarget = postSpawnCallbackTarget or nil
	})
end

function Queue:OnSpawnQueueTick()
	self.tiSpawnQueue = self.tiSpawnQueue + self.Timer.TimeStep
	if #self.SpawnQueue <= 0 then
		return
	end
	if self.CurrSpawnItem == nil then
		self.CurrSpawnItem = self.SpawnQueue[1]
		self.CurrSpawnItem.delay = self.tiSpawnQueue + math.max(self.CurrSpawnItem.delay, self.tiSpawnDurationLast + 0.1)
		print('SpawnQueue: Will Spawn ' .. self.CurrSpawnItem.count .. ' ' .. self.CurrSpawnItem.spawnTag .. ' in ' .. self.CurrSpawnItem.delay - self.tiSpawnQueue .. 's')
	end
	if self.tiSpawnQueue >= self.CurrSpawnItem.delay then
		print('SpawnQueue: Spawning ' .. self.CurrSpawnItem.count .. ' ' .. self.CurrSpawnItem.spawnTag .. ' over ' .. self.CurrSpawnItem.duration .. 's')
		table.remove(self.SpawnQueue, 1)
		ai.CreateOverDuration(
			self.CurrSpawnItem.duration,
			self.CurrSpawnItem.count,
			self.CurrSpawnItem.spawnPoints,
			self.CurrSpawnItem.spawnTag
		)
		if self.CurrSpawnItem.postSpawnCallback ~= nil and self.CurrSpawnItem.postSpawnCallbackTarget then
			timer.Set('PostSpawnCallbackTimer', self.CurrSpawnItem.postSpawnCallbackTarget, self.CurrSpawnItem.postSpawnCallback, self.CurrSpawnItem.duration + 0.1, false)
		end
		self.tiSpawnDurationLast = self.CurrSpawnItem.duration
		self.CurrSpawnItem = nil
	end
end

---Must be called every time the timers have been reset globally
function Queue:Start()
	self.tiSpawnQueue = 0
	self.tiSpawnDurationLast = 0
	timer.Set(
				self.Timer.Name,
				self,
				self.OnSpawnQueueTick,
				self.Timer.TimeStep,
				true
			)
end

return Queue