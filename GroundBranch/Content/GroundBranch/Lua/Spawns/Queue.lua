
local Queue = {
    SpawnQueue = {},
    CurrSpawnItem = nil,
    tiSpawnQueue = 0,
	ExpectedAICount = 0,
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

---Resets the queue, has to be called by pre round cleanup.
function Queue:Reset()
	self.tiSpawnQueue = 0
	self.ExpectedAICount = 0
	self.SpawnQueue = {}
	self.CurrSpawnItem = nil
end

---Schedules AI spawning on the specified spawn points.
---@param delay number The time after which spawning shall start.
---@param freezeTime number the time for which the ai should be frozen.
---@param count integer The amount of the AI to spawn.
---@param spawnPoints table The list of spawn points to use.
---@param spawnTag string The tag that will be assigned to spawned AI.
---@param postSpawnCallback function A function to call after spawning is complete (optional).
---@param postSpawnCallbackOwner table A owner object of postSpawnCallback (optional).
function Queue:Enqueue(delay, freezeTime, count, spawnPoints, spawnTag, postSpawnCallback, postSpawnCallbackOwner)
	local NewItem = {
		tiSpawn = self.tiSpawnQueue + delay,
		freezeTime = freezeTime,
		count = count,
		spawnPoints = spawnPoints,
		spawnTag = spawnTag,
		postSpawnCallback = postSpawnCallback or nil,
		postSpawnCallbackOwner = postSpawnCallbackOwner or nil
	}
	self.ExpectedAICount = self.ExpectedAICount + math.min(#spawnPoints, count)
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
		print('SpawnQueue: Spawning ' .. self.CurrSpawnItem.count .. ' ' .. self.CurrSpawnItem.spawnTag .. ' frozen for ' .. self.CurrSpawnItem.freezeTime .. 's')
		table.remove(self.SpawnQueue, 1)
        for i, spawnPoint in ipairs(self.CurrSpawnItem.spawnPoints) do
			if i > self.CurrSpawnItem.count then
				break
			end
           ai.Create(spawnPoint, self.CurrSpawnItem.spawnTag, self.CurrSpawnItem.freezeTime)
        end
		if self.CurrSpawnItem.postSpawnCallback ~= nil and self.CurrSpawnItem.postSpawnCallbackOwner ~= nil then
			self.CurrSpawnItem.postSpawnCallback(self.CurrSpawnItem.postSpawnCallbackOwner)
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