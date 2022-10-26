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
local super = Tables.DeepCopy(require("KillConfirmed"))

-- Use a separate loadout
super.PlayerTeams.BluFor.Loadout='NoTeamCamouflage'

-- Add new score types
super.PlayerScoreTypes.CollateralDamage = {
	Score = -250,
	OneOff = false,
	Description = 'Killed a non-combatant'
}
super.TeamScoreTypes.CollateralDamage = {
	Score = -250,
	OneOff = false,
	Description = 'Killed a non-combatant'
}
-- Add additional objectives
super.Objectives.AvoidFatality = AvoidFatality.new('NoCollateralDamage')
super.Objectives.NoSoftFail = NoSoftFail.new()

-- Add additional settings
super.Settings.UpriseOnHVTKillChance = {
	Min = 0,
	Max = 100,
	Value = 0,
	AdvancedSetting = false,
}
super.Settings.InitialUpriseChance = {
	Min = 0,
	Max = 100,
	Value = 50,
	AdvancedSetting = false,
}
super.Settings.ChanceIncreasePerCollateral = {
	Min = 0,
	Max = 100,
	Value = 20,
	AdvancedSetting = false,
}
super.Settings.CIVUpriseSize = {
	Min = 0,
	Max = 30,
	Value = 10,
	AdvancedSetting = false,
}
super.Settings.CIVPopulation = {
	Min = 0,
	Max = 30,
	Value = 10,
	AdvancedSetting = false,
}

-- Add additional teams
super.AiTeams.CIVUnarmed = {
	Tag = 'CIV_Unarmed',
	TeamId = 10,
	CalculatedAiCount = 0,
	Spawns = nil
}
super.AiTeams.CIVArmed = {
	Tag = 'CIV_Armed',
	TeamId = 20,
	CalculatedAiCount = 0,
	Spawns = nil
}

-- Our sub-class of the singleton
local Mode = setmetatable({}, { __index = super })

-- Indicates that the uprise is triggered already
Mode.IsUprise = false

-- Current effective uprise chance
Mode.UpriseChance = 0

function Mode:PreInit()
	self.AiTeams.CIVUnarmed.Spawns = MSpawnsGroups:Create(self.AiTeams.CIVUnarmed.Tag)
	self.AiTeams.CIVArmed.Spawns = MSpawnsGroups:Create(self.AiTeams.CIVArmed.Tag)
	super.PreInit(self)
	self.SpawnQueue:RegisterDefaultEliminationCallback(self.AiTeams.CIVUnarmed.TeamId, Callback:Create(self, self.OnCivDied))
end

function Mode:TakeChance(chance)
	return math.random(0, 99) < chance
end

function Mode:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'NeutralizeHVTs', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ConfirmEliminatedHVTs', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'NoCollateralDamage', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ExfiltrateBluFor', 1)
end

function Mode:OnRoundStageSet(RoundStage)
	if RoundStage == 'PostRoundWait' or RoundStage == 'TimeLimitReached' then
		-- Make sure the 'SOFT FAIL' message is cleared
		gamemode.BroadcastGameMessage('Blank', 'Center', -1)
	elseif RoundStage == 'PreRoundWait' then
		self.IsUprise = false
		self.UpriseChance = self.Settings.InitialUpriseChance.Value
		self:SpawnCIVs()
	end
	super.OnRoundStageSet(self, RoundStage)
end

function Mode:SpawnCIVs()
	self.AiTeams.CIVUnarmed.Spawns:AddRandomSpawns()
	self.AiTeams.CIVUnarmed.Spawns:EnqueueSpawning(self.SpawnQueue, 0.0, 0.5, self.Settings.CIVPopulation.Value, self.AiTeams.CIVUnarmed.Tag)
end

function Mode:PreRoundCleanUp()
	super.PreRoundCleanUp(self)
	gamemode.SetTeamAttitude(self.PlayerTeams.BluFor.TeamId, self.AiTeams.CIVUnarmed.TeamId, 'Neutral')
	gamemode.SetTeamAttitude(self.AiTeams.CIVUnarmed.TeamId, self.PlayerTeams.BluFor.TeamId, 'Neutral')
	gamemode.SetTeamAttitude(self.AiTeams.OpFor.TeamId, self.AiTeams.CIVArmed.TeamId, 'Friendly')
	gamemode.SetTeamAttitude(self.AiTeams.CIVArmed.TeamId, self.AiTeams.OpFor.TeamId, 'Friendly')
	gamemode.SetTeamAttitude(self.AiTeams.CIVUnarmed.TeamId, self.AiTeams.CIVArmed.TeamId, 'Friendly')
	gamemode.SetTeamAttitude(self.AiTeams.CIVArmed.TeamId, self.AiTeams.CIVUnarmed.TeamId, 'Friendly')
	gamemode.SetTeamAttitude(self.AiTeams.CIVUnarmed.TeamId, self.AiTeams.OpFor.TeamId, 'Friendly')
	gamemode.SetTeamAttitude(self.AiTeams.OpFor.TeamId, self.AiTeams.CIVUnarmed.TeamId, 'Friendly')
