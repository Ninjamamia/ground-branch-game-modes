local MTeams                = require('Agents.Team')
local MSpawnsPriority       = require('Spawns.Priority')
local AgentsManager         = require('Agents.Manager')
local AdminTools 			= require('AdminTools')
local AmbushManager         = require('Ambush.Manager')
local Callback 				= require('common.Callback')
local CallbackList			= require('common.CallbackList')
local KillData              = require('Agents.KillData')

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
			Max = 120,
			Value = 60,
			AdvancedSetting = false,
		},
		DebugMessageLevel = {
			Min = 0,
			Max = 3,
			Value = 0,
			AdvancedSetting = false,
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
		BleedoutTime = {
			Min = 10,
			Max = 120,
			Value = 30,
			AdvancedSetting = false,
		}
	},
	PlayerScoreTypes = {
	},
	TeamScoreTypes = {
	},
	PlayerTeams = {
		BluFor = {
			TeamId = 1,
			Name = 'BluFor',
			Loadout = 'NoTeam'
		},
	},
	AiTeams = {
		OpFor = {
			TeamId = 100,
			Name = 'OpFor',
		},
		SuicideSquad = {
			TeamId = 30,
			Name = 'SuicideSquad',
		}
	},
	AISpawnDefs = {
		OpFor = {
			Tag = 'OpFor'
		}
	},
	Teams = {
	},
	AISpawns = {
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
	AgentsManager = nil,
	AmbushManager = nil,
}

function Mode:CreateTeams()
	print('Creating player teams...')
	for _, teamTable in pairs(self.PlayerTeams) do
		NewTeam = MTeams:Create(teamTable)
		self.Teams[NewTeam.Name] = NewTeam
	end
	print('Creating AI teams...')
	for _, teamTable in pairs(self.AiTeams) do
		NewTeam = MTeams:Create(teamTable)
		self.Teams[NewTeam.Name] = NewTeam
	end
end

function Mode:PreInit()
	print('Pre initialization')
	self.AgentsManager = AgentsManager:Create(self.Settings.AIMaxConcurrentCount.Value, self.Settings.BleedoutTime.Value, Callback:Create(self, self.OnOpForDied))
	self.AllNavBlocks = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/GameMode/BP_MissionNavBlock.BP_MissionNavBlock_C')
	gamemode.SetTeamScoreTypes(self.TeamScoreTypes)
	gamemode.SetPlayerScoreTypes(self.PlayerScoreTypes)
	self.OnCharacterDiedCallback = CallbackList:Create()
	self.OnGameTriggerBeginOverlapCallback = CallbackList:Create()
	self.OnGameTriggerEndOverlapCallback = CallbackList:Create()
	self:CreateTeams()
	-- Gathers all OpFor spawn points by priority
	self.AISpawns.OpFor = MSpawnsPriority:Create()
	self.AmbushManager = AmbushManager:Create(self.AISpawnDefs.OpFor.Tag)

	TotalSpawns = math.min(ai.GetMaxCount(), self.AISpawns.OpFor.Total)
	self.Settings.OpForCount.Max = TotalSpawns
	self.Settings.OpForCount.Value = math.min(self.Settings.OpForCount.Value, TotalSpawns)

	self.Teams.SuicideSquad:SetAttitude(self.Teams.BluFor, 'Neutral', true)
	self.Teams.SuicideSquad:SetAttitude(self.Teams.OpFor, 'Neutral', true)
end

function Mode:PostInit()
	print('Post initialization')
end

