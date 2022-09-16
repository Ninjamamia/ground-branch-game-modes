local Tables = require('Common.Tables')
local Actors = require('Common.Actors')
local AdminTools = require('AdminTools')

local AmbushManager = {
    SpawnQueue = nil,
    TeamTag = nil,
    Triggers = {}
}

AmbushManager.__index = AmbushManager

---Creates a new ambush manager object. At creation all relevant spawn points are
---gathered, default values are set.
---@return table AmbushManager Newly created AmbushManager object.
function AmbushManager:Create(spawnQueue, teamTag, gameMode)
    local self = setmetatable({}, AmbushManager)
    -- Setting attributes
    self.SpawnQueue = spawnQueue
    self.GameMode = gameMode
    self.TeamTag = teamTag
    self.Triggers = {}
    print('Gathering ambush triggers...')
    Triggers = gameplaystatics.GetAllActorsOfClassWithTag('GroundBranch.GBGameTrigger', 'Ambush')
    local count = 0
    for _, Trigger in ipairs(Triggers) do
        local Name = actor.GetName(Trigger)
        local CurrTrigg = {
            Name = Name,
            Tag = nil,
            Actor = Trigger,
            State = 'Inactive',
            Spawns = nil
        }
        print('Ambush trigger ' .. Name .. ' found.')
        for _, Tag in ipairs(actor.GetTags(Trigger)) do
            local key
            local value
            _, _, key, value = string.find(Tag, "(%a+)%s*=%s*(%w+)")
            if key ~= nil then
                print("  " .. Tag)
                if key == "Group" then
                    CurrTrigg.Tag = value
                    CurrTrigg.Spawns = gameplaystatics.GetAllActorsOfClassWithTag(
                        'GroundBranch.GBAISpawnPoint',
                        value
                    )
                else
                    CurrTrigg[key] = tonumber(value)
                end
            end
        end
        if CurrTrigg.Tag ~= nil then
            self.Triggers[Name] = CurrTrigg
            count = count + 1
        else
            print('  No group assigned, this is not allowed!')
        end
    end
    print('Found a total of ' .. count .. ' ambush triggers.')
    return self
end

function AmbushManager:ActivateTrigger(Trigger)
    print('Activating ambush trigger ' .. Trigger.Name .. '...')
    Trigger.tiAmbush = math.random((Trigger.tiMin or self.tiMin) * 10, (Trigger.tiMax or self.tiMax) * 10) * 0.1
    Trigger.sizeAmbush = math.min(math.random((Trigger.sizeMin or self.sizeMin), (Trigger.sizeMax or self.sizeMax)), #Trigger.Spawns)
    print("  tiAmbush=" .. Trigger.tiAmbush)
    print("  sizeAmbush=" .. Trigger.sizeAmbush)
    if Trigger.sizeAmbush > 0 then
        Trigger.Spawns = Tables.ShuffleTable(Trigger.Spawns)
        Trigger.State = 'Active'
        actor.SetActive(Trigger.Actor, true)
    end
end

function AmbushManager:DeactivateTrigger(Trigger)
    print('Deactivating ambush trigger ' .. Trigger.Name .. '...')
    Trigger.State = 'Inactive'
    actor.SetActive(Trigger.Actor, false)
end

function AmbushManager:Activate()
    print('Activating ambush triggers based on their settings...')
    self.Chance = 50
    if self.GameMode.Settings.TriggerActivationChance ~= nil then
        self.Chance = self.GameMode.Settings.TriggerActivationChance.Value
    end
    self.tiMin = 0
    if self.GameMode.Settings.MinAmbushDelay ~= nil then
        self.tiMin = self.GameMode.Settings.MinAmbushDelay.Value
    end
    self.tiMax = 15
    if self.GameMode.Settings.MaxAmbushDelay ~= nil then
        self.tiMax = self.GameMode.Settings.MaxAmbushDelay.Value
    end
    self.sizeMin = 0
    if self.GameMode.Settings.MinAmbushSize ~= nil then
        self.sizeMin = self.GameMode.Settings.MinAmbushSize.Value
    end
    self.sizeMax = 15
    if self.GameMode.Settings.MaxAmbushSize ~= nil then
        self.sizeMax = self.GameMode.Settings.MaxAmbushSize.Value
    end
    for _, Trigger in pairs(self.Triggers) do
        if math.random(0, 99) < (Trigger.Chance or self.Chance) then
            self:ActivateTrigger(Trigger)
        else
            self:DeactivateTrigger(Trigger)
        end
    end
end

function AmbushManager:Deactivate()
    print('Deactivating all ambush triggers...')
    for _, Trigger in pairs(self.Triggers) do
        self:DeactivateTrigger(Trigger)
    end
end

function AmbushManager:OnGameTriggerBeginOverlap(GameTrigger, Player)
    local Trigger = self.Triggers[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        if Trigger.State == 'Active' then
            Trigger.State = 'Triggered'
            actor.SetActive(Trigger.Actor, false)
            AdminTools:ShowDebug("Ambush " .. Trigger.Tag .. " triggered, spawning " .. Trigger.sizeAmbush .. " AI in " .. Trigger.tiAmbush .. "s")
            self.SpawnQueue:Enqueue(Trigger.tiAmbush, 0.1, Trigger.sizeAmbush, Trigger.Spawns, self.TeamTag, nil, nil, nil, nil, true)
        end
    end
end

return AmbushManager
