local Actors   = require('Common.Actors')
local Tables   = require('Common.Tables')
local Callback = require('common.Callback')
local SpawnPoint = require('Spawns.Point')

local ConfirmKill = {
    Team = {},
    HVT = {
        Count = 1,
        Tag = 'HVT',
        Spawns = {},
        Markers = {},
        SpawnsShuffled = {},
        EliminatedNotConfirmed = {},
        EliminatedNotConfirmedCount = 0,
        EliminatedAndConfirmedCount = 0
    },
    ObjectiveTimer = {
        Name = 'KillConfirmTimer',
        TimeStep = {
            Max = 1.0,
            Min = 0.1,
            Value = 1.0
        }
    },
    PromptTimer = {
        Name = 'KillConfirmedPromptTimer',
        ShowTime = 5.0,
        DelayTime = 15.0
    }
}

ConfirmKill.__index = ConfirmKill

---Creates a new object of type Objectives Kill Confirmation. This prototype can be
---used for setting up and tracking an Kill Confirmation objective for a specific team.
---Kill Confirmation requires players to kill selected targets (HVTs), and confirm
---the HVT kills by walking over HVTs bodies.
---If messageBroker is provided will display objective related messages to players.
---If promptBroker is provided will display objective prompts to players.
---@param onObjectiveCompleteCallback table A callback object to be called when the objective is completed.
---@param team table the team object of the eligible team.
---@param hvtTag string Tag assigned to HVT spawn points in mission editor. Used to find HVT spawn points.
---@param hvtCount integer How many HVTs are in play.
---@param onConfirmedKillCallback table A callback object to be called when a kill is confirmed (optional).
---@param OnNeutralizationCallback table A callback object to be called when a HVT is killed (optional).
---@return table ConfirmKill The newly created ConfirmKill object.
function ConfirmKill:Create(
    onObjectiveCompleteCallback,
    team,
    hvtTag,
    hvtCount,
    onConfirmedKillCallback,
    OnNeutralizationCallback
)
    local self = setmetatable({}, ConfirmKill)
    self.__index = self
    self.OnObjectiveCompleteCallback = onObjectiveCompleteCallback
    self.OnConfirmedKillCallback = onConfirmedKillCallback or nil
    self.OnNeutralizationCallback = OnNeutralizationCallback or nil
    self.Team = team
    self.HVT.Count = hvtCount or 1
    self.HVT.Tag = hvtTag or 'HVT'
    self.HVT.Spawns = SpawnPoint.CreateMultiple(gameplaystatics.GetAllActorsOfClassWithTag(
		'GroundBranch.GBAISpawnPoint',
		self.HVT.Tag
	))
	print('Found ' .. #self.HVT.Spawns .. ' ' .. self.HVT.Tag .. ' spawns')
    print('Adding inactive objective markers for ' .. self.HVT.Tag)
    for _, Spawn in ipairs(self.HVT.Spawns) do
		local description = self.HVT.Tag
		description = Actors.GetSuffixFromActorTag(Spawn, 'ObjectiveMarker')
		self.HVT.Markers[description] = gamemode.AddObjectiveMarker(
			Spawn:GetLocation(),
			self.Team:GetId(),
			description,
            'MissionLocation',
			false
		)
	end
    self.HVT.SpawnsShuffled = {}
    self.HVT.EliminatedNotConfirmed = {}
    self.HVT.EliminatedNotConfirmedCount = 0
    self.HVT.EliminatedAndConfirmedCount = 0
    print('Intialized Objective Kill Confirmation ' .. tostring(self))
    return self
end

---Resets the object attributes to default values. Should be called before every round.
function ConfirmKill:Reset()
    self.HVT.EliminatedNotConfirmed = {}
	self.HVT.EliminatedNotConfirmedCount = 0
	self.HVT.EliminatedAndConfirmedCount = 0
end

function ConfirmKill:GetCompletedObjectives()
    if self:AreAllConfirmed() then
        return {'NeutralizeHVTs','ConfirmEliminatedHVTs'}
    elseif self:AreAllNeutralized() then
        return {'NeutralizeHVTs'}
    end
    return {}
end

---Shuffle HVT spawn order. Should be called before every round.
function ConfirmKill:ShuffleSpawns()
    print('Shuffling ' .. self.HVT.Tag ..  ' spawns')
	self.HVT.SpawnsShuffled = Tables.ShuffleTable(
		self.HVT.Spawns
	)
    print('Setting up ' .. self.HVT.Tag .. ' objective markers ' ..self.HVT.Count)
	for index, spawn in ipairs(self.HVT.SpawnsShuffled) do
		local spawnTag = Actors.GetSuffixFromActorTag(spawn, 'ObjectiveMarker')
		local bActive = index <= self.HVT.Count
		print('Setting HVT marker ' .. spawnTag .. ' to ' .. tostring(bActive))
		actor.SetActive(self.HVT.Markers[spawnTag], bActive)
	end
end

---Schedule spawning the specified amount of HVTs at the shuffled spawn points immediately.
---@param freezeTime number time for which the ai should be frozen.
function ConfirmKill:Spawn(freezeTime)
    print('Schedule spawning ' .. self.HVT.Tag)
	gamemode.script.AgentsManager:SpawnAI(0.0, freezeTime, self.HVT.Count, self:PopShuffledSpawnPoints(), self.HVT.Tag, Callback:Create(self, self.Neutralized), nil, Callback:Create(self, self.checkSpawnsTimer))
end

---Makes sure that the HVT count is equal to the HVT ai controllers count.
function ConfirmKill:checkSpawnsTimer(spawnedAI)
    if self.HVT.Count ~= #spawnedAI then
        print('HVT count is not equal to HVT ai controllers count, adjusting HVT count')
        self.HVT.Count = #spawnedAI
    end
end

---Updates objective tracking variables. If the GameMessageBroker was provided
---at object creation, displays a message to the players. If the WorldPromptBroker
---was provided at object creation, displays a message to the players. Should be
---called whenever an HVT is eliminated.
---@param killData userdata KillData of the neutralized HVT.
function ConfirmKill:Neutralized(killData)
    print('OpFor HVT eliminated')
    self.Team:DisplayMessageToAlivePlayers('HVTEliminated', 'Upper', 5.0, 'ObjectiveMessage')
    timer.Set(
        self.PromptTimer.Name,
        self,
        self.GuideToObjectiveTimer,
        self.PromptTimer.DelayTime,
        true
    )
    killData.KillerAgent:AwardPlayerScore('KillHvt')
    killData.KillerAgent:AwardTeamScore('KillHvt')
    table.insert(
        self.HVT.EliminatedNotConfirmed,
        killData.KilledAgent
    )
    self.HVT.EliminatedNotConfirmedCount =
        self.HVT.EliminatedNotConfirmedCount + 1
    self:ShouldConfirmKillTimer()
    if self.OnNeutralizationCallback ~= nil then
        self.OnNeutralizationCallback:Call(killData)
    end
end

---Used to display world prompt guiding players to the neutralized HVT for confirming
---the kill.
function ConfirmKill:GuideToObjectiveTimer()
    for _, hvt in ipairs(self.HVT.EliminatedNotConfirmed) do
        self.Team:DisplayPromptToAlivePlayers(
            hvt:GetLocation(),
            'ConfirmKill',
            self.PromptTimer.ShowTime,
            'ObjectivePrompt'
        )
    end
end

---Checks if any player is in range of the neutralized HVT in order to confirm the
---kill. If player is in range, will confirm the kill. If no player is in range,
---will find distance from neutralized HVT to closest players, and based on that
---distance determine how much time until next check.
function ConfirmKill:ShouldConfirmKillTimer()
	if self.HVT.EliminatedNotConfirmedCount <= 0 then
        timer.Clear(self, self.PromptTimer.Name)
		return
	end
	local LowestDist = self.ObjectiveTimer.TimeStep.Max * 1000.0
	for leaderIndex, hvt in ipairs(self.HVT.EliminatedNotConfirmed) do
        local leaderLocation = hvt:GetLocation()
		for _, player in ipairs(self.Team:GetAliveAgents()) do
			local playerLocation = player:GetLocation()
			local DistVector = playerLocation - leaderLocation
			local Dist = vector.Size(DistVector)
			LowestDist = math.min(LowestDist, Dist)
			if Dist <= 250 and math.abs(DistVector.z) < 110 then
                self:ConfirmKill(leaderIndex, player, hvt)
			end
		end
	end
	self.ObjectiveTimer.TimeStep.Value = math.max(
		math.min(
			LowestDist/1000,
			self.ObjectiveTimer.TimeStep.Max
		),
		self.ObjectiveTimer.TimeStep.Min
	)
	timer.Set(
		self.ObjectiveTimer.Name,
		self,
		self.ShouldConfirmKillTimer,
		self.ObjectiveTimer.TimeStep.Value,
		false
	)
end

---Confirms the kill and updates objective tracking variables.
---@param leaderIndex integer index of the leader location in table EliminatedNotConfirmed that was confirmed.
function ConfirmKill:ConfirmKill(leaderIndex, confirmer, hvt)
    table.remove(self.HVT.EliminatedNotConfirmed, leaderIndex)
    self.HVT.EliminatedNotConfirmedCount = #self.HVT.EliminatedNotConfirmed
    self.HVT.EliminatedAndConfirmedCount = self.HVT.EliminatedAndConfirmedCount + 1
    confirmer:AwardPlayerScore('ConfirmHvt')
    confirmer:AwardTeamScore('ConfirmHvt')
    if self.OnConfirmedKillCallback ~= nil then
        self.OnConfirmedKillCallback:Call(hvt, confirmer)
    end
    if self:AreAllConfirmed() then
		print('All HVT kills confirmed')
        self.Team:DisplayMessageToAlivePlayers('HVTConfirmedAll', 'Upper', 5.0, 'ObjectiveMessage')
        self.OnObjectiveCompleteCallback:Call()
	else
        self.Team:DisplayMessageToAlivePlayers('HVTConfirmed', 'Upper', 5.0, 'ObjectiveMessage')
	end
end

---Sets the HVT count.
---@param count integer Desired HVT count.
function ConfirmKill:SetHvtCount(count)
    if count > #self.HVT.Spawns then
        self.HVT.Count = #self.HVT.Spawns
    else
        self.HVT.Count = count
    end
end

---Gets the current HVT count.
---@return integer hvtCount Current HVT count.
function ConfirmKill:GetHvtCount()
    return self.HVT.Count
end

---Returns true if all HVTs are neutralized, false otherwise.
---@return boolean areAllNeutralized
function ConfirmKill:AreAllNeutralized()
    return (self.HVT.EliminatedNotConfirmedCount + self.HVT.EliminatedAndConfirmedCount) >= self.HVT.Count
end

---Returns true if all HVT kill are confirmed, false otherwise.
---@return boolean areAllConfirmed
function ConfirmKill:AreAllConfirmed()
    return self.HVT.EliminatedAndConfirmedCount >= self.HVT.Count
end

---Returns all spawn points count.
---@return integer allSpawnPointsCount
function ConfirmKill:GetAllSpawnPointsCount()
    return #self.HVT.Spawns
end

---Returns a table of shuffled spawn points.
---@return table shuffledSpawnPoints list of shuffled spawn points.
function ConfirmKill:GetShuffledSpawnPoints()
    return {table.unpack(self.HVT.SpawnsShuffled)}
end

---Returns the spawn point specified by the index in the shuffled spawn points table.
---@param index integer index of the spawn point in the shuffled spawn points table.
---@return userdata spawnPoint
function ConfirmKill:GetShuffledSpawnPoint(index)
    return self.HVT.SpawnsShuffled[index]
end

---Returns a copy of shuffled spawn points table, and empties the original shuffled
---spawn points table.
---@return table
function ConfirmKill:PopShuffledSpawnPoints()
    print('Poping ' .. self.HVT.Tag .. ' spawns')
    local hvtSpawns = self:GetShuffledSpawnPoints()
    self.HVT.SpawnsShuffled = {}
    return hvtSpawns
end

return ConfirmKill
