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

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("KillConfirmed"))

-- Use a separate loadout
super.PlayerTeams.BluFor.Loadout='NoTeamCamouflage'
super.Settings.RespawnCost.Value = 2000

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
super.Settings.UpriseOnHVTKill = {
	Min = 0,
	Max = 1,
	Value = 1,
	AdvancedSetting = false,
}
super.Settings.CIVUpriseSize = {
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

-- The max. amount of collateral damage before failing the mission
Mode.CollateralDamageThreshold = 3

-- Indicates that the uprise is triggered already
Mode.IsUprise = false
	
function Mode:PreInit()
	self.AiTeams.CIVUnarmed.Spawns = MSpawnsGroups:Create("CIV_Unarmed")
	self.AiTeams.CIVArmed.Spawns = MSpawnsGroups:Create("CIV_Armed")
	super.PreInit(self)
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
		self:SpawnCIVs()
	end
	super.OnRoundStageSet(self, RoundStage)
end

function Mode:SpawnCIVs()
	self.AiTeams.CIVUnarmed.Spawns:AddSpawnsFromRandomGroup(10)
	self.AiTeams.CIVUnarmed.Spawns:Spawn(0.5, 10, "CIV_Unarmed")
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
		print("Uprise triggered, spawning armed CIVs in " .. tiUprise .. "s")
		AdminTools:ShowDebug("Uprise triggered, spawning armed CIVs in " .. tiUprise .. "s")
		self.IsUprise = true
		self.AiTeams.CIVArmed.Spawns:AddSpawnsFromRandomGroup(self.Settings.CIVUpriseSize.Value)
		self.AiTeams.CIVArmed.Spawns:EnqueueSpawning(self.SpawnQueue, tiUprise, 0.4, self.Settings.CIVUpriseSize.Value, "CIV_Armed")
	end
end

function Mode:OnCharacterDied(Character, CharacterController, KillerController)
	local goodKill = true

	if gamemode.GetRoundStage() == 'PreRoundWait' or gamemode.GetRoundStage() == 'InProgress'
	then
		if CharacterController ~= nil then
			local killedTeam = actor.GetTeamId(CharacterController)
			local killerTeam = nil
			if KillerController ~= nil then
				killerTeam = actor.GetTeamId(KillerController)
			end
			if ((killedTeam == self.AiTeams.CIVUnarmed.TeamId) or (killedTeam == self.AiTeams.CIVArmed.TeamId and self.IsUprise == false)) and killerTeam == self.PlayerTeams.BluFor.TeamId then
				goodKill = false
				Mode:Uprise()
				self.Objectives.AvoidFatality:ReportFatality()
				self.PlayerTeams.BluFor.Script:AwardPlayerScore(KillerController, 'CollateralDamage')
				self.PlayerTeams.BluFor.Script:AwardTeamScore('CollateralDamage')

				local message = 'Collateral damage by ' .. player.GetName(KillerController)
				self.PlayerTeams.BluFor.Script:DisplayMessageToAllPlayers(message, 'Engine', 5.0, 'ScoreMilestone')
								
				if self.Objectives.AvoidFatality:GetFatalityCount() >= self.CollateralDamageThreshold then
					self.Objectives.NoSoftFail:Fail()
					self.PlayerTeams.BluFor.Script:DisplayMessageToAlivePlayers('SoftFail', 'Upper', 10.0, 'Always')
					gamemode.SetRoundStage('PostRoundWait')
				end
			end
			if killedTeam == killerTeam and killerTeam == self.PlayerTeams.BluFor.TeamId then
				-- Count fratricides as collateral damage
				self.Objectives.AvoidFatality:ReportFatality()
			end
		end
	end

	if goodKill then
		super.OnCharacterDied(self, Character, CharacterController, KillerController)
		if actor.HasTag(CharacterController, self.HVT.Tag) and Mode.Settings.UpriseOnHVTKill.Value == 1 then
			Mode:Uprise()
		end
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
