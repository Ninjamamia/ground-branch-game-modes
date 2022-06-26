local Tables = require('Common.Tables')
local Actors = require('Common.Actors')
local AdminTools = require('AdminTools')

local AmbushManager = {
    SpawnQueue = nil,
    TeamTag = nil,
    Triggers = {},
    MandatoryTriggerKeys = {},
    OptionalTriggerKeys = {}
}

AmbushManager.__index = AmbushManager

---Creates a new ambush manager object. At creation all relevant spawn points are
---gathered, default values are set.
---@return table AmbushManager Newly created AmbushManager object.
function AmbushManager:Create(spawnQueue, teamTag)
    local self = setmetatable({}, AmbushManager)
    -- Setting attributes
    self.SpawnQueue = spawnQueue
    self.TeamTag = teamTag
    self.Triggers = {}
    self.MandatoryTriggerKeys = {}
    self.OptionalTriggerKeys = {}
    print('Gathering ambush triggers...')
    Triggers = gameplaystatics.GetAllActorsOfClassWithTag('GroundBranch.GBGameTrigger', 'Ambush')
    for _, Trigger in ipairs(Triggers) do
        local Name = actor.GetName(Trigger)
        for _, Tag in ipairs(actor.GetTags(Trigger)) do
            if Tag ~= 'Ambush' and Tag ~= 'MissionActor' and Tag ~= 'Mandatory' then
                self.Triggers[Name] = {
                    Name = Name,
                    Tag = Tag,
                    Actor = Trigger,
                    State = 'Inactive',
                    Spawns = gameplaystatics.GetAllActorsOfClassWithTag(
                        'GroundBranch.GBAISpawnPoint',
                        Tag
                    )
                }
                if actor.HasTag(Trigger, 'Mandatory') then
                    print('Mandatory ambush trigger ' .. Tag .. ' found, has ' .. #self.Triggers[Name].Spawns .. ' associated AI spawns')
                    table.insert(self.MandatoryTriggerKeys, Name)
                else
                    print('Optional ambush trigger ' .. Tag .. ' found, has ' .. #self.Triggers[Name].Spawns .. ' associated AI spawns')
                    table.insert(self.OptionalTriggerKeys, Name)
                end
                break
            end
        end
    end
    print('Found a total of ' .. #self.MandatoryTriggerKeys .. ' mandatory and ' .. #self.OptionalTriggerKeys .. ' optional ambush triggers.')
    return self
end

function AmbushManager:ActivateTrigger(Trigger)
    print('Activating ambush trigger ' .. Trigger.Name .. '...')
    Trigger.State = 'Active'
    actor.SetActive(Trigger.Actor, true)
end

function AmbushManager:DeactivateTrigger(Trigger)
    print('Deactivating ambush trigger ' .. Trigger.Name .. '...')
    Trigger.State = 'Inactive'
    actor.SetActive(Trigger.Actor, false)
end

function AmbushManager:ActivateAll()
    print('Activating all ambush triggers...')
    for _, Trigger in pairs(self.Triggers) do
        self:ActivateTrigger(Trigger)
    end
end

function AmbushManager:DeactivateAll()
    print('Deactivating all ambush triggers...')
    for _, Trigger in pairs(self.Triggers) do
        self:DeactivateTrigger(Trigger)
    end
end

function AmbushManager:ActivateRandomly(percentage)
    self:DeactivateAll()
    print('Activating all mandatory ambush triggers (' .. #self.MandatoryTriggerKeys .. ')...')
    for i, Key in ipairs(self.MandatoryTriggerKeys) do
        local Trigger = self.Triggers[Key]
        self:ActivateTrigger(Trigger)
    end
    percentage = percentage or 100
    local count = math.min(math.floor((#self.OptionalTriggerKeys * percentage) / 100), #self.OptionalTriggerKeys)
    print('Activating ' .. percentage .. '% of optional ambush triggers (' .. count .. ')...')
    for i, Key in ipairs(Tables.ShuffleTable(self.OptionalTriggerKeys)) do
        if i > count then
            break
        end
        local Trigger = self.Triggers[Key]
        self:ActivateTrigger(Trigger)
    end
end

function AmbushManager:OnGameTriggerBeginOverlap(GameTrigger, Player)
    local Trigger = self.Triggers[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        if Trigger.State == 'Active' then
            Trigger.State = 'Triggered'
            actor.SetActive(Trigger.Actor, false)
            local tiAmbush = math.random(0, 150) * 0.1
            local sizeAmbush = math.min(math.random(0, 10), #Trigger.Spawns)
            AdminTools:ShowDebug("Ambush " .. Trigger.Tag .. " triggered, spawning " .. sizeAmbush .. " AI in " .. tiAmbush .. "s")
            if sizeAmbush > 0 then
                self.SpawnQueue:Enqueue(tiAmbush, 0.1, sizeAmbush, Tables.ShuffleTable(Trigger.Spawns), self.TeamTag, nil, nil, nil, nil, true)
            end
        end
    end
end

return AmbushManager
