local AdminTools = require "AdminTools"
local Tables = require('Common.Tables')

local Respawn = {
    tiIdle = 30,
    tiHeal = 10,
    tiWait = 10
}

Respawn.__index = Respawn

function Respawn:Create(Team, killData)
    local self = setmetatable({}, Respawn)
    self.Team = Team
	self.KillData = killData
    self.PlayerName = player.GetName(killData.CharacterController)
    self.OriginalInsertionPoint = self.Team.CurrentInsertionPoints[player.GetName(killData.CharacterController)]
    self.State = 'Idle'
    self.tiState = self.tiIdle
    self.tiTimeout = self.tiIdle
    self.Position = killData:GetPosition()
    return self
end

function Respawn:OnCheckTick()
    if self.State == 'Waiting' then
        self.tiState = self.tiState - 1
        if self.tiState <= 0 then
            self.Team:SetCurrentPlayerStart(self.PlayerName, self.Team:GetClosestHospitalStart(self.Position, self.OriginalInsertionPoint))
            gamemode.EnterPlayArea(self.KillData.CharacterController)
            self.State = 'Done'
            AdminTools:ShowDebug(self.PlayerName .. ' respawned')
            return true
        else
            self:DisplayMessageToWounded('You will respawn in ' .. self.tiState .. 's!')
        end
    elseif self.State == 'Idle' then
        self.tiState = self.tiState - 1
        self.tiTimeout = self.tiTimeout - 1
        local Healers = self:GetHealers()
        if #Healers > 0 then
            self.State = 'Healing'
            self.tiState = self.tiHeal
            self:DisplayMessageToHealers(Healers, 'Healing (' .. self.tiState .. 's remaining)...')
            self:DisplayMessageToWounded('You are getting healed (' .. self.tiState .. 's remaining)...')
        elseif self.tiState <= 0 then
            self.State = 'Timeout'
            AdminTools:ShowDebug('Healing of ' .. self.PlayerName .. ' timed out')
            return true
        else
            self:DisplayMessageToWounded('Your time will run out in ' .. self.tiState .. 's!')
        end
    elseif self.State == 'Healing' then
        self.tiState = self.tiState - 1
        local Healers = self:GetHealers()
        if #Healers > 0 then
            if self.tiState <= 0 then
                self:DisplayMessageToHealers(Healers, 'Healed.')
                AdminTools:ShowDebug('Healing of ' .. self.PlayerName .. ' successful')
                self.State = 'Waiting'
                self.tiState = self.tiWait
            else
                self:DisplayMessageToHealers(Healers, 'Healing (' .. self.tiState .. 's remaining)...')
                self:DisplayMessageToWounded('You are getting healed (' .. self.tiState .. 's remaining)...')
            end
        else
            self.State = 'Idle'
            self.tiState = self.tiTimeout
        end
    end
    return false
end

function Respawn:DisplayMessageToHealers(healers, message)
    for _, healer in ipairs(healers) do
        self.Team:DisplayMessageToPlayer(healer, message, 'Upper', 0.9, 'Always')
    end
end

function Respawn:DisplayMessageToWounded(message)
    self.Team:DisplayMessageToPlayer(self.KillData.CharacterController, message, 'Upper', 0.9, 'Always')
end

function Respawn:GetHealers()
    local killLocation = self.Position.Location
    local healers = {}
    for _, playerController in ipairs(self.Team:GetAlivePlayers()) do
        local playerLocation = actor.GetLocation(
            player.GetCharacter(playerController)
        )
        local Dist = vector.Size(playerLocation - killLocation)
        if Dist <= 150 then
            table.insert(healers, playerController)
        end
    end
    return healers
end

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
    CurrentPlayerStart = {},
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
    self.CurrentPlayerStart = {}
    self.CurrentInsertionPoints = {}
    self.HospitalStartsCount = 0
    self.InsertionPointsCount = 0
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
    self.HealingCounts = {}
    self.CurrentPlayerStart = {}
    self.PendingRespawns = {}
    self.CurrentInsertionPoints = {}
    for _, insertionPoint in pairs(self.InsertionPoints) do
        insertionPoint:OnRoundStart()
    end
    gamemode.ResetTeamScores()
	gamemode.ResetPlayerScores()
    self:SetAllowedToRespawn(self:CanRespawn())
    self:UpdatePlayers()
end

--#region Players