function Mode:OnRoundStageSet(RoundStage)
	print('Started round stage ' .. RoundStage)
	if RoundStage == 'WaitingForReady' then
		self:PreRoundCleanUp()
		self:PrepareObjectives()
	elseif RoundStage == 'PreRoundWait' then
		gamemode.ResetTeamScores()
		gamemode.ResetPlayerScores()
		AdminTools:SetDebugMessageLevel(self.Settings.DebugMessageLevel.Value)
		self.Teams.BluFor:SetMaxHealings(self.Settings.MaxHealings.Value)
		self.Teams.BluFor:SetHealingMode(self.Settings.HealingMode.Value)
		self.AgentsManager:SetBleedoutTime(self.Settings.BleedoutTime.Value)
		if self.Settings.TriggersEnabled.Value == 1 then
			self.AmbushManager:Activate()
		else
			self.AmbushManager:Deactivate()
		end
		self:SpawnOpFor()
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
	elseif RoundStage == 'InProgress' then
		AdminTools:ShowDebug(self.AgentsManager:GetStateMessage())
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
	timer.ClearAll()
	self.AgentsManager:SetMaxConcurrentAICount(self.Settings.AIMaxConcurrentCount.Value)
	self.AgentsManager:Reset()
	self.AgentsManager:Start()
	for name, objective in pairs(self.Objectives) do
		print("Resetting " .. name)
		objective:Reset()
	end
	print("Resetting all NavBlocks...")
	for _, NavBlock in ipairs(self.AllNavBlocks) do
		actor.SetActive(NavBlock, true)
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
	return self.AgentsManager:OnPlayerCanEnterPlayArea(PlayerState)
end

function Mode:GetSpawnInfo(PlayerState)
	print('GetSpawnInfo')
	return self.AgentsManager:OnGetSpawnInfo(PlayerState)
end

function Mode:PlayerEnteredPlayArea(PlayerState)
	print('PlayerEnteredPlayArea')
	self.AgentsManager:OnPlayerEnteredPlayArea(PlayerState)
	player.SetInsertionPoint(PlayerState, nil)
end

function Mode:LogOut(Exiting)
	print('Player ' .. player.GetName(Exiting) .. ' left the game ')
	if
		gamemode.GetRoundStage() == 'PreRoundWait' or
		gamemode.GetRoundStage() == 'InProgress'
	then
		self.AgentsManager:OnLogOut(Exiting)
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
		local KilledAgent = self.AgentsManager:GetAgent(CharacterController)
		local KillerAgent = self.AgentsManager:GetAgent(KillerController)
		local killData = KillData:Create(KilledAgent, KillerAgent)
		KilledAgent:OnCharacterDied(killData)
		self.OnCharacterDiedCallback:Call(killData)
	end
end

function Mode:OnGameTriggerBeginOverlap(GameTrigger, Player)
	print('OnGameTriggerBeginOverlap')
	local Agent = self.AgentsManager:GetAgent(Player)
	self.OnGameTriggerBeginOverlapCallback:Call(GameTrigger, Agent)
end

function Mode:OnGameTriggerEndOverlap(GameTrigger, Player)
	print('OnGameTriggerEndOverlap')
	local Agent = self.AgentsManager:GetAgent(Player)
	self.OnGameTriggerEndOverlapCallback:Call(GameTrigger, Agent)
end

function Mode:CheckBluForCountTimer()
	if gamemode.GetRoundStage() ~= 'InProgress' then
		return
	end
	if self.Teams.BluFor:IsWipedOut() then
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

function Mode:PrepareObjectives()
end

function Mode:UpdateSummaryOnFail()
	gamemode.AddGameStat('Summary=BluForEliminated')
end

function Mode:SpawnOpFor()
	self.AISpawns.OpFor:SelectSpawnPoints()
	self.AISpawns.OpFor:Spawn(0.0, 0.4, self.Settings.OpForCount.Value)
end

function Mode:OnOpForDied(killData)
end

function Mode:OnPlayerDied(killData)
	timer.Set(
		self.Timers.CheckBluForCount.Name,
		self,
		self.CheckBluForCountTimer,
		self.Timers.CheckBluForCount.TimeStep,
		false
	)
end

function Mode:OnMissionSettingChanged(Setting, NewValue)
	print('OnMissionSettingChanged: ' .. Setting .. ' = ' .. NewValue)
	self.AgentsManager:SetMaxConcurrentAICount(self.Settings.AIMaxConcurrentCount.Value)
end

return Mode