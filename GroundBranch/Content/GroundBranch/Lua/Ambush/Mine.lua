local AdminTools = require('AdminTools')
local ActorState = require('common.ActorState')
local Prop = require('Ambush.Prop')

local Mine = {
    Name = nil,
    Tag = nil,
    Actor = nil,
    State = 'Inactive',
}

Mine.__index = Mine

function Mine:Create(Parent, Actor)
    local self = setmetatable({}, Mine)
    self.Parent = Parent
    self.Name = actor.GetName(Actor)
    self.Actor = Actor
    self.ActorState = ActorState:Create(self.Actor)
    self.Tag = nil
    self.State = 'Inactive'
    self.Props = {}
    self.PropsCount = 0
    self.Defusers = {}
    self.BlastZones = {}
    self.Hidden = actor.HasTag(Actor, 'Hidden')
    print('  ' .. tostring(self) .. ' found.')
    print('    Parameters:')
    for _, Tag in ipairs(actor.GetTags(Actor)) do
        local key
        local value
        _, _, key, value = string.find(Tag, "(%a+)%s*=%s*(.+)")
        if key ~= nil then
            print('      ' .. Tag)
            if key == 'BlastZone' then
                local BlastZone = self.Parent.BlastZonesByName[value]
                if BlastZone ~= nil then
                    table.insert(self.BlastZones, BlastZone)
                else
                    print('      BlastZone ' .. value .. ' is unknown!')
                end
            else
                self[key] = tonumber(value)
            end
        end
    end
    print('    Gathering props...')
    for _, Actor in ipairs(gameplaystatics.GetAllActorsWithTag(self.Name)) do
        local NewProp = Prop:Create(Parent, Actor)
        self.Props[NewProp.Name] = NewProp
        self.PropsCount = self.PropsCount + 1
    end
    for _, Actor in ipairs(gameplaystatics.GetAllActorsOfClassWithTag('/Game/GroundBranch/Props/Electronics/MilitaryLaptop/BP_Laptop_Usable.BP_Laptop_Usable_C', self.Name)) do
        local NewDefuser = Prop:Create(Parent, Actor)
        self.Props[NewDefuser.Name] = nil
        table.insert(self.Defusers, NewDefuser)
    end
    self.PropsCount = self.PropsCount - #self.Defusers
    print('    Found a total of ' .. self.PropsCount .. ' props and ' .. #self.Defusers .. ' defusers.')
    return self
end

function Mine:__tostring()
    return 'Mine ' .. self.Name
end

function Mine:SyncState()
    self.ActorState:Sync()
    for _, Prop in pairs(self.Props) do
        Prop:SyncState()
    end
    for _, Prop in ipairs(self.Defusers) do
        Prop:SyncState()
    end
    for _, CurrBlast in ipairs(self.BlastZones) do
        CurrBlast:SyncState()
    end
end

function Mine:Activate()
    print('Activating ' .. tostring(self) .. '...')
    self.State = 'Active'
    self.ActorState:SetActive(true)
    self.ActorState:SetVisible(not self.Hidden)
    for _, Prop in pairs(self.Props) do
        Prop:SetActive(true)
        Prop:SetVisible(true)
        Prop:SetCollidable(not Prop.Walkthrough)
    end
    for _, Prop in ipairs(self.Defusers) do
        Prop:SetActive(true)
        Prop:SetVisible(false)
        Prop:SetCollidable(true)
    end
    for _, CurrBlast in ipairs(self.BlastZones) do
        CurrBlast:SetDebugVisibility(AdminTools.DebugMessageLevel > 2)
        CurrBlast:Activate()
    end
    local tiDelayMin = self.tiDelayMin or 0
    local tiDelayMax = self.tiDelayMax or 0
    if tiDelayMin >= tiDelayMax then
        self.tiDelay = math.min(tiDelayMin, tiDelayMax)
    else
        self.tiDelay = math.random(tiDelayMin * 10, tiDelayMax * 10) * 0.1
    end
end

function Mine:Deactivate()
    print('Deactivating ' .. tostring(self) .. '...')
    self.State = 'Inactive'
    self.ActorState:SetActive(false)
    for _, Prop in pairs(self.Props) do
        Prop:SetActive(false)
        Prop:SetVisible(false)
        Prop:SetCollidable(false)
    end
    for _, Prop in ipairs(self.Defusers) do
        Prop:SetActive(false)
        Prop:SetVisible(false)
        Prop:SetCollidable(false)
    end
    for _, CurrBlast in ipairs(self.BlastZones) do
        CurrBlast:Deactivate()
    end
end

function Mine:Defuse()
    AdminTools:ShowDebug(tostring(self) .. ' defused.')
    self.State = 'Inactive'
    self.ActorState:SetActive(false)
    for _, Prop in pairs(self.Props) do
        Prop:SetActive(true)
        Prop:SetVisible(Prop.Keep)
        Prop:SetCollidable(not Prop.Walkthrough)
    end
    for _, Prop in ipairs(self.Defusers) do
        Prop:SetVisible(false)
        Prop:SetCollidable(false)
    end
    for _, CurrBlast in ipairs(self.BlastZones) do
        CurrBlast:Deactivate()
    end
    self:SyncState()
end

function Mine:Trigger(force)
    force = force or false
    if force then
        self:Activate()
        self:SyncState()
    end
    if self.State == 'Active' then
        AdminTools:ShowDebug(tostring(self) .. " triggered, igniting after " .. self.tiDelay .. "s.")
        if self.tiDelay < 0.2 then
            self:Ignite()
        else
            timer.Set(
                "Trigger_" .. self.Name,
                self,
                self.Ignite,
                self.tiDelay,
                false
            )
        end
    end
end


function Mine:Ignite()
    self.State = 'Triggered'
    AdminTools:ShowDebug(tostring(self) .. ": Ignition!")
    actor.SetActive(self.Actor, true)
    GetLuaComp(self.Actor).Explode()
    self.ActorState:SetActive(false)
    self.ActorState:SetVisible(false)
    for _, CurrBlast in ipairs(self.BlastZones) do
        CurrBlast:Trigger()
    end
    for _, Prop in pairs(self.Props) do
        Prop:SetActive(false)
        Prop:SetVisible(false)
        Prop:SetCollidable(false)
    end
    for _, Prop in ipairs(self.Defusers) do
        Prop:SetActive(false)
        Prop:SetVisible(false)
        Prop:SetCollidable(false)
    end
    self:SyncState()
end

return Mine