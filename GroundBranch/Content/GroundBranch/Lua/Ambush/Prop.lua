local ActorState = require('common.ActorState')

local Prop = {
}

Prop.__index = Prop

function Prop:Create(Parent, Actor)
    local self = setmetatable({}, Prop)
    self.Parent = Parent
    self.Actor = Actor
    self.ActorState = ActorState:Create(self.Actor)
    self.Name = actor.GetName(Actor)
    self.Keep = actor.HasTag(Actor, 'Keep')
    self.IsActive = true
    self.IsVisible = true
    self.IsCollidable = true
    return self
end

function Prop:SyncState()
    self.ActorState:Sync()
end

function Prop:GetName()
    return self.Name
end

function Prop:SetActive(isActive)
    self.ActorState:SetActive(isActive)
end

function Prop:SetVisible(isVisible)
    self.ActorState:SetVisible(isVisible)
end

function Prop:SetCollidable(isCollidable)
    self.ActorState:SetCollidable(isCollidable)
end

return Prop
