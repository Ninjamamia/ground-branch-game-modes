local AdminTools = require('AdminTools')
local ActorTools = require('common.Actors')

local Base = {
    IsAgent = true
}

Base.tiHeal = 10
Base.tiWait = 10

Base.__index = Base

---Creates a new base agent object.
function Base:Init(AgentsManager, characterController, eliminationCallback)
	self.IsAlive = true
	self.AgentsManager = AgentsManager
    self.CharacterController = characterController
    self.Healings = 0
	self.Tags = {}
    self.HealableTeams = {}
    if characterController ~= nil then
        self.Character = player.GetCharacter(characterController)
        self.TeamId = actor.GetTeamId(characterController)
        self.Team = self.AgentsManager:GetTeamByID(self.TeamId)
        self.HealableTeams = self.Team.HealableTeams
        self.EliminationCallback = eliminationCallback
        self.ActiveEliminationCallback = nil
    else
        self.Name = "Unknown"
        self.Character = nil
        self.TeamId = 255
        self.EliminationCallback = nil
    end
    getmetatable(self).__tostring = Base.__tostring
    getmetatable(self).__eq = Base.__eq
end

function Base:PostInit()
    if self.Team ~= nil then
        self.Team:AddAgent(self)
    end
end

function Base:__tostring()
    return self.Name
end

function Base:__eq(Other)
    return self.Type == Other.Type and self.Name == Other.Name
end

function Base:GetMaxHealings()
    return self.Team.maxHealings
end

function Base:UpdateCharacter()
    self.Character = player.GetCharacter(self.CharacterController)
end

function Base:HasTag(Tag)
	return self.Tags[Tag] == true
end

function Base:GetTags()
    local Tags = {}
    for Tag, _ in pairs(self.Tags) do
        table.insert(Tags, Tag)
    end
	return Tags
end

function Base:AddTag(NewTag)
	self.Tags[NewTag] = true
end

function Base:GetLocation()
    if self.Character == nil then
        return nil
    end
    return actor.GetLocation(self.Character)
end

function Base:GetPosition()
    return ActorTools.GetPosition(self.Character)
end

function Base:OnCharacterDied(KillData)
    self.KillData = KillData
	self.IsAlive = false
    if gamemode.GetRoundStage() == 'InProgress' then
        self.ActiveEliminationCallback = self.EliminationCallback or self.Team:GetDefaultEliminationCallback()
        if self.Healings < self:GetMaxHealings() then
            self.Healings = self.Healings + 1
            AdminTools:ShowDebug(tostring(self) .. ' is wounded and can be healed now (' .. self.Healings .. ' of ' .. self:GetMaxHealings() .. ')')
            self:PrepareHealing()
        else
            AdminTools:ShowDebug(tostring(self) .. ' died')
            self:OnBleedout()
        end
        self.Team:UpdateAgentsLists()
    end
end

function Base:OnBleedout()
    if self.ActiveEliminationCallback ~= nil then
        self.ActiveEliminationCallback:Call(self.KillData)
    else
        print(tostring(self) .. ": unable to determine active elimination callback!")
    end
end

function Base:Kill(message)
    print('Function "Kill" has to be overridden')
end

function Base:PrepareHealing()
    self.State = 'Idle'
    self.tiState = self.AgentsManager.tiIdle
    self.tiTimeout = self.AgentsManager.tiIdle
    self.AgentsManager:EnqueueHealingChance(self)
end

function Base:CanHeal(WoundedAgent)
    return self.IsAlive and self.HealableTeams[WoundedAgent.TeamId] ~= nil
end

function Base:OnHealingCheckTick()
    if self.IsAlive then
        self.State = 'Aborted'
        return true
    end
    if self.State == 'Waiting' then
        self.tiState = self.tiState - 1
        if self.tiState <= 0 then
            self:Respawn()
            self.State = 'Done'
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
            AdminTools:ShowDebug(tostring(self) .. ' died (healing timed out)')
            self:OnBleedout()
            return true
        else
            self:DisplayMessageToWounded('Your will bleed out in ' .. self.tiState .. 's!')
        end
    elseif self.State == 'Healing' then
        self.tiState = self.tiState - 1
        local Healers = self:GetHealers()
        if #Healers > 0 then
            if self.tiState <= 0 then
                self:DisplayMessageToHealers(Healers, 'Healed.')
                AdminTools:ShowDebug('Healing of ' .. tostring(self) .. ' successful')
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

function Base:DisplayMessage(message, position, duration, messageType)
end

function Base:DisplayPrompt(location, label, duration, messageType)
end

function Base:AwardPlayerScore(action)
end

function Base:AwardTeamScore(action)
end

function Base:MoveTo(NewTeam)
    self.TeamId = NewTeam.Id
    self.Team = NewTeam
    self.HealableTeams = self.Team.HealableTeams
    if self.Team ~= nil then
        self.Team:AddAgent(self)
    end
    self:OnTeamAttitudeChange()
end

function Base:OnTeamAttitudeChange()
end

function Base:DisplayMessageToHealers(healers, message)
    for _, healer in ipairs(healers) do
        healer:DisplayMessage(message, 'Upper', 0.9)
    end
end

function Base:DisplayMessageToWounded(message)
    self:DisplayMessage(message, 'Upper', 0.9)
end

function Base:GetHealers()
    local killLocation = self:GetLocation()
    local healers = {}
    local potentialHealersAlive = false
    for _, Agent in ipairs(self.AgentsManager.Agents) do
        if Agent:CanHeal(self) then
            local Dist = vector.Size(Agent:GetLocation() - killLocation)
            if Dist <= 150 then
                table.insert(healers, Agent)
            end
            potentialHealersAlive = true
        end
    end
    if potentialHealersAlive == false then  -- no potential healers alive, time out immediately
        self.tiState = 0
    end
    return healers
end

return Base