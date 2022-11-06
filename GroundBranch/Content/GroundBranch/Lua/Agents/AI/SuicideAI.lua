local Tables = require("Common.Tables")
local AdminTools = require('AdminTools')

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("Agents.AI.BasicAI"))

-- Our sub-class of the singleton
local SuicideAI = setmetatable({}, { __index = super })

SuicideAI.__index = SuicideAI
SuicideAI.Type = "Suicide AI"

---Creates a new SuicideAI object.
---@return table SuicideAI Newly created AI object.
function SuicideAI:Create(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    local self = setmetatable({}, SuicideAI)
    self:Init(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    self:PostInit()
    return self
end

function SuicideAI:Init(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    super.Init(self, AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    self.TriggerTeams = {}
    self.TriggerRadius = 1000
    self.TriggerHeight = 1000000
    self.BlastRadius = 1500
    self.BlastHeight = 1000000
    self.Mine = nil
    print('  This is a Suicide AI, Parameters:')
    for _, Tag in ipairs(actor.GetTags(spawnPoint)) do
        local key
        local value
        _, _, key, value = string.find(Tag, "(%a+)%s*=%s*(%w+)")
        if key ~= nil then
            print("    " .. Tag)
            if key == 'TriggerTeam' then
                self.TriggerTeams[tonumber(value)] = true
            elseif key == "Mine" then
                self.Mine = gamemode.script.AmbushManager:GetMine(value)
            else
                self[key] = tonumber(value)
            end
        end
    end
end

function SuicideAI:__tostring()
    return self.Type .. ' ' .. self.Name
end

function SuicideAI:OnCharacterDied(KillData)
    super.OnCharacterDied(self, KillData)
    timer.Clear('Tick_' .. self.UUID, self)
end

function SuicideAI:PostInit()
    super.PostInit(self)
    if self.IsAlive then
        self:StartTimer(1.0)
    end
end

function SuicideAI:StartTimer(interval)
    timer.Clear('Tick_' .. self.UUID, self)
    timer.Set(
            'Tick_' .. self.UUID,
            self,
            self.OnTick,
            interval,
            false
        )
end

function SuicideAI:CheckTrigger()
    local Location = self:GetLocation()
    local ClosestDist = 10000.0
    for _, Agent in ipairs(self.AgentsManager.Agents) do
        if Agent.IsAlive and Agent ~= self and self.TriggerTeams[Agent.TeamId] == true then
            local DistVect = Agent:GetLocation() - Location
            local Dist = vector.Size(DistVect)
            if Dist <= self.TriggerRadius and math.abs(DistVect.z) < (self.TriggerHeight / 2) then
                return 0
            elseif Dist < ClosestDist then
                ClosestDist = Dist
            end
        end
    end
    return ClosestDist
end

function SuicideAI:GetTargets()
    local Location = self:GetLocation()
    local Targets = {}
    for _, Agent in ipairs(self.AgentsManager.Agents) do
        if Agent.IsAlive then
            local DistVect = Agent:GetLocation() - Location
            local Dist = vector.Size(DistVect)
            if Dist <= self.BlastRadius and math.abs(DistVect.z) < (self.BlastHeight / 2) then
                table.insert(Targets, Agent)
            end
        end
    end
    return Targets
end

function SuicideAI:OnTick()
    if self.IsAlive then
        local Dist = self:CheckTrigger()
        if Dist < 1 then
            AdminTools:ShowDebug(tostring(self) .. ': Boom!')
            if self.Mine ~= nil then
                self.Mine:Trigger(true)
            end
            for _, Target in ipairs(self:GetTargets()) do
                Target:Kill('You got killed by a suicide bomber!')
            end
            self:Kill()
        else
            local tiSleep = math.min(10.0, math.max(0.5, Dist / 1000.0))
            self:StartTimer(tiSleep)
        end
    end
end

return SuicideAI