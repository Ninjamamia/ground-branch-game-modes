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
	self.Name = uuid .. ' @ ' .. spawnPoint:GetName()
    super.Init(self, AgentsManager, characterController, eliminationCallback)
	self.UUID = uuid
	self.SpawnPoint = spawnPoint
	self.BaseTag = BaseTag
    self:AddTag(BaseTag)
    self.OriginalTeamId = self.TeamId
    self.RespawnCount = 0
end

function BasicAI:CleanUp()
    self.SpawnPoint:SetTeamId(self.OriginalTeamId)
	ai.CleanUp(self.UUID)
    for i = 0, self.RespawnCount, 1 do
        local CurrUUID = self.UUID .. "_" .. i
        ai.CleanUp(CurrUUID)
    end
end

function BasicAI:OnBleedout()
    super.OnBleedout(self)
    self.AgentsManager:OnAIBleedout(self)
end

function BasicAI:Kill(message, isRespawnPrep)
	ai.KillAI(self.CharacterController)
    if not (isRespawnPrep == true) then
        self.Healings = 255 -- avoid healing attempt in this case as the body disappears
	    gamemode.script:OnCharacterDied(self, self, nil)
    end
end

function BasicAI:Respawn(Position)
    local CurrUUID = self.UUID .. "_" .. self.RespawnCount
    self.RespawnCount = self.RespawnCount + 1
    self.SpawnPoint:SpawnAI(CurrUUID, 0.0, Position or self:GetPosition())
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

function BasicAI:OnTeamAttitudeChange()
    super.OnTeamAttitudeChange(self)
    self.SpawnPoint:SetTeamId(self.TeamId)
    if self.IsAlive then
        local Position = self:GetPosition()
        self:Kill('', true)
        self:Respawn(Position)
    end
end

return BasicAI