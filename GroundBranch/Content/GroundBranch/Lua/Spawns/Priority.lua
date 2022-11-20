local Tables = require('Common.Tables')
local SpawnPoint = require('Spawns.Point')

local Priority = {
    Spawns = {},
    Total = 0,
    Tags = {
        'AISpawn_1', 'AISpawn_2', 'AISpawn_3', 'AISpawn_4', 'AISpawn_5',
        'AISpawn_6_10', 'AISpawn_11_20', 'AISpawn_21_30', 'AISpawn_31_40',
        'AISpawn_41_50'
    },
    Selected = {}
}

Priority.__index = Priority

---Creates new Priority spawns object.
---@return table Priority Newly created Priority spawns object.
---@param eliminationCallback table A callback object to call after the AI has been killed (optional).
function Priority:Create(eliminationCallback)
    local self = setmetatable({}, Priority)
    self.eliminationCallback = eliminationCallback or nil
	self.Spawns = {}
    self.Total = 0
	self.Tags = Priority.Tags
	self.Selected = {}
	local priorityIndex = 1
	for _, priorityTag in ipairs(self.Tags) do
		local spawnsWithTag = SpawnPoint.CreateMultiple(gameplaystatics.GetAllActorsOfClassWithTag(
			'GroundBranch.GBAISpawnPoint',
			priorityTag
		))
		if #spawnsWithTag > 0 then
			self.Spawns[priorityIndex] = spawnsWithTag
			self.Total = self.Total + #spawnsWithTag
			priorityIndex = priorityIndex + 1
		end
	end
	print('Found ' .. self.Total .. ' spawns by priority')
	print('Initialized PrioritySpawns ' .. tostring(self))
    return self
end

---Shuffles priority grouped spawns. Ensures spawns of higher priority will be
---selected before lower priority.
function Priority:SelectSpawnPoints()
    local tableWithShuffledSpawns = Tables.ShuffleTables(
		self.Spawns
	)
	self.Selected = Tables.GetTableFromTables(
		tableWithShuffledSpawns
	)
end

---Schedules AI spawning in the selected spawn points.
---@param delay number The time after which spawning shall start.
---@param freezeTime number the time for which the ai should be frozen.
---@param count integer The amount of the AI to spawn.
---@param preSpawnCallback table A callback object to call immediately before the first AI is spawned (optional).
---@param postSpawnCallback table A callback object to call after spawning is complete (optional).
---@param isBlocking boolean If set to true, the next queue item will only be processed after all AI have been spawned (optional, default = false).
---@param prio number Higher prios will spawn before (optional, default = 255).
function Priority:Spawn(delay, freezeTime, count, preSpawnCallback, postSpawnCallback, isBlocking, prio)
    if count > #self.Selected then
        count = #self.Selected
    end
	gamemode.script.AgentsManager:SpawnAI(delay, freezeTime, count, self.Selected, self.eliminationCallback, preSpawnCallback, postSpawnCallback, isBlocking, prio)
end

return Priority
