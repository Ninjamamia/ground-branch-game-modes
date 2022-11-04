local AdminTools = require('AdminTools')

local Base = {
}

Base.tiIdle = 30
Base.tiHeal = 10
Base.tiWait = 10

Base.__index = Base

---Creates a new base agent object.
function Base:Create(Queue, characterController, eliminationCallback)
	self.IsAI = false
	self.IsAlive = true
	self.Queue = Queue
    self.CharacterController = characterController
    self.Healings = 0
	self.Tags = {}
    self.HealableTeams = {}
    if characterController ~= nil then
        self.Name = player.GetName(characterController)
        self.Character = player.GetCharacter(characterController)
        self.TeamId = actor.GetTeamId(characterController)
        self.eliminationCallback = eliminationCallback or Queue:GetDefaultEliminationCallback(self.TeamId)
    else
        self.Name = "Unknonw"
        self.Character = nil
        self.TeamId = 255
        self.eliminationCallback = nil
    end
end

function Base:__tostring()
    return self.Name
end

function Base:GetMaxHealings()
    return 1
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
    if self.Character == nil then
        return nil
    end
    local location = actor.GetLocation(self.Character)
    local rotation = actor.GetRotation(self.Character)
    -- fix first letter case of rotation indices, no way around since
    -- actor.GetLocation uses lowercase but we are supposed to return
    -- PascalCase in the GetSpawnInfo() function
	if rotation ~= nil then
		rotation = {
			Pitch = rotation.pitch,
			Yaw = rotation.yaw,
			Roll = rotation.roll,
		}
	end
    -- add the dead player's postion to the deadPlayerPositions the
    -- PlayerState is used as an id to select the correct position in
    -- the list later in the GetSpawnInfo() function
    return {
        Location = location,
        Rotation = rotation,
    }
end

function Base:OnCharacterDied(KillData)
    self.KillData = KillData
	self.IsAlive = false
    if gamemode.GetRoundStage() == 'InProgress' then
        if self.Healings < self:GetMaxHealings() then
            self.Healings = self.Healings + 1
            AdminTools:ShowDebug('Agent ' .. self.Name .. ' can be healed now (' .. self.Healings .. ' of ' .. self:GetMaxHealings() .. ')')
            self:PrepareHealing()
        else
            self.eliminationCallback:Call(KillData)
        end
    end
end

function Base:Kill(message)
    print('Function "Kill" has to be overridden')
end

function Base:PrepareHealing()
    self.State = 'Idle'
    self.tiState = self.tiIdle
    self.tiTimeout = self.tiIdle
    self.Queue:EnqueueHealingChance(self)
end

function Base:CanHeal(WoundedAgent)
    return self.IsAlive and self.HealableTeams[WoundedAgent.TeamId] ~= nil
end

function Base:OnHealingCheckTick()
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
            AdminTools:ShowDebug('Healing of ' .. self.Name .. ' timed out')
            self.eliminationCallback:Call(self.KillData)
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
                AdminTools:ShowDebug('Healing of ' .. self.Name .. ' successful')
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

function Base:DisplayMessage(message, position, duration)
end

function Base:DisplayPrompt(location, label, duration)
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
    for _, Agent in ipairs(self.Queue.Agents) do
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