local AdminTools = require('AdminTools')

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
    self.Tag = nil
    self.State = 'Inactive'
    self.Props = {}
    self.Defusers = {}
    self.BlastZones = {}
    self.Hidden = actor.HasTag(Actor, 'Hidden')
    print(tostring(self) .. ' found.')
    print('  Parameters:')
    for _, Tag in ipairs(actor.GetTags(Actor)) do
        local key
        local value
        _, _, key, value = string.find(Tag, "(%a+)%s*=%s*(%w+)")
        if key ~= nil then
            print("    " .. Tag)
            if key == 'BlastZone' then
                local BlastZone = self.Parent.BlastZones[value]
                if BlastZone ~= nil then
                    table.insert(self.BlastZones, BlastZone)
                else
                    print('    BlastZone ' .. value .. ' is unknown!')
                end
            else
                self[key] = tonumber(value)
            end
        end
    end
    print('  Gathering props...')
    self.Props = gameplaystatics.GetAllActorsWithTag(self.Name)
    self.Defusers = gameplaystatics.GetAllActorsOfClassWithTag('/Game/GroundBranch/Props/Electronics/MilitaryLaptop/BP_Laptop_Usable.BP_Laptop_Usable_C', self.Name)
    print('  Found a total of ' .. #self.Props .. ' props and ' .. #self.Defusers .. ' defusers.')
    return self
end

function Mine:__tostring()
    return 'Mine ' .. self.Name
end

function Mine:Activate()
    print('Activating ' .. tostring(self) .. '...')
    self.State = 'Active'
    actor.SetActive(self.Actor, true)
    actor.SetHidden(self.Actor, self.Hidden)
    for _, Prop in ipairs(self.Props) do
        actor.SetActive(Prop, true)
        actor.SetHidden(Prop, false)
        actor.SetEnableCollision(Prop, false)
    end
    for _, Prop in ipairs(self.Defusers) do
        actor.SetActive(Prop, true)
        actor.SetHidden(Prop, true)
        actor.SetEnableCollision(Prop, true)
    end
    for _, CurrBlast in ipairs(self.BlastZones) do
        CurrBlast:SetDebugVisibility(AdminTools.DebugMessageLevel > 2)
        CurrBlast:Activate()
    end
end

function Mine:Deactivate()
    print('Deactivating ' .. tostring(self) .. '...')
    self.State = 'Inactive'
    actor.SetActive(self.Actor, false)
    for _, Prop in ipairs(self.Props) do
        actor.SetActive(Prop, false)
        actor.SetHidden(Prop, true)
        actor.SetEnableCollision(Prop, false)
    end
    for _, CurrBlast in ipairs(self.BlastZones) do
        CurrBlast:Deactivate()
    end
end

function Mine:Defuse()
    AdminTools:ShowDebug(tostring(self) .. ' defused.')
    self.State = 'Inactive'
    actor.SetActive(self.Actor, false)
    for _, Prop in ipairs(self.Props) do
        actor.SetActive(Prop, false)
        actor.SetEnableCollision(Prop, false)
        if not actor.HasTag(Prop, 'Keep') then
            actor.SetHidden(Prop, true)
        end
    end
    for _, CurrBlast in ipairs(self.BlastZones) do
        CurrBlast:Deactivate()
    end
end

function Mine:Trigger(force)
    force = force or false
    if force then
        self:Activate()
    end
    if self.State == 'Active' then
        self.State = 'Triggered'
        AdminTools:ShowDebug(tostring(self) .. " triggered.")
        actor.SetActive(self.Actor, true)
        GetLuaComp(self.Actor).Explode()
        actor.SetHidden(self.Actor, true)
        actor.SetEnableCollision(self.Actor, false)
        for _, CurrBlast in ipairs(self.BlastZones) do
            CurrBlast:Trigger()
        end
        for _, Prop in ipairs(self.Props) do
            actor.SetActive(Prop, false)
            actor.SetHidden(Prop, true)
            actor.SetEnableCollision(Prop, false)
        end
    end
end

return Mine