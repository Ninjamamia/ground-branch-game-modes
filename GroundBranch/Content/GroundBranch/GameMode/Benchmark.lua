local benchmark = {
	UseReadyRoom = false,
	UseRounds = false,
	StringTables = { "Benchmark" },
	
	GameModeAuthor = "(c) BlackFoot Studios, 2021-2022",
	GameModeType = "PVE",
	
	PlayerTeams = {
		BluFor = {
			TeamId = 1,
			Loadout = "NoTeam",
		},
	},
	Settings = {
		OpForCount = {
			Min = 1,
			Max = 50,
			Value = 30,
			AdvancedSetting = false,
		},
		MapOnly = {
			Min = 0,
			Max = 1,
			Value = 0,
			AdvancedSetting = false,
		},
		-- This forces the player to spawn as a spectato
		-- TODO: Figure out a way to have gamemode options without having them appear as settings
		SpectatorOnly = {
			Min = 1,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
	},
	
	OpForTeamTag = "OpFor",
		
	PlayerCapsuleHalfHeight = 100,
	PlayerCapsuleRadius = 40,
	-- size for collision checking
}


function benchmark:DumbTableCopy(MyTable)
	local ReturnTable = {}
	
	for Key, TableEntry in ipairs(MyTable) do
		table.insert(ReturnTable, TableEntry)
	end
	
	return ReturnTable
end


function benchmark:PreInit()
	local AllSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	local TotalSpawns = 0
		
	for i, SpawnPoint in ipairs(AllSpawns) do
		TotalSpawns = TotalSpawns + 1 
	end
	
	TotalSpawns = math.min(ai.GetMaxCount(), TotalSpawns)
	self.Settings.OpForCount.Max = TotalSpawns
	self.Settings.OpForCount.Value = math.min(self.Settings.OpForCount.Value, TotalSpawns)	
end

function benchmark:PostInit()
	local Benchmarkers = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBBenchmarker')
	local BenchmarkersFound = 0

	for i, Benchmarker in ipairs(Benchmarkers) do
		BenchmarkersFound = BenchmarkersFound + 1 
	end

	if BenchmarkersFound < 1 then
		timer.Set("ReturnToMenu", self, self.ReturnToMenu, 3.5, false)
		return
	end

	if not gamemode.IsEditingMission() then
		self:StartBenchmark()
	end
end

function benchmark:StartBenchmark()
	local AllNavBlocks = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/GameMode/BP_MissionNavBlock.BP_MissionNavBlock_C')

	-- Start the gamemode so when AI spawn they don't shoot each other etc.
	gamemode.SetRoundStage("ReadyCountdown")
	gamemode.SetRoundStage("PreRoundWait")
	gamemode.SetDefaultRoundStageTime("InProgress", 60)
	gamemode.SetRoundStage("InProgress")
	
	for _, NavBlock in ipairs(AllNavBlocks) do
		actor.SetActive(NavBlock, true)
	end

	if self.Settings.MapOnly.Value ~= 1 then
		self:SpawnOpFor()
	end

	gamemode.StartBenchmark()
end


function benchmark:SpawnOpFor()
	local OrderedSpawns = {}
	local AllSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')

	for i, SpawnPoint in ipairs(AllSpawns) do
		table.insert(OrderedSpawns, SpawnPoint)
	end

	ai.CreateOverDuration(0.2, self.Settings.OpForCount.Value, OrderedSpawns, self.OpForTeamTag)
end

function benchmark:StartEditMission()
	gamemode.CancelBenchmark()
end

function benchmark:StopEditMission()
	self:StartBenchmark()
end

function benchmark:ReturnToMenu()
	gamemode.ReturnToMenu()
end

function benchmark:OnRoundStageSet(RoundStage)
end


function benchmark:OnRoundStageSet(RoundStage)
end


function benchmark:OnCharacterDied(Character, CharacterController, KillerController)
end


function benchmark:ShouldCheckForTeamKills()
	return false
end


function benchmark:PlayerCanEnterPlayArea(PlayerState)
	return true
end


function benchmark:OnMissionSettingChanged(Setting, NewValue)
end


function benchmark:LogOut(Exiting)
end


return benchmark