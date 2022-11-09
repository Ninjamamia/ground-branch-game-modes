local ActorTools = require('common.Actors')

local SpawnPoint = {
}

SpawnPoint.__index = SpawnPoint

function SpawnPoint.CreateMultiple(Actors)
    Spawns = {}
    for _, Actor in ipairs(Actors) do
        table.insert(Spawns, SpawnPoint:Create(Actor))
    end
    return Spawns
end

function SpawnPoint:Create(Actor)
    local self = setmetatable({}, SpawnPoint)
    self.Actor = Actor
    self.Name = actor.GetName(self.Actor)
    self.OriginalPosition = ActorTools.GetPosition(Actor)
	return self
end

function SpawnPoint:SpawnAI(tag, freezeTime, position)
    ai.CreateWithTransform(self.Actor, position or self.OriginalPosition, tag, freezeTime)
end

function SpawnPoint:GetPosition()
	return self.OriginalPosition
end

function SpawnPoint:GetLocation()
	return self.OriginalPosition.Location
end

function SpawnPoint:SetTeamId(Id)
    actor.SetTeamId(self.Actor, Id)
end

function SpawnPoint:HasTag(tag)
    return actor.HasTag(self.Actor, tag)
end

function SpawnPoint:GetTags()
    return actor.GetTags(self.Actor)
end

function SpawnPoint:GetActor()
    return self.Actor
end

function SpawnPoint:GetName()
    return self.Name
end

return SpawnPoint