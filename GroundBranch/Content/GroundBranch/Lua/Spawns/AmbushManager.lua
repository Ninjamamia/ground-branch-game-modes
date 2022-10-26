local Tables = require('Common.Tables')
local AdminTools = require('AdminTools')

local AmbushManager = {
    SpawnQueue = nil,
    TeamTag = nil,
    Triggers = {}
}

AmbushManager.__index = AmbushManager

local Trigger = {
    Name = nil,
    Tag = nil,
    Actor = nil,
    State = 'Inactive',
    Spawns = {},
    Activates = {},
    Mines = {}
}

Trigger.__index = Trigger

function Trigger:Create(Parent, Actor)
    local self = setmetatable({}, Trigger)
    self.Parent = Parent
    self.Name = actor.GetName(Actor)
    self.Actor = Actor
    self.Tag = nil
    self.State = 'Inactive'
    self.Spawns = {}
    self.Activates = {}
    self.Mines = {}
    print('Ambush trigger ' .. self.Name .. ' found.')
    print('  Parameters:')
    for _, Tag in ipairs(actor.GetTags(Actor)) do
        local key
        local value
        _, _, key, value = string.find(Tag, "(%a+)%s*=%s*(%w+)")
        if key ~= nil then
            print("    " .. Tag)
            if key == "Group" then
                self.Tag = value
                self.Spawns = gameplaystatics.GetAllActorsOfClassWithTag(
                    'GroundBranch.GBAISpawnPoint',
                    value
                )
            elseif key == "Activate" then
                table.insert(self.Activates, value)
            elseif key == "Mine" then
                table.insert(self.Mines, value)
            else
                self[key] = tonumber(value)
            end
        end
    end
    print('  Summary:')
    print("    Spawns: " .. #self.Spawns)
    print("    Activation links: " .. #self.Activates)
    print("    Mines: " .. #self.Mines)
    return self
end

function Trigger:Activate(IsLinked)
    print('Activating ambush trigger ' .. self.Name .. '...')
    self.postSpawnCallback = nil
    local tiMin = self.tiMin or self.Parent.tiMin
    local tiMax = self.tiMax or self.Parent.tiMax
    if tiMin >= tiMax then
        self.tiAmbush = math.min(tiMin, tiMax)
    else
        self.tiAmbush = math.random(tiMin * 10, tiMax * 10) * 0.1
    end
    local tiPresenceMin = self.tiPresenceMin or self.Parent.tiPresenceMin
    local tiPresenceMax = self.tiPresenceMax or self.Parent.tiPresenceMax
    if tiPresenceMin >= tiPresenceMax then
        self.tiPresence = math.min(tiPresenceMin, tiPresenceMax)
    else
        self.tiPresence = math.random(tiPresenceMin * 10, tiPresenceMax * 10) * 0.1
    end
    local sizeMin = self.sizeMin or self.Parent.sizeMin
    local sizeMax = self.sizeMax or self.Parent.sizeMax
    if sizeMin >= sizeMax then
        self.sizeAmbush = math.min(sizeMin, sizeMax)
    else
        self.sizeAmbush = math.min(math.random(sizeMin, sizeMax), #self.Spawns)
    end
    print("  tiPresence=" .. self.tiPresence)
    print("  tiAmbush=" .. self.tiAmbush)
    print("  sizeAmbush=" .. self.sizeAmbush)
    self.Spawns = Tables.ShuffleTable(self.Spawns)
    self.State = 'Active'
    IsLinked = IsLinked or false
    if IsLinked then
        if self.PlayersCount > 0 then
            if self.tiPresence < 5.0 then
                AdminTools:ShowDebug('Trigger ' .. self.Name .. ' reactivated, tiPresence < 5.0s (' .. self.tiPresence .. 's), will only re-trigger if re-occupied.')
            else
                timer.Set(
                    "Trigger_" .. self.Name,
                    self,
                    self.Trigger,
                    self.tiPresence,
                    false
                )
                AdminTools:ShowDebug('Trigger ' .. self.Name .. ' reactivated, ' .. self.PlayersCount .. ' players still present, will re-trigger in ' .. self.tiPresence .. 's')
            end
        end
    else
        self.Players = {}
        self.PlayersCount = 0
        actor.SetActive(self.Actor, true)
    end
end

function Trigger:Deactivate()
    print('Deactivating ambush trigger ' .. self.Name .. '...')
    self.State = 'Inactive'
    self.Players = {}
    self.PlayersCount = 0
    actor.SetActive(self.Actor, false)
end

function Trigger:Trigger()
    self.State = 'Triggered'
    if self.sizeAmbush > 0 then
        AdminTools:ShowDebug("Ambush trigger " .. self.Name .. " triggered, activating " .. #self.Activates .. " other triggers, triggering " .. #self.Mines .. " mines, spawning " .. self.sizeAmbush .. " AI of group " .. self.Tag .. " in " .. self.tiAmbush .. "s")
        self.Parent.SpawnQueue:Enqueue(self.tiAmbush, 0.1, self.sizeAmbush, self.Spawns, self.Parent.TeamTag, nil, nil, self.postSpawnCallback, true)
    else
        AdminTools:ShowDebug("Ambush trigger " .. self.Name .. " triggered, activating " .. #self.Activates .. " other triggers, triggering " .. #self.Mines .. " mines, nothing to spawn.")
    end
    for _, Activate in pairs(self.Activates) do
        local ActivateTrigger = self.Parent.Triggers[Activate]
        if ActivateTrigger ~= nil then
            ActivateTrigger:Activate(true)
        end
    end
    for _, MineName in pairs(self.Mines) do
        local CurrMine = self.Parent.Mines[MineName]
        if CurrMine ~= nil then
            CurrMine:Trigger()
        end
    end
end

local Mine = {
    Name = nil,
    Tag = nil,
    Actor = nil,
    State = 'Inactive',
}

Mine.__index = Mine

function Mine:Create(Parent, Actor)
    local self = setmetatable({}, Mine)
    self.Parent = Parent
    self.Name = actor.GetName(Actor)
    self.Actor = Actor
    self.Tag = nil
    self.State = 'Inactive'
    self.Props = {}
    self.Defusers = {}
    print('Mine ' .. self.Name .. ' found.')
    print('  Parameters:')
    for _, Tag in ipairs(actor.GetTags(Actor)) do
        local key
        local value
        _, _, key, value = string.find(Tag, "(%a+)%s*=%s*(%w+)")
        if key ~= nil then
            print("    " .. Tag)
            self[key] = tonumber(value)
        end
    end
    print('  Gathering props...')
    self.Props = gameplaystatics.GetAllActorsWithTag(self.Name)
    self.Defusers = gameplaystatics.GetAllActorsOfClassWithTag('/Game/GroundBranch/Props/Electronics/MilitaryLaptop/BP_Laptop_Usable.BP_Laptop_Usable_C', self.Name)
    print('  Found a total of ' .. #self.Props .. ' props and ' .. #self.Defusers .. ' defusers.')
    return self
end

function Mine:Activate()
    print('Activating mine ' .. self.Name .. '...')
    self.State = 'Active'
    actor.SetActive(self.Actor, true)
    for _, Prop in ipairs(self.Props) do
        actor.SetActive(Prop, true)
        actor.SetHidden(Prop, false)
    end
    for _, Prop in ipairs(self.Defusers) do
        actor.SetHidden(Prop, true)
    end
end

function Mine:Deactivate()
    print('Deactivating mine ' .. self.Name .. '...')
    self.State = 'Inactive'
    actor.SetActive(self.Actor, false)
    for _, Prop in ipairs(self.Props) do
        actor.SetActive(Prop, false)
        actor.SetHidden(Prop, true)
    end
end

function Mine:Defuse()
    AdminTools:ShowDebug(self.Name .. ' defused.')
    self.State = 'Inactive'
    actor.SetActive(self.Actor, false)
    for _, Prop in ipairs(self.Props) do
        actor.SetActive(Prop, false)
        if not actor.HasTag(Prop, 'Keep') then
            actor.SetHidden(Prop, true)
        end
    end
end

function Mine:Trigger()
    if self.State == 'Active' then
        self.State = 'Triggered'
        AdminTools:ShowDebug(self.Name .. " triggered.")
        GetLuaComp(self.Actor).Explode()
        for _, Prop in ipairs(self.Props) do
            actor.SetActive(Prop, false)
            actor.SetHidden(Prop, true)
        end
    end
end

---Creates a new ambush manager object. At creation all relevant spawn points are
---gathered, default values are set.
---@param spawnQueue table The SpawnQueue object used to spawn AI.
---@param teamTag string The tag to assign to each spawned AI.
---@return table AmbushManager Newly created AmbushManager object.
function AmbushManager:Create(spawnQueue, teamTag)
    local self = setmetatable({}, AmbushManager)
    -- Setting attributes
    self.SpawnQueue = spawnQueue
    self.GameMode = gamemode.script
    self.TeamTag = teamTag
    self.Triggers = {}
    self.Mines = {}
    self.Defusers = {}
    print('Gathering ambush triggers...')
    Triggers = gameplaystatics.GetAllActorsWithTag('Ambush')
    local count = 0
    for _, Actor in ipairs(Triggers) do
        local NewTrigg = Trigger:Create(self, Actor)
        self.Triggers[NewTrigg.Name] = NewTrigg
        count = count + 1
    end
    print('Found a total of ' .. count .. ' ambush triggers.')
    print('Gathering mines...')
    Mines = gameplaystatics.GetAllActorsOfClassWithTag('/Game/GroundBranch/Props/GameMode/BP_BigBomb.BP_BigBomb_C', 'Mine')
    count = 0
    for _, Actor in ipairs(Mines) do
        local NewMine = Mine:Create(self, Actor)
        self.Mines[NewMine.Name] = NewMine
        for _, Defuser in ipairs(NewMine.Defusers) do
            self.Defusers[actor.GetName(Defuser)] = NewMine
        end
        count = count + 1
    end
    print('Found a total of ' .. count .. ' mines.')
    return self
end

function AmbushManager:OnDefuse(Defuser)
    local Mine = self.Defusers[actor.GetName(Defuser)]
    if Mine ~= nil then
        Mine:Defuse()
    end
end

function AmbushManager:Activate(GameTrigger)
    GameTrigger = GameTrigger or nil
    if GameTrigger == nil then
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
        self.tiPresenceMin = 0
        if self.GameMode.Settings.MinPresenceTime ~= nil then
            self.tiPresenceMin = self.GameMode.Settings.MinPresenceTime.Value
        end
        self.tiPresenceMax = 0
        if self.GameMode.Settings.MaxPresenceTime ~= nil then
            self.tiPresenceMax = self.GameMode.Settings.MaxPresenceTime.Value
        end
        for _, Trigger in pairs(self.Triggers) do
            if math.random(0, 99) < (Trigger.Chance or self.Chance) then
                Trigger:Activate()
            else
                Trigger:Deactivate()
            end
        end
        for _, Mine in pairs(self.Mines) do
            if math.random(0, 99) < (Mine.Chance or self.Chance) then
                Mine:Activate()
            else
                Mine:Deactivate()
            end
        end
    else
        local Trigger = self.Triggers[actor.GetName(GameTrigger)]
        if Trigger ~= nil then
            Trigger:Activate()
        end
    end
end

function AmbushManager:Deactivate()
    print('Deactivating all ambush triggers...')
    for _, Trigger in pairs(self.Triggers) do
        Trigger:Deactivate()
    end
    for _, Mine in pairs(self.Mines) do
        Mine:Deactivate()
    end
end

function AmbushManager:OnGameTriggerBeginOverlap(GameTrigger, Player, postSpawnCallback)
    local Trigger = self.Triggers[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        if Trigger.State == 'Active' then
            Trigger.postSpawnCallback = postSpawnCallback or nil
            local PlayerName = player.GetName(Player)
            if Trigger.Players[PlayerName] == nil then
                Trigger.Players[PlayerName] = true
                Trigger.PlayersCount = Trigger.PlayersCount + 1
                local Message = 'Player ' .. PlayerName .. ' entered trigger ' .. Trigger.Name .. ', ' .. Trigger.PlayersCount .. ' players present'
                if Trigger.PlayersCount == 1 then
                    if Trigger.tiPresence < 0.2 then
                        Trigger:Trigger()
                    else
                        timer.Set(
                            "Trigger_" .. Trigger.Name,
                            Trigger,
                            Trigger.Trigger,
                            Trigger.tiPresence,
                            false
                        )
                        Message = Message .. ', will trigger in ' .. Trigger.tiPresence .. 's'
                    end
                end
                AdminTools:ShowDebug(Message)
            end
        end
    end
end

function AmbushManager:OnGameTriggerEndOverlap(GameTrigger, Player)
    local Trigger = self.Triggers[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        if Trigger.State == 'Active' then
            local PlayerName = player.GetName(Player)
            if Trigger.Players[PlayerName] ~= nil then
                Trigger.Players[PlayerName] = nil
                Trigger.PlayersCount = Trigger.PlayersCount - 1
                local Message = 'Player ' .. PlayerName .. ' left trigger ' .. Trigger.Name .. ', ' .. Trigger.PlayersCount .. ' players present'
                if Trigger.PlayersCount == 0 then
                    timer.Clear("Trigger_" .. Trigger.Name, Trigger)
                    Message = Message .. ', timer aborted'
                end
                AdminTools:ShowDebug(Message)
            end
        end
    end
end

function AmbushManager:OnCharacterDied(Character)
    local PlayerName = player.GetName(Character)
    for _, Trigger in pairs(self.Triggers) do
        if Trigger.State == 'Active' then
            if Trigger.Players[PlayerName] ~= nil then
                Trigger.Players[PlayerName] = nil
                Trigger.PlayersCount = Trigger.PlayersCount - 1
                local Message = 'Player ' .. PlayerName .. ' left trigger ' .. Trigger.Name .. ' (died), ' .. Trigger.PlayersCount .. ' players present'
                if Trigger.PlayersCount == 0 then
                    timer.Clear("Trigger_" .. Trigger.Name, Trigger)
                    Message = Message .. ', timer aborted'
                end
                AdminTools:ShowDebug(Message)
            end
        end
    end
end

return AmbushManager
