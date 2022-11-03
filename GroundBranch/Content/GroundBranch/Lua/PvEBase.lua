local MTeams                = require('Players.Teams')
local MSpawnsPriority       = require('Spawns.Priority')
local MSpawnsQueue          = require('Spawns.Queue')
local AdminTools 			= require('AdminTools')
local MSpawnsAmbushManager  = require('Spawns.AmbushManager')
local Callback 				= require('common.Callback')
local CallbackList			= require('common.CallbackList')

local Mode = {
	UseReadyRoom = true,
	UseRounds = true,
	MissionTypeDescription = "TBD",
	StringTables = { "TerroristHunt" },
	Settings = {
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
			Min = 3,
			Max = 60,
			Value = 60,
			AdvancedSetting = false,
		},
		DebugMessageLevel = {
			Min = 0,
			Max = 2,
			Value = 0,
			AdvancedSetting = true,
		},
		TriggersEnabled = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = false,
		},
		MaxHealings = {
			Min = 0,
			Max = 2,
			Value = 2,
			AdvancedSetting = false,
		},
		HealingMode = {
			Min = 0,
			Max = 1,
			Value = 0,
			AdvancedSetting = false,
		},
	},
	PlayerScoreTypes = {
	},
	TeamScoreTypes = {
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

function Mode:PreInit()
	print('Pre initialization')
	self.OnCharacterDiedCallback = CallbackList:Create()
	self.OnGameTriggerBeginOverlapCallback = CallbackList:Create()
	self.OnGameTriggerEndOverlapCallback = CallbackList:Create()
	self.PlayerTeams.BluFor.Script = MTeams:Create(
		self.PlayerTeams.BluFor.TeamId,
		false,
		self.PlayerScoreTypes,
		self.TeamScoreTypes
	)
	-- Gathers all OpFor spawn points by priority
	self.AiTeams.OpFor.Spawns = MSpawnsPriority:Create()
	self.SpawnQueue = MSpawnsQueue:Create(self.Settings.AIMaxConcurrentCount.Value, Callback:Create(self, self.OnOpForDied))
	self.AmbushManager = MSpawnsAmbushManager:Create(self.SpawnQueue, self.AiTeams.OpFor.Tag)

	TotalSpawns = math.min(ai.GetMaxCount(), self.AiTeams.OpFor.Spawns.Total)
	self.Settings.OpForCount.Max = TotalSpawns
	self.Settings.OpForCount.Value = math.min(self.Settings.OpForCount.Value, TotalSpawns)
end

function Mode:PostInit()
	print('Post initialization')
end

function Mode:OnRoundStageSet(RoundStage)
	print('Started round stage ' .. RoundStage)
	timer.ClearAll()
	self.SpawnQueue:Start()
	if RoundStage == 'WaitingForReady' then
		self:PreRoundCleanUp()
		self:PrepareObjectives()
	elseif RoundStage == 'PreRoundWait' then
		AdminTools.DebugMessageLevel = self.Settings.DebugMessageLevel.Value
		self.PlayerTeams.BluFor.Script:RoundStart(self.Settings.MaxHealings.Value, self.Settings.HealingMode.Value)
		if self.Settings.TriggersEnabled.Value == 1 then
			self.AmbushManager:Activate()
		else
			self.AmbushManager:Deactivate()
		end
		self:SpawnOpFor()
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
	elseif RoundStage == 'InProgress' then
		AdminTools:ShowDebug(self.SpawnQueue:GetStateMessage())
	end
end

function Mode:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
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

function Mode:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
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

function Mode:CheckReadyUpTimer()
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

function Mode:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == 'ReadyCountdown' then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage('WaitingForReady')
		end
	end
end

function Mode:PreRoundCleanUp()
	self.SpawnQueue:SetMaxConcurrentAICount(self.Settings.AIMaxConcurrentCount.Value)
	self.SpawnQueue:Reset()
	for name, objective in pairs(self.Objectives) do
		print("Resetting " .. name)
		objective:Reset()
	end
end

function Mode:ShouldCheckForTeamKills()
	print('ShouldCheckForTeamKills')
	if gamemode.GetRoundStage() == 'InProgress' then
		return true
	end
	return false
end

function Mode:PlayerCanEnterPlayArea(PlayerState)
	print('PlayerCanEnterPlayArea')
	if
		gamemode.GetRoundStage() == 'InProgress' or
		player.GetInsertionPoint(PlayerState) ~= nil
	then
		return true
	end
	return false
end

function Mode:GetSpawnInfo(PlayerState)
	print('GetSpawnInfo')
	local PlayerStart = nil
	if gamemode.GetRoundStage() == 'InProgress' then
		PlayerStart = self.PlayerTeams.BluFor.Script:RespawnCleanUp(PlayerState)
	end
	if PlayerStart == nil then
		PlayerStart = self.PlayerTeams.BluFor.Script:GetPlayerStart(PlayerState)
	end
	return PlayerStart
end

function Mode:PlayerEnteredPlayArea(PlayerState)
	print('PlayerEnteredPlayArea')
	self.PlayerTeams.BluFor.Script:UpdatePlayers()
	player.SetInsertionPoint(PlayerState, nil)
end

function Mode:LogOut(Exiting)
	print('Player ' .. player.GetName(Exiting) .. ' left the game ')
	if
		gamemode.GetRoundStage() == 'PreRoundWait' or
		gamemode.GetRoundStage() == 'InProgress'
	then
		self.PlayerTeams.BluFor.Script:UpdatePlayers()
		timer.Set(
			self.Timers.CheckBluForCount.Name,
			self,
			self.CheckBluForCountTimer,
			self.Timers.CheckBluForCount.TimeStep,
			false
		)
	end
end

function Mode:OnCharacterDied(Character, CharacterController, KillerController)
	print('OnCharacterDied')
	if
		gamemode.GetRoundStage() == 'PreRoundWait' or
		gamemode.GetRoundStage() == 'InProgress'
	then
		self.OnCharacterDiedCallback:Call(Character, CharacterController, KillerController)
	end
end

function Mode:OnGameTriggerBeginOverlap(GameTrigger, Player)
	print('OnGameTriggerBeginOverlap')
	self.OnGameTriggerBeginOverlapCallback:Call(GameTrigger, Player)
end

function Mode:OnGameTriggerEndOverlap(GameTrigger, Player)
	print('OnGameTriggerEndOverlap')
	self.OnGameTriggerEndOverlapCallback:Call(GameTrigger, Player)
end

function Mode:CheckBluForCountTimer()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	if self.PlayerTeams.BluFor.Script:IsWipedOut() then
		gamemode.AddGameStat('Result=None')
		self:UpdateCompletedObjectives()
		self:UpdateSummaryOnFail()
		gamemode.SetRoundStage('PostRoundWait')
	end
end

function Mode:UpdateCompletedObjectives()
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

function Mode:GetPlayerTeamScript()
	return self.PlayerTeams.BluFor.Script
end

function Mode:PrepareObjectives()
end

function Mode:UpdateSummaryOnFail()
	gamemode.AddGameStat('Summary=BluForEliminated')
end

function Mode:SpawnOpFor()
	self.AiTeams.OpFor.Spawns:SelectSpawnPoints()
	self.AiTeams.OpFor.Spawns:EnqueueSpawning(self.SpawnQueue, 0.0, 0.4, self.Settings.OpForCount.Value, self.AiTeams.OpFor.Tag)
end

function Mode:OnOpForDied(killData)
end

function Mode:OnPlayerDied(killData)
	AdminTools:NotifyKIA(killData.CharacterController)
	self.PlayerTeams.BluFor.Script:PlayerDied(killData)
	timer.Set(
		self.Timers.CheckBluForCount.Name,
		self,
		self.CheckBluForCountTimer,
		self.Timers.CheckBluForCount.TimeStep,
		false
	)
end

function Mode:OnMissionSettingChanged(Setting, NewValue)
	print('OnMissionSettingChanged')
	self.SpawnQueue:SetMaxConcurrentAICount(self.Settings.AIMaxConcurrentCount.Value)
end

return Mode