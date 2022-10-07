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
    Triggers = gameplaystatics.GetAllActorsWithTag('Ambush')
    local count = 0
    for _, Trigger in ipairs(Triggers) do
        local Name = actor.GetName(Trigger)
        local CurrTrigg = {
            Name = Name,
            Tag = nil,
            Actor = Trigger,
            State = 'Inactive',
            Spawns = {},
            Activates = {}
        }
        print('Ambush trigger ' .. Name .. ' found.')
        print('  Parameters:')
        for _, Tag in ipairs(actor.GetTags(Trigger)) do
            local key
            local value
            _, _, key, value = string.find(Tag, "(%a+)%s*=%s*(%w+)")
            if key ~= nil then
                print("    " .. Tag)
                if key == "Group" then
                    CurrTrigg.Tag = value
                    CurrTrigg.Spawns = gameplaystatics.GetAllActorsOfClassWithTag(
                        'GroundBranch.GBAISpawnPoint',
                        value
                    )
                elseif key == "Activate" then
                    if value ~= CurrTrigg.Name then
                        table.insert(CurrTrigg.Activates, value)
                    else
                        print("      Error: Circular reference, a trigger may not activate itself!")
                    end
                else
                    CurrTrigg[key] = tonumber(value)
                end
            end
        end
        print('  Summary:')
        print("    Spawns: " .. #CurrTrigg.Spawns)
        print("    Activation links: " .. #CurrTrigg.Activates)
        self.Triggers[Name] = CurrTrigg
        count = count + 1
    end
    print('Found a total of ' .. count .. ' ambush triggers.')
    return self
end

function AmbushManager:ActivateTrigger(Trigger)
    print('Activating ambush trigger ' .. Trigger.Name .. '...')
    local tiMin = Trigger.tiMin or self.tiMin
    local tiMax = Trigger.tiMax or self.tiMax
    if tiMin == tiMax then
        Trigger.tiAmbush = tiMin
    else
        Trigger.tiAmbush = math.random(tiMin * 10, tiMax * 10) * 0.1
    end
    local sizeMin = Trigger.sizeMin or self.sizeMin
    local sizeMax = Trigger.sizeMax or self.sizeMax
    if sizeMin == sizeMax then
        Trigger.sizeAmbush = sizeMin
    else
        Trigger.sizeAmbush = math.min(math.random(sizeMin, sizeMax), #Trigger.Spawns)
    end
    print("  tiAmbush=" .. Trigger.tiAmbush)
    print("  sizeAmbush=" .. Trigger.sizeAmbush)
    Trigger.Spawns = Tables.ShuffleTable(Trigger.Spawns)
    Trigger.State = 'Active'
    actor.SetActive(Trigger.Actor, true)
end

function AmbushManager:DeactivateTrigger(Trigger)
    print('Deactivating ambush trigger ' .. Trigger.Name .. '...')
    Trigger.State = 'Inactive'
    actor.SetActive(Trigger.Actor, false)
end

function AmbushManager:Activate()
    print('Activating ambush triggers based on their settings...')
    self.Chance = 80
    if self.GameMode.Settings.TriggerActivationChance ~= nil then
        self.Chance = self.GameMode.Settings.TriggerActivationChance.Value
    end
    self.tiMin = 1
    if self.GameMode.Settings.MinAmbushDelay ~= nil then
        self.tiMin = self.GameMode.Settings.MinAmbushDelay.Value
    end
    self.tiMax = 7
    if self.GameMode.Settings.MaxAmbushDelay ~= nil then
        self.tiMax = self.GameMode.Settings.MaxAmbushDelay.Value
    end
    self.sizeMin = 0
    if self.GameMode.Settings.MinAmbushSize ~= nil then
        self.sizeMin = self.GameMode.Settings.MinAmbushSize.Value
    end
    self.sizeMax = 5
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
            if Trigger.sizeAmbush > 0 then
                AdminTools:ShowDebug("Ambush trigger " .. Trigger.Name .. " triggered, activating " .. #Trigger.Activates .. " other triggers, spawning " .. Trigger.sizeAmbush .. " AI of group " .. Trigger.Tag .. " in " .. Trigger.tiAmbush .. "s")
                self.SpawnQueue:Enqueue(Trigger.tiAmbush, 0.1, Trigger.sizeAmbush, Trigger.Spawns, self.TeamTag, nil, nil, nil, nil, true)
            else
                AdminTools:ShowDebug("Ambush trigger " .. Trigger.Name .. " triggered, activating " .. #Trigger.Activates .. " other triggers, nothing to spawn.")
            end
            for _, Activate in pairs(Trigger.Activates) do
                local ActivateTrigger = self.Triggers[Activate]
                if ActivateTrigger ~= nil then
                    self:ActivateTrigger(ActivateTrigger)
                end
            end
        end
    end
end

return AmbushManager
