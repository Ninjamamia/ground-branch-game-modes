local AdminTools = require('AdminTools')
local Callback   = require('common.Callback')
local CallbackList			= require('common.CallbackList')
local AI = require('Agents.AI')
local Player = require('Agents.Player')
local DummyAgent = require('Agents.Dummy')


local KillData = {
}

KillData.__index = KillData

function KillData:Create(KilledAgent, KillerAgent)
    local self = setmetatable({}, KillData)
	self.KilledAgent = KilledAgent
	self.KillerAgent = KillerAgent
	self.KilledTeam = KilledAgent.TeamId
	self.KillerTeam = nil
	if KillerAgent ~= nil then
		self.KillerTeam = KilledAgent.TeamId
	end
	return self
end

function KillData:GetPosition()
	return self.KilledAgent:GetPosition()
end

function KillData:GetLocation()
	return self:GetPosition().Location
end

function KillData:HasTag(Tag)
	return self.KilledAgent:HasTag(Tag)
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
	self.SpawnedAIByUUID = {}
	self.SpawnedAIByCharacterName = {}
	self.SpawnedAIByControllerName = {}
	self.PlayersByName = {}
	self.TeamsById = {}
	self.OnAgentDiedCallback = CallbackList:Create()
	if gamemode.script.OnCharacterDiedCallback ~= nil then
		gamemode.script.OnCharacterDiedCallback:Add(Callback:Create(self, self.OnCharacterDied))
	else
		AdminTools:ShowDebug("SpawnQueue: gamemode doesn't define OnCharacterDiedCallback, cant't hook to it")
	end
    return self
end

function Queue:AddTeam(Team)
	self.TeamsById[Team.Id] = Team
end

function Queue:AddDefaultEliminationCallback(TeamId, Callback)
	self.DefaultEliminationCallbacks[TeamId] = Callback
end

function Queue:GetDefaultEliminationCallback(TeamId)
	return self.DefaultEliminationCallbacks[TeamId] or self.FallbackEliminationCallback
end

---Resets the queue, has to be called by pre round cleanup.
function Queue:Reset(maxConcurrentAI)
	for _, AI in pairs(self.SpawnedAIByUUID) do
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
	self.SpawnedAIByUUID = {}
	self.SpawnedAIByControllerName = {}
	self.SpawnedAIByCharacterName = {}
	self.PlayersByName = {}
	self.Agents = {}
    self.PendingHealings = {}
end

function Queue:GetStateMessage()
	return "Current AI count: " .. self.AliveAICount .. " (" .. self.KilledAICount .. " of " .. self.AliveAICount + self.KilledAICount .. " killed), " .. self.PendingAICount .. ' AI pending'
end

function Queue:SetMaxConcurrentAICount(value)
	self.MaxConcurrentAICount = value
end

function Queue:OnCharacterDied(Character, CharacterController, KillerController)
	local KilledAgent = self:GetAgent(CharacterController)
	local KillerAgent = self:GetAgent(KillerController)
	self:OnAgentDied(KilledAgent, KillerAgent)
end

function Queue:OnAgentDied(KilledAgent, KillerAgent)
	self.OnAgentDiedCallback:Call(KilledAgent, KillerAgent)
	local killData = KillData:Create(KilledAgent, KillerAgent)
	if KilledAgent.IsAI then
		print('SpawnQueue: ' .. KilledAgent.UUID .. ' died')
		self.KilledAICount = self.KilledAICount + 1
		self.AliveAICount = math.max(self.AliveAICount - 1, 0)
		AdminTools:ShowDebug(self:GetStateMessage())
	end
	KilledAgent:OnCharacterDied(killData)
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
		local failCount = 0
		if CurrSpawnItem.prio == 1 then
			maxAICount = ai.GetMaxCount()
		end
		for i, spawnPoint in ipairs(CurrSpawnItem.spawnPoints) do
			if i > CurrSpawnItem.spawnedCount then
				if self.AliveAICount >= maxAICount then
					if CurrSpawnItem.isBlocking then
						if count > 0 or failCount > 0 then
							local message = 'SpawnQueue: Spawned (P) ' .. count .. ' ' .. CurrSpawnItem.spawnTag .. ' frozen for ' .. CurrSpawnItem.freezeTime .. 's'
							if failCount > 0 then
								message = message .. ', failed to spawn ' .. failCount
							end
							message = message .. ', ' .. self.PendingAICount .. ' AI still pending'
							AdminTools:ShowDebug(message)
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
				local characterController = gameplaystatics.GetAllActorsWithTag(uuid)
				if characterController ~= nil then
					local message = 'SpawnQueue: Spawned ' .. uuid
					characterController = characterController[1]
					local NewAI = AI:Create(self, uuid, characterController, spawnPoint, CurrSpawnItem.spawnTag, CurrSpawnItem.eliminationCallback)
					table.insert(self.Agents, NewAI)
					self.SpawnedAIByUUID[uuid] = NewAI
					self.SpawnedAIByControllerName[actor.GetName(NewAI.CharacterController)] = NewAI
					self.SpawnedAICount = self.SpawnedAICount + 1
					if NewAI.Character ~= nil then
						print(message .. ' (OK)')
						self.SpawnedAIByCharacterName[actor.GetName(NewAI.Character)] = NewAI
						self.AliveAICount = self.AliveAICount + 1
						count = count + 1
						table.insert(CurrSpawnItem.spawnedAI, NewAI)
					else
						print(message .. ' (DoA)')
						NewAI.IsAlive = false
						failCount = failCount + 1
					end
				else
					AdminTools:ShowDebug('SpawnQueue: Unable to spawn an AI')
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
			local message = 'SpawnQueue: Spawned (F) ' .. count .. ' ' .. CurrSpawnItem.spawnTag .. ' frozen for ' .. CurrSpawnItem.freezeTime .. 's'
			if failCount > 0 then
				message = message .. ', failed to spawn ' .. failCount
			end
			AdminTools:ShowDebug(message)
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

function Queue:OnGetSpawnInfo(PlayerState)
	local Agent = self.PlayersByName[player.GetName(PlayerState)]
	if Agent == nil then
		print('SpawnQueue: New player ' .. player.GetName(PlayerState))
		local Team = self.TeamsById[actor.GetTeamId(PlayerState)]
		if Team == nil then
			print('SpawnQueue: Player ' .. player.GetName(PlayerState) .. ' has team ID ' .. actor.GetTeamId(PlayerState) .. ' but a matching team was not found!')
			return nil
		end
		Agent = Player:Create(self, Team, PlayerState, Callback:Create(gamemode.script, gamemode.script.OnPlayerDied))
		table.insert(self.Agents, Agent)
		self.PlayersByName[player.GetName(PlayerState)] = Agent
	else
		if gamemode.GetRoundStage() == 'InProgress' then
			Agent:PrepareRespawn()
		end
	end
	return Agent.CurrentPlayerStart
end

function Queue:OnLogOut(Exiting)
	local Agent = self.PlayersByName[player.GetName(Exiting)]
	if Agent ~= nil then
		Agent:OnLogOut()
	else
		print('SpawnQueue: Player ' .. player.GetName(Exiting) .. ' logged out but no agent was found!')
	end
end

function Queue:OnPlayerEnteredPlayArea(PlayerState)
	local Agent = self.PlayersByName[player.GetName(PlayerState)]
	if Agent ~= nil then
		Agent:OnSpawned()
	else
		print('SpawnQueue: OnPlayerEnteredPlayArea: Unexpected new player ' .. player.GetName(PlayerState))
	end
end

function Queue:GetAgent(Character)
	if Character == nil then
		return DummyAgent:Create(self)
	end
	local Agent = self.SpawnedAIByCharacterName[actor.GetName(Character)]
	if Agent == nil then
		Agent = self.SpawnedAIByControllerName[actor.GetName(Character)]
	end
	if Agent == nil then
		Agent = self.PlayersByName[player.GetName(Character)]
	end
	if Agent == nil then
		Agent = DummyAgent:Create(self)
	end
	return Agent
end

function Queue:EnqueueHealingChance(Agent)
    table.insert(self.PendingHealings, Agent)
    if #self.PendingHealings == 1 then
        timer.Set(
            'HealingChecker',
            self,
            self.OnHealingCheckTick,
            1.0,
            true
        )
        print('HealingChecker started')
    end
end

function Queue:OnHealingCheckTick()
    for idx, Agent in ipairs(self.PendingHealings) do
        local isDone = Agent:OnHealingCheckTick()
        if isDone then
            table.remove(self.PendingHealings, idx)
        end
    end
    if #self.PendingHealings < 1 then
        timer.Clear('HealingChecker', self)
        print('HealingChecker stopped')
    end
end

return Queue