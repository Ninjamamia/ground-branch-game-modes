--[[
Kill Confirmed (Semi-Permissive)
PvE Ground Branch game mode by Bob/AT
2022-05-08

https://github.com/JakBaranowski/ground-branch-game-modes/issues/26

Notes for Mission Editing:

  1. Start with a regular 'Kill Confirmed' mission
  2. Add non-combatants
  - use team id = 10
  - assign a group tag with the pattern CIV_Unarmed<GroupNumber>
  - one of the unarmed 'Civ*' kits)
  2. Add armed (uprising) civilians
  - use team id = 20
  - assign a group tag with the pattern CIV_Armed<GroupNumber>
  - a matching armed civ kit

]]--

local Tables = require("Common.Tables")
local AvoidFatality = require("Objectives.AvoidFatality")
local NoSoftFail = require("Objectives.NoSoftFail")
local AdminTools = require('AdminTools')
local MSpawnsGroups         = require('Spawns.Groups')
local Callback 				= require('common.Callback')

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("GroundBranch.GameMode.KillConfirmed"))

-- Our sub-class of the singleton
local Mode = setmetatable({}, { __index = super })

-- Add new score types
Mode.PlayerScoreTypes.CollateralDamage = {
	Score = -250,
	OneOff = false,
	Description = 'Killed a non-combatant'
}
Mode.TeamScoreTypes.CollateralDamage = {
	Score = -250,
	OneOff = false,
	Description = 'Killed a non-combatant'
}
-- Add additional objectives
Mode.Objectives.AvoidFatality = AvoidFatality.new('NoCollateralDamage')
Mode.Objectives.NoSoftFail = NoSoftFail.new()

-- Add additional settings
Mode.Settings.UpriseOnHVTKillChance = {
	Min = 0,
	Max = 100,
	Value = 0,
	AdvancedSetting = false,
}
Mode.Settings.InitialUpriseChance = {
	Min = 0,
	Max = 100,
	Value = 50,
	AdvancedSetting = false,
}
Mode.Settings.ChanceIncreasePerCollateral = {
	Min = 0,
	Max = 100,
	Value = 20,
	AdvancedSetting = false,
}
Mode.Settings.GlobalCIVUpriseSize = {
	Min = 0,
	Max = 30,
	Value = 10,
	AdvancedSetting = false,
}
Mode.Settings.LocalCIVUpriseSize = {
	Min = 0,
	Max = 30,
	Value = 10,
	AdvancedSetting = false,
}
Mode.Settings.CIVPopulation = {
	Min = 0,
	Max = 30,
	Value = 10,
	AdvancedSetting = false,
}

-- Add additional teams
Mode.AiTeams.CIVUnarmed = {
	Name = 'CIVUnarmed',
	TeamId = 10,
}
Mode.AiTeams.CIVArmed = {
	Name = 'CIVArmed',
	TeamId = 20,
}

Mode.AISpawnDefs.CIV = {
	Tag = 'CIV',
	OldTag = 'CIV_Unarmed',
}
Mode.AISpawnDefs.Uprise = {
	Tag = 'Uprise',
	OldTag = 'CIV_Armed',
}

-- Indicates that the uprise is triggered already
Mode.IsUprise = false

-- Current effective uprise chance
Mode.UpriseChance = 0

