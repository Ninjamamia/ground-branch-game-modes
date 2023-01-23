local Tables = require("Common.Tables")
local AdminTools = require('AdminTools')

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("Agents.Base"))

-- Our sub-class of the singleton
local Player = setmetatable({}, { __index = super })

Player.__index = Player
Player.Type = "Player"

---Creates a new Player object.
---@return table Player Newly created Player object.
function Player:Create(AgentsManager, characterController, eliminationCallback)
    local self = setmetatable({}, Player)
    self:Init(AgentsManager, characterController, eliminationCallback)
    self:PostInit()
    return self
end

function Player:Init(AgentsManager, characterController, eliminationCallback)
    self.Name = player.GetName(characterController)
    super.Init(self, AgentsManager, characterController, eliminationCallback)
    self.IsNew = true
    self.IsAlive = false
    self.DeathReason = ''
    self.CurrentPlayerStart = self.Team:GetPlayerStart(characterController)
    self.OriginalInsertionPointName = gamemode.GetInsertionPointName(self.CurrentPlayerStart)
end

function Player:AwardPlayerScore(action)
    self.Team:AwardPlayerScore(self.CharacterController, action)
end

function Player:AwardTeamScore(action)
    self.Team:AwardTeamScore(action)
end

function Player:OnCharacterDied(KillData)
    super.OnCharacterDied(self, KillData)
    if gamemode.GetRoundStage() == 'InProgress' then
        AdminTools:NotifyKIA(self.CharacterController)
        player.SetLives(self.CharacterController, 0)
    end
    self.CurrentPlayerStart = self:GetPosition() -- do this here in case the player gets resurrected by an admin
end

function Player:Respawn()
    self.CurrentPlayerStart = self.Team:GetClosestHospitalStart(self:GetPosition(), self.OriginalInsertionPointName)
    gamemode.EnterPlayArea(self.CharacterController)
end

function Player:PrepareRespawn()
    player.SetLives(self.CharacterController, 1)
    self:AwardTeamScore('Respawn')
end

function Player:OnSpawned()
    self:UpdateCharacter()
    if self.IsNew then
        print(tostring(self) .. ' spawned initially')
    else
        print(tostring(self) .. ' respawned')
    end
    self.IsNew = false
    if self.Character ~= nil then
        self.IsAlive = true
        self.DeathReason = ''
        self.Team:UpdateAgentsLists()
    else
        self.DeathReason = 'Spawn failed'
        AdminTools:ShowDebug('Failed to spawn ' .. tostring(self))
    end
end

function Player:Kill(message)
    self.DeathMessage = message
    player.FreezePlayer(player.GetPlayerState(self.Character), 2.0)
	self:DisplayMessage(message, 'Upper', 2.0)
    timer.Set(
            'PreKill_' .. self.Name,
            self,
            self.PostFreeze,
            2.0,
            false
        )
end

function Player:PostFreeze()
	gamemode.EnterReadyRoom(player.GetPlayerState(self.Character))
	self:DisplayMessage(self.DeathMessage, 'Upper', 3.0)
end

function Player:OnLogOut()
    self.IsAlive = false
    self.DeathReason = 'LogOut'
    self.Team:UpdateAgentsLists()
end

function Player:DisplayMessage(message, position, duration, messageType)
    messageType = messageType or "Always"
    if not self.Team.Display[messageType] then
        return
    end
    player.ShowGameMessage(
        self.CharacterController,
        message,
        position,
        duration
    )
end

function Player:ShowWorldPrompt(location, label, duration, messageType)
    messageType = messageType or "Always"
    if not self.Team.Display[messageType] then
        return
    end
    player.ShowWorldPrompt(
        self.CharacterController,
        location,
        label,
        duration
    )
end

function Player:MoveTo(NewTeam)
    super.MoveTo(self, NewTeam)
    AdminTools:ShowDebug(tostring(self) .. ': swapping teams on player agents is not fully supported!')
end

return Player