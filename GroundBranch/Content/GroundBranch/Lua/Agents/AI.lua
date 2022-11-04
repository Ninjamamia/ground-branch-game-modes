local Tables = require("Common.Tables")
local AdminTools = require('AdminTools')

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("Agents.Base"))

-- Our sub-class of the singleton
local AI = setmetatable({}, { __index = super })

AI.__index = AI

---Creates a new AI object.
---@return table AI Newly created AI object.
function AI:Create(Queue, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    local self = setmetatable({}, AI)
    super.Create(self, Queue, characterController, eliminationCallback)
	self.IsAI = true
	self.UUID = uuid
	self.Name = uuid
	self.SpawnPoint = spawnPoint
	self.BaseTag = BaseTag
    self:AddTag(BaseTag)
    return self
end

function AI:CleanUp()
	ai.CleanUp(self.UUID)
    for i = 0, self.Healings, 1 do
        local CurrUUID = self.UUID .. "_" .. self.Healings
        ai.CleanUp(CurrUUID)
    end
end

function AI:Kill(message)
	ai.KillAI(self.CharacterController)
    self.Healings = 255 -- avoid healing attempt in this case as the body disappears
	self.Queue:OnAgentDied(self, nil)
end

function AI:Respawn()
    local CurrUUID = self.UUID .. "_" .. self.Healings
    ai.CreateWithTransform(self.SpawnPoint, self:GetPosition(), CurrUUID, 0.1)
    local characterController = gameplaystatics.GetAllActorsWithTag(CurrUUID)
    if characterController ~= nil then
        self.CharacterController = characterController[1]
        self.Queue.SpawnedAIByControllerName[actor.GetName(self.CharacterController)] = self
        self:UpdateCharacter()
        if self.Character ~= nil then
            self.IsAlive = true
            self.Queue.SpawnedAIByCharacterName[actor.GetName(self.Character)] = self
            AdminTools:ShowDebug(self.Name .. ' respawned as ' .. CurrUUID)
        else
            print('Failed to respawn ' .. self.Name .. ' as ' .. CurrUUID)
        end
    end
end

return AI