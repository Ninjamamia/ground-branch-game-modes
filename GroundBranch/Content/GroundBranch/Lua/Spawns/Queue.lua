local AdminTools = require('AdminTools')

local AI = {
}

AI.__index = AI

---Creates a new AI object.
---@return table AI Newly created AI object.
function AI:Create(Queue, uuid, aiObject, spawnPoint, BaseTag, eliminationCallback)
    local self = setmetatable({}, AI)
	self.Queue = Queue
	self.UUID = uuid
    self.Object = aiObject
	self.TeamId = actor.GetTeamId(aiObject)
	self.SpawnPoint = spawnPoint
	self.BaseTag = BaseTag
	self.eliminationCallback = eliminationCallback or Queue:GetDefaultEliminationCallback(self.TeamId)
	self.Tags = {}
	self.Location = nil
	table.insert(self.Tags, BaseTag)
    return self
end

function AI:HasTag(Tag)
	for _, CurrTag in ipairs(self.Tags) do
		if CurrTag == Tag then
			return true
		end
	end
	return false
end

function AI:GetTags()
	return self.Tags
end

function AI:CleanUp()
	ai.CleanUp(self.UUID)
end

function AI:OnCharacterDied(KillData)
	KillData.AI = self
	self.eliminationCallback:Call(KillData)
end

local KillData = {
}

KillData.__index = KillData

function KillData:Create(Character, CharacterController, KillerController)
    local self = setmetatable({}, KillData)
	self.Character = Character
	self.CharacterController = CharacterController
	self.KillerController = KillerController
	self.AI = nil
	self.KilledTeam = actor.GetTeamId(CharacterController)
	self.KillerTeam = nil
	if KillerController ~= nil then
		self.KillerTeam = actor.GetTeamId(KillerController)
	end
	self.Location = actor.GetLocation(Character)
	return self
end

function KillData:GetLocation()
	return self.Location
end

function KillData:HasTag(Tag)
	if self.AI == nil then
		return false
	else
		return self.AI:HasTag(Tag)
	end
end

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
function Queue:Create(maxConcurrentAI, fallbackEliminationCallback)
    local self = setmetatable({}, Queue)
    self.SpawnQueue = {}
	self.tiSpawnQueue = 0
	self.MaxConcurrentAICount = maxConcurrentAI or ai.GetMaxCount()
	self.DefaultEliminationCallbacks = {}
	self.FallbackEliminationCallback = fallbackEliminationCallback
	self.SpawnedAI = {}
    return self
end

function Queue:RegisterDefaultEliminationCallback(TeamId, Callback)
	self.DefaultEliminationCallbacks[TeamId] = Callback
end

function Queue:GetDefaultEliminationCallback(TeamId)
	return self.DefaultEliminationCallbacks[TeamId] or self.FallbackEliminationCallback
end

---Resets the queue, has to be called by pre round cleanup.
function Queue:Reset(maxConcurrentAI)
	for _, AI in pairs(self.SpawnedAI) do
		AI:CleanUp()
	end
	if maxConcurrentAI ~= nil then
		self.MaxConcurrentAICount = maxConcurrentAI
	end
	self.tiSpawnQueue = 0
	self.SpawnedAICount = 0
	self.KilledAICount = 0
	self.AliveAICount = 0
	self.PendingAICount = 0
	self.SpawnQueue = {}
	self.SpawnedAI = {}
end

function Queue:GetStateMessage()
	return "Current AI count: " .. self.AliveAICount .. " (" .. self.KilledAICount .. " of " .. self.SpawnedAICount .. " killed), " .. self.PendingAICount .. ' AI pending'
end

function Queue:SetMaxConcurrentAICount(value)
	self.MaxConcurrentAICount = value
end

function Queue:OnCharacterDied(Character, CharacterController, KillerController)
	local killData = KillData:Create(Character, CharacterController, KillerController)
	local uuid = actor.GetTags(CharacterController)
	if uuid ~= nil then
		uuid = uuid[1]
		if uuid ~= nil then
			local CurrAI = self.SpawnedAI[uuid]
			if CurrAI ~= nil then
				print('SpawnQueue: ' .. uuid .. ' died')
				self.KilledAICount = self.KilledAICount + 1
				self.AliveAICount = math.max(self.AliveAICount - 1, 0)
				CurrAI:OnCharacterDied(killData)
				AdminTools:ShowDebug(self:GetStateMessage())
				return
			end
		end
	end
	gamemode.script:OnPlayerDied(killData)
end

function Queue:AbortPending()
	if #self.SpawnQueue > 0 then
		local CurrSpawnItem = self.SpawnQueue[1]
		if CurrSpawnItem.postSpawnCallback ~= nil then
			CurrSpawnItem.postSpawnCallback:Call()
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
---@param eliminationCallback table A callback object to call after the AI has been killed (optional).
---@param preSpawnCallback table A callback object to call immediately before the first AI is spawned (optional).
---@param postSpawnCallback table A callback object to call after spawning is complete (optional).
---@param isBlocking boolean If set to true, the next queue item will only be processed after all AI have been spawned (optional, default = false).
---@param prio number Higher prios will spawn before (optional, default = 255).
function Queue:Enqueue(delay, freezeTime, count, spawnPoints, spawnTag, eliminationCallback, preSpawnCallback, postSpawnCallback, isBlocking, prio)
	count = math.min(#spawnPoints, count)
	local NewItem = {
		tiSpawn = self.tiSpawnQueue + delay,
		freezeTime = freezeTime,
		count = count,
		spawnedCount = 0,
		spawnPoints = spawnPoints,
		spawnTag = spawnTag,
		eliminationCallback = eliminationCallback or nil,
		preSpawnCallback = preSpawnCallback or nil,
		postSpawnCallback = postSpawnCallback or nil,
		isBlocking = isBlocking or false,
		prio = prio or 255,
		spawnedAI = {}
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
					CurrSpawnItem.preSpawnCallback:Call(CurrSpawnItem.spawnTag)
				end
				local uuid = "AI_" .. self.SpawnedAICount
				ai.Create(spawnPoint, uuid, CurrSpawnItem.freezeTime)
				local spawnedAI = gameplaystatics.GetAllActorsWithTag(uuid)
				if spawnedAI ~= nil then
					spawnedAI = spawnedAI[1]
					print('SpawnQueue: Spawned ' .. uuid)
					local NewAI = AI:Create(self, uuid, spawnedAI, spawnPoint, CurrSpawnItem.spawnTag, CurrSpawnItem.eliminationCallback)
					self.SpawnedAI[uuid] = NewAI
					self.AliveAICount = self.AliveAICount + 1
					self.SpawnedAICount = self.SpawnedAICount + 1
					table.insert(CurrSpawnItem.spawnedAI, NewAI)
					count = count + 1
				else
					print('SpawnQueue: Unable to spawn an AI')
				end
				CurrSpawnItem.spawnedCount = CurrSpawnItem.spawnedCount + 1
				self.PendingAICount = self.PendingAICount - 1
				if CurrSpawnItem.spawnedCount >= CurrSpawnItem.count then
					break
				end
			end
        end
		if CurrSpawnItem.postSpawnCallback ~= nil then
			CurrSpawnItem.postSpawnCallback:Call(CurrSpawnItem.spawnedAI)
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