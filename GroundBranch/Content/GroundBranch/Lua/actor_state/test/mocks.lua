local Mocks = {}

--
-- Mocking Actor UserData
--
Mocks.Actor = { count = 0 }

function Mocks.Actor:new()
	Mocks.Actor.count = Mocks.Actor.count + 1
	self.__index = self;
	o = {
		name = "test_actor_"..Mocks.Actor.count,
		tags = {},
		active = nil,
		visible = nil,
		collide = nil,
	}
	
	local self = setmetatable(o, self);
	return self
end
function Mocks.Actor.GetName(self) return self.name end
function Mocks.Actor.SetTag(self, tag) table.insert(self.tags, tag) end
function Mocks.Actor.GetTags(self) return self.tags end
function Mocks.Actor.SetActive(self, value) self.active = value end
function Mocks.Actor.SetHidden(self, value) self.visible = not value end
function Mocks.Actor.SetEnableCollision(self, value) self.collide = value end
function Mocks.Actor.__tostring(self)
	return string.format(
		'<Mocks.Actor> name=%s visible=%s collide=%s active=%s tags={ %s }',
		self.name, self.visible, self.collide, self.active, table.concat(self.tags, ', '))
end
function Mocks.Actor.__concat(self, other)
	return tostring(self)..tostring(other)
end

-- gameplaystatics = {}

-- function gameplaystatics:GetAllActorsWithTag(tag)
-- 	local actorList = {}
-- 	for _i, anActor in ipairs(mockedActors) do
-- 		for _i, aTag in ipairs(anActor:GetTags()) do
-- 			if tag == aTag then
-- 				table.insert(actorList, anActor)
-- 			end
-- 		end
-- 	end
-- 	return actorList
-- end

return Mocks