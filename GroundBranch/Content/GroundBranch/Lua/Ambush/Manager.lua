local AdminTools = require('AdminTools')
local Callback = require('common.Callback')
local Trigger = require('Ambush.Trigger')
local BlastZone = require('Ambush.BlastZone')
local Mine = require('Ambush.Mine')

local AmbushManager = {
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
    self.TriggersByName = {}
    self.MinesByName = {}
    self.MinesByDefuserName = {}
    self.BlastZonesByName = {}
    print('Gathering blast zones...')
    local BlastZones = gameplaystatics.GetAllActorsWithTag('BlastZone')
    local count = 0
    for _, Actor in ipairs(BlastZones) do
        local NewBlast = BlastZone:Create(self, Actor)
        self.BlastZonesByName[NewBlast.Name] = NewBlast
        count = count + 1
    end
    print('Found a total of ' .. count .. ' blasts.')
    print('Gathering mines...')
    local Mines = gameplaystatics.GetAllActorsOfClassWithTag('/Game/GroundBranch/Props/GameMode/BP_BigBomb.BP_BigBomb_C', 'Mine')
    count = 0
    for _, Actor in ipairs(Mines) do
        local NewMine = Mine:Create(self, Actor)
        self.MinesByName[NewMine.Name] = NewMine
        for _, Defuser in ipairs(NewMine.Defusers) do
            local defuserName = Defuser:GetName()
            if self.MinesByDefuserName[defuserName] == nil then
                self.MinesByDefuserName[defuserName] = {}
            end
            table.insert(self.MinesByDefuserName[defuserName], NewMine)
        end
        count = count + 1
    end
    print('Found a total of ' .. count .. ' mines.')
    print('Gathering ambush triggers...')
    count = 0
    -- search for laptops first explicitly because they have a different debug visiblily behaviour
    local TriggerLaptops = gameplaystatics.GetAllActorsOfClassWithTag('/Game/GroundBranch/Props/Electronics/MilitaryLaptop/BP_Laptop_Usable.BP_Laptop_Usable_C', 'Ambush')
    for _, Actor in ipairs(TriggerLaptops) do
        local NewTrigg = Trigger:Create(self, Actor, true)
        self.TriggersByName[NewTrigg.Name] = NewTrigg
        count = count + 1
    end
    local Triggers = gameplaystatics.GetAllActorsWithTag('Ambush')
    for _, Actor in ipairs(Triggers) do
        if self.TriggersByName[actor.GetName(Actor)] == nil then
            local NewTrigg = Trigger:Create(self, Actor)
            self.TriggersByName[NewTrigg.Name] = NewTrigg
            count = count + 1
        end
    end
    print('Found a total of ' .. count .. ' ambush triggers.')
    print('Performing trigger post init tasks...')
    for _, CurrTrigger in pairs(self.TriggersByName) do
        CurrTrigger:PostInit()
    end
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
    return self.MinesByName[Name]
end

function AmbushManager:OnDefuse(Defuser, DefusingAgent)
    DefusingAgent:DisplayMessage('IED sucessfully defused.', 'Upper', 2.0)
    local Mines = self.MinesByDefuserName[actor.GetName(Defuser)]
    if Mines ~= nil then
        for _, Mine in ipairs(Mines) do
            Mine:Defuse()
        end
    end
end

function AmbushManager:SyncState()
    for _, BlastZone in pairs(self.BlastZonesByName) do
        BlastZone:SyncState()
    end
    for _, Trigger in pairs(self.TriggersByName) do
        Trigger:SyncState()
    end
    for _, Mine in pairs(self.MinesByName) do
        Mine:SyncState()
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
        for _, BlastZone in pairs(self.BlastZonesByName) do
            BlastZone:SetDebugVisibility(false)
        end
        print('Activating ambush triggers based on their chance...')
        for _, Trigger in pairs(self.TriggersByName) do
            Trigger:SetDebugVisibility(false)
            if math.random(0, 99) < (Trigger.Chance or self.Chance) then
                Trigger:Activate()
                Trigger:SetDebugVisibility(AdminTools.DebugMessageLevel > 2)
            else
                Trigger:Deactivate()
            end
            Trigger:SyncState()
        end
        print('Deactivating all mines in advance...') -- this is required to ensure that defuser collisions will be activated additively
        for _, Mine in pairs(self.MinesByName) do
            Mine:Deactivate()
        end
        print('Activating mines based on their chance...')
        for _, Mine in pairs(self.MinesByName) do
            if math.random(0, 99) < (Mine.Chance or self.Chance) then
                Mine:Activate()
            end
            Mine:SyncState()
        end
    else
        local Trigger = self.TriggersByName[actor.GetName(GameTrigger)]
        if Trigger ~= nil then
            Trigger:Activate()
            Trigger:SetDebugVisibility(AdminTools.DebugMessageLevel > 2)
            Trigger:SyncState()
        end
    end
end

function AmbushManager:Deactivate()
    print('Deactivating all ambush triggers...')
    for _, Trigger in pairs(self.TriggersByName) do
        Trigger:Deactivate()
    end
    for _, Mine in pairs(self.MinesByName) do
        Mine:Deactivate()
    end
    self:SyncState()
end

function AmbushManager:OnGameTriggerBeginOverlap(GameTrigger, Player)
    local BlastZone = self.BlastZonesByName[actor.GetName(GameTrigger)]
    if BlastZone ~= nil then
        BlastZone:OnBeginOverlap(Player)
    end
    local Trigger = self.TriggersByName[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        Trigger:OnBeginOverlap(Player)
    end
end

function AmbushManager:OnGameTriggerEndOverlap(GameTrigger, Player)
    local BlastZone = self.BlastZonesByName[actor.GetName(GameTrigger)]
    if BlastZone ~= nil then
        BlastZone:OnEndOverlap(Player)
    end
    local Trigger = self.TriggersByName[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        Trigger:OnEndOverlap(Player)
    end
end

function AmbushManager:OnLaptopSuccess(GameTrigger, Player)
    local Trigger = self.TriggersByName[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        Trigger:OnLaptopSuccess(Player)
    end
end

function AmbushManager:OnCustomEvent(GameTrigger, Player, postSpawnCallback, force)
    local Trigger = self.TriggersByName[actor.GetName(GameTrigger)]
    if Trigger ~= nil then
        Trigger:OnCustomEvent(Player, postSpawnCallback, force)
    end
end

function AmbushManager:OnCharacterDied(KillData)
    for _, BlastZone in pairs(self.BlastZonesByName) do
        BlastZone:OnEndOverlap(KillData.KilledAgent)
    end
    for _, Trigger in pairs(self.TriggersByName) do
        Trigger:OnEndOverlap(KillData.KilledAgent)
    end
end

return AmbushManager
