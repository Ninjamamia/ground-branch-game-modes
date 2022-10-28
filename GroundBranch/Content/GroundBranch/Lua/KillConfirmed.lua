--[[
	Kill Confirmed
	PvE Ground Branch game mode by Jakub 'eelSkillz' Baranowski
	More details @ https://github.com/JakBaranowski/ground-branch-game-modes/wiki/game-mode-kill-confirmed
]]--

local MTeams                = require('Players.Teams')
local MSpawnsPriority       = require('Spawns.Priority')
local MSpawnsQueue          = require('Spawns.Queue')
local MObjectiveExfiltrate  = require('Objectives.Exfiltrate')
local MObjectiveConfirmKill = require('Objectives.ConfirmKill')
local AdminTools 			= require('AdminTools')
local MSpawnsAmbushManager  = require('Spawns.AmbushManager')
local Callback 				= require('common.Callback')
local CallbackList			= require('common.CallbackList')

--#region Properties

local KillConfirmed = {
	UseReadyRoom = true,
	UseRounds = true,
	MissionTypeDescription = '[Solo/Co-Op] Locate, neutralize and confirm elimination of all High Value Targets in the area of operation.',
	StringTables = {'KillConfirmed'},
	Settings = {
		HVTCount = {
			Min = 1,
			Max = 5,
			Value = 1,
			AdvancedSetting = false,
		},
		OpForCount = {
			Min = 1,
			Max = 50,
			Value = 15,
			AdvancedSetting = false,
		},
		AIMaxConcurrentCount = {
			Min = 1,
			Max = 50,
			Value = 50,
			AdvancedSetting = false,
		},
		Difficulty = {
			Min = 0,
			Max = 4,
			Value = 2,
			AdvancedSetting = false,
		},
		RoundTime = {
			Min = 10,
			Max = 60,
			Value = 60,
			AdvancedSetting = false,
		},
		ReinforcementsTrigger = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
		DisplayDebugMessages = {
			Min = 0,
			Max = 1,
			Value = 0,
			AdvancedSetting = true,
		},
		TriggersEnabled = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = false,
		},
		DisplayObjectiveMessages = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
		DisplayObjectivePrompts = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
	},
	PlayerScoreTypes = {
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
	},
	TeamScoreTypes = {
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
	},
	PlayerTeams = {
		BluFor = {
			TeamId = 1,
			Loadout = 'NoTeam',
			Script = nil
		},
	},
	AiTeams = {
		OpFor = {
			TeamId = 100,
			Tag = 'OpFor',
			CalculatedAiCount = 0,
			Spawns = nil
		},
	},
	Objectives = {
		ConfirmKill = nil,
		Exfiltrate = nil,
	},
	HVT = {
		Tag = 'HVT',
	},
	Timers = {
		-- Delays
		CheckBluForCount = {
			Name = 'CheckBluForCount',
			TimeStep = 1.0,
		},
		CheckReadyUp = {
			Name = 'CheckReadyUp',
			TimeStep = 0.25,
		},
		CheckReadyDown = {
			Name = 'CheckReadyDown',
			TimeStep = 0.1,
		},
	},
	SpawnQueue = nil,
	AmbushManager = nil,
}

--#endregion

--#region Preparation

function KillConfirmed:PreInit()
	print('Pre initialization')
	print('Initializing Kill Confirmed')
	self.OnCharacterDiedCallback = CallbackList:Create()
	self.OnGameTriggerBeginOverlapCallback = CallbackList:Create()
	self.OnGameTriggerEndOverlapCallback = CallbackList:Create()
	self.PlayerTeams.BluFor.Script = MTeams:Create(
		1,
		false,
		self.PlayerScoreTypes,
		self.TeamScoreTypes
	)
	-- Gathers all OpFor spawn points by priority
	self.AiTeams.OpFor.Spawns = MSpawnsPriority:Create()
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
	self.SpawnQueue = MSpawnsQueue:Create(self.Settings.AIMaxConcurrentCount.Value, Callback:Create(self, self.OnOpForDied))
	self.AmbushManager = MSpawnsAmbushManager:Create(self.SpawnQueue, self.AiTeams.OpFor.Tag)
end

function KillConfirmed:PostInit()
	print('Post initialization')
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'NeutralizeHVTs', 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ConfirmEliminatedHVTs', 1)
    print('Added Kill Confirmation objectives')
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, 'ExfiltrateBluFor', 1)
	print('Added exfiltration objective')
end

--#endregion

--#region Common

function KillConfirmed:OnRoundStageSet(RoundStage)
	print('Started round stage ' .. RoundStage)
	timer.ClearAll()
	self.SpawnQueue:Start()
	if RoundStage == 'WaitingForReady' then
		self:PreRoundCleanUp()
		self.Objectives.Exfiltrate:SelectPoint(false)
		self.Objectives.ConfirmKill:SetHvtCount(self.Settings.HVTCount.Value)
		self.Objectives.ConfirmKill:ShuffleSpawns()
	elseif RoundStage == 'PreRoundWait' then
		if self.Settings.TriggersEnabled.Value == 1 then
			self.AmbushManager:Activate()
		else
			self.AmbushManager:Deactivate()
		end
		self:SpawnOpFor()
	elseif RoundStage == 'InProgress' then
		AdminTools:ShowDebug(self.SpawnQueue:GetStateMessage())
		self.PlayerTeams.BluFor.Script:RoundStart(
			1000000,
			false,
			false,
			self.Settings.DisplayObjectiveMessages.Value == 1,
			self.Settings.DisplayObjectivePrompts.Value == 1
		)
	end
end

function KillConfirmed:OnConfirmedKill(hvt, confirmer)
	if self.Settings.ReinforcementsTrigger.Value == 1 then
		self.AmbushManager:OnCustomEvent(hvt.AI.SpawnPoint, confirmer, Callback:Create(self, self.OnReinforcementsSpawned))
	end
end

function KillConfirmed:OnCharacterDied(Character, CharacterController, KillerController)
	print('OnCharacterDied')
	if
		gamemode.GetRoundStage() == 'PreRoundWait' or
		gamemode.GetRoundStage() == 'InProgress'
	then
		self.OnCharacterDiedCallback:Call(Character, CharacterController, KillerController)
	end
end

function KillConfirmed:OnOpForDied(killData)
	print('OpFor standard eliminated')
	if killData.KillerTeam == self.PlayerTeams.BluFor.TeamId then
		self.PlayerTeams.BluFor.Script:AwardPlayerScore(killData.KillerController, 'KillStandard')
	end
end

function KillConfirmed:OnHVTDied(killData)
	if self.Settings.ReinforcementsTrigger.Value == 0 then
		local tiReinforce = math.random(50, 150) * 0.1
		local hvtLocation = killData:GetLocation()
		self:SpawnReinforcements(hvtLocation, tiReinforce)
	end
end

function KillConfirmed:OnPlayerDied(killData)
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

function KillConfirmed:OnReinforcementsSpawned()
	self.PlayerTeams.BluFor.Script:DisplayMessageToAlivePlayers('INTEL: HVT reinforcements spotted!', 'Upper', 5.0, 'Always')
end

--#endregion

--#region Player Status

function KillConfirmed:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	print('PlayerInsertionPointChanged')
	if InsertionPoint == nil then
		-- Player unchecked insertion point.
		timer.Set(
			self.Timers.CheckReadyDown.Name,
			self,
			self.CheckReadyDownTimer,
			self.Timers.CheckReadyDown.TimeStep,
			false
		)
	else
		-- Player checked insertion point.
		timer.Set(
			self.Timers.CheckReadyUp.Name,
			self,
			self.CheckReadyUpTimer,
			self.Timers.CheckReadyUp.TimeStep,
			false
		)
	end
end

function KillConfirmed:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	print('PlayerReadyStatusChanged ' .. ReadyStatus)
	if ReadyStatus ~= 'DeclaredReady' then
		-- Player declared ready.
		timer.Set(
			self.Timers.CheckReadyDown.Name,
			self,
			self.CheckReadyDownTimer,
			self.Timers.CheckReadyDown.TimeStep,
			false
		)
	elseif
		gamemode.GetRoundStage() == 'PreRoundWait' and
		gamemode.PrepLatecomer(PlayerState)
	then
		-- Player did not declare ready, but the timer run out.
		gamemode.EnterPlayArea(PlayerState)
	end
end

function KillConfirmed:CheckReadyUpTimer()
	if
		gamemode.GetRoundStage() == 'WaitingForReady' or
		gamemode.GetRoundStage() == 'ReadyCountdown'
	then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local BluForReady = ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId]
		if BluForReady >= gamemode.GetPlayerCount(true) then
			gamemode.SetRoundStage('PreRoundWait')
		elseif BluForReady > 0 then
			gamemode.SetRoundStage('ReadyCountdown')
		end
	end
end

function KillConfirmed:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == 'ReadyCountdown' then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage('WaitingForReady')
		end
	end
end

function KillConfirmed:ShouldCheckForTeamKills()
	print('ShouldCheckForTeamKills')
	if gamemode.GetRoundStage() == 'InProgress' then
		return true
	end
	return false
end

function KillConfirmed:PlayerCanEnterPlayArea(PlayerState)
	print('PlayerCanEnterPlayArea')
	if
		gamemode.GetRoundStage() == 'InProgress' or
		player.GetInsertionPoint(PlayerState) ~= nil
	then
		return true
	end
	return false
end

function KillConfirmed:GetSpawnInfo(PlayerState)
	print('GetSpawnInfo')
	if gamemode.GetRoundStage() == 'InProgress' then
		self.PlayerTeams.BluFor.Script:RespawnCleanUp(PlayerState)
	end
end

function KillConfirmed:PlayerEnteredPlayArea(PlayerState)
	print('PlayerEnteredPlayArea')
	player.SetInsertionPoint(PlayerState, nil)
end

function KillConfirmed:LogOut(Exiting)
	print('Player left the game ')
	print(Exiting)
	if
		gamemode.GetRoundStage() == 'PreRoundWait' or
		gamemode.GetRoundStage() == 'InProgress'
	then
		timer.Set(
			self.Timers.CheckBluForCount.Name,
			self,
			self.CheckBluForCountTimer,
			self.Timers.CheckBluForCount.TimeStep,
			false
		)
	end
end

--#endregion

--#region Spawns

function KillConfirmed:SpawnOpFor()
	self.Objectives.ConfirmKill:EnqueueSpawning(self.SpawnQueue, 0.4)
	self.AiTeams.OpFor.Spawns:SelectSpawnPoints()
	self.AiTeams.OpFor.Spawns:EnqueueSpawning(self.SpawnQueue, 0.0, 0.4, self.Settings.OpForCount.Value, self.AiTeams.OpFor.Tag)
end

--#endregion

--#region Objective: Kill confirmed

function KillConfirmed:OnAllKillsConfirmed()
	self.Objectives.Exfiltrate:EnableExfiltration()
	self.AmbushManager:OnCustomEvent(self.Objectives.Exfiltrate:GetSelectedPoint(), nil, nil, true)
end

--#endregion

--#region Objective: Extraction

function KillConfirmed:OnGameTriggerBeginOverlap(GameTrigger, Player)
	print('OnGameTriggerBeginOverlap')
	self.OnGameTriggerBeginOverlapCallback:Call(GameTrigger, Player)
end

function KillConfirmed:OnGameTriggerEndOverlap(GameTrigger, Player)
	print('OnGameTriggerEndOverlap')
	self.OnGameTriggerEndOverlapCallback:Call(GameTrigger, Player)
end

function KillConfirmed:OnExfiltrated()
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
	gamemode.AddGameStat('Result=Team1')
	gamemode.AddGameStat('Summary=HVTsConfirmed')
	gamemode.SetRoundStage('PostRoundWait')
end

--#endregion

--#region Fail Condition

function KillConfirmed:CheckBluForCountTimer()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	if self.PlayerTeams.BluFor.Script:IsWipedOut() then
		gamemode.AddGameStat('Result=None')
		self:UpdateCompletedObjectives()
		if self.Objectives.ConfirmKill:AreAllNeutralized() then
			gamemode.AddGameStat('Summary=BluForExfilFailed')
		elseif self.Objectives.ConfirmKill:AreAllConfirmed() then
			gamemode.AddGameStat('Summary=BluForExfilFailed')
		else
			gamemode.AddGameStat('Summary=BluForEliminated')
		end
		gamemode.SetRoundStage('PostRoundWait')
	end
end

--#endregion

--#region Helpers

function KillConfirmed:PreRoundCleanUp()
	self.SpawnQueue:Reset()
	for name, objective in pairs(self.Objectives) do
		print("Resetting " .. name)
		objective:Reset()
	end
end

function KillConfirmed:OnMissionSettingChanged(Setting, NewValue)
	AdminTools.ShowDebugGameMessages = self.Settings.DisplayDebugMessages.Value == 1
	self.SpawnQueue:SetMaxConcurrentAICount(self.Settings.AIMaxConcurrentCount.Value)
	if Setting == "HVTCount" then
		print('HVT count set to ' .. NewValue .. ', updating spawns & objective markers.')
		self.Objectives.ConfirmKill:SetHvtCount(self.Settings.HVTCount.Value)
		self.Objectives.ConfirmKill:ShuffleSpawns()
	end
end

function KillConfirmed:GetPlayerTeamScript()
	return self.PlayerTeams.BluFor.Script
end

function KillConfirmed:UpdateCompletedObjectives()
	local completedObjectives = {}

	for _, objective in pairs(self.Objectives) do
		for _, completed in ipairs(objective:GetCompletedObjectives()) do
			table.insert(completedObjectives, completed)
		end
	end

	if #completedObjectives > 0 then
		gamemode.AddGameStat(
				'CompleteObjectives=' .. table.concat(completedObjectives, ",")
		)
	end
end

--#endregion

return KillConfirmed
