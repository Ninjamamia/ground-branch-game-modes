local MSpawnsPriority       = require('Spawns.Priority')
local MSpawnsQueue          = require('Spawns.Queue')
local AdminTools 			= require('AdminTools')
local MSpawnsAmbushManager  = require('Spawns.AmbushManager')

local terroristhunt = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = { "TerroristHunt" },
	MissionTypeDescription = "[Solo/Co-Op] Locate and eliminate a (somewhat) predetermined number of enemies in the area of operations.",
	PlayerTeams = {
		BluFor = {
			TeamId = 1,
			Loadout = "NoTeam",
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
	Settings = {
		OpForCount = {
			Min = 1,
			Max = 50,
			Value = 15,
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
		ShowRemaining = {
			Min = 0,
			Max = 50,
			Value = 10,
			AdvancedSetting = true,
		},
		AIMaxConcurrentCount = {
			Min = 1,
			Max = 50,
			Value = 50,
			AdvancedSetting = false,
		},
		DisplayDebugMessages = {
			Min = 0,
			Max = 1,
			Value = 0,
			AdvancedSetting = true,
		},
		TriggerActivationChance = {
			Min = 0,
			Max = 100,
			Value = 0,
			AdvancedSetting = true,
		},
		MinAmbushDelay = {
			Min = 0,
			Max = 30,
			Value = 0,
			AdvancedSetting = true,
		},
		MaxAmbushDelay = {
			Min = 0,
			Max = 30,
			Value = 15,
			AdvancedSetting = true,
		},
		MinAmbushSize = {
			Min = 0,
			Max = 50,
			Value = 0,
			AdvancedSetting = true,
		},
		MaxAmbushSize = {
			Min = 0,
			Max = 50,
			Value = 10,
			AdvancedSetting = true,
		},
		TriggersEnabled = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = false,
		},
	},
	SpawnQueue = nil,
	AmbushManager = nil,
}

function terroristhunt:PreInit()
	print('Pre initialization')
	self.AiTeams.OpFor.Spawns = MSpawnsPriority:Create()
	self.SpawnQueue = MSpawnsQueue:Create(self.Settings.AIMaxConcurrentCount.Value)
	self.AmbushManager = MSpawnsAmbushManager:Create(self.SpawnQueue, self.AiTeams.OpFor.Tag, self)

	TotalSpawns = math.min(ai.GetMaxCount(), self.AiTeams.OpFor.Spawns.Total)
	self.Settings.OpForCount.Max = TotalSpawns
	self.Settings.OpForCount.Value = math.min(self.Settings.OpForCount.Value, TotalSpawns)

	self.Settings.ShowRemaining.Max = TotalSpawns
	self.Settings.ShowRemaining.Value = math.min(self.Settings.ShowRemaining.Value, TotalSpawns)
end

function terroristhunt:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "EliminateOpFor", 1)
end

function terroristhunt:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false)
	end
end

function terroristhunt:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	end
	
	if ReadyStatus == "WaitingToReadyUp" 
	and gamemode.GetRoundStage() == "PreRoundWait" 
	and gamemode.PrepLatecomer(PlayerState) then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function terroristhunt:CheckReadyUpTimer()
	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		local BluForReady = ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId]
	
		if BluForReady >= gamemode.GetPlayerCount(true) then
			gamemode.SetRoundStage("PreRoundWait")
		elseif BluForReady > 0 then
			gamemode.SetRoundStage("ReadyCountdown")
		end
	end
end

function terroristhunt:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function terroristhunt:OnRoundStageSet(RoundStage)
	print('Started round stage ' .. RoundStage)
	timer.ClearAll()
	self.SpawnQueue:Start()
	if RoundStage == "WaitingForReady" then
		ai.CleanUp(self.AiTeams.OpFor.Tag)
		self.SpawnQueue:SetMaxConcurrentAICount(self.Settings.AIMaxConcurrentCount.Value)
		self.SpawnQueue:Reset()
	elseif RoundStage == "PreRoundWait" then
		if self.Settings.TriggersEnabled.Value == 1 then
			self.AmbushManager:Activate()
		else
			self.AmbushManager:Deactivate()
		end
		self:SpawnOpFor()
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
		-- need to update this as ops board setting may have changed - have to do this before RoundStage InProgress to be effective
	elseif RoundStage == "InProgress" then
		--gamemode.SetRoundStageTime(self.Settings.RoundTime.Value * 60.0)
		--does not work because round stage time is set immediately afterwards based on RoundTime
	end
end

function terroristhunt:SpawnOpFor()
	self.AiTeams.OpFor.Spawns:SelectSpawnPoints()
	self.AiTeams.OpFor.Spawns:EnqueueSpawning(self.SpawnQueue, 0.0, 0.4, self.Settings.OpForCount.Value, self.AiTeams.OpFor.Tag)
end

function terroristhunt:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.AiTeams.OpFor.Tag) then
				self.SpawnQueue:OnAIKilled()
				timer.Set("CheckOpForCount", self, self.CheckOpForCountTimer, 1.0, false)
			else
				AdminTools:NotifyKIA(CharacterController)
				player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
								
				local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, false)
				if #PlayersWithLives == 0 then
					self:CheckBluForCountTimer()
					-- call immediately because round is about to end and nothing more can happen
				else
					timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
				end
				
			end
		end
	end
end

function terroristhunt:OnMissionSettingChanged(Setting, NewValue)
	AdminTools.ShowDebugGameMessages = self.Settings.DisplayDebugMessages.Value == 1
	self.SpawnQueue:SetMaxConcurrentAICount(self.Settings.AIMaxConcurrentCount.Value)
end

function terroristhunt:OnGameTriggerBeginOverlap(GameTrigger, Player)
	print('OnGameTriggerBeginOverlap')
	self.AmbushManager:OnGameTriggerBeginOverlap(GameTrigger, Player)
end

function terroristhunt:CheckOpForCountTimer()
	if self.SpawnQueue.AliveAICount == 0 then
		timer.Clear("ShowRemaining")
		gamemode.AddGameStat("Result=Team1")
		gamemode.AddGameStat("Summary=OpForEliminated")
		gamemode.AddGameStat("CompleteObjectives=EliminateOpFor")
		gamemode.SetRoundStage("PostRoundWait")
	elseif self.Settings.ShowRemaining.Value > 0 and self.SpawnQueue.AliveAICount <= self.Settings.ShowRemaining.Value then
		self.RemainingMessage = "RemainingOpFor" .. tostring(self.SpawnQueue.AliveAICount)
		timer.Set("ShowRemaining", self, self.ShowRemainingTimer, 10, false)
	end
end

function terroristhunt:ShowRemainingTimer()
	gamemode.BroadcastGameMessage(self.RemainingMessage, "Engine", 2.0)
end

function terroristhunt:CheckBluForCountTimer()
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, false)
	if #PlayersWithLives == 0 then
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BluForEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function terroristhunt:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end

function terroristhunt:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function terroristhunt:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
	end
end


return terroristhunt