function Teams:UpdatePlayers()
    self.Players.All = gamemode.GetPlayerList(self.Id, self.IncludeBots)
    self.Players.Alive = {}
    self.Players.Dead = {}
    print('Found ' .. #self.Players.All .. ' Players')
    for i, playerState in ipairs(self.Players.All) do
        if player.GetLives(playerState) == 1 then
            print('Player ' .. i .. ' is alive')
            table.insert(self.Players.Alive, playerState)
        else
            print('Player ' .. i .. ' is dead')
            table.insert(self.Players.Dead, playerState)
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
    self:SetAllowedToRespawn(self:CanRespawn())
    print('Changed team score to ' .. self.Score)
end

function Teams:AwardPlayerScore(awardedPlayer, action)
    if self.PlayerScoreTypes[action] == nil then
        return
    end

    local multiplier = 1
    player.AwardPlayerScore(awardedPlayer, action, multiplier)

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

function Teams:SetAllowedToRespawn(respawnAllowed)
    print('Setting team allowed to respawn to ' .. tostring(respawnAllowed))
    for _, playerController in ipairs(self.Players.All) do
        player.SetAllowedToRestart(playerController, respawnAllowed)
    end
end

function Teams:PlayerDied(killData)
    print('Player died')
    if gamemode.GetRoundStage() ~= 'InProgress' then
        return
    end
    local PlayerName = player.GetName(killData.CharacterController)
    if self.HealingCounts[PlayerName] == nil then
        self.HealingCounts[PlayerName] = 0
    end
    if self.HealingCounts[PlayerName] < self.maxHealings then
        self.HealingCounts[PlayerName] = self.HealingCounts[PlayerName] + 1
        AdminTools:ShowDebug('Player ' .. PlayerName .. ' can be healed now (' .. self.HealingCounts[PlayerName] .. ' of ' .. self.maxHealings .. ')')
        NewRespawn = Respawn:Create(self, killData)
        table.insert(self.PendingRespawns, NewRespawn)
        if #self.PendingRespawns == 1 then
            timer.Set(
                'RespawnChecker',
                self,
                self.OnRespawnCheckTick,
                1.0,
                true
            )
            print('RespawnChecker started')
        end
    end
    player.SetLives(killData.CharacterController, 0)
    self:UpdatePlayers()
end

function Teams:OnRespawnCheckTick()
    for idx, CurrRespawn in ipairs(self.PendingRespawns) do
        local isDone = CurrRespawn:OnCheckTick()
        if isDone then
            table.remove(self.PendingRespawns, idx)
        end
    end
    if #self.PendingRespawns < 1 then
        timer.Clear('RespawnChecker', self)
        print('RespawnChecker stopped')
    end
end

function Teams:SetCurrentPlayerStart(PlayerName, PlayerStart)
    self.CurrentPlayerStart[PlayerName] = PlayerStart
end

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

function Teams:RespawnFromReadyRoom(playerController)
    print('Player respawning from ready room')
    if gamemode.GetRoundStage() ~= 'InProgress' then
        player.ShowGameMessage(
            playerController,
            'RespawnNotInProgress',
            'Lower',
            2.5
        )
        return
    end
    if self:CanRespawn() then
        gamemode.EnterPlayArea(playerController)
    else
        player.ShowGameMessage(
            playerController,
            'RespawnInsufficientScore',
            'Lower',
            2.5
        )
    end
end

function Teams:RespawnCleanUp(playerState)
    print('Cleaning up after respawn')
    player.SetLives(playerState, 1)
    self:UpdatePlayers()
    self:AwardTeamScore('Respawn')
    return self.CurrentPlayerStart[player.GetName(playerState)]
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
    self.CurrentInsertionPoints[player.GetName(playerState)] = gamemode.GetInsertionPointName(playerStart)
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

function Teams:CanRespawn()
    if self.RespawnCost == 0 then
        return true
    else
        return self.Score >= self.RespawnCost
    end
end

--#endregion

--#region Messages

function Teams:DisplayMessageToPlayer(playerController, message, position, duration, messageType)
    if not self.Display[messageType] then
        return
    end
    player.ShowGameMessage(
        playerController,
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
        for _, playerController in ipairs(self.Players.Alive) do
            player.ShowGameMessage(
                playerController,
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
        for _, playerController in ipairs(self.Players.All) do
            player.ShowGameMessage(
                playerController,
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
        for _, playerController in ipairs(self.Players.Alive) do
            player.ShowWorldPrompt(
                playerController,
                location,
                label,
                duration
            )
        end
    end
end

--#endregion

return Teams