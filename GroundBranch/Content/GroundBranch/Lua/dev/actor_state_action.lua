--
-- ActorStateAction "class"
--
-- @todo implement complementary local functions _disableProb(), _disableNum()
-- and _disableRndNum(), link them with correct params in ActorStateAction:exec()
--

local Tables = require('Common.Tables')
local log = require('dev.actor_state_logger')
require("dev.functions")

local ActorStateAction = {}

-- Set visibility and or collision of a target actor from the object arg
local function setActorState(target, object)
	local out = {}
	if object.visible ~= nil then
		actor.SetHidden(target, not object.visible)
		table.insert(out, sprintf("visible=%s", object.visible))
	end
	if object.collide ~= nil then
		actor.SetEnableCollision(target, object.collide)
		table.insert(out, sprintf("collide=%s", object.collide))
	end
	local actorStateStr
	if Tables.notEmpty(out) then
		actorStateStr = table.concat(out, ', ') else
		actorStateStr = '(no change)' end

	log:Debug(sprintf("  Actor '%s' new state:", actor.GetName(target)))
	log:Debug(sprintf("  %s", actorStateStr))
end

-- Set visibility and collision of a target actor based on the shouldEnable arg
local function setActorEnabled(target, shouldEnable)
	setActorState(target, {
		visible = shouldEnable,
		collide = shouldEnable,
	})
end

-- Enable the target actors based on a given probability in percent
local function _enableProb(targets, enableProb)
	local shouldEnable = math.random(100) <= enableProb
	local result = {}
	for _, target in pairs(targets) do			
		setActorEnabled(target, shouldEnable)
		result[actor.GetName(target)] = shouldEnable
	end
	return result
end

-- Enable a specified number of target actors in the group
local function _enableNum(targets, enableNum)
	local result = {}
	for index, target in ipairs(Tables.ShuffleTable(targets)) do
		local shouldEnable = index <= enableNum
		setActorEnabled(target, shouldEnable)
		result[actor.GetName(target)] = shouldEnable
	end
	return result
end

-- Enable a random number of target actors in the group constrained by a max and min
local function _enableRndNum(targets, enableMin, enableMax)
	local targetCount = #targets

	enableMin = default(enableMin, 0)
	enableMax = default(enableMax, targetCount)

	-- force enableMin between 0 and targetCount
	enableMin = math.max(0, math.min(enableMin, targetCount))
	-- force enableMax between enableMin and targetCount
	enableMax = math.max(enableMin, math.min(enableMax, targetCount))
	
	-- pick a random number of targets to enable
	local enableNum = math.random(enableMin, enableMax)
	
	-- debug
	log:Debug(sprintf("  Adjusted params: EnableMin=%s, EnableMax=%s",
		enableMin, enableMax))
	log:Debug(sprintf("  Random EnableNum value: %s", enableNum))

	return _enableNum(targets, enableNum)
end

-- Enable the target actors by copying state of another actor, possibly inverted
local function _copyStateFrom(targets, stateByActorName, linkedActorName, inverse)
	local result = {}
	
	-- special case to when the linkedActorName ends with _, we  use the actor's
	-- name suffix to complete linkedActorName
	local shouldCompleteLinkedActorName = linkedActorName:sub(-1) == '_'
		
	for _, target in pairs(targets) do
	 	
	 	if shouldCompleteLinkedActorName then
			local actorName = actor.GetName(target)
			local suffix = actorName:sub(actorName:find("_[^_]*$") + 1)
			linkedActorName = linkedActorName .. suffix
			log:Debug(sprintf("  Computed linkedActorName value: '%s'",
				linkedActorName))
		end

		local linkedActorEnabled = toboolean(stateByActorName[linkedActorName])
		local shouldEnable = inverse ~= linkedActorEnabled

		setActorEnabled(target, shouldEnable)
		result[actor.GetName(target)] = shouldEnable
	end
	return result
end

-- Enable the target actors when another actor is enabled
local function _enableWith(targets, stateByActorName, linkedActorName)
	return _copyStateFrom(targets, stateByActorName, linkedActorName, false)
end

-- Disable the target actors when another actor is enabled
local function _disableWith(targets, stateByActorName, linkedActorName)
	return _copyStateFrom(targets, stateByActorName, linkedActorName, true)
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
		log:Info(sprintf("Processing actor group '%s'...", self.params.Group))
	else
		local target = self.targets[1]
		log:Info(sprintf("Processing single actor '%s'...",
			actor.GetName(target)))
	end

	-- debug params
	local out = "  Action params: "
	for k,v in pairs(self.params) do out = out..k..'='..v..', ' end
	out = out:sub(1, -3) -- remove trailing coma and space
	log:Debug(out)

	-- call the correct specialized function based on the parameters
	if self.params.EnableProb then
		return _enableProb(self.targets, self.params.EnableProb)
	elseif self.params.EnableNum then
		return _enableNum(self.targets, self.params.EnableNum)
	elseif self.params.EnableMin or self.params.EnableMax then
		return _enableRndNum(self.targets, self.params.EnableMin, self.params.EnableMax)
	elseif self.params.EnableWith then
		return _enableWith(self.targets, stateByActorName, self.params.EnableWith)
	elseif self.params.DisableWith then
		return _disableWith(self.targets, stateByActorName, self.params.DisableWith)
	end

	-- omitted else case since all previous cases return

	-- no parameter matches our selection, do nothing
	for _, target in pairs(self.targets) do
		log:Debug(sprintf( "  Actor '%s': no action taken",
			actor.GetName(target)))
	end
	
	return {}
end

return ActorStateAction