end

function Mode:Uprise()
	if not self.IsUprise then
		local tiUprise = math.random(50, 150) * 0.1
		AdminTools:ShowDebug("Uprise triggered, spawning armed CIVs in " .. tiUprise .. "s")
		self.IsUprise = true
		local sizeUprise = self.Settings.CIVUpriseSize.Value
		if sizeUprise > 0 then
			self.AiTeams.CIVArmed.Spawns:AddRandomSpawns()
			self.AiTeams.CIVArmed.Spawns:EnqueueSpawning(self.SpawnQueue, tiUprise, 0.4, sizeUprise, self.AiTeams.CIVArmed.Tag, Callback:Create(self, self.OnUpriseSpawned), nil, true)
		end
	end
end

function Mode:OnUpriseSpawned()
	self.PlayerTeams.BluFor.Script:DisplayMessageToAlivePlayers('INTEL: Civilians are uprising, no more "mistakes" are permitted...', 'Upper', 5.0, 'Always')
end

function Mode:LocalUprise(killedCivLocation)
	local tiUprise = math.random(50, 150) * 0.1
	local sizeUprise = math.random(0, 10)
	AdminTools:ShowDebug("Local uprise triggered, spawning " .. sizeUprise .. " armed CIVs close in " .. tiUprise .. "s")
	if sizeUprise > 0 then
		self.AiTeams.CIVArmed.Spawns:AddSpawnsFromClosestGroup(sizeUprise, killedCivLocation)
		self.AiTeams.CIVArmed.Spawns:EnqueueSpawning(self.SpawnQueue, tiUprise, 0.4, sizeUprise, self.AiTeams.CIVArmed.Tag, Callback:Create(self, self.OnLocalUpriseSpawned), nil, true)
	end
end

function Mode:OnLocalUpriseSpawned()
	self.PlayerTeams.BluFor.Script:DisplayMessageToAlivePlayers('INTEL: Armed civilians spotted nearby!', 'Upper', 5.0, 'Always')
end

function Mode:OnCivDied(killData)
	if killData.KillerTeam == self.PlayerTeams.BluFor.TeamId then
		self.Objectives.AvoidFatality:ReportFatality()
		self.PlayerTeams.BluFor.Script:AwardPlayerScore(killData.KillerController, 'CollateralDamage')
		self.PlayerTeams.BluFor.Script:AwardTeamScore('CollateralDamage')
		local message = 'Collateral damage by ' .. player.GetName(killData.KillerController)
		self.PlayerTeams.BluFor.Script:DisplayMessageToAllPlayers(message, 'Engine', 5.0, 'ScoreMilestone')
		if self.IsUprise then
			self.Objectives.NoSoftFail:Fail()
			self.PlayerTeams.BluFor.Script:DisplayMessageToAlivePlayers('SoftFail', 'Upper', 10.0, 'Always')
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
		self:Uprise()
	end
end

function Mode:OnPlayerDied(killData)
	super.OnPlayerDied(self, killData)
	if killData.KilledTeam == killData.KillerTeam then
		-- Count fratricides as collateral damage
		self.Objectives.AvoidFatality:ReportFatality()
	end
end

function Mode:OnExfiltrated()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	-- Award surviving players
	local alivePlayers = self.PlayerTeams.BluFor.Script:GetAlivePlayers()
	for _, alivePlayer in ipairs(alivePlayers) do
		self.PlayerTeams.BluFor.Script:AwardPlayerScore(alivePlayer, 'Survived')
	end

	-- Prepare summary
	self:UpdateCompletedObjectives()
	if self.Objectives.NoSoftFail:IsOK() then
		gamemode.AddGameStat('Summary=HVTsConfirmed')
		gamemode.AddGameStat('Result=Team1')
	else
		gamemode.AddGameStat('Summary=SoftFail')
		gamemode.AddGameStat('Result=None')
	end
	gamemode.SetRoundStage('PostRoundWait')
end

return Mode
