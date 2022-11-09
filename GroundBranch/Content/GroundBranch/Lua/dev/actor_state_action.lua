--
-- ActorStateAction "class"
--

local Tables = require('Common.Tables')
require("dev.functions")

local ActorStateAction = {}

-- Set visibility and or collision of a target actor from the object arg
function setActorState(target, object)
	local out = {}
	if object.visible ~= nil then
		actor.SetHidden(target, not object.visible)
		table.insert(out, sprintf("visible=%s", object.visible))
	end
	if object.collide ~= nil then
		actor.SetEnableCollision(target, object.collide)
		table.insert(out, sprintf("collide=%s", object.collide))
	end
	
	printf("  Set actor '%s' state: %s", actor.GetName(target), out)
end

-- Set visibility and collision of a target actor based on the shouldEnable arg
function setActorEnabled(target, shouldEnable)
	setActorState(target, {
		visible = shouldEnable,
		collide = shouldEnable,
	})
end

-- Enable the target actors based on a given probability in percent
function _enableProb(targets, enableProb)
	local shouldEnable = math.random(100) <= enableProb
	local result = {}
	for _, target in pairs(targets) do			
		setActorEnabled(target, shouldEnable)
		result[actor.GetName(target)] = shouldEnable
	end
	return result
end

-- Enable a specified number of target actors in the group
function _enableNum(targets, enableNum)
	local result = {}
	for index, target in ipairs(Tables.ShuffleTable(targets)) do
		local shouldEnable = index <= enableNum
		setActorEnabled(target, shouldEnable)
		result[actor.GetName(target)] = shouldEnable
	end
	return result
end

-- Enable a random number of target actors in the group constrained by a max and min
function _enableRndNum(targets, enableMin, enableMax)
	if enableMin == nil then
		enableMin = 0 else
		enableMin = math.min(math.max(enableMin, 0), enableMax) end

	if enableMax == nil then
		enableMax = #targets else
		enableMax = math.min(enableMax, enableMax) end
	
	local enableNum = math.random(enableMin, enableMax)
	
	printf("  Adjusted params: EnableMin=%s, EnableMax=%s", enableMin, enableMax)
	printf("  Random EnableNum value: %s", enableNum)

	return _enableNum(targets, enableNum)
end

-- Enable the target actors by copying state of another actor, possibly inverted
function _copyStateFrom(target, linkedActorName, inverse)
	local result = {}
	
	-- special case to when the EnableWith param ends with _, we do some
	-- use the actor's name suffix to build the linked actor name
	local suffix = nil
	if linkedActorName:sub(-1) == '_' then
		suffix = actorName:sub(actorName:find("_[^_]*$") + 1)
	end

	for _, target in pairs(targets) do
		
		local actorName = actor.GetName(target)
		if suffix ~= nil then
			linkedActorName = table.concat({ linkedActorName, suffix })
			printf("  Computed EnableWith value: '%s'", linkedActorName)
		end

		local linkedActorEnabled = toboolean(stateByActorName[linkedActorName])
		local shouldEnable = inverse ~= linkedActorEnabled

		setActorEnabled(target, shouldEnable)
		result[actor.GetName(target)] = shouldEnable
	end
	return result
end

-- Enable the target actors when another actor is enabled
function _enableWith(targets, linkedActorName)
	return _copyStateFrom(targets, linkedActorName, false)
end

-- Disable the target actors when another actor is enabled
function _disableWith(targets, linkedActorName)
	return _copyStateFrom(targets, linkedActorName, true)
end

--- Instantiate an ActorStateAction statically
 --
 --	@param	object	Table
 --		Will be passed "as is" to the ActorStateAction:new() method.
 --
 --	@return	Table
 --		An ActorStateAction	instance
 --
function ActorStateAction.create(object)
	return ActorStateAction:new(object)
end

--- Instantiate an ActorStateAction
 --	
 --	@param	object	Table
 --		Will be used as a metatable for the returned instance.
 --		If object contains a 'targets' (plural) property, the corresponding
 --		values will be used as the target list.
 --		If object contains a 'params' property, the corresponding value will be
 --		used as the parameter list.
 --		If object contains a 'target' (singular) property, the corresponding
 --		value will be added to the instance targets.
 --
 --	@return	Table
 --		An ActorStateAction	instance
 --
function ActorStateAction:new(object)
	self.__index = self
	object = object or {}
	local self = setmetatable(object, self)	

	self.targets = self.targets or {}
	self.params = self.params or {}

	-- if a single target is provided, move it to the target list
	if self.target then
		self:addTarget(self.target)
	end

	return self
end

--- Add a target to an ActorStateAction instance
 --	
 --	@param	anActor	UserData
 --		An Actor as returned by the GB API
 --
function ActorStateAction:addTarget(anActor)
	table.insert(self.targets, anActor)
end

--- Add parameters to an ActorStateAction instance
 --	
 --	@param	params	Table
 --		Associative array of parameters for the ActorStateAction, keys are the
 --		parameters names, values are the corresponding values.
 --
function ActorStateAction:addParams(params)
	-- merge tables, 1 dimension, last override first
	for k,v in pairs(params) do self.params[k] = v end
end

--- Execute the ActorStateAction instance
 --
 --	Enable or disable the target actors based on the parameters of the instance.
 --	
 --	@param	stateByActorName	Table	(optional, defaults to empty table)
 --		Associative array of actor states. Keys are the actors names, values are
 --		the corresponding states. Used when we need to decide the state of an
 --		actor based on the state of other actors.
 --
 --	@return	Table
 --		Associative array of actor states that have been set by this call. Keys
 --		are the actors names, values are the corresponding states.
 --
function ActorStateAction:exec(stateByActorName)
	stateByActorName = stateByActorName or {}

	-- debug action processing
	if #self.targets > 1 then
		printf("Processing state for actor group '%s'...", self.params.Group)
	else
		local target = self.targets[1]
		printf("Processing state for single actor '%s'...", actor.GetName(target))
	end

	-- debug params
	local out = "  Params: "
	for k,v in pairs(self.params) do out = out..k..'='..v..', ' end
	out = out:sub(1, -3) -- remove trailing coma and space
	print(out)

	if self.params.EnableProb then
		return _enableProb(targets, self.params.EnableProb)
	elseif self.params.EnableNum then
		return _enableNum(targets, self.params.EnableNum)
	elseif self.params.EnableMin or self.params.EnableMax then
		return _enableRndNum(self.targets, self.params.EnableMin, self.params.EnableMax)
	elseif self.params.EnableWith then
		return _enableWith(targets, self.params.EnableWith)
	elseif self.params.DisableWith then
		return _disableWith(targets, self.params.DisableWith)

	-- no param to trigger an action
	else 
		for _, target in pairs(self.targets) do
			printf("  Actor '%s': no action taken", actor.GetName(target))
		end
		return {}
	end
end

return ActorStateAction