function Mode:PreInit()
	super.PreInit(self)
	self.AISpawns.CIV = MSpawnsGroups:Create(self.AISpawnDefs.CIV.Tag)
	if self.AISpawns.CIV:GetTotalSpawnPointsCount() == 0 then
		self.AISpawns.CIV = MSpawnsGroups:Create(self.AISpawnDefs.CIV.OldTag)
	end
	self.AISpawns.Uprise = MSpawnsGroups:Create(self.AISpawnDefs.Uprise.Tag)
	if self.AISpawns.Uprise:GetTotalSpawnPointsCount() == 0 then
		self.AISpawns.Uprise = MSpawnsGroups:Create(self.AISpawnDefs.Uprise.OldTag)
	end
	self.Teams.CIVUnarmed:SetAttitude(self.Teams.BluFor, 'Neutral')
	self.Teams.CIVUnarmed:SetAttitude(self.Teams.OpFor, 'Friendly', true)
	self.Teams.CIVUnarmed:SetAttitude(self.Teams.SuicideSquad, 'Neutral', true)
	self.Teams.CIVArmed:SetAttitude(self.Teams.BluFor, 'Neutral')
	self.Teams.CIVArmed:SetAttitude(self.Teams.OpFor, 'Friendly', true)
	self.Teams.CIVArmed:SetAttitude(self.Teams.SuicideSquad, 'Neutral', true)
	self.Teams.CIVArmed:SetAttitude(self.Teams.CIVUnarmed, 'Friendly', true)
	self.Teams.BluFor:AddHealableTeam(self.Teams.CIVUnarmed)
	self.Teams.CIVUnarmed:SetDefaultEliminationCallback(Callback:Create(self, self.OnCivDied))
	self.Teams.BluFor:AddHealableTeam(self.Teams.CIVArmed)
	self.Teams.CIVArmed:SetDefaultEliminationCallback(Callback:Create(self, self.OnCivDied))
end

function Mode:TakeChance(chance)
	return math.random(0, 99) < chance
end

function Mode:PostInit()
	super.PostInit(self)
	self.Teams.BluFor:AddGameObjective('NoCollateralDamage', 1)
end

function Mode:OnRoundStageSet(RoundStage)
	super.OnRoundStageSet(self, RoundStage)
	if RoundStage == 'PostRoundWait' or RoundStage == 'TimeLimitReached' then
		-- Make sure the 'SOFT FAIL' message is cleared
		gamemode.BroadcastGameMessage('Blank', 'Center', -1)
	elseif RoundStage == 'PreRoundWait' then
		self.IsUprise = false
		self.UpriseChance = self.Settings.InitialUpriseChance.Value
		self:SpawnCIVs()
	end
end

function Mode:SpawnCIVs()
	self.AISpawns.CIV:AddRandomSpawns()
	self.AISpawns.CIV:Spawn(0.0, 0.5, self.Settings.CIVPopulation.Value)
end

function Mode:PreRoundCleanUp()
	super.PreRoundCleanUp(self)
	self.Teams.CIVArmed:SetAttitude(self.Teams.BluFor, 'Neutral')
	self.Teams.BluFor:AddHealableTeam(self.Teams.CIVArmed)
	self.Teams.CIVArmed:SetDefaultEliminationCallback(Callback:Create(self, self.OnCivDied))
end

function Mode:Uprise()
	if not self.IsUprise then
		local tiUprise = math.random(50, 150) * 0.1
		AdminTools:ShowDebug("Global uprise triggered, spawning armed CIVs in " .. tiUprise .. "s")
		self.IsUprise = true
		local sizeUprise = self.Settings.GlobalCIVUpriseSize.Value
		if sizeUprise > 0 then
			self.AISpawns.Uprise:AddRandomSpawns()
			self.AISpawns.Uprise:Spawn(tiUprise, 0.4, sizeUprise, Callback:Create(self, self.OnUpriseSpawned), nil, true)
		end
	end
end

function Mode:OnUpriseSpawned()
	self.Teams.BluFor:DisplayMessageToAlivePlayers('INTEL: Civilians are uprising, no more "mistakes" are permitted...', 'Upper', 5.0, 'Always')
end

