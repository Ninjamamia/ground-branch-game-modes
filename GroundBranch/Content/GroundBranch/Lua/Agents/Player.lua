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
function Player:Create(AgentsManager, Team, characterController, eliminationCallback)
    local self = setmetatable({}, Player)
    self:Init(AgentsManager, Team, characterController, eliminationCallback)
    return self
end

function Player:Init(AgentsManager, Team, characterController, eliminationCallback)
    super.Init(self, AgentsManager, characterController, eliminationCallback)
    self.IsNew = true
    self.IsAlive = false
    self.Team = Team
    self.DeathReason = ''
    self.CurrentPlayerStart = self.Team:GetPlayerStart(characterController)
    self.OriginalInsertionPointName = gamemode.GetInsertionPointName(self.CurrentPlayerStart)
    self.Team:AddPlayer(self)
    self.HealableTeams = self.Team.HealableTeams
end

function Player:__tostring()
    return self.Type .. ' ' .. self.Name
end

function Player:AwardPlayerScore(action)
    self.Team:AwardPlayerScore(self.CharacterController, action)
end

function Player:AwardTeamScore(action)
    self.Team:AwardTeamScore(action)
end

function Player:GetMaxHealings()
    return self.Team.maxHealings
end

function Player:OnCharacterDied(KillData)
    super.OnCharacterDied(self, KillData)
    if gamemode.GetRoundStage() == 'InProgress' then
        AdminTools:NotifyKIA(self.CharacterController)
        player.SetLives(self.CharacterController, 0)
        self.Team:UpdatePlayerLists()
    end
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
        self.Team:UpdatePlayerLists()
    else
        self.DeathReason = 'Spawn failed'
        AdminTools:ShowDebug('Failed to spawn ' .. tostring(self))
    end
end

function Player:Kill(message)
	gamemode.EnterReadyRoom(player.GetPlayerState(self.Character))
	player.ShowGameMessage(self.Character, message, 'Upper', 3.0)
end

function Player:OnLogOut()
    self.IsAlive = false
    self.DeathReason = 'LogOut'
    self.Team:UpdatePlayerLists()
end

function Player:DisplayMessage(message, position, duration)
    player.ShowGameMessage(
        self.CharacterController,
        message,
        position,
        duration
    )
end

function Player:ShowWorldPrompt(location, label, duration)
    player.ShowWorldPrompt(
        self.CharacterController,
        location,
        label,
        duration
    )
end

return Player