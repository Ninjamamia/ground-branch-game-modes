local AdminTools = require('AdminTools')
local Callback = require('common.Callback')
local Trigger = require('Ambush.Trigger')
local BlastZone = require('Ambush.BlastZone')
local Mine = require('Ambush.Mine')

local AmbushManager = {
    TeamTag = nil,
    Triggers = {}
}

AmbushManager.__index = AmbushManager

---Creates a new ambush manager object. At creation all relevant spawn points are
---gathered, default values are set.
---@param teamTag string The tag to assign to each spawned AI.
---@return table AmbushManager Newly created AmbushManager object.
function AmbushManager:Create(teamTag)
    local self = setmetatable({}, AmbushManager)
    -- Setting attributes
    self.TeamTag = teamTag
    self.Triggers = {}
    self.Mines = {}
    self.Defusers = {}
    self.BlastZones = {}
    print('Gathering blast zones...')
    local BlastZones = gameplaystatics.GetAllActorsWithTag('BlastZone')
    local count = 0
    for _, Actor in ipairs(BlastZones) do
        local NewBlast = BlastZone:Create(self, Actor)
        self.BlastZones[NewBlast.Name] = NewBlast
        count = count + 1
    end
    print('Found a total of ' .. count .. ' blasts.')
    print('Gathering ambush triggers...')
    local Triggers = gameplaystatics.GetAllActorsWithTag('Ambush')
    count = 0
    for _, Actor in ipairs(Triggers) do
        local NewTrigg = Trigger:Create(self, Actor)
        self.Triggers[NewTrigg.Name] = NewTrigg
        count = count + 1
    end
    print('Found a total of ' .. count .. ' ambush triggers.')
    print('Gathering mines...')
    local Mines = gameplaystatics.GetAllActorsOfClassWithTag('/Game/GroundBranch/Props/GameMode/BP_BigBomb.BP_BigBomb_C', 'Mine')
    count = 0
    for _, Actor in ipairs(Mines) do
        local NewMine = Mine:Create(self, Actor)
        self.Mines[NewMine.Name] = NewMine
        for _, Defuser in ipairs(NewMine.Defusers) do
            local defuserName = actor.GetName(Defuser)
            if self.Defusers[defuserName] == nil then
                self.Defusers[defuserName] = {}
            end
            table.insert(self.Defusers[defuserName], NewMine)
        end
        count = count + 1
    end
    print('Found a total of ' .. count .. ' mines.')
	print('Hooking to callbacks')
	if gamemode.script.OnCharacterDiedCallback ~= nil then
		gamemode.script.OnCharacterDiedCallback:Add(Callback:Create(self, self.OnCharacterDied))
	else
		AdminTools:ShowDebug("AmbushManager: gamemode doesn't define OnCharacterDiedCallback, cant't hook to it")
	end
	if gamemode.script.OnGameTriggerBeginOverlapCallback ~= nil then
		gamemode.script.OnGameTriggerBeginOverlapCallback:Add(Callback:Create(self, self.OnGameTriggerBeginOverlap))
	else
		AdminTools:ShowDebug("AmbushManager: gamemode doesn't define OnGameTriggerBeginOverlapCallback, cant't hook to it")
	end
	if gamemode.script.OnGameTriggerEndOverlapCallback ~= nil then
		gamemode.script.OnGameTriggerEndOverlapCallback:Add(Callback:Create(self, self.OnGameTriggerEndOverlap))
	else
		AdminTools:ShowDebug("AmbushManager: gamemode doesn't define OnGameTriggerEndOverlapCallback, cant't hook to it")
	end
    return self
end

function AmbushManager:GetMine(Name)
    return self.Mines[Name]
end

function AmbushManager:OnDefuse(Defuser)
    local Mines = self.Defusers[actor.GetName(Defuser)]
    if Mines ~= nil then
        for _, Mine in ipairs(Mines) do
            Mine:Defuse()
        end
    end
end

function AmbushManager:Activate(GameTrigger)
    GameTrigger = GameTrigger or nil
    if GameTrigger == nil then
        self.Chance = 80
        if gamemode.script.Settings.TriggerActivationChance ~= nil then
            self.Chance = gamemode.script.Settings.TriggerActivationChance.Value
        end
        self.tiMin = 1
        if gamemode.script.Settings.MinAmbushDelay ~= nil then
            self.tiMin = gamemode.script.Settings.MinAmbushDelay.Value
        end
        self.tiMax = 7
        if gamemode.script.Settings.MaxAmbushDelay ~= nil then
            self.tiMax = gamemode.script.Settings.MaxAmbushDelay.Value
        end
        self.sizeMin = 0
        if gamemode.script.Settings.MinAmbushSize ~= nil then
            self.sizeMin = gamemode.script.Settings.MinAmbushSize.Value
        end
        self.sizeMax = 5
        if gamemode.script.Settings.MaxAmbushSize ~= nil then
            self.sizeMax = gamemode.script.Settings.MaxAmbushSize.Value
        end
        self.tiPresenceMin = 0
        if gamemode.script.Settings.MinPresenceTime ~= nil then
            self.tiPresenceMin = gamemode.script.Settings.MinPresenceTime.Value
        end
        self.tiPresenceMax = 0
        if gamemode.script.Settings.MaxPresenceTime ~= nil then
            self.tiPresenceMax = gamemode.script.Settings.MaxPresenceTime.Value
        end
        print('Activating ambush triggers based on their chance...')
        for _, Trigger in pairs(self.Triggers) do
            if math.random(0, 99) < (Trigger.Chance or self.Chance) then
                Trigger:Activate()
            else
                Trigger:Deactivate()
            end
        end
        print('Deactivating all mines in advance...') -- this is required to ensure that defuser collisions will be activated additively
        for _, Mine in pairs(self.Mines) do
            Mine:Deactivate()
        end
        print('Activating mines based on their chance...')
        for _, Mine in pairs(self.Mines) do
            if math.random(0, 99) < (Mine.Chance or self.Chance) then
                Mine:Activate()
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

function AmbushManager:OnGameTriggerBeginOverlap(GameTrigger, Player)
    local BlastZone = self.BlastZones[actor.GetName(GameTrigger)]
    if BlastZone ~= nil then
        BlastZone:OnBeginOverlap(Player)
    end
    local Trigger = self.Triggers[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        Trigger:OnBeginOverlap(Player)
    end
end

function AmbushManager:OnGameTriggerEndOverlap(GameTrigger, Player)
    local BlastZone = self.BlastZones[actor.GetName(GameTrigger)]
    if BlastZone ~= nil then
        BlastZone:OnEndOverlap(Player)
    end
    local Trigger = self.Triggers[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        Trigger:OnEndOverlap(Player)
    end
end

function AmbushManager:OnLaptopSuccess(GameTrigger)
    local Trigger = self.Triggers[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        Trigger:OnLaptopSuccess()
    end
end

function AmbushManager:OnCustomEvent(GameTrigger, Player, postSpawnCallback, force)
    local Trigger = self.Triggers[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        Trigger:OnCustomEvent(Player, postSpawnCallback, force)
    end
end

function AmbushManager:OnCharacterDied(KillData)
    for _, BlastZone in pairs(self.BlastZones) do
        BlastZone:OnEndOverlap(KillData.KilledAgent)
    end
    for _, Trigger in pairs(self.Triggers) do
        Trigger:OnEndOverlap(KillData.KilledAgent)
    end
end

return AmbushManager
