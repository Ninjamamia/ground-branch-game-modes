local AdminTools = require('AdminTools')

local BlastZone = {
}

BlastZone.__index = BlastZone

function BlastZone:Create(Parent, Actor)
    local self = setmetatable({}, BlastZone)
    self.Parent = Parent
    self.Name = actor.GetName(Actor)
    self.Actor = Actor
    print(tostring(self) .. ' found.')
    return self
end

function BlastZone:__tostring()
    return 'BlastZone ' .. self.Name
end

function BlastZone:SetDebugVisibility(visible)
    actor.SetHidden(self.Actor, not visible)
end

function BlastZone:Activate()
    print('Activating ' .. tostring(self) .. '...')
    self.Agents = {}
    self.AgentsCount = 0
    actor.SetActive(self.Actor, true)
end

function BlastZone:Deactivate()
    print('Deactivating ' .. tostring(self) .. '...')
    self.Agents = {}
    self.AgentsCount = 0
    actor.SetActive(self.Actor, false)
end

function BlastZone:Trigger()
    for _, Agent in pairs(self.Agents) do
        Agent:Kill('You just got killed by explosives!')
    end
end

function BlastZone:OnBeginOverlap(Agent)
    if self.Agents[Agent.Name] == nil then
        self.Agents[Agent.Name] = Agent
        self.AgentsCount = self.AgentsCount + 1
        AdminTools:ShowDebug(tostring(Agent) .. ' entered ' .. tostring(self) .. ', ' .. self.AgentsCount .. ' agents present')
    end
end

function BlastZone:OnEndOverlap(Agent)
    if self.Agents[Agent.Name] ~= nil then
        self.Agents[Agent.Name] = nil
        self.AgentsCount = self.AgentsCount - 1
        AdminTools:ShowDebug(tostring(Agent) .. ' left ' .. tostring(self) .. ', ' .. self.AgentsCount .. ' agents present')
    end
end

return BlastZone