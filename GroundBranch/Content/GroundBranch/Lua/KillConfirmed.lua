--[[
	Kill Confirmed
	PvE Ground Branch game mode by Jakub 'eelSkillz' Baranowski
	More details @ https://github.com/JakBaranowski/ground-branch-game-modes/wiki/game-mode-kill-confirmed
]]--

local AdminTools 			= require('AdminTools')
local Callback 				= require('common.Callback')
local MObjectiveExfiltrate  = require('Objectives.Exfiltrate')
local MObjectiveConfirmKill = require('Objectives.ConfirmKill')
local Tables = require("Common.Tables")

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("PvEBase"))

-- Our sub-class of the singleton
local Mode = setmetatable({}, { __index = super })

Mode.MissionTypeDescription = '[Solo/Co-Op] Locate, neutralize and confirm elimination of all High Value Targets in the area of operation.'
Mode.StringTables = {'KillConfirmed'}
Mode.Settings.HVTCount = {
	Min = 1,
	Max = 5,
	Value = 1,
	AdvancedSetting = false,
}
Mode.Settings.ReinforcementsTrigger = {
	Min = 0,
	Max = 1,
	Value = 1,
	AdvancedSetting = true,
}
Mode.PlayerScoreTypes = {
	KillStandard = {
		Score = 100,
		OneOff = false,
		Description = 'Eliminated threat'
	},
	KillHvt = {
		Score = 250,
		OneOff = false,
		Description = 'Eliminated HVT'
	},
	ConfirmHvt = {
		Score = 750,
		OneOff = false,
		Description = 'Confirmed HVT elimination'
	},
	Survived = {
		Score = 200,
		OneOff = false,
		Description = 'Made it out alive'
	},
	TeamKill = {
		Score = -250,
		OneOff = false,
		Description = 'Killed a teammate'
	},
	Accident = {
		Score = -50,
		OneOff = false,
		Description = 'Killed oneself'
	}
}
Mode.TeamScoreTypes = {
	KillHvt = {
		Score = 250,
		OneOff = false,
		Description = 'Eliminated HVT'
	},
	ConfirmHvt = {
		Score = 750,
		OneOff = false,
		Description = 'Confirmed HVT elimination'
	},
	Respawn = {
		Score = -1,
		OneOff = false,
		Description = 'Respawned'
	}
}
Mode.Objectives = {
	ConfirmKill = nil,
	Exfiltrate = nil,
}
Mode.HVT = {
	Tag = 'HVT',
}

function Mode:PreInit()
	super.PreInit(self)
	-- Gathers all HVT spawn points
	self.Objectives.ConfirmKill = MObjectiveConfirmKill:Create(
		Callback:Create(self, self.OnAllKillsConfirmed),
		self.PlayerTeams.BluFor.Script,
		self.HVT.Tag,
		self.Settings.HVTCount.Value,
		Callback:Create(self, self.OnConfirmedKill),
		Callback:Create(self, self.OnHVTDied)
	)
	-- Gathers all extraction points placed in the mission
	self.Objectives.Exfiltrate = MObjectiveExfiltrate:Create(
		Callback:Create(self, self.OnExfiltrated),
		self.PlayerTeams.BluFor.Script,
		5.0,
		1.0
	)
	-- Set maximum HVT count and ensure that HVT value is within limit
	self.Settings.HVTCount.Max = math.min(
		ai.GetMaxCount(),
		self.Objectives.ConfirmKill:GetAllSpawnPointsCount()
	)
	self.Settings.HVTCount.Value = math.min(
		self.Settings.HVTCount.Value,
		self.Settings.HVTCount.Max
	)
end

function Mode:PostInit()
	print('Post initialization')
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'NeutralizeHVTs', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ConfirmEliminatedHVTs', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ExfiltrateBluFor', 1)
end

function Mode:PrepareObjectives()
	self.Objectives.Exfiltrate:SelectPoint(false)
	self.Objectives.ConfirmKill:SetHvtCount(self.Settings.HVTCount.Value)
	self.Objectives.ConfirmKill:ShuffleSpawns()
end

function Mode:UpdateSummaryOnFail()
	if self.Objectives.ConfirmKill:AreAllNeutralized() then
		gamemode.AddGameStat('Summary=BluForExfilFailed')
	else
		gamemode.AddGameStat('Summary=BluForEliminated')
	end
end

function Mode:SpawnOpFor()
	super.SpawnOpFor(self)
	self.Objectives.ConfirmKill:EnqueueSpawning(self.SpawnQueue, 0.4)
end

function Mode:OnOpForDied(killData)
	print('OpFor standard eliminated')
	if killData.KillerTeam == self.PlayerTeams.BluFor.TeamId then
		self.PlayerTeams.BluFor.Script:AwardPlayerScore(killData.KillerController, 'KillStandard')
	end
end

function Mode:OnPlayerDied(killData)
	if killData.KilledTeam == self.PlayerTeams.BluFor.TeamId then
		print('BluFor eliminated')
		AdminTools:NotifyKIA(killData.CharacterController)
		if killData.CharacterController == killData.KillerController then
			self.PlayerTeams.BluFor.Script:AwardPlayerScore(killData.CharacterController, 'Accident')
		elseif killData.KillerTeam == killData.KilledTeam then
			self.PlayerTeams.BluFor.Script:AwardPlayerScore(killData.KillerController, 'TeamKill')
		end
		self.PlayerTeams.BluFor.Script:PlayerDied(killData.CharacterController, killData.Character)
		timer.Set(
			self.Timers.CheckBluForCount.Name,
			self,
			self.CheckBluForCountTimer,
			self.Timers.CheckBluForCount.TimeStep,
			false
		)
	end
end

function Mode:OnMissionSettingChanged(Setting, NewValue)
	super.OnMissionSettingChanged(self, Setting, NewValue)
	if Setting == "HVTCount" then
		print('HVT count set to ' .. NewValue .. ', updating spawns & objective markers.')
		self.Objectives.ConfirmKill:SetHvtCount(self.Settings.HVTCount.Value)
		self.Objectives.ConfirmKill:ShuffleSpawns()
	end
end

function Mode:OnAllKillsConfirmed()
	self.Objectives.Exfiltrate:EnableExfiltration()
	self.AmbushManager:OnCustomEvent(self.Objectives.Exfiltrate:GetSelectedPoint(), nil, nil, true)
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
	self:UpdateGameStatsOnExfil()
	gamemode.SetRoundStage('PostRoundWait')
end

function Mode:UpdateGameStatsOnExfil()
	gamemode.AddGameStat('Result=Team1')
	gamemode.AddGameStat('Summary=HVTsConfirmed')
end

function Mode:OnConfirmedKill(hvt, confirmer)
	if self.Settings.ReinforcementsTrigger.Value == 1 then
		self.AmbushManager:OnCustomEvent(hvt.AI.SpawnPoint, confirmer, Callback:Create(self, self.OnReinforcementsSpawned))
	end
end

function Mode:OnHVTDied(killData)
	if self.Settings.ReinforcementsTrigger.Value == 0 then
		local tiReinforce = math.random(50, 150) * 0.1
		local hvtLocation = killData:GetLocation()
		self:SpawnReinforcements(hvtLocation, tiReinforce)
	end
end

function Mode:OnReinforcementsSpawned()
	self.PlayerTeams.BluFor.Script:DisplayMessageToAlivePlayers('INTEL: HVT reinforcements spotted!', 'Upper', 5.0, 'Always')
end

return Mode