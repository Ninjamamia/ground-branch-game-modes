local AdminTools = require('AdminTools')
local Callback   = require('common.Callback')
local AI = require('Agents.AI')
local Player = require('Agents.Player')
local DummyAgent = require('Agents.Dummy')

local Manager = {
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

Manager.__index = Manager

---Creates a new spawn queue object.
---@return table Manager Newly create Manager object.
function Manager:Create(maxConcurrentAI, fallbackEliminationCallback)
    local self = setmetatable({}, Manager)
    self.SpawnQueue = {}
	self.tiSpawnQueue = 0
	self.MaxConcurrentAICount = maxConcurrentAI or ai.GetMaxCount()
	self.FallbackEliminationCallback = fallbackEliminationCallback
	self.SpawnedAIByUUID = {}
	self.SpawnedAIByCharacterName = {}
	self.SpawnedAIByControllerName = {}
	self.PlayersByName = {}
	self.TeamsById = {}
    return self
end

function Manager:AddTeam(Team)
	self.TeamsById[Team.Id] = Team
end

function Manager:GetTeamByID(TeamId)
	return self.TeamsById[TeamId]
end

---Resets the queue, has to be called by pre round cleanup.
function Manager:Reset(maxConcurrentAI)
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
	for _, Team in pairs(self.TeamsById) do
		Team:Reset()
	end
end

function Manager:GetStateMessage()
	return "Current AI count: " .. self.AliveAICount .. " (" .. self.KilledAICount .. " of " .. self.AliveAICount + self.KilledAICount .. " killed), " .. self.PendingAICount .. ' AI pending'
end

function Manager:SetMaxConcurrentAICount(value)
	self.MaxConcurrentAICount = value
end

function Manager:OnAIBleedout(KilledAgent)
	self.KilledAICount = self.KilledAICount + 1
	self.AliveAICount = math.max(self.AliveAICount - 1, 0)
	AdminTools:ShowDebug(self:GetStateMessage())
end

function Manager:AbortPending()
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
---@param eliminationCallback table A callback object to call after the AI has been killed (optional).
---@param preSpawnCallback table A callback object to call immediately before the first AI is spawned (optional).
---@param postSpawnCallback table A callback object to call after spawning is complete (optional).
---@param isBlocking boolean If set to true, the next queue item will only be processed after all AI have been spawned (optional, default = false).
---@param prio number Higher prios will spawn before (optional, default = 255).
function Manager:SpawnAI(delay, freezeTime, count, spawnPoints, eliminationCallback, preSpawnCallback, postSpawnCallback, isBlocking, prio)
	count = math.min(#spawnPoints, count)
	local NewItem = {
		tiSpawn = self.tiSpawnQueue + delay,
		freezeTime = freezeTime,
		count = count,
		spawnedCount = 0,
		spawnPoints = spawnPoints,
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

function Manager:OnSpawnQueueTick()
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
							local message = 'AgentsManager: Spawned (P) ' .. count .. ' AI frozen for ' .. CurrSpawnItem.freezeTime .. 's'
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
					CurrSpawnItem.preSpawnCallback:Call()
				end
				local uuid = "AI_" .. self.SpawnedAICount
				spawnPoint:SpawnAI(uuid, CurrSpawnItem.freezeTime)
				local characterController = gameplaystatics.GetAllActorsWithTag(uuid)
				if characterController ~= nil then
					print('AgentsManager: Spawned ' .. uuid .. ' @ ' .. actor.GetName(spawnPoint.Actor))

					characterController = characterController[1]
					local NewAI = AI:Create(self, uuid, characterController, spawnPoint, CurrSpawnItem.eliminationCallback)
					table.insert(self.Agents, NewAI)
					self.SpawnedAIByUUID[uuid] = NewAI
					self.SpawnedAIByControllerName[actor.GetName(NewAI.CharacterController)] = NewAI
					self.SpawnedAICount = self.SpawnedAICount + 1
					if NewAI.Character ~= nil then
						self.SpawnedAIByCharacterName[actor.GetName(NewAI.Character)] = NewAI
						self.AliveAICount = self.AliveAICount + 1
						count = count + 1
						table.insert(CurrSpawnItem.spawnedAI, NewAI)
					else
						print('  Unable to spawn character, DoA')
						NewAI.IsAlive = false
						failCount = failCount + 1
					end
				else
					AdminTools:ShowDebug('AgentsManager: Unable to spawn an AI')
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
			local message = 'AgentsManager: Spawned (F) ' .. count .. ' AI frozen for ' .. CurrSpawnItem.freezeTime .. 's'
			if failCount > 0 then
				message = message .. ', failed to spawn ' .. failCount
			end
			AdminTools:ShowDebug(message)
		end
		table.remove(self.SpawnQueue, 1)
	end
end

---Must be called every time the timers have been reset globally
function Manager:Start()
	timer.Set(
		self.Timer.Name,
		self,
		self.OnSpawnQueueTick,
		self.Timer.TimeStep,
		true
	)
end

function Manager:OnGetSpawnInfo(PlayerState)
	local Agent = self.PlayersByName[player.GetName(PlayerState)]
	if Agent == nil then
		print('AgentsManager: New player ' .. player.GetName(PlayerState))
		local Team = self.TeamsById[actor.GetTeamId(PlayerState)]
		if Team == nil then
			print('AgentsManager: Player ' .. player.GetName(PlayerState) .. ' has team ID ' .. actor.GetTeamId(PlayerState) .. ' but a matching team was not found!')
			return nil
		end
		Agent = Player:Create(self, PlayerState, Callback:Create(gamemode.script, gamemode.script.OnPlayerDied))
		table.insert(self.Agents, Agent)
		self.PlayersByName[player.GetName(PlayerState)] = Agent
	else
		if gamemode.GetRoundStage() == 'InProgress' then
			Agent:PrepareRespawn()
		end
	end
	return Agent.CurrentPlayerStart
end

function Manager:OnLogOut(Exiting)
	local Agent = self.PlayersByName[player.GetName(Exiting)]
	if Agent ~= nil then
		Agent:OnLogOut()
	else
		print('AgentsManager: Player ' .. player.GetName(Exiting) .. ' logged out but no agent was found!')
	end
end

function Manager:OnPlayerEnteredPlayArea(PlayerState)
	local Agent = self.PlayersByName[player.GetName(PlayerState)]
	if Agent ~= nil then
		Agent:OnSpawned()
	else
		print('AgentsManager: OnPlayerEnteredPlayArea: Unexpected new player ' .. player.GetName(PlayerState))
	end
end

function Manager:GetAgent(Character)
	if type(Character) == 'table' and Character.IsAgent == true then
		return Character
	end
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

function Manager:EnqueueHealingChance(Agent)
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

function Manager:OnHealingCheckTick()
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

return Manager