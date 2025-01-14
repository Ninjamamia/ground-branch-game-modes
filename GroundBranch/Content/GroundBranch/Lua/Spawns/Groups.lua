local Tables = require('Common.Tables')
local Actors = require('Common.Actors')
local SpawnPoint = require('Spawns.Point')

local Groups = {
    Spawns = {},
    Total = 0,
    SelectedSpawnPoints = {},
    ReserveSpawnPoints = {},
    RemainingGroups = {},
    GroupTagPrefix = 'Group'
}

Groups.__index = Groups

---Creates a new group spawns object. At creation all relevant spawn points are
---gathered, default values are set.
---@param groupTagPrefix string The tag prefix assigned to group spawn points.
---@return table Groups Newly create Groups object.
---@param eliminationCallback table A callback object to call after the AI has been killed (optional).
function Groups:Create(groupTagPrefix, eliminationCallback)
    local self = setmetatable({}, Groups)
    -- Setting attributes
    self.GroupTagPrefix = groupTagPrefix or 'Group'
    self.eliminationCallback = eliminationCallback or nil
    -- Gathering all relevant spawn points
    print('Gathering group spawn points (Prefix: ' .. self.GroupTagPrefix .. ')')
    self.Spawns = {}
    self.Total = 0
	local groupIndex = 1
	for i = 1, 32, 1 do
		local groupTag = self.GroupTagPrefix .. tostring(i)
		local spawnsWithGroupTag = SpawnPoint.CreateMultiple(gameplaystatics.GetAllActorsOfClassWithTag(
			'GroundBranch.GBAISpawnPoint',
			groupTag
		))
		if #spawnsWithGroupTag > 0 then
			self.Spawns[groupIndex] = spawnsWithGroupTag
			self.Total = self.Total + #spawnsWithGroupTag
			groupIndex = groupIndex + 1
		end
	end
	print('Found ' .. #self.Spawns .. ' groups. Total spawn count ' .. self.Total)
    -- Setting default values
    self.RemainingGroups = {table.unpack(self.Spawns)}
    self.ReserveSpawnPoints = {}
    self.SelectedSpawnPoints = {}
    print('Initialized Spawns Groups ' .. tostring(self))
    return self
end

---Adds spawn points from a random group within the given maxDistance from provided
---location found in RemainingGroups table to the SelectedSpawnPoints table.
---Spawns that excceed the aiPerGroupAmount will be added to ReserveSpawnPoints table.
---@param aiPerGroupAmount integer Amount of spawn points to be added from the group.
---@param location table vector {x,y,z} The origin point for distance calculation.
---@param maxDistance number The maximum distance from location to a selected group.
---@return  integer Amount of spawn points actually added.
function Groups:AddSpawnsFromRandomGroupWithinDistance(
    aiPerGroupAmount,
    location,
    maxDistance
)
    print(
        'Searching for a group within ' .. maxDistance ..
        ' from location ' .. tostring(location) .. ' (Prefix: ' .. self.GroupTagPrefix .. ')'
    )
    local maxDistanceSq = maxDistance ^ 2
    local groupsToConsider = {}
    for groupIndex, group in ipairs(self.RemainingGroups) do
        local shortestDistanceSq = Actors.GetShortestDistanceSqWithinGroup(
            location,
            group
        )
        if shortestDistanceSq < maxDistanceSq then
            local groupName = Actors.GetSuffixFromActorTag(
                self.RemainingGroups[groupIndex][1],
                self.GroupTagPrefix
            )
            print(
                'Found group ' .. groupName ..
                ' with member at distance squared ' .. shortestDistanceSq
            )
            table.insert(groupsToConsider, groupIndex)
        end
    end

    if #groupsToConsider <=0 then
        print('No groups within distance found')
        return 0
    end

    local selectedGroupIndex = groupsToConsider[math.random(#groupsToConsider)]
    return self:AddSpawnsFromGroup(
        aiPerGroupAmount,
        selectedGroupIndex
    )
end

---Adds spawn points from a group closest to the given location found in RemainingGroups
---table to the SelectedSpawnPoints table.
---Spawns that excceed the aiPerGroupAmount will be added to ReserveSpawnPoints table.
---@param aiPerGroupAmount integer Amount of spawn points to be added from the group.
---@param location table vector {x,y,z} The origin point for distance calculation.
---@return  integer Amount of spawn points actually added.
function Groups:AddSpawnsFromClosestGroup(aiPerGroupAmount, location)
    print('Searching for group closest to '.. tostring(location) .. ' (Prefix: ' .. self.GroupTagPrefix .. ')')
    local selectedGroupIndex = 0
    local lowestDistanceSq = -1
    for groupIndex, group in ipairs(self.RemainingGroups) do
        local distanceSq = Actors.GetShortestDistanceSqWithinGroup(
            location,
            group
        )
        if
            lowestDistanceSq < 0 or
            distanceSq < lowestDistanceSq
        then
            local groupName = Actors.GetSuffixFromActorTag(
                self.RemainingGroups[groupIndex][1],
                self.GroupTagPrefix
            )
            print(
                'Found new closest group ' .. groupName ..
                ' at distance ' .. distanceSq
            )
            lowestDistanceSq = distanceSq
            selectedGroupIndex = groupIndex
        end
    end

    if selectedGroupIndex == 0 then
        print('No groups within max distance found')
        return 0
    end

    return self:AddSpawnsFromGroup(
        aiPerGroupAmount,
        selectedGroupIndex
    )
end

---Adds spawn points from a random group found in RemainingGroups table to the
---SelectedSpawnPoints table.
---Spawns that excceed the aiPerGroupAmount will be added to ReserveSpawnPoints table.
---@param aiPerGroupAmount integer Amount of spawn points to be added from the group.
---@return  integer Amount of spawn points to actually added.
function Groups:AddSpawnsFromRandomGroup(aiPerGroupAmount)
    print('Adding spawn points from randomly selected group' .. ' (Prefix: ' .. self.GroupTagPrefix .. ')')
    if #self.RemainingGroups <=0 then
        print('No groups left')
        return 0
    end
    local selectedGroupIndex = math.random(#self.RemainingGroups)
    return self:AddSpawnsFromGroup(
        aiPerGroupAmount,
        selectedGroupIndex
    )
end

---Adds spawn points from ReserveSpawnPoints table to SelectedSpawnPoints table
---in random order. Basically this will fill up already selected groups.
function Groups:AddRandomSpawnsFromReserve()
    print('Adding random spawns from reserve' .. ' (Prefix: ' .. self.GroupTagPrefix .. ')')
    while #self.ReserveSpawnPoints > 0 do
        local randIndex = math.random(#self.ReserveSpawnPoints)
        table.insert(self.SelectedSpawnPoints, self.ReserveSpawnPoints[randIndex])
        table.remove(self.ReserveSpawnPoints, randIndex)
    end
end

---Adds shuffled spawn points from RemainingGroups groups tables to SelectedSpawnPoints
---table. Note that calling this function will empty RemainingGroups table, so it
---should be called last - after all other spawn points are added.
function Groups:AddRandomSpawns()
    if #self.RemainingGroups > 0 then
        print('Adding random spawns' .. ' (Prefix: ' .. self.GroupTagPrefix .. ')')
        local randomSpawns = Tables.GetTableFromTables(
            self.RemainingGroups
        )
        self.RemainingGroups = {}
        randomSpawns = Tables.ShuffleTable(randomSpawns)
        self.SelectedSpawnPoints = Tables.ConcatenateTables(
            self.SelectedSpawnPoints,
            randomSpawns
        )
    end
end

---Helper function that adds spawns from a group with selectedGroupIndex in the
---remainingGroups table to selectedSpawns table. Spawns that exceed the
---aiPerGroupAmount will be added to the reserveSpawns table.
---@param aiPerGroupAmount integer Amount of spawn points to be added from the group.
---@param selectedGroupIndex integer Index of group from which spawn points will be added.
---@return integer Number of spawns actually added.
function Groups:AddSpawnsFromGroup(aiPerGroupAmount, selectedGroupIndex)
    local groupName = Actors.GetSuffixFromActorTag(
        self.RemainingGroups[selectedGroupIndex][1],
        self.GroupTagPrefix
    )
    print('Adding spawn points from group ' .. groupName .. ' (Prefix: ' .. self.GroupTagPrefix .. ')')
    local group = Tables.ShuffleTable(self.RemainingGroups[selectedGroupIndex])
    for j, member in ipairs(group) do
        if j <= aiPerGroupAmount then
            table.insert(self.SelectedSpawnPoints, member)
        else
            table.insert(self.ReserveSpawnPoints, member)
        end
    end
    print(
        'Added ' .. aiPerGroupAmount .. ' to Selected, and ' ..
        #self.RemainingGroups[selectedGroupIndex] - aiPerGroupAmount .. ' to Reserve'
    )
    table.remove(self.RemainingGroups, selectedGroupIndex)
    print('Removed group ' .. groupName .. ' from remaining groups')
    return math.min(aiPerGroupAmount, #group)
end

---Returns the total cound of all groups.
---@return integer totalGroupsCount
function Groups:GetTotalGroupsCount()
    return #self.Spawns
end

---Returns the total count of remaining groups.
---@return integer remainingGroupsCount
function Groups:GetRemainingGroupsCount()
    return #self.RemainingGroups
end

---Returns total count of groups spawn points.
---@return integer totalSpawnPointsCount
function Groups:GetTotalSpawnPointsCount()
    return self.Total
end

---Returns the total count of selected spawn points.
---@return integer selectedSpawnPointsCount
function Groups:GetSelectedSpawnPointsCount()
    return #self.SelectedSpawnPoints
end

---Returns a list of selected spawn points.
---@return table selectedSpawnPoints
function Groups:GetSelectedSpawnPoints()
    return {table.unpack(self.SelectedSpawnPoints)}
end

---Returns a list of selected spawns and resets RemainingGroups, ReserveSpawnPoints
---and SelectedSpawnPoints tables to default values. It is equal to calling
---GetSelectedSpawnPoints and ResetSpawnTables.
---@return table SelectedSpawns a list of selected spawn points.
function Groups:PopSelectedSpawnPoints()
    local selectedSpawns = self:GetSelectedSpawnPoints()
    self:ResetSpawnTables()
    return selectedSpawns
end

---Resets RemainingGroups, SelectedSpawnPoints and ReserveSpawnPoints tables to
---default values.
function Groups:ResetSpawnTables()
    print('Reseting group spawn tables')
    self.RemainingGroups = {table.unpack(self.Spawns)}
    self.ReserveSpawnPoints = {}
    self.SelectedSpawnPoints = {}
end

---Schedules AI spawning in the selected spawn points.
---@param delay number The time after which spawning shall start.
---@param freezeTime number the time for which the ai should be frozen.
---@param count integer The amount of the AI to spawn.
---@param preSpawnCallback table A callback object to call immediately before the first AI is spawned (optional).
---@param postSpawnCallback table A callback object to call after spawning is complete (optional).
---@param isBlocking boolean If set to true, the next queue item will only be processed after all AI have been spawned (optional, default = false).
---@param prio number Higher prios will spawn before (optional, default = 255).
function Groups:Spawn(delay, freezeTime, count, preSpawnCallback, postSpawnCallback, isBlocking, prio)
    if count > #self.SelectedSpawnPoints then
        count = #self.SelectedSpawnPoints
    end
	gamemode.script.AgentsManager:SpawnAI(delay, freezeTime, count, self:PopSelectedSpawnPoints(), self.eliminationCallback, preSpawnCallback, postSpawnCallback, isBlocking, prio)
end

--#endregion

return Groups
