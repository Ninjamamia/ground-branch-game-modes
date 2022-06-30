local AdminTools 			= require('AdminTools')

local Queue = {
    SpawnQueue = {},
    tiSpawnQueue = 0,
	SpawnedAICount = 0,
	KilledAICount = 0,
	AliveAICount = 0,
	MaxConcurrentAICount = 0,
	PendingAICount = 0,
    Timer = {
        Name = 'SpawnQueue',
        TimeStep = 0.25,
    },
}

Queue.__index = Queue

---Creates a new spawn queue object.
---@return table Queue Newly create Queue object.
function Queue:Create(maxConcurrentAI)
    local self = setmetatable({}, Queue)
    self.SpawnQueue = {}
	self.tiSpawnQueue = 0
	self.MaxConcurrentAICount = maxConcurrentAI or ai.GetMaxCount()
    return self
end

---Resets the queue, has to be called by pre round cleanup.
function Queue:Reset(maxConcurrentAI)
	if maxConcurrentAI ~= nil then
		self.MaxConcurrentAICount = maxConcurrentAI
	end
	self.tiSpawnQueue = 0
	self.SpawnedAICount = 0
	self.KilledAICount = 0
	self.AliveAICount = 0
	self.PendingAICount = 0
	self.SpawnQueue = {}
end

function Queue:GetStateMessage()
	return "Current AI count: " .. self.AliveAICount .. " (" .. self.KilledAICount .. " of " .. self.SpawnedAICount .. " killed), " .. self.PendingAICount .. ' AI pending'
end

function Queue:SetMaxConcurrentAICount(value)
	self.MaxConcurrentAICount = value
end

function Queue:OnAIKilled()
	self.KilledAICount = self.KilledAICount + 1
	self.AliveAICount = math.max(self.AliveAICount - 1, 0)
	AdminTools:ShowDebug(self:GetStateMessage())
end

function Queue:AbortPending()
	if #self.SpawnQueue > 0 then
		local CurrSpawnItem = self.SpawnQueue[1]
		if CurrSpawnItem.postSpawnCallback ~= nil and CurrSpawnItem.postSpawnCallbackOwner ~= nil then
			CurrSpawnItem.postSpawnCallback(CurrSpawnItem.postSpawnCallbackOwner)
		end
	end
	self.SpawnQueue = {}
	self.PendingAICount = 0
end

---Schedules AI spawning on the specified spawn points.
---@param delay number The time after which spawning shall start.
---@param freezeTime number the time for which the ai should be frozen.
---@param count integer The amount of the AI to spawn.
---@param spawnPoints table The list of spawn points to use.
---@param spawnTag string The tag that will be assigned to spawned AI.
---@param preSpawnCallback function A function to call immediately before the first AI is spawned (optional).
---@param preSpawnCallbackOwner table A owner object of preSpawnCallback (optional).
---@param postSpawnCallback function A function to call after spawning is complete (optional).
---@param postSpawnCallbackOwner table A owner object of postSpawnCallback (optional).
---@param isBlocking boolean If set to true, the next queue item will only be processed after all AI have been spawned (optional, default = false).
---@param prio number Higher prios will spawn before (optional, default = 255).
function Queue:Enqueue(delay, freezeTime, count, spawnPoints, spawnTag, preSpawnCallback, preSpawnCallbackOwner, postSpawnCallback, postSpawnCallbackOwner, isBlocking, prio)
	count = math.min(#spawnPoints, count)
	local NewItem = {
		tiSpawn = self.tiSpawnQueue + delay,
		freezeTime = freezeTime,
		count = count,
		spawnedCount = 0,
		spawnPoints = spawnPoints,
		spawnTag = spawnTag,
		preSpawnCallback = preSpawnCallback or nil,
		preSpawnCallbackOwner = preSpawnCallbackOwner or nil,
		postSpawnCallback = postSpawnCallback or nil,
		postSpawnCallbackOwner = postSpawnCallbackOwner or nil,
		isBlocking = isBlocking or false,
		prio = prio or 255
	}
	self.PendingAICount = self.PendingAICount + count
	if #self.SpawnQueue == 0 then
		table.insert(self.SpawnQueue, NewItem)
	else
		for i, CurrItem in ipairs(self.SpawnQueue) do
			if CurrItem.tiSpawn > NewItem.tiSpawn or CurrItem.prio > NewItem.prio then
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
	local CurrSpawnItem = self.SpawnQueue[1]
	local maxAICount = self.MaxConcurrentAICount
	if self.tiSpawnQueue >= CurrSpawnItem.tiSpawn then
        local count = 0
		if CurrSpawnItem.prio == 1 then
			maxAICount = ai.GetMaxCount()
		end
		for i, spawnPoint in ipairs(CurrSpawnItem.spawnPoints) do
			if i > CurrSpawnItem.spawnedCount then
				if self.AliveAICount >= maxAICount then
					if CurrSpawnItem.isBlocking then
						if count > 0 then
							AdminTools:ShowDebug('SpawnQueue: Spawned (P) ' .. count .. ' ' .. CurrSpawnItem.spawnTag .. ' frozen for ' .. CurrSpawnItem.freezeTime .. 's, ' .. self.PendingAICount .. ' AI still pending' )
						end
						return
					else
						self.PendingAICount = self.PendingAICount - (CurrSpawnItem.count - CurrSpawnItem.spawnedCount)
						break
					end
				end
				if CurrSpawnItem.spawnedCount == 0 and CurrSpawnItem.preSpawnCallback ~= nil then
					CurrSpawnItem.preSpawnCallback(CurrSpawnItem.preSpawnCallbackOwner)
				end
				self.AliveAICount = self.AliveAICount + 1
				self.SpawnedAICount = self.SpawnedAICount + 1
				ai.Create(spawnPoint, CurrSpawnItem.spawnTag, CurrSpawnItem.freezeTime)
				CurrSpawnItem.spawnedCount = CurrSpawnItem.spawnedCount + 1
				count = count + 1
				self.PendingAICount = self.PendingAICount - 1
				if CurrSpawnItem.spawnedCount >= CurrSpawnItem.count then
					break
				end
			end
        end
		if CurrSpawnItem.postSpawnCallback ~= nil and CurrSpawnItem.postSpawnCallbackOwner ~= nil then
			CurrSpawnItem.postSpawnCallback(CurrSpawnItem.postSpawnCallbackOwner)
		end
		if count > 0 then
			AdminTools:ShowDebug('SpawnQueue: Spawned (F) ' .. count .. ' ' .. CurrSpawnItem.spawnTag .. ' frozen for ' .. CurrSpawnItem.freezeTime .. 's')
		end
		table.remove(self.SpawnQueue, 1)
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