local AdminTools = require "AdminTools"
local Tables = require('Common.Tables')

local InsertionPoint = {
}

InsertionPoint.__index = InsertionPoint

function InsertionPoint:Create(Team, insertionPoint)
    local self = setmetatable({}, InsertionPoint)
    self.Team = Team
    self.InsertionPoint = insertionPoint
    self.Name = gamemode.GetInsertionPointName(insertionPoint)
    self.PlayerStarts = {}
	return self
end

function InsertionPoint:__tostring()
    return self.Name
end

function InsertionPoint:AddPlayerStart(playerStart)
    table.insert(self.PlayerStarts, playerStart)
end

function InsertionPoint:OnRoundStart()
    self.UnusedPlayerStarts = Tables.Copy(self.PlayerStarts)
    self.UsedPlayerStartsCount = 0
    self.EnforcedIndex = 1
end

function InsertionPoint:GetPlayerStart(force)
    force = force or false
    local playerStart = nil
    if #self.UnusedPlayerStarts > 0 then
        playerStart = self.UnusedPlayerStarts[1]
        table.remove(self.UnusedPlayerStarts, 1)
        self.UsedPlayerStartsCount = self.UsedPlayerStartsCount + 1
    end
    if playerStart ~= nil then
        print('Found a free player start on insertion point ' .. tostring(self) .. ' (' .. actor.GetName(playerStart) .. '), ' .. #self.UnusedPlayerStarts .. ' left')
    elseif force then
        playerStart = self.PlayerStarts[self.EnforcedIndex]
        self.EnforcedIndex = self.EnforcedIndex + 1
        if self.EnforcedIndex > #self.PlayerStarts then
            self.EnforcedIndex = 1
        end
        print('No free player start found on insertion point ' .. tostring(self) .. ', enforcing one (' .. actor.GetName(playerStart) .. ')')
    end
    return playerStart
end

local Team = {
    Id = 0,
    maxHealings = 0,
    healingMode = 0  -- 0 = in place; 1 = MedEvac
}

Team.__index = Team

function Team:Create(
    teamTable
)
    local self = setmetatable({}, Team)
    self.Id = teamTable.TeamId
    self.Name = teamTable.Name
    print('Initializing ' .. tostring(self) .. '...')
    self.Agents = {}
    self.Agents.All = {}
    self.Agents.Alive = {}
    self.Agents.Dead = {}
    self.Display = {}
    self.Display.ScoreMessage = false
    self.Display.ScoreMilestone = true
    self.Display.ObjectiveMessage = true
    self.Display.ObjectivePrompt = true
    self.Display.Always = true
    self.PlayerScoreTypes = gamemode.script.PlayerScoreTypes
    self.TeamScoreTypes = gamemode.script.TeamScoreTypes
    self.InsertionPoints = {}
    self.HospitalStarts = {}
    self.HospitalStartsCount = 0
    self.InsertionPointsCount = 0
    self.DefaultEliminationCallback = nil
    self.Attitudes = {}
    self.HealableTeams = {}
    self.HealableTeams[self.Id] = true
    for _, insertionPoint in ipairs(gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')) do
        if actor.GetTeamId(insertionPoint) == self.Id then
            local newInsertionPoint = InsertionPoint:Create(self, insertionPoint)
            self.InsertionPoints[newInsertionPoint.Name] = newInsertionPoint
            self.InsertionPointsCount = self.InsertionPointsCount + 1
        end
    end
	for _, playerStart in ipairs(gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPlayerStart')) do
        local insertionPointName = gamemode.GetInsertionPointName(playerStart)
        if actor.HasTag(playerStart, 'Hospital') and actor.GetTeamId(playerStart) == self.Id then
            self.HospitalStartsCount = self.HospitalStartsCount + 1
            self.HospitalStarts[actor.GetLocation(playerStart)] = playerStart
        else
            local insertionPoint = self.InsertionPoints[insertionPointName]
            if insertionPoint ~= nil then
                insertionPoint:AddPlayerStart(playerStart)
            end
        end
	end
    print('  Found ' .. self.InsertionPointsCount .. ' insertion points and ' .. self.HospitalStartsCount .. ' hospital starts')
    gamemode.script.AgentsManager:AddTeam(self)
    return self
end

function Team:__eq(Other)
    if self == nil or Other == nil then
        return false
    end
    return self.Id == Other.Id
end

function Team:__tostring()
    return "Team " .. self.Name .. ' (ID=' .. self.Id .. ')'
end

function Team:GetId()
    return self.Id
end

function Team:Reset()
    if gamemode.script.Settings.DisplayScoreMessages ~= nil then
        self.Display.ScoreMessage = gamemode.script.Settings.DisplayScoreMessages.Value == 1
    else
        self.Display.ScoreMessage = false
    end
    if gamemode.script.Settings.DisplayScoreMilestones ~= nil then
        self.Display.ScoreMilestone = gamemode.script.Settings.DisplayScoreMilestones.Value == 1
    else
        self.Display.ScoreMilestone = false
    end
    if gamemode.script.Settings.DisplayObjectiveMessages ~= nil then
        self.Display.ObjectiveMessage = gamemode.script.Settings.DisplayObjectiveMessages.Value == 1
    else
        self.Display.ObjectiveMessage = false
    end
    if gamemode.script.Settings.DisplayObjectivePrompts ~= nil then
        self.Display.ObjectivePrompt = gamemode.script.Settings.DisplayObjectivePrompts.Value == 1
    else
        self.Display.ObjectivePrompt = false
    end
    self.Agents.All = {}
    for _, insertionPoint in pairs(self.InsertionPoints) do
        insertionPoint:OnRoundStart()
    end
end

function Team:SetMaxHealings(maxHealings)
    self.maxHealings = maxHealings
end

function Team:SetHealingMode(healingMode)
    self.healingMode = healingMode
end

function Team:SetDefaultEliminationCallback(Callback)
	self.DefaultEliminationCallback = Callback
end

function Team:RemoveDefaultEliminationCallback()
	self.DefaultEliminationCallback = nil
end

function Team:GetDefaultEliminationCallback()
	return self.DefaultEliminationCallback or gamemode.script.AgentsManager.FallbackEliminationCallback
end

--#region Players

function Team:AddAgent(Agent)
    table.insert(self.Agents.All, Agent)
    self:UpdateAgentsLists()
end

function Team:AddHealableTeam(OtherTeam)
    self.HealableTeams[OtherTeam.Id] = true
end

function Team:RemoveHealableTeam(OtherTeam)
    self.HealableTeams[OtherTeam.Id] = nil
end

function Team:UpdateAgentsLists()
    self.Agents.Alive = {}
    self.Agents.Dead = {}
    for i, Agent in ipairs(self.Agents.All) do
        if Agent.IsAlive then
            table.insert(self.Agents.Alive, Agent)
        else
            table.insert(self.Agents.Dead, Agent)
        end
    end
    print(tostring(self) .. ': ' .. #self.Agents.Alive .. ' of ' .. #self.Agents.All .. ' alive')

end

function Team:GetAllAgentsCount()
    return #self.Agents.All
end

--#endregion

--#region Alive players

function Team:GetAliveAgents()
    return self.Agents.Alive
end

function Team:GetAliveAgentsCount()
    return #self.Agents.Alive
end

function Team:IsWipedOut()
    return #self.Agents.Alive <= 0
end

function Team:MoveTo(NewTeam)
    local Agents = Tables.Copy(self.Agents.All)
    self.Agents.All = {}
    self:UpdateAgentsLists()
    for _, Agent in ipairs(Agents) do -- use self.Agents.All here because self.Agents.Alive might not be up to date yet
        if Agent.IsAlive then
            Agent:MoveTo(NewTeam)
        end
    end
end

function Team:SetAttitude(OtherTeam, Attitude, mutual)
    mutual = mutual or false
    AdminTools:ShowDebug(tostring(self) .. ': setting attitude towards ' .. tostring(OtherTeam) .. ' to ' .. Attitude)
	gamemode.SetTeamAttitude(self.Id, OtherTeam.Id, Attitude)
    self.Attitudes[OtherTeam.Id] = Attitude
    for _, Agent in ipairs(self.Agents.All) do
        Agent:OnTeamAttitudeChange()
    end
    if mutual then
        OtherTeam:SetAttitude(self, Attitude)
    end
end

function Team:GetAttitude(OtherTeam)
    local Attitude = self.Attitudes[OtherTeam.Id]
    if Attitude == nil then
        return 'Hostile'
    else
        return Attitude
    end
end

function Team:AddGameObjective(ObjectiveName, Weight)
    gamemode.AddGameObjective(self.Id, ObjectiveName, Weight)
end

--#endregion

--#region Score

function Team:AwardTeamScore(action)
    if self.TeamScoreTypes[action] == nil then
        return
    end

    gamemode.AwardTeamScore(self.Id, action, 1)
end

function Team:AwardPlayerScore(awardedPlayer, action)
    if self.PlayerScoreTypes[action] == nil then
        return
    end

    player.AwardPlayerScore(player.GetPlayerState(awardedPlayer), action, 1)
end

--#endregion

--#region Respawns

function Team:GetClosestHospitalStart(Position, originalInsertionPoint)
    if self.healingMode == 0 then
        AdminTools:ShowDebug('Respawning in-place')
        return Position
    end
	local LowestDist = 100000000
    local ClosestHospital = nil
    for HospitalLocation, Hospital in pairs(self.HospitalStarts) do
        local Dist = vector.Size(Position.Location - HospitalLocation)
        if Dist ~= nil then
            if Dist <= LowestDist then
                LowestDist = Dist
                ClosestHospital = Hospital
            end
        end
    end
    if ClosestHospital ~= nil then
        AdminTools:ShowDebug('Closest hospital start: ' .. actor.GetName(ClosestHospital))
    else
        local insertionPoint = self.InsertionPoints[originalInsertionPoint]
        if insertionPoint ~= nil then
            ClosestHospital = insertionPoint:GetPlayerStart(true)
        end
        if ClosestHospital ~= nil then
            AdminTools:ShowDebug('No hospital start found, using one of the original insertion point (' .. actor.GetName(ClosestHospital) .. ')')
        else
            AdminTools:ShowDebug('No hospital start found, will use default player start')
        end
    end
    return ClosestHospital
end

function Team:GetPlayerStart(playerState)
    local insertionPointName = gamemode.GetInsertionPointName(player.GetInsertionPoint(playerState))
    local playerStart = nil
    if insertionPointName ~= nil then
        local insertionPoint = self.InsertionPoints[insertionPointName]
        if insertionPoint ~= nil then
            playerStart = insertionPoint:GetPlayerStart()
        end
    else
        playerStart = self:GetClosestPlayerStart()
    end
    return playerStart
end

function Team:GetClosestPlayerStart()
    local insertionPoint = nil
    local maxPlayersCount = 0
    for _, currInsertionPoint in pairs(self.InsertionPoints) do
        if currInsertionPoint.UsedPlayerStartsCount > maxPlayersCount and #currInsertionPoint.UnusedPlayerStarts > 0 then
            insertionPoint = currInsertionPoint
            maxPlayersCount = currInsertionPoint.UsedPlayerStartsCount
        end
    end
    if insertionPoint == nil then
        for _, currInsertionPoint in pairs(self.InsertionPoints) do
            insertionPoint = currInsertionPoint
            break
        end
    end
    return insertionPoint:GetPlayerStart(true)
end

--#endregion

--#region Messages

function Team:DisplayMessageToPlayer(agent, message, position, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    agent:DisplayMessage(
        message,
        position,
        duration
    )
end

function Team:DisplayMessageToAlivePlayers(message, position, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    if #self.Agents.Alive > 0 then
        for _, agent in ipairs(self.Agents.Alive) do
            agent:DisplayMessage(
                message,
                position,
                duration
            )
        end
    end
end

function Team:DisplayMessageToAllPlayers(message, position, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    if #self.Agents.All > 0 then
        for _, agent in ipairs(self.Agents.All) do
            agent:DisplayMessage(
                message,
                position,
                duration
            )
        end
    end
end

function Team:DisplayPromptToAlivePlayers(location, label, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    if #self.Agents.Alive > 0 then
        for _, agent in ipairs(self.Agents.Alive) do
            agent:ShowWorldPrompt(
                location,
                label,
                duration
            )
        end
    end
end

--#endregion

return Team