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
        print('Found a free player start on insertion point ' .. self.Name .. ' (' .. actor.GetName(playerStart) .. '), ' .. #self.UnusedPlayerStarts .. ' left')
    elseif force then
        playerStart = self.PlayerStarts[self.EnforcedIndex]
        self.EnforcedIndex = self.EnforcedIndex + 1
        if self.EnforcedIndex > #self.PlayerStarts then
            self.EnforcedIndex = 1
        end
        print('No free player start found on insertion point ' .. self.Name .. ', enforcing one (' .. actor.GetName(playerStart) .. ')')
    end
    return playerStart
end

local Teams = {
    Id = 0,
    Score = 0,
    Milestones = 0,
    Players = {
        All = {},
        Alive = {},
        Dead = {},
    },
    IncludeBots = false,
    RespawnCost = 1000000,
    Display = {
        ScoreMessage = false,
        ScoreMilestone = true,
        ObjectiveMessage = true,
        ObjectivePrompt = true,
        Always = true
    },
    PlayerScoreTypes = {},
    TeamScoreTypes = {},
    PlayerStarts = {},
    HospitalStarts = {},
    maxHealings = 0,
    healingMode = 0  -- 0 = in place; 1 = MedEvac
}

Teams.__index = Teams

function Teams:Create(
    teamId,
    includeBots,
    playerScoreTypes,
    teamScoreTypes
)
    print('Initializing team ' .. teamId .. '...')
    local self = setmetatable({}, Teams)
    self.Id = teamId
    self.Score = 0
    self.Milestones = 0
    self.IncludeBots = includeBots
    self.Players.All = {}
    self.Players.Alive = {}
    self.Players.Dead = {}
    self.RespawnCost = 1000000
    self.Display.ScoreMessage = false
    self.Display.ScoreMilestone = true
    self.Display.ObjectiveMessage = true
    self.Display.ObjectivePrompt = true
    self.Display.Always = true
    self.PlayerScoreTypes = playerScoreTypes or {}
    self.TeamScoreTypes = teamScoreTypes or {}
    self.InsertionPoints = {}
    self.HospitalStarts = {}
    self.HospitalStartsCount = 0
    self.InsertionPointsCount = 0
    self.HealableTeams = {}
    self.HealableTeams[self.Id] = true
    for _, insertionPoint in ipairs(gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')) do
        local newInsertionPoint = InsertionPoint:Create(self, insertionPoint)
        self.InsertionPoints[newInsertionPoint.Name] = newInsertionPoint
        self.InsertionPointsCount = self.InsertionPointsCount + 1
    end
	for _, playerStart in ipairs(gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPlayerStart')) do
        local insertionPointName = gamemode.GetInsertionPointName(playerStart)
		if actor.HasTag(playerStart, 'Hospital') then
            self.HospitalStartsCount = self.HospitalStartsCount + 1
            self.HospitalStarts[actor.GetLocation(playerStart)] = playerStart
        else
            local insertionPoint = self.InsertionPoints[insertionPointName]
            if insertionPoint ~= nil then
                insertionPoint:AddPlayerStart(playerStart)
            else
                print('  Player start ' .. actor.GetName(playerStart) .. ' is neither assigned to any insertion point nor tagged as "Hospital"!')
            end
		end
	end
	gamemode.SetTeamScoreTypes(self.TeamScoreTypes)
	gamemode.SetPlayerScoreTypes(self.PlayerScoreTypes)
    print('  Found ' .. self.InsertionPointsCount .. ' insertion points and ' .. self.HospitalStartsCount .. ' hospital starts')
    print('  Intialized Team ' .. tostring(self))
    gamemode.script.SpawnQueue:AddTeam(self)
    return self
end

function Teams:GetId()
    return self.Id
end

function Teams:RoundStart(
    maxHealings,
    healingMode
)
    self.Score = 0
    self.Milestones = 0
    self.RespawnCost = 1000000
    self.maxHealings = maxHealings or 0
    self.healingMode = healingMode or 0
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
    self.Players.All = {}
    for _, insertionPoint in pairs(self.InsertionPoints) do
        insertionPoint:OnRoundStart()
    end
    gamemode.ResetTeamScores()
	gamemode.ResetPlayerScores()
end

--#region Players

function Teams:AddPlayer(Player)
    table.insert(self.Players.All, Player)
    self:UpdatePlayerLists()
end

function Teams:AddHealableTeam(TeamId)
    self.HealableTeams[TeamId] = true
end

function Teams:UpdatePlayerLists()
    self.Players.Alive = {}
    self.Players.Dead = {}
    print('Found ' .. #self.Players.All .. ' Players')
    for i, Player in ipairs(self.Players.All) do
        if Player.IsAlive then
            print('Player ' .. Player.Name .. ' is alive')
            table.insert(self.Players.Alive, Player)
        else
            print('Player ' .. Player.Name .. ' is dead')
            table.insert(self.Players.Dead, Player)
        end
    end
end

function Teams:GetAllPlayersCount()
    return #self.Players.All
end

--#endregion

--#region Alive players

function Teams:GetAlivePlayers()
    return self.Players.Alive
end

function Teams:GetAlivePlayersCount()
    return #self.Players.Alive
end

function Teams:IsWipedOut()
    return #self.Players.Alive <= 0 and self.Score < self.RespawnCost
end

--#endregion

--#region Score

function Teams:AwardTeamScore(action)
    if self.TeamScoreTypes[action] == nil then
        return
    end

    local multiplier = 1
    if action == 'Respawn' then
        multiplier = self.RespawnCost
    end
    gamemode.AwardTeamScore(self.Id, action, multiplier)

    local scoreChange = self.TeamScoreTypes[action].Score * multiplier
    self.Score = self.Score + scoreChange
    if self.Score < 0 then
        self.Score = 0
    end

    self:DisplayMilestones()
    print('Changed team score to ' .. self.Score)
end

function Teams:AwardPlayerScore(awardedPlayer, action)
    if self.PlayerScoreTypes[action] == nil then
        return
    end

    local multiplier = 1
    player.AwardPlayerScore(player.GetPlayerState(awardedPlayer), action, multiplier)

    local scoreChange = self.PlayerScoreTypes[action].Score * multiplier
    local message = nil
    if scoreChange >= 0 then
        message = action .. ' +' .. scoreChange
    else
        message = action .. ' -' .. -scoreChange
    end
    self:DisplayMessageToPlayer(awardedPlayer, message, 'Lower', 2.0, 'ScoreMessage')
    print('Changed player score by ' .. scoreChange)
end

function Teams:DisplayMilestones()
    if self.RespawnCost == 0 then
        return
    end
    local newMilestone = math.floor(self.Score / self.RespawnCost)
    if newMilestone ~= self.Milestones then
        local message = 'Respawns available ' .. newMilestone
        self.Milestones = newMilestone
        self:DisplayMessageToAllPlayers(message, 'Lower', 2.0, 'ScoreMilestone')
    end
end

--#endregion

--#region Respawns

function Teams:GetClosestHospitalStart(Position, originalInsertionPoint)
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

function Teams:GetPlayerStart(playerState)
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

function Teams:GetClosestPlayerStart()
    print('Teams:GetClosestPlayerStart')
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

function Teams:DisplayMessageToPlayer(agent, message, position, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    agent:DisplayMessage(
        message,
        position,
        duration
    )
end

function Teams:DisplayMessageToAlivePlayers(message, position, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    if #self.Players.Alive > 0 then
        for _, agent in ipairs(self.Players.Alive) do
            agent:DisplayMessage(
                message,
                position,
                duration
            )
        end
    end
end

function Teams:DisplayMessageToAllPlayers(message, position, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    if #self.Players.All > 0 then
        for _, agent in ipairs(self.Players.All) do
            agent:DisplayMessage(
                message,
                position,
                duration
            )
        end
    end
end

function Teams:DisplayPromptToAlivePlayers(location, label, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    if #self.Players.Alive > 0 then
        for _, agent in ipairs(self.Players.Alive) do
            agent:ShowWorldPrompt(
                location,
                label,
                duration
            )
        end
    end
end

--#endregion

return Teams