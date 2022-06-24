local Tables = require('Common.Tables')
local Actors = require('Common.Actors')
local AdminTools = require('AdminTools')

local AmbushManager = {
    SpawnQueue = nil,
    TeamTag = nil,
    Triggers = {},
    TriggerKeys = {}
}

AmbushManager.__index = AmbushManager

---Creates a new ambush manager object. At creation all relevant spawn points are
---gathered, default values are set.
---@return table AmbushManager Newly create AmbushManager object.
function AmbushManager:Create(spawnQueue, teamTag)
    local self = setmetatable({}, AmbushManager)
    -- Setting attributes
    self.SpawnQueue = spawnQueue
    self.TeamTag = teamTag
    print('Gathering ambush triggers...')
    Triggers = gameplaystatics.GetAllActorsOfClassWithTag('GroundBranch.GBGameTrigger', 'Ambush')
    for _, Trigger in ipairs(Triggers) do
        local Name = actor.GetName(Trigger)
        for _, Tag in ipairs(actor.GetTags(Trigger)) do
            if Tag ~= 'Ambush' and Tag ~= 'MissionActor' then
                self.Triggers[Name] = {
                    Name = Name,
                    Tag = Tag,
                    Actor = Trigger,
                    IsActive = false,
                    IsTriggered = false,
                    Spawns = gameplaystatics.GetAllActorsOfClassWithTag(
                        'GroundBranch.GBAISpawnPoint',
                        Tag
                    )
                }
                table.insert(self.TriggerKeys, Name)
                print('Ambush trigger ' .. Tag .. ' found, has ' .. #self.Triggers[Name].Spawns .. ' associated AI spawns')
                break
            end
        end
    end
    return self
end

function AmbushManager:ActivateTrigger(Trigger)
    print('Activating ambush trigger ' .. Trigger.Name .. ' ...')
    Trigger.IsActive = true
    Trigger.IsTriggered = false
    actor.SetActive(Trigger.Actor, true)
end

function AmbushManager:ActivateAll()
    print('Activating all ambush triggers ...')
    for _, Trigger in pairs(self.Triggers) do
        self:ActivateTrigger(Trigger)
    end
end

function AmbushManager:ActivateRandomly(percentage)
    percentage = percentage or 100
    local count = math.min(math.floor((#self.TriggerKeys * percentage) / 100), #self.TriggerKeys)
    print('Activating ' .. percentage .. '% of ambush triggers (' .. count .. ') ...')
    for i, Key in ipairs(Tables.ShuffleTable(self.TriggerKeys)) do
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
        if not Trigger.IsTriggered then
            Trigger.IsTriggered = true
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
