local Mocks = {}

local each = require('common.Tables').each

--
-- Mocking actor UserData
--
Mocks.Actor = { count = 0 }
Mocks.Actor.__index = Mocks.Actor;

function Mocks.Actor.create(name)
    Mocks.Actor.count = Mocks.Actor.count + 1
    local self = setmetatable({
        name = name or "test_actor_"..Mocks.Actor.count,
        tags = {},
        active = nil,
        visible = nil,
        collide = nil,
    }, Mocks.Actor);
    return self
end
function Mocks.Actor.GetName(self) return self.name end
function Mocks.Actor.GetTags(self) return self.tags end
function Mocks.Actor.SetTag(self, tag) table.insert(self.tags, tag); return self end
function Mocks.Actor.SetTags(self, tags)  each(tags, function(tag) self:SetTag(tag) end); return self end
function Mocks.Actor.SetActive(self, value) self.active = value; return self end
function Mocks.Actor.SetHidden(self, value) self.visible = not value; return self end
function Mocks.Actor.SetEnableCollision(self, value) self.collide = value; return self end
function Mocks.Actor.__tostring(self)
    return string.format('<Mocks.Actor> name=%s', self.name)
end
function Mocks.Actor.__concat(self, other)
    return tostring(self)..tostring(other)
end

--
-- Mocking gameplaystatics UserData
--
Mocks.Gameplaystatics = {
    mockedActors = {}
}
function Mocks.Gameplaystatics.reset()
    Mocks.Gameplaystatics.mockedActors = {}
end

function Mocks.Gameplaystatics.addActor(actor)
    table.insert(Mocks.Gameplaystatics.mockedActors, actor)
end

function Mocks.Gameplaystatics.GetAllActorsWithTag(tag)
    local actorList = {}
    for _i, anActor in ipairs(Mocks.Gameplaystatics.mockedActors) do
        for _i, aTag in ipairs(Mocks.Actor.GetTags(anActor)) do
            if tag == aTag then
                table.insert(actorList, anActor)
            end
        end
    end
    return actorList
end

return Mocks
