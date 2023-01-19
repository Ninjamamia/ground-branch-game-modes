local AdminTools = require('AdminTools')
local Tables = require('Common.Tables')
local SpawnPoint = require('Spawns.Point')
local ActorState = require('common.ActorState')

local Trigger = {
    Name = nil,
    Tag = nil,
    Actor = nil,
    State = 'Inactive',
    Spawns = {},
    Activates = {},
    Mines = {}
}

Trigger.__index = Trigger

function Trigger:Create(Parent, Actor, IsLaptop)
    local self = setmetatable({}, Trigger)
    self.Parent = Parent
    self.Name = actor.GetName(Actor)
    self.Actor = Actor
    self.ActorState = ActorState:Create(self.Actor)
    self.IsLaptop = IsLaptop or false
    self.Tag = nil
    self.State = 'Inactive'
    self.Spawns = {}
    self.ActivatePatterns = {}
    self.Activates = {}
    self.MinePatterns = {}
    self.Mines = {}
    self.VisibleWhenActive = actor.HasTag(Actor, 'Visible')
    self.TriggerOnRelease = actor.HasTag(Actor, 'TriggerOnRelease')
    self.FirstAgent = nil
    self.EntryMessageToFirst = nil
    self.DelayedMessageToBluFor = nil
    print('  ' .. tostring(self) .. ' found.')
    print('    Parameters:')
    for _, Tag in ipairs(actor.GetTags(Actor)) do
        local key
        local value
        _, _, key, value = string.find(Tag, "(%a+)%s*=%s*(.+)")
        if key ~= nil then
            print("      " .. Tag)
            if key == "Group" then
                self.Tag = value
                self.Spawns = SpawnPoint.CreateMultiple(gameplaystatics.GetAllActorsOfClassWithTag(
                    'GroundBranch.GBAISpawnPoint',
                    value
                ))
            elseif key == "Activate" then
                table.insert(self.ActivatePatterns, value)
            elseif key == "Mine" then
                table.insert(self.MinePatterns, value)
            elseif key == "EntryMessageToFirst" then
                self.EntryMessageToFirst = value
            elseif key == "DelayedMessageToBluFor" then
                self.DelayedMessageToBluFor = value
            else
                self[key] = tonumber(value)
            end
        end
    end
    return self
end

function Trigger:PostInit()
    print('  ' .. tostring(self) .. ' post init...')
    print('    Processing mine links...')
    for _, value in ipairs(self.MinePatterns) do
        local pattern = string.gsub(value, '%*', '.*') .. '$'
        for name, mine in pairs(self.Parent.MinesByName) do
            if string.find(name, pattern) ~= nil then
                print('      ' .. tostring(mine) .. ' added')
                table.insert(self.Mines, mine)
            end
        end
    end
    print('    Processing activation links...')
    for _, value in ipairs(self.ActivatePatterns) do
        local pattern = string.gsub(value, '%*', '.*') .. '$'
        for name, item in pairs(self.Parent.TriggersByName) do
            if string.find(name, pattern) ~= nil then
                print('      ' .. tostring(item) .. ' added')
                table.insert(self.Activates, item)
            end
        end
        for name, item in pairs(self.Parent.MinesByName) do
            if string.find(name, pattern) ~= nil then
                print('      ' .. tostring(item) .. ' added')
                table.insert(self.Activates, item)
            end
        end
    end
    print('    Summary:')
    print("      Spawns: " .. #self.Spawns)
    print("      Activation links: " .. #self.Activates)
    print("      Mines: " .. #self.Mines)
end

function Trigger:__tostring()
    return 'Ambush Trigger ' .. self.Name
end

function Trigger:SyncState()
    self.ActorState:Sync()
end

function Trigger:SetDebugVisibility(visible)
    if not self.IsLaptop and not self.VisibleWhenActive then
        self.ActorState:SetVisible(visible)
    end
end

function Trigger:Activate(IsLinked)
    print('Activating ' .. tostring(self) .. '...')
    self.postSpawnCallback = nil
    local tiMin = self.tiMin or self.Parent.tiMin
    local tiMax = self.tiMax or self.Parent.tiMax
    if tiMin >= tiMax then
        self.tiAmbush = math.min(tiMin, tiMax)
    else
        self.tiAmbush = math.random(tiMin * 10, tiMax * 10) * 0.1
    end
    local tiPresenceMin = self.tiPresenceMin or self.Parent.tiPresenceMin
    local tiPresenceMax = self.tiPresenceMax or self.Parent.tiPresenceMax
    if tiPresenceMin >= tiPresenceMax then
        self.tiPresence = math.min(tiPresenceMin, tiPresenceMax)
    else
        self.tiPresence = math.random(tiPresenceMin * 10, tiPresenceMax * 10) * 0.1
    end
    local sizeMin = self.sizeMin or self.Parent.sizeMin
    local sizeMax = self.sizeMax or self.Parent.sizeMax
    if sizeMin >= sizeMax then
        self.sizeAmbush = math.min(sizeMin, sizeMax)
    else
        self.sizeAmbush = math.min(math.random(sizeMin, sizeMax), #self.Spawns)
    end
    print("  tiPresence=" .. self.tiPresence)
    print("  tiAmbush=" .. self.tiAmbush)
    print("  sizeAmbush=" .. self.sizeAmbush)
    self.Spawns = Tables.ShuffleTable(self.Spawns)
    self.State = 'Active'
    IsLinked = IsLinked or false
    if IsLinked then
        if self.AgentsCount > 0 then
            if self.tiPresence < 5.0 then
                AdminTools:ShowDebug(tostring(self) .. ' reactivated, tiPresence < 5.0s (' .. self.tiPresence .. 's), will only re-trigger if re-occupied.')
            else
                timer.Set(
                    "Trigger_" .. self.Name,
                    self,
                    self.Trigger,
                    self.tiPresence,
                    false
                )
                AdminTools:ShowDebug(tostring(self) .. ' reactivated, ' .. self.AgentsCount .. ' agents still present, will re-trigger in ' .. self.tiPresence .. 's')
            end
        end
    else
        self.Agents = {}
        self.AgentsCount = 0
    end
    self.ActorState:SetActive(true)
    if self.VisibleWhenActive then
        self.ActorState:SetVisible(true)
    end
end

function Trigger:Deactivate()
    print('Deactivating ' .. tostring(self) .. '...')
    self.State = 'Inactive'
    self.Agents = {}
    self.AgentsCount = 0
    self.ActorState:SetActive(false)
    self.ActorState:SetVisible(false)
end

function Trigger:Trigger()
    self.State = 'Triggered'
    if self.sizeAmbush > 0 then
        AdminTools:ShowDebug(tostring(self) .. " triggered, activating " .. #self.Activates .. " other triggers, triggering " .. #self.Mines .. " mines, spawning " .. self.sizeAmbush .. " AI of group " .. self.Tag .. " in " .. self.tiAmbush .. "s")
        gamemode.script.AgentsManager:SpawnAI(self.tiAmbush, 0.1, self.sizeAmbush, self.Spawns, nil, nil, self.postSpawnCallback, true)
        timer.Set(
            "Trigger_Message_" .. self.Name,
            self,
            self.SendMessage,
            self.tiAmbush,
            false
        )
    else
        AdminTools:ShowDebug(tostring(self) .. " triggered, activating " .. #self.Activates .. " other triggers, triggering " .. #self.Mines .. " mines, nothing to spawn.")
    end
    self.ActorState:SetActive(false)
    self.ActorState:SetVisible(false)
    for _, CurrActivate in pairs(self.Activates) do
        CurrActivate:Activate(true)
        CurrActivate:SyncState()
    end
    for _, CurrMine in pairs(self.Mines) do
        CurrMine:Trigger()
    end
    self:SyncState()
end

function Trigger:SendMessage()
    if self.DelayedMessageToBluFor ~= nil then
        gamemode.script.Teams['BluFor']:DisplayMessageToAlivePlayers(self.DelayedMessageToBluFor, 'Upper', 10.0)
    end
end

function Trigger:OnBeginOverlap(Agent)
    if self.State == 'Active' then
        if self.Agents[Agent.Name] == nil then
            self.Agents[Agent.Name] = true
            self.AgentsCount = self.AgentsCount + 1
            local Message = tostring(Agent) .. ' entered ' .. tostring(self) .. ', ' .. self.AgentsCount .. ' agents present'
            if self.AgentsCount == 1 then
                self.FirstAgent = Agent
                if self.EntryMessageToFirst ~= nil then
                    Agent:DisplayMessage(self.EntryMessageToFirst, 'Upper', 10.0)
                end
                if self.TriggerOnRelease == false then
                    if self.tiPresence < 0.2 then
                        AdminTools:ShowDebug(Message)
                        self:Trigger()
                    else
                        Message = Message .. ', will trigger in ' .. self.tiPresence .. 's'
                        AdminTools:ShowDebug(Message)
                        timer.Set(
                            "Trigger_" .. self.Name,
                            self,
                            self.Trigger,
                            self.tiPresence,
                            false
                        )
                    end
                end
            end
        end
    end
end

function Trigger:OnEndOverlap(Agent)
    if self.State == 'Active' then
        if self.Agents[Agent.Name] ~= nil then
            self.Agents[Agent.Name] = nil
            self.AgentsCount = self.AgentsCount - 1
            local Message = tostring(Agent) .. ' left ' .. tostring(self) .. ', ' .. self.AgentsCount .. ' agents present'
            if self.TriggerOnRelease == true then
                if Agent == self.FirstAgent then
                    AdminTools:ShowDebug('This was the first agent (TriggerOnRelease set), tiggering...')
                    self:Trigger()
                end
            end
            if self.AgentsCount == 0 then
                timer.Clear("Trigger_" .. self.Name, self)
                Message = Message .. ', timer aborted'
            end
            AdminTools:ShowDebug(Message)
        end
    end
end

function Trigger:OnLaptopSuccess(Agent)
    if self.State == 'Active' then
        AdminTools:ShowDebug(tostring(Agent) .. ' used Laptop ' .. self.Name .. ' successfully')
        self:Trigger()
    end
end

function Trigger:OnCustomEvent(Agent, postSpawnCallback, force)
    force = force or false
    if force then
        self:Activate()
    end
    if self.State == 'Active' then
        self.postSpawnCallback = postSpawnCallback or nil
        AdminTools:ShowDebug(tostring(Agent) .. ' caused event trigger ' .. self.Name)
        self:Trigger()
    end
end

return Trigger