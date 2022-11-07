local Tables = require("Common.Tables")
local AdminTools = require('AdminTools')

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("Agents.Base"))

-- Our sub-class of the singleton
local BasicAI = setmetatable({}, { __index = super })

BasicAI.__index = BasicAI
BasicAI.Type = "Basic AI"

---Creates a new BasicAI object.
---@return table BasicAI Newly created AI object.
function BasicAI:Create(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    local self = setmetatable({}, BasicAI)
    self:Init(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    self:PostInit()
    return self
end

function BasicAI:Init(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
	self.Name = uuid .. ' @ ' .. actor.GetName(spawnPoint)
    super.Init(self, AgentsManager, characterController, eliminationCallback)
	self.UUID = uuid
	self.SpawnPoint = spawnPoint
	self.BaseTag = BaseTag
    self:AddTag(BaseTag)
    self.OriginalTeamId = self.TeamId
end

function BasicAI:__tostring()
    return self.Type .. ' ' .. self.Name
end

function BasicAI:CleanUp()
    actor.SetTeamId(self.SpawnPoint, self.OriginalTeamId)
	ai.CleanUp(self.UUID)
    for i = 0, self.Healings, 1 do
        local CurrUUID = self.UUID .. "_" .. self.Healings
        ai.CleanUp(CurrUUID)
    end
end

function BasicAI:OnBleedout()
    super.OnBleedout(self)
    self.AgentsManager:OnAIBleedout(self)
end

function BasicAI:Kill(message)
	ai.KillAI(self.CharacterController)
    self.Healings = 255 -- avoid healing attempt in this case as the body disappears
	gamemode.script:OnCharacterDied(self, self, nil)
end

function BasicAI:Respawn(Position)
    local CurrUUID = self.UUID .. "_" .. self.Healings
    ai.CreateWithTransform(self.SpawnPoint, Position or self:GetPosition(), CurrUUID, 0.0)
    local characterController = gameplaystatics.GetAllActorsWithTag(CurrUUID)
    if characterController ~= nil then
        self.CharacterController = characterController[1]
        self.AgentsManager.SpawnedAIByControllerName[actor.GetName(self.CharacterController)] = self
        self:UpdateCharacter()
        if self.Character ~= nil then
            self.IsAlive = true
            self.AgentsManager.SpawnedAIByCharacterName[actor.GetName(self.Character)] = self
            self.Team:UpdateAgentsLists()
            AdminTools:ShowDebug(tostring(self) .. ' respawned as ' .. CurrUUID)
        else
            print('Failed to respawn ' .. tostring(self) .. ' as ' .. CurrUUID)
        end
    end
end

function BasicAI:MoveTo(NewTeam)
    super.MoveTo(self, NewTeam)
    actor.SetTeamId(self.SpawnPoint, self.TeamId)
    local Position = self:GetPosition()
    self:Kill()
    self:Respawn(Position)
end

return BasicAI