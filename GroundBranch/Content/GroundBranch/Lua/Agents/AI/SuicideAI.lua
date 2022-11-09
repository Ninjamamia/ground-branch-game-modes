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
    self.TriggerAngle = 360
    self.BlastRadius = 1500
    self.BlastHeight = 1000000
    self.Mine = nil
    print('  This is a Suicide AI, Parameters:')
    for _, Tag in ipairs(spawnPoint:GetTags()) do
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
    self.BlastRadius = self.BlastRadius * 2.7  -- BlastRadius defines the 50% death chance radius, scale it up
    self.BlastChanceFactor = 130.0 / (self.BlastRadius ^ 2)
    self.TriggerRadiusSq = self.TriggerRadius ^ 2
    self.TriggerAngleHalf = self.TriggerAngle / 2
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

function SuicideAI:Respawn(Position)
    super.Respawn(self, Position)
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

-- Returns the result of Angle1 - Angle2 normalized to [-180,180]
function SuicideAI:CalcAngleDiff(Angle1, Angle2)
    local Angle = Angle1 - Angle2
    if Angle > 180 then
        return Angle - 360
    elseif Angle < -180 then
        return Angle + 360
    end
    return Angle
end

function SuicideAI:GetBearing(MyPos, OtherPos)
    local DistVect = OtherPos.Location - MyPos.Location
    return self:CalcAngleDiff(math.deg(math.atan(DistVect.y, DistVect.x)), MyPos.Rotation.Yaw)
end

function SuicideAI:CheckTrigger()
    local MyPos = self:GetPosition()
    local ClosestDist = 1000000000000.0
    for _, Agent in ipairs(self.AgentsManager.Agents) do
        if Agent.IsAlive and Agent ~= self and self.TriggerTeams[Agent.TeamId] == true then
            local AgentPos = Agent:GetPosition()
            local DistVect = AgentPos.Location - MyPos.Location
            local Dist = vector.SizeSq(DistVect)
            if Dist <= self.TriggerRadiusSq and math.abs(DistVect.z) < (self.TriggerHeight / 2) then
                local Bearing = self:GetBearing(MyPos, AgentPos)
                if math.abs(Bearing) <= self.TriggerAngleHalf then
                    return 0
                end
            end
            if Dist < ClosestDist then
                ClosestDist = Dist
            end
        end
    end
    return math.sqrt(ClosestDist)
end

function SuicideAI:GetTargets()
    local MyPos = self:GetPosition()
    local PrelimTargets = {}
    print('SuicideAI:GetTargets: Collecting candidates (in range)...')
    for _, Agent in ipairs(self.AgentsManager.Agents) do
        if Agent.IsAlive then
            local AgentPos = Agent:GetPosition()
            local DistVect = AgentPos.Location - MyPos.Location
            local Dist = vector.Size(DistVect)
            if Dist <= self.BlastRadius and math.abs(DistVect.z) < (self.BlastHeight / 2) then
                local Bearing = self:GetBearing(MyPos, AgentPos)
                local Chance = ((self.BlastRadius - Dist) ^ 2) * self.BlastChanceFactor
                local CoveredAngle = math.deg(math.atan(30, Dist))
                local NewItem = {Agent=Agent, Dist=Dist, Bearing=Bearing, Chance=Chance, CoveredAngle=CoveredAngle, Killed = false}
                table.insert(PrelimTargets, NewItem)
                print('  Candidate ' .. tostring(NewItem.Agent) .. ': Dist=' .. math.floor(NewItem.Dist) .. '; Bearing=' .. math.floor(NewItem.Bearing) .. '; CoveredAngle=' .. math.floor(NewItem.CoveredAngle) .. '; Chance=' .. math.floor(NewItem.Chance) .. '%')
            end
        end
    end
    print('SuicideAI:GetTargets: Sorting candidates by distance...')
    table.sort(PrelimTargets, function (a, b)
        return a.Dist < b.Dist
    end)
    print('SuicideAI:GetTargets: Evaluating kill criteria...')
    local Targets = {}
    for idx, Item in ipairs(PrelimTargets) do
        print('  Handling ' .. tostring(Item.Agent) .. ' (Dist=' .. math.floor(Item.Dist) .. '; Bearing=' .. math.floor(Item.Bearing) .. '):')
        local InitialChance = Item.Chance
        for i = idx-1, 2, -1 do
            local CloserItem = PrelimTargets[i]
            local BearingDiff = math.abs(self:CalcAngleDiff(Item.Bearing, CloserItem.Bearing))
            if BearingDiff < (CloserItem.CoveredAngle / 2) then
                if CloserItem.Killed == false then
                    print('   Covered by survivor ' .. tostring(CloserItem.Agent) .. ' (Dist=' .. math.floor(CloserItem.Dist) .. '; Bearing=' .. math.floor(CloserItem.Bearing) .. '; CoveredAngle=' .. math.floor(CloserItem.CoveredAngle) .. ')')
                    Item.Chance = Item.Chance * 0.1
                else
                    print('   Covered by casualty ' .. tostring(CloserItem.Agent) .. ' (Dist=' .. math.floor(CloserItem.Dist) .. '; Bearing=' .. math.floor(CloserItem.Bearing) .. '; CoveredAngle=' .. math.floor(CloserItem.CoveredAngle) .. ')')
                    Item.Chance = Item.Chance * 0.5
                end
                break
            end
        end
        local RandVal = math.random(0, 99)
        if RandVal < Item.Chance then
            Item.Killed = true
            table.insert(Targets, Item.Agent)
        end
        print('   -> Chance=' .. math.floor(InitialChance).. '% -> ' .. math.floor(Item.Chance) .. '%; RandVal=' .. math.floor(RandVal) .. '; Killed=' .. tostring(Item.Killed))
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
        else
            local tiSleep = math.min(10.0, math.max(0.1, Dist / 1000.0))
            self:StartTimer(tiSleep)
        end
    end
end

return SuicideAI