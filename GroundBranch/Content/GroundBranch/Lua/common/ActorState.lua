local ActorState = {
}

ActorState.__index = ActorState

function ActorState:Create(Actor)
    local self = setmetatable({}, ActorState)
    self.Actor = Actor
    self.IsActive = nil
    self.IsActivePrev = nil
    self.IsVisible = nil
    self.IsVisiblePrev = nil
    self.IsCollidable = nil
    self.IsCollidablePrev = nil
    return self
end

function ActorState:Sync()
    if self.IsActive ~= self.IsActivePrev then
        actor.SetActive(self.Actor, self.IsActive)
        self.IsActivePrev = self.IsActive
    end
    if self.IsVisible ~= self.IsVisiblePrev then
        actor.SetHidden(self.Actor, not self.IsVisible)
        self.IsVisiblePrev = self.IsVisible
    end
    if self.IsCollidable ~= self.IsCollidablePrev then
        actor.SetEnableCollision(self.Actor, self.IsCollidable)
        self.IsCollidablePrev = self.IsCollidable
    end
end

function ActorState:SetActive(isActive)
    self.IsActive = isActive
end

function ActorState:SetVisible(isVisible)
    self.IsVisible = isVisible
end

function ActorState:SetCollidable(isCollidable)
    self.IsCollidable = isCollidable
end

return ActorState