function Mode:LocalUprise(killedAgentLocation)
	local tiUprise = math.random(50, 150) * 0.1
	local sizeUprise = math.random(0, self.Settings.LocalCIVUpriseSize.Value)
	AdminTools:ShowDebug("Local uprise triggered, spawning " .. sizeUprise .. " armed CIVs close in " .. tiUprise .. "s")
	if sizeUprise > 0 then
		self.AISpawns.Uprise:AddSpawnsFromClosestGroup(sizeUprise, killedAgentLocation)
		self.AISpawns.Uprise:Spawn(tiUprise, 0.4, sizeUprise, Callback:Create(self, self.OnLocalUpriseSpawned), nil, true)
	end
	local tiUpset = math.random(30, 90)
	AdminTools:ShowDebug(tostring(self.Teams.CIVArmed) .. ' will uprise for ' .. tiUpset .. 's now...')
	timer.Set(
		'UpriseCooldown',
		self,
		self.OnUpriseCooldown,
		tiUpset,
		false
	)
	self.Teams.CIVArmed:RemoveDefaultEliminationCallback()
	self.Teams.BluFor:RemoveHealableTeam(self.Teams.CIVArmed)
	self.Teams.CIVArmed:SetAttitude(self.Teams.BluFor, 'Hostile')
end

function Mode:OnUpriseCooldown()
	AdminTools:ShowDebug(tostring(self.Teams.CIVArmed) .. ' is relaxed again.')
	self.Teams.CIVArmed:SetAttitude(self.Teams.BluFor, 'Neutral')
	self.Teams.BluFor:AddHealableTeam(self.Teams.CIVArmed)
	timer.Set(
		'PostUpriseCooldown',
		self,
		self.PostUpriseCooldown,
		3.0,
		false
	)
end

function Mode:PostUpriseCooldown()
	AdminTools:ShowDebug('Killing ' .. tostring(self.Teams.CIVArmed) .. ' is punishable again now.')
	self.Teams.CIVArmed:SetDefaultEliminationCallback(Callback:Create(self, self.OnCivDied))
end

function Mode:OnLocalUpriseSpawned()
	self.Teams.BluFor:DisplayMessageToAlivePlayers('INTEL: Armed civilians spotted nearby!', 'Upper', 5.0, 'Always')
end

function Mode:OnCivDied(killData)
	if killData.KillerTeam == self.Teams.BluFor then
		self.Objectives.AvoidFatality:ReportFatality()
		killData.KillerAgent:AwardPlayerScore('CollateralDamage')
		killData.KillerAgent:AwardTeamScore('CollateralDamage')
		local message = 'Collateral damage by ' .. tostring(killData.KillerAgent)
		self.Teams.BluFor:DisplayMessageToAllPlayers(message, 'Engine', 5.0, 'ScoreMilestone')
		if self.IsUprise then
			self.Objectives.NoSoftFail:Fail()
			self.Teams.BluFor:DisplayMessageToAlivePlayers('SoftFail', 'Upper', 10.0, 'Always')
			gamemode.SetRoundStage('PostRoundWait')
		end
		self:LocalUprise(killData:GetLocation())
		if self:TakeChance(self.UpriseChance) then
			self:Uprise()
		end
		self.UpriseChance = self.UpriseChance + self.Settings.ChanceIncreasePerCollateral.Value
		if self.IsUprise == false then
			AdminTools:ShowDebug("Uprise chance on next collateral damage: " .. self.UpriseChance .. "%")
		end
	end
end

function Mode:OnHVTDied(killData)
	super.OnHVTDied(self, killData)
	if self:TakeChance(self.Settings.UpriseOnHVTKillChance.Value) then
		self:LocalUprise(killData:GetLocation())
	end
end

function Mode:OnPlayerDied(killData)
	super.OnPlayerDied(self, killData)
	if killData.KilledTeam == killData.KillerTeam then
		-- Count fratricides as collateral damage
		self.Objectives.AvoidFatality:ReportFatality()
	end
end

function Mode:UpdateGameStatsOnExfil()
	if self.Objectives.NoSoftFail:IsOK() then
		gamemode.AddGameStat('Summary=HVTsConfirmed')
		gamemode.AddGameStat('Result=Team1')
	else
		gamemode.AddGameStat('Summary=SoftFail')
		gamemode.AddGameStat('Result=None')
	end
end

return Mode
