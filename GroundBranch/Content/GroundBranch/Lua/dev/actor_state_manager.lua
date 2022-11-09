--
-- ActorStateManager "class"
--
-- Used to set the state of actors based on "action parameters" provided using
-- tags on the actors. Action parameters are parsed from actors having a special
-- "flag tag" set, the default flag tag is "ActorState".
--
-- Supported "action parameters":
--
--	Group <groupName>
--		Actors with the same group name will be processed at the same time,
--		their parameters are merged together.
--
-- 	EnableProb <number>
--		Enable actor(s) based on a given probability in percent. 100 means 100%
-- 		probability, 1 means 1% probability.
--
-- 	EnableNum <number>
--		Enable a specified number of actors in a group.
--
-- 	EnableMin <number> and/or EnableMax <number>
--		Enable a random number of actors in a group, constrained by either a
--		minimum or a maximum, or both.
--
-- 	EnableWith <actorName>
--		enable actor(s) based on the state of another actor.
--

local Tables = require('Common.Tables')
local ActorStateAction = require("dev.actor_state_action")
local log = require('dev.actor_state_logger')

require("dev.functions")

local function validateInt(value, min, max)
	intValue = tonumber(value)

	if intValue == nil then return nil end
	if min ~= nil and intValue < min then return nil end
	if max ~= nil and intValue > max then return nil end
	
	return intValue
end

local function parseTag(tag)
	local finalParamValue
	local _, _, paramName, paramValue = string.find(tag, "(%a+)%s*=%s*(.+)")
	
	-- soft fail on empty name or value
	if paramName == nil or paramName == '' then return nil end
	if paramValue == nil or paramValue == '' then return nil end
	
	-- check value is valid for known parameters

	if paramName == 'Group' then
		finalParamValue = paramValue

	elseif paramName == 'EnableWith' then
		finalParamValue = paramValue

	elseif paramName == 'DisableWith' then
		finalParamValue = paramValue

	elseif paramName == 'EnableProb' then
		finalParamValue = validateInt(paramValue, 0, 100)
		if finalParamValue == nil then
			error(string.format(
				"Invalid parameter value for <%s>: number between 0 to 100 expected, got '%s'",
				paramName, paramValue
			))
		end

	elseif paramName == 'EnableNum' then
		finalParamValue = validateInt(paramValue, 0)
		if finalParamValue == nil then
			error(string.format(
				"Invalid parameter value for <%s>: number greater than or equal to 0 expected, got '%s'",
				paramName, paramValue
			))
		end

	elseif paramName == 'EnableMin' then
		finalParamValue = validateInt(paramValue, 0)
		if finalParamValue == nil then
			error(string.format(
				"Invalid parameter value for <%s>: number greater than or equal to 0 expected, got '%s'",
				paramName, paramValue
			))
		end
	
	elseif paramName == 'EnableMax' then
		finalParamValue = validateInt(paramValue, 0)
		if finalParamValue == nil then
			error(string.format(
				"Invalid parameter value for <%s>: number greater than or equal 0 expected, got '%s'",
				paramName, paramValue
			))
		end
	else
		error(string.format("Unknown parameter name <%s>", paramName, paramValue))
	end

	return {
		name = paramName,
		value = finalParamValue,
	}
end

local function parseTags(tags)
	local params = {}
	for _, tag in ipairs(tags) do
		local param = parseTag(tag)
		if param ~= nil then			
			params[param.name] = param.value
		end
	end
	return params
end

local function debugParams(params)
	out = {}
	for paramName, paramValue in pairs(params) do
		table.insert(out, string.format('%s=%s', paramName, paramValue))
	end
	return table.concat(out, ', ')
end

local function extractParams(anActor)
	log:Debug(sprintf("Parsing parameters for actor '%s'...",
		actor.GetName(anActor)))

	local success, result = pcall(function()
		-- returns for the inline function, not extractParams
		return parseTags(actor.GetTags(anActor))
	end)
	
	if not success then
		local error = result
		log:Error(sprintf("Parameter parsing failed for actor '%s': %s",
			actor.GetName(anActor), error))
		return {}
	end
	
	local params = result
	
	log:Debug(sprintf("  Found %s parameter(s): %s",
		Tables.count(params), debugParams(params)))
	return params
end

local ActorStateManager = {
	flagTag = 'ActorState'
}

function ActorStateManager:Create()
	self.__index = self
	local self = setmetatable({}, self)

	log:Info(sprintf("Gathering actors with tag '%s'...", self.flagTag))
	local actors = gameplaystatics.GetAllActorsWithTag(self.flagTag)
	log:Info(sprintf("  Found %s actor(s)", #actors))

	-- extract params and store them along their corresponding actor
	-- to create a table accepted by ActorStateAction:new()
	local actionArgsList = Tables.map(actors, function(anActor)
		return {
			target = anActor,
			params = extractParams(anActor)
		}
	end)

	log:Info("Creating action list...")

	-- filter out items with empty params
	actionArgsList = Tables.filter(actionArgsList, function(tbl)
		return Tables.notEmpty(tbl.params)
	end)
	
	-- functions used below
	local hasGroupParam = function(tbl)
		return tbl.params.Group ~= nil
	end
	local groupActionArgs = function(action, result)
		local groupName = action.params.Group
		if result[groupName] == nil then
			result[groupName] = {}
		end
		table.insert(result[groupName], action)
		return result
	end
	local mergeGroupedActionArgsList = function(actionArgsList)
		-- make a list of targets
		local targets = Tables.map(actionArgsList, function(actionArgs)
			return actionArgs.target
		end)
		-- make a list of params and merge them all
		local params = Tables.map(actionArgsList, function(actionArgs)
			return actionArgs.params
		end)
		params = Tables.naiveMergeAssocTables(table.unpack(params))

		return { targets = targets, params = params }
	end

	-- extract actions on single actor (no group)
	local loneActionArgsList = Tables.filterNot(actionArgsList, hasGroupParam)

	-- extract actions with a group parameter, group and merge them
	local actionArgsToGroup = Tables.filter(actionArgsList, hasGroupParam)
	local groupedActionArgs = Tables.reduce(actionArgsToGroup, groupActionArgs, {})
	local groupActionArgsList = Tables.map(groupedActionArgs, mergeGroupedActionArgsList)

	-- concat both ActionArgsList
	local actorStateActionArgList = Tables.ConcatenateTables(
		loneActionArgsList,
		groupActionArgsList
	)

	-- create list of ActorStateAction
	self.actions = Tables.map(actorStateActionArgList, ActorStateAction.create)
	
	log:Info(sprintf("Created %s action(s)",  #self.actions))

	return self
end

function ActorStateManager:SetState()
	-- delay actions having the "With" param since they depend on result of
	-- other actions
	local previousActionsResults = {}
	local delayedActions = {}

	for _, action in pairs(self.actions) do
		if 
			action.params.EnableWith ~= nil or
			action.params.DisableWith ~= nil
		then
			table.insert(delayedActions, action)
		else
			-- state is true for enabled (visible and collide)
			local actionResult = action:exec(previousActionsResults)
			previousActionsResults = Tables.naiveMergeAssocTables(
				previousActionsResults,
				actionResult
			)
		end
	end

	for _, action in pairs(delayedActions) do
		action:exec(previousActionsResults)
	end
end

return ActorStateManager
