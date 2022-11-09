--
-- ActorStateAction "class"
--

local Tables = require('Common.Tables')
require("dev.functions")

local ActorStateAction = {}

--[[ Instantiate an ActorStateAction statically
	
	@param	object	Table
		Will be passed "as is" to the ActorStateAction:new() method.
	
	@return	Table
		An ActorStateAction	instance
	--]]
function ActorStateAction.create(object)
	return ActorStateAction:new(object)
end

--[[ Instantiate an ActorStateAction
	
	@param	object	Table
		Will be used as a metatable for the returned instance.
		If object contains a 'targets' (plural) property, the corresponding
		values will be used as the target list.
		If object contains a 'params' property, the corresponding value will be
		used as the parameter list.
		If object contains a 'target' (singular) property, the corresponding
		value will be added to the instance targets.

	@return	Table
		An ActorStateAction	instance
	--]]
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

--[[ Add a target to an ActorStateAction instance
	
	@param	anActor	UserData
		An Actor as returned by the GB API
	--]]
function ActorStateAction:addTarget(anActor)
	table.insert(self.targets, anActor)
end

--[[ Add parameters to an ActorStateAction instance
	
	@param	params	Table
		Associative array of parameters for the ActorStateAction, keys are the
		parameters names, values are the corresponding values.
	--]]
function ActorStateAction:addParams(params)
	-- merge tables, 1 dimension, last override first
	for k,v in pairs(params) do self.params[k] = v end
end

--[[ Execute the ActorStateAction instance

	Enable or disable the target actors based on the parameters of the instance.
	
	@param	stateByActorName	Table	(optional, defaults to empty table)
		Associative array of actor states. Keys are the actors names, values are
		the corresponding states. Used when we need to decide the state of an
		actor based on the state of other actors.

	@return	Table
		Associative array of actor states that have been set by this call. Keys
		are the actors names, values are the corresponding states.
	--]]
function ActorStateAction:exec(stateByActorName)

	stateByActorName = stateByActorName or {}

	-- debug action processing
	if #self.targets > 1 then
		print(string.format("Processing state for actor group '%s'...", self.params.Group))
	else
		local target = self.targets[1]
		print(string.format("Processing state for single actor '%s'...", actor.GetName(target)))
	end

	-- debug params
	local out = "  Params: "
	for k,v in pairs(self.params) do out = out..k..'='..v..', ' end
	out = out:sub(1, -3) -- remove trailing coma and space
	print(out)

	-- enable/disable the actor(s) based on a given probability in percent
	if self.params.EnableProb then
		local isHidden = self.params.EnableProb < math.random(0, 100)
		local doCollide = not isHidden

		local result = {}
		for _, target in pairs(self.targets) do
			local actorName = actor.GetName(target)
			printf("  Actor '%s': Visible=%s, Collide=%s",
				actorName, not isHidden, doCollide)

			actor.SetHidden(target, isHidden)
			actor.SetEnableCollision(target, doCollide)
			result[actorName] = doCollide
		end
		return result

	-- enable a specified number of actors in the group
	elseif self.params.EnableNum then
		
		local result = {}
		for index, target in ipairs(Tables.ShuffleTable(self.targets)) do
			local actorName = actor.GetName(target)
			local isHidden = index > self.params.EnableNum
			local doCollide = not isHidden

			printf("  Actor '%s': Visible=%s, Collide=%s",
				actorName, not isHidden, doCollide)

			actor.SetHidden(target, isHidden)
			actor.SetEnableCollision(target, doCollide)
			result[actorName] = doCollide
		end
		return result

	-- enable a random number of actors in the group constrained by a maximum
	-- and minimum
	elseif self.params.EnableMin or self.params.EnableMax then
		local enableMin = 0
		local enableMax = #self.targets

		if self.params.EnableMin then
			enableMin = math.min(math.max(
				self.params.EnableMin, enableMin), enableMax)
		end
		if self.params.EnableMax then
			enableMax = math.min(self.params.EnableMax, enableMax)
		end
		printf("  Adjusted params: EnableMin=%s, EnableMax=%s",
			enableMin, enableMax)

		local enableNum = math.random(enableMin, enableMax)
		printf("  Random EnableNum value: %s",enableNum)

		local result = {}
		for index, target in ipairs(Tables.ShuffleTable(self.targets)) do
			local actorName = actor.GetName(target)
			local isHidden = index > enableNum
			local doCollide = not isHidden

			printf("  Actor '%s': Visible=%s, Collide=%s",
				actorName, not isHidden, doCollide)

			actor.SetHidden(target, isHidden)
			actor.SetEnableCollision(target, doCollide)
			actor.SetActive(target, not isHidden)
			result[actorName] = doCollide
		end
		return result

	-- enable/disable the actor(s) based on the state of another actor
	elseif self.params.EnableWith then
		local result = {}
		for _, target in pairs(self.targets) do
			local actorName = actor.GetName(target)
			
			local linkedActorName
			if self.params.EnableWith:sub(-1) == '_' then
				local suffix = actorName:sub(actorName:find("_[^_]*$") + 1)
				linkedActorName = table.concat({ self.params.EnableWith, suffix })

				printf("  Computed EnableWith value: '%s'", linkedActorName)
			else
				linkedActorName = self.params.EnableWith
			end

			local linkedActorEnable = toboolean(stateByActorName[linkedActorName])
			local isHidden = not linkedActorEnable
			local doCollide = linkedActorEnable

			printf("  Actor '%s': Visible=%s, Collide=%s",
				actorName, not isHidden, doCollide)
			
			actor.SetHidden(target, isHidden)
			actor.SetEnableCollision(target, doCollide)
			result[actorName] = doCollide
		end
		return result
	
	-- enable/disable the actor(s) based on the state of another actor
	elseif self.params.DisableWith then
		local result = {}
		for _, target in pairs(self.targets) do
			local actorName = actor.GetName(target)
			
			local linkedActorName
			if self.params.DisableWith:sub(-1) == '_' then
				local suffix = actorName:sub(actorName:find("_[^_]*$") + 1)
				linkedActorName = table.concat({ self.params.DisableWith, suffix })

				printf("  Computed DisableWith value: '%s'", linkedActorName)
			else
				linkedActorName = self.params.DisableWith
			end

			local linkedActorEnable = toboolean(stateByActorName[linkedActorName])
			local isHidden = linkedActorEnable
			local doCollide = not linkedActorEnable

			printf("  Actor '%s': Visible=%s, Collide=%s",
				actorName, not isHidden, doCollide)
			
			actor.SetHidden(target, isHidden)
			actor.SetEnableCollision(target, doCollide)
			result[actorName] = doCollide
		end

	-- no param to trigger an action
	else 
		for _, target in pairs(self.targets) do
			printf("  Actor '%s': no action taken",
				actor.GetName(target))
		end
		return {}
	end
end

return ActorStateAction
