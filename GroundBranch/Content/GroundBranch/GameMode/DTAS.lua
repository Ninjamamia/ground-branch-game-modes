local DTAS = {
	
	-- Welcome to the Dynamic Take And Secure (DTAS) game mode
	-- implemented in Ground Branch by Matt 'Fatmarrow' Farrow
	-- Credits at the end of this file.
	-- 
	-- Please, no lame rip-offs of this game mode. It took a very,
	-- very long time to write, debug and test. It is how it is
	-- for a reason, based on many years of extensive play-testing
	-- back in the day. So if you don't like it, go make something 
	-- different and better...

	-- v0.21+ (version control switched to Perforce)

	-- original DTAS documentation is at https://www.cleeus.de/cms/content/view/35/46/index.html

	StringTables = { "DTAS" },
	
	GameModeAuthor = "(c) BlackFoot Studios, 2021-2022",
	GameModeType = "PVP",

	---------------------------------------------
	----- Game Rules ----------------------------
	---------------------------------------------

	UseReadyRoom = true,
	UseRounds = true,

	AllowUnrestrictedRadio = false,
	AllowUnrestrictedVoice = false,
	SpectateForceFirstPerson = true,
	SpectateFreeCam = false,
	SpectateEnemies = false,
	
	---------------------------------------------
	------- Player Teams ------------------------
	---------------------------------------------

	PlayerTeams = {
		Blue = {
			TeamId = 1,
			Loadout = "Blue",
		},
		Red = {
			TeamId = 2,
			Loadout = "Red",
		},
	},
	
	---------------------------------------------
	---- Game Settings --------------------------
	---------------------------------------------
	
	Settings = {
		RoundTime = {
			Min = 2,
			Max = 30,
			Value = 10,
			AdvancedSetting = false,
		},
		-- number of minutes in each round (default: 10)
		
		FlagPlacementTime = {
			Min = 5,
			Max = 20,
			Value = 10,
			AdvancedSetting = true,
		},
		-- number of seconds before flag is placed after flag carrier is assigned (default: 15)
		
		AutoSwap = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
		-- automatically swap teams around at end of round? (default: yes)

		CaptureTime = {
			Min = 1,
			Max = 60,
			Value = 15,
			AdvancedSetting = true,
		},
		-- number of seconds needed to capture flag (default: 15)

		ForceDTAS = {
			Min = 0,
			Max = 2,
			Value = 0,
			AdvancedSetting = false,
		},
		-- old: if set, DTAS will start regardless of numbers of players present. Some stuff may be cranky (default: no)
		-- new: 0 = don't force game mode, 1 = force DTAS, 2 = force fox hunt
		
		BalanceTeams = {
			Min = 0,
			Max = 3,
			Value = 3,
			AdvancedSetting = false,
		},
		-- settings: 
		-- 0 - off
		-- 1 - light touch
		-- 2 - aggressive
		-- 3 - always

		-- move players around to even up teams. For autobalance 'always', if an odd number of players, give the 1 extra to the attackers each round
		-- (pick a random player to move but try to avoid moving the same person twice or more in a row)
		
		--QuickTeamKits = {
		--	Min = 0,
		--	Max = 3,
		--	Value = 0,
		--	AdvancedSetting = false,
		--},
		-- will probably move this into GB code, but prototyping quick team kits here for now...
	},

	
	ServerSettings = {
	-- TODO this table is currently not used (by the GB infrastructure) - but maybe at some point these will be settable at the server configuration level
		
		ShowBearing = {
			Min = 0,
			Max = 1,
			Value = 1,
		},
		-- show bearing to flag (or asset) to attackers (and defenders), e.g. flag is at NNW
		
		ShowDistance = {
			Min = 0,
			Max = 1,
			Value = 1,
		},
		-- show distance to flag (or asset) to attackers (and defenders), e.g. flag is 40-45m away
		
		ShowCardinalDirection = {
			Min = 0,
			Max = 1,
			Value = 1,
		},
		-- show bearing in cardinal form, e.g. NNW, instead of degrees, e.g. 230 (default: yes)
		
		AttackersNeededToCap = {
			Min = 1,
			Max = 5,
			Value = 2,
		},
		-- need this many attackers in range to start capture countdown (default: 2)
		
		DefendersNeededToDefend = {
			Min = 0,
			Max = 8,
			Value = 2,
		},
		-- this many defenders in range will prevent any cap no matter how many attackers (default: 3)
		-- this number will scale down to number of defenders alive at start of round (won't scale during round)
		
		CaptureRadius = {
			Min = 5,
			Max = 30,
			Value = 15,
		},
		-- the radius of the flag capture zone (cylinder) in m (default: 15m)
		
		CaptureHeight = {
			Min = 5,
			Max = 50,
			Value = 25,
		},
		-- the height of the flag capture zone (cylinder) in m (default: 25m)
		
		ShowInRange = {
			Min = 0,
			Max = 1,
			Value = 1,
		},
		-- show attackers when they are in range of the flag (default: yes)
		
		ShowCapturing = {
			Min = 0,
			Max = 1,
			Value = 1,
		},
		-- show attackers when they are capturing the flag (default: yes)
		
		CaptureIfMoreAttackersThanDefenders	= {
			Min = 0,
			Max = 1,
			Value = 0,
		},
		-- change capture mechanics so flag can be captured if there are simply more attackers than defenders (as well as minimum attacker count being met). Default: no
		
		MinPlayersOnEachTeamForDTAS	= {
			Min = 1,
			Max = 5,
			Value = 2,
		},
		-- players must have this many people on each team before DTAS will kick in (default: 2, in due course should be 3 like in original)
		
		ShowUpDown	= {
			Min = 0,
			Max = 1,
			Value = 1,
		},
		
		FoxHuntSetupTime = {
			Min = 3,
			Max = 20,
			Value = 5,
		},
		
		DisplayYourBearing = {
			Min = 0,
			Max = 1,
			Value = 1,
		},
	},


	---------------------------------------------
	-- general game mode settings/variables -----
	---------------------------------------------

	CurrentDTASGameMode = "FoxHunt",

	DefendingTeam = nil,
	AttackingTeam = nil,
	
	StartingDefendingTeamSize = nil,
	StartingAttackingTeamSize = nil,
	
	CompletedARound = false,
	AbandonedRound = false,
	-- used to determine whether to tell players that they swapped round

	AutoSwap = true,
	AutoSwapCount = 0,
	
	AutoBalanceLightTouchSetting = 0.19,
	AutoBalanceAggressiveSetting = 0.10,
	-- aggressive setting not currently used
	
	ObjectiveInfoUpdateInterval = 1.1,
	-- was 5.0 for text based system
	-- time between updating info on bearing, flag caps, etc
	
	HighlightMovingTargetInterval = 0.15,
	-- how often to update the moving highlight on fox/flag carrier

	MovingTarget = nil,
	-- the player/AI to target with the highlight
	
	PastTeamMovements = {},
	NumberOfPastTeamMovementsToTrack = 6,
	-- record of who was last moved team
	
	CurrentRoundNumber = 0,		
	
	---------------------------------------------
	----- UI stuff ------------------------------
	---------------------------------------------
		
	ScreenPositionRoundInfo = "Lower",
	ScreenPositionScoring = "Lower",
	ScreenPositionError = "Upper",
	ScreenPositionAuxiliaryInfo = "Upper",
	ScreenPositionSetupStatus = "Engine",
	-- "Upper",
	-- TODO "Engine",
	
	TeamBalancingMessageDuration = 8.0,
	
	---------------------------------------------
	----- DTAS mode stuff -----------------------
	---------------------------------------------

	FlagCarrier = nil,
	-- the playerstate of the person or AI who is the currently selected flagcarrier. Only relevant during DTASSetup round
	FlagCarrierIsAI = nil,
	FlagPlacement = nil,
	-- the location (vector) where the flag has been placed at the end of the DTASSetup round
	Flag = nil,
	-- the flag itself
	
	DTASCheckInterval = 0.5,
	-- how often to check for flag caps. Is usefully every second or less, because it is used to count time
		
	LastDTASStatus = nil,
	CurrentFlagCaptureTime = 0,
	-- time that flag has spent attacked

	PastFlagCarriers = {},
	NumberOfPastFlagCarriersToTrack = 4,
	-- this tracks previous selections of flag carrier to avoid (if possible) selecting the same person in consecutive rounds

	UpDownHeightThreshold = 2.0 * 100,
	-- how much height difference between player and flag before displaying Up/Down

	---------------------------------------------
	----- fox hunt stuff ------------------------
	---------------------------------------------
	
	FoxPlayer = nil,
	-- the playerstate of the person or AI who is the currently selected Asset (fox).
	FoxPlayerIsAI = nil,
	
	FoxDisableBearing = true,
	FoxDisableDistance = false,
	-- whether to override the default settings for Fox Hunt mode

	PastFoxes = {},
	NumberOfPastFoxesToTrack = 4,
	-- this tracks previous selections of foxes to avoid (if possible) selecting the same person in consecutive rounds

	FoxHuntTimeMultiple = 0.7,
	-- this is the proportion of the normal round time to use for fox hunts
	-- roundish number preferred because it messes up the time remaining countdown

	---------------------------------------------
	-- custom scoring stuff ---------------------
	---------------------------------------------
	
	-- player score types includes score types for both attacking and defending players
	PlayerScoreTypes = {
		SurvivedRound = {
			Score = 1,
			OneOff = true,
			Description = "Survived round",
		},
		WonRound = {
			Score = 1,
			OneOff = true,
			Description = "Team won the round",
		},
		DiedInRange = {
			Score = 1,
			OneOff = true,
			Description = "Died within range of flag",
		},
		SurvivedInRange = {
			Score = 1,
			OneOff = true,
			Description = "Within range of flag at round end",
		},
		Killed = {
			Score = 1,
			OneOff = false,
			Description = "Kills",
		},
		LastKill = {
			Score = 1,
			OneOff = true,
			Description = "Got last kill of the round",
		},		
		InRangeOfKill = {
			Score = 1,
			OneOff = false,
			Description = "In proximity of someone who killed",
		},
		TeamKill = {
			Score = -4,
			OneOff = false,
			Description = "Team killed!",
		},
		CapturedFlag = {
			Score = 10,
			OneOff = true,
			Description = "Captured the flag",
		},
		PreventedCapture = {
			Score = 2,
			OneOff = true,
			Description = "Prevented a capture",
		},
		DefenderOutsideRange = {
			Score = -3,
			OneOff = true,
			Description = "Was outside range of flag when it was captured",
		},		
		-- now some fox hunt scoring
		KilledAsset = {
			Score = 2,
			OneOff = true,
			Description = "Killed the Asset",
		},
		CloseToAssetRoundEnd = {
			Score = 1,
			OneOff = true,
			Description = "Was near Asset at round end",
		},		
		SurvivingAsset = {
			Score = 2,
			OneOff = true,
			Description = "Survived as Asset",
		},
		SurvivingAssetByTime = {
			Score = 2,
			OneOff = true,
			Description = "Survived as Asset until round time-out",
		},
		DyingAssetDefsAlive = {
			Score = -4,
			OneOff = true,
			Description = "Died as Asset while defenders were alive",
		},
	},
	
	
	-- team score types includes scores for both attackers and defenders
	TeamScoreTypes = {
		WonRound = {
			Score = 2,
			OneOff = true,
			Description = "Team won the round",
		},
		DefenderTimeout  = {
			Score = 6,
			OneOff = true,
			Description = "Defenders held out until end of time limit",
		},
		DiedInRange = {
			Score = 2,
			OneOff = true,
			Description = "At least one team member died in flag range",
		},
		SurvivedInRange = {
			Score = 1,
			OneOff = true,
			Description = "At least one team member survived in flag range",
		},
		Killed = {
			Score = 1,
			OneOff = false,
			Description = "Kills by team",
		},
		InRangeOfKill = {
			Score = 1,
			OneOff = false,
			Description = "Team member in proximity of someone who killed",
		},		
		TeamKill = {
			Score = -4,
			OneOff = false,
			Description = "Team kills",
		},
		CapturedFlag = {
			Score = 10,
			OneOff = true,
			Description = "Team captured the flag",
		},
		PreventedCapture = {
			Score = 2,
			OneOff = true,
			Description = "Team prevented a flag capture",
		},
		DefenderOutsideRange = {
			Score = -3,
			OneOff = true,
			Description = "A defender was outside range of flag when captured",
		},	
	-- now some fox hunt scoring
		AssetKilled = {
			Score = 2,
			OneOff = true,
			Description = "Asset was killed",
		},
		CloseToAssetRoundEnd = {
			Score = 1,
			OneOff = true,
			Description = "At least one defender was near Asset at round end",
		},	
		AssetSurvived = {
			Score = 2,
			OneOff = true,
			Description = "Asset survived",
		},
		AssetSurvivedByTime = {
			Score = 2,
			OneOff = true,
			Description = "Asset survived until round time-out",
		},
		AssetDiedDefsAlive = {
			Score = -3,
			OneOff = true,
			Description = "Asset died while defenders were alive",
		},		
	},
	
	
	ScoringKillProximity = 10,
	-- how near a player has to be to another to count as 'near' for a killing (in metres)
	-- was 7.5
	
	ScoringFoxPromixity = 10,
	-- how near a player has to be to the asset to count as 'near' at round end
	
	LastKiller = nil,
	-- playerstate of last player to kill someone
	
	
	---------------------------------------------
	-- bearing and distance stuff ---------------
	---------------------------------------------
	
	BearingDistanceQuantisation = 5,
	-- the granularity of distance readouts (e.g. 5 -> 45-50m, 10 -> 30-40m, etc)
	-- SUPERSEDED by BearingDistanceRangeAndQuantisation
	
	BearingDistanceMaxRange = 100,
	-- after this range, you will get 100m+ displayed (or whatever m+)
	-- SUPERSEDED by BearingDistanceRangeAndQuantisation
	
	BearingDisplayTime = 3,
	-- time to display bearing on screen
	
	BearingQuantisation = 5,
	-- the number of degrees to quantize (numerical) bearings to
	
	BearingDistanceRangeAndQuantisation = {
		{ 50, 5, },
		{ 100, 10, },
		{ 400, 50, },
		{ 1000, 100, },
	},
	
	CardinalBearingLookUp = { "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",},
	
	---------------------------------------------
	------------- AI stuff ----------------------
	---------------------------------------------
	
	OpForTeamTag = "OpFor",

	---------------------------------------------
	--------- spawning management ---------------
	---------------------------------------------

	AttackerInsertionPoints = {},
	DefenderInsertionPoints = {},
	-- initially this will hold all generated spawn points (as vector locations). As spawns fail, the relevant spawns will be removed 
	-- from these lists. 
	
	--CurrentAttackerInsertionPointIndex = 0,
	--CurrentDefenderInsertionPointIndex = 0,
	CurrentInsertionPointIndex = {},
	-- indices are TeamId
	CurrentInsertionPointIndexHasLooped = {},
	-- indices are TeamId, true if has looped round to first spawn again for this team
	
	BadSpawnCheckTime = 2.0,
	-- check for bad spawns every 2 seconds
 
	SpawnAttempts = {},
	-- tracks player, teamID and spawn index:
	-- SpawnAttempts.PlayerState, SpawnAttempts.TeamId, SpawnAttempts.SpawnInfo, SpawnAttempts.SpawnIndex, SpawnAttempts.AttemptsMade, SpawnAttempts.HasLooped

	MaximumSpawnAttemptsForPlayer = 11,

	NumberOfSpawnAttemptCycles = 0,
	MaximumSpawnAttemptCycles = 10,
	-- number of times to attempt respawns for everyone
	
	FailedSpawns = {},
	-- for posterity, keep a list of the bad spawns
	-- TODO (might be nice to be able to grab map name)
 
	PlayersWaitingToSpawnIn = {},
	-- if there is a shortfall in available spawns, players may have to wait to spawn
	-- they will be listed here (it may instead be possible just to iterate through active players to find those not in play area)
	
	--NonClickersIn = {},
	-- .Player = the player
	-- .ConsecutiveRounds = number of consecutive rounds not clicked in
	-- .TotalRounds = number of total rounds not clicked in
	-- .ConsecutiveRoundsClickedIn = number of consecutive rounds clicked in, leading to 'forgiveness'
	
	NumberOfRoundsBeforeForgiveNonClickers = 3,
	-- if someone has clicked in for 3 rounds, all is forgiven
	
	PreRoundWaitWelcomeCount = 0,
	
	---------------------------------------------
	--------random spawn finding configuration---
	---------------------------------------------

	--GameModeObjectTypes = { 'GroundBranch.GBInsertionPoint', 'GroundBranch.GBPlayerStart', 'GroundBranch.GBAISpawnPoint', 'GroundBranch.GBAIGuardPoint', 'GroundBranch.GBAIPatrolRoute', 'GroundBranch.BP_Laptop_Usable_C', },
	GameModeObjectTypes = { 'GroundBranch.GBPlayerStart', 'GroundBranch.GBAISpawnPoint', 'GroundBranch.GBAIGuardPoint', 'GroundBranch.GBAIPatrolRoute', },
	-- insertion points must be listed before player starts, because reasons
	
	GameModeObjectTypesUseForRandomSpawns = { 'GroundBranch.GBPlayerStart', 'GroundBranch.GBAISpawnPoint', 'GroundBranch.GBAIGuardPoint', },
	-- use these specific game mode objects to use for random walks to find random spawns
	-- TODO add bomb type
	
	
	NumberObjectsToTestAsUnreachable = 10,
	-- test up to this many other objects to see if it is unreachable
	-- (not using at present - caused performance issues - juddering in RR)
	
	GameModeObjects = {},
	-- GameModeObjects contains things like insertion points and AI actors to try and define the bounds of the play area
	
	VoxelsOfInterest = {},
	-- this identifies sub-cubes in the game object space that contain game objects (to try and 
	VoxelsXY = 8,
	-- divide X and Y into this many subdivisions
	VoxelsZ = 8,
	-- divide Z into this many subdivisions
	
	
	UnreachableGameModeObjects = {},
	-- UnreachableGameModeObjects is the subset of GameModeObjects that can't be reached from any player spawn (so must be behind doors, etc.)
	-- we assume that no game mode objects are placed 'off the grid'
	-- (not using at present)
	
	GameModeObjectsUseForRandomSpawns = {},
	
	RandomNavMeshTestObject = nil,

	GameObjectBoundingBox = {},
	
	SpawnsLargestDiagonalDivisor = 4,
	-- spawns smaller than largest diagonal divided by this number will start to be penalised
	
	--SpawnsMinimumTeamSeparation = 150.0 * 100,
	SpawnsMinimumTeamSeparation = 90.0 * 100,
	-- progressively penalise spawns closer than at least 90m --150m
	
	SpawnsMaximumTeamSeparation = 750.0 * 100,
	-- don't want spawns more than 750m away (nearly 1km!)

	PlayerCapsuleHalfHeight = 100,
	PlayerCapsuleRadius = 40,
	-- size for collision checking when spawning flags and players, etc

	
	---------------------------------------------
	--------- spawn finding routine proper ------
	---------------------------------------------

	SpawnsLastSpawns = {},
	-- track the last two base spawn locations (should probably track four since teams flip each round)
	
	SpawnsLastSpawnsMaxNumber = 2 * 2,
	-- track the last two rounds of spawn locations (for scoring proximity to old spawns)
	
	SpawnsNumberOfCandidateSpawnListsToEvaluate = 10,
	-- number of candidate spawn sets to pick based on random point in map (includes random point sets and game object walk sets)
	
	SpawnsProportionOfGameObjectWalksToEvaluate = 0.5,
	--SpawnsProportionOfGameObjectWalksToEvaluate = 0.0,
	-- proportion of candidate spawn sets to pick based on random walk from game object (AI spawn, AI patrol point, laptop, etc)
	-- should be 0 < x < 1
	
	SpawnsNumberOfTriesToFindReachableGameObject = 150,
	-- try up to 100 attempts to path to a random game object from a candidate spawn
	
	SpawnsMinimumNumberOfGameModeObjectsRequiredForRandomWalk = 6,
	-- if there are fewer than this many random game objects, don't use them as basis for random spawns
	
	--SpawnsNumberOfRandomPointsSelectedFromVoxels = 2,
	-- choose at least this many random points using the voxel system (downside - will cluster spawns near game objects, not in the inbetween spaces)
	
	--SpawnsExtraUnreachableObjectsToTry = 1,
	-- force using this many 'unreachable' game objects in the spawn search
	
	SpawnsExtraRandomizeStep = true,
	-- carry out a random walk from random points on mesh to increase randomness

	SpawnsExtraRandomizeStepSearchLengthMultiplier = 5.0,
	-- how much to extend the random walk on the RandomizeStepSearch process
	-- (not used?)
	
	SpawnsGameObjectRandomWalkLength = 100 * 100.0,
	-- how far to look for spawn from random game object (10000 UE4 units = 100m but average distance will be 50m)
	
	SpawnsRandomPointRandomWalkLength = 20 * 100.0,
	-- how far to look for spawn from random point on nav mesh (to mix it up a bit) e.g. 20m
	
	SpawnsNumberOfSpawnPointsToFind = 8,
	-- total number of spawn points to find for each spawn point set
	-- GB (ideal) max server load is 8 per side
	-- also ideal max player count for DTAS mode
	
	SpawnsNumberOfTriesToFindMainSpawn = 10,
	-- number of times to attempt to find a valid random point on navmesh
	
	SpawnsNumberOfTriesToFindEachSubSpawn = 5,
	-- number of times (for each sub spawn) to attempt to find a valid sub spawn location near a base spawn location

	SpawnsNumberOfHardFailsToPermit = 3,
	-- number of bad fails (can't find a valid random point on mesh) to allow before giving up
	-- default 3

	SpawnsInitialSpawnCheckRadius = 200.0,
	-- initial search radius for finding sub spawns, though 'it's complicated'
	
	SpawnsMultiplySpawnCheckRadius = 2.0,
	-- enlarges the spawn check radius for sub spawns. Bigger than 1 will give looser clusters but may help find spawns inside

	SpawnsMinimumSpawnSeparation = 1 * 100.0,
	-- minimum distance in UE4 units (cm) between different spawn points

	---------------------------------------------
	---- spawn scoring configuration ------------
	---------------------------------------------

	SpawnsScorePenaliseProximityDistance = 0.0,
	-- any spawns nearer than this (10000.0 UE4 units = 100m) get penalised progressively
	-- this is written in based on the largest diagonal detected
	
	SpawnsScorePenaliseProximity = 1.0,
	-- the severity with which close spawns are penalised (1.0 is standard)

	SpawnsScorePenaliseShortfall = 1.0,
	-- the severity with which spawn point shortfalls (couldn't find all requested points) are penalised (1.0 is standard)
	
	SpawnsScorePenaliseDistanceFromOldSpawns = 1.0,
	-- the severity with which proximity to previous spawn points is penalised (1.0 is standard)
	
	SpawnsScoreSpawnsNotReachableFromEachOther = 1.5,
	-- give greater weight to spawns not being attached on the navmesh (which is good because e.g. one is in building, one not)
	
	DistanceZMultiplier = 4.5,
	-- this means that z separation of spawns is given more importance (in deciding if spawns are too close)
	
	---------------------------------------------
	--- temporary / miscellaneous / hacky stuff -
	---------------------------------------------
	
	TmpAttackPoints = {},
	TmpDefendPoints = {},
	TimerIncrement = 0,
	-- temporary fix to allow spawning in
	
}





------------------ init functions ----------------

function DTAS:PreInit()

	self.FinishedRoundProperly = false

	self:ResetAllScores()
	
	gamemode.SetTeamScoreTypes( self.TeamScoreTypes )
	gamemode.SetPlayerScoreTypes( self.PlayerScoreTypes )
	-- set up the score types in gamestate
	-- need this done only once at init
	gamemode.SetGameModeName('DTAS')
		
	self.CurrentRoundNumber = 1
	-- this will be incremented by 1 at start of first round
	-- this is no longer needed - now tracked in AGBGameState as part of match stuff

	gamemode.SetRoundStage("WaitingForReady")
	
end


function DTAS:PostInit()
	-- need to set this earlier than before so that the following code doesn't hiccup
	self.DefendingTeam = self.PlayerTeams.Blue
	self.AttackingTeam = self.PlayerTeams.Red

	gamemode.ClearGameObjectives()
	
	gamemode.AddGameObjective(self.DefendingTeam.TeamId, "DefendObjectiveDTAS", 1)
	gamemode.AddGameObjective(self.AttackingTeam.TeamId, "CaptureObjectiveDTAS", 1)

	gamemode.AddGameObjective(self.DefendingTeam.TeamId, "KillAllAttackers", 2)
	gamemode.AddGameObjective(self.AttackingTeam.TeamId, "KillAllDefenders", 2)

	-- at this point, game mode name is already set to DTAS
	
	-- now, we may end up playing Fox Hunt so these objectives will be bogus, but best have something up when round starts
end


----------------------- end init routines -----------------------



----------------------- handle starting round in ready room -----


function DTAS:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
    if ReadyStatus == "DeclaredReady" then
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false);
	elseif ReadyStatus == "WaitingToReadyUp" or ReadyStatus == "NotReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false);
    end
end

-- this replaces PlayerInsertionPointChanged(), at least when no insertion points are enabled



function DTAS:CheckReadyUpTimer()
	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(false)
		local DefendersReady = ReadyPlayerTeamCounts[self.DefendingTeam.TeamId]
		local AttackersReady = ReadyPlayerTeamCounts[self.AttackingTeam.TeamId]

		if (DefendersReady > 0 and AttackersReady > 0) or gamemode.GetPlayerCount(true) == 1 then
			if DefendersReady + AttackersReady >= gamemode.GetPlayerCount(true) then
				self:GiveEveryoneReadiedUpStatus()
				-- do this before calling balanceteams
				self:BalanceTeams()
				gamemode.SetRoundStage("PreRoundWait")
			else
				gamemode.SetRoundStage("ReadyCountdown")
			end
		end
	end
end



function DTAS:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local DefendersReady = ReadyPlayerTeamCounts[self.DefendingTeam.TeamId]
		local AttackersReady = ReadyPlayerTeamCounts[self.AttackingTeam.TeamId]
		if DefendersReady < 1 or AttackersReady < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

----------------------- end handle starting round in ready room ---




------------ round stage handling --------------------------------------


-- Game Round Stages:

-- WaitingForReady	-- players are in ready room at start of game/map/set of rounds
-- ReadyCountdown	-- at least one player has clicked on map
-- PreRoundWait		-- players have been spawned into the level but are frozen (to allow all other players to spawn in)
-- *FoxHuntSetup		-- all players are frozen and can't shoot except Fox
-- *FoxHuntInProgress	-- Fox Hunt round is in progress
-- *DTASSetup		-- both sides can move but neither can shoot. Defenders are finding place for flag
-- *DTASInProgress	-- DTAS round is in progress
-- PostRoundWait	-- round has ended, post round info is displayed
-- TimeLimitReached	-- round timed out
-- *RoundAbandoned   -- pause at end of round but do not switch teams after
--
-- * = custom round stages


function DTAS:OnRoundStageSet(RoundStage)

	if RoundStage == "WaitingForReady" then

		self:ResetRound()
		-- clears timers
	
		--print("DTAS: ****RoundStage WaitingForReady")
		self:SetupRound()
		
		gamemode.SetWatchMode( "ObjectiveFinder", false, false, true, false )
		gamemode.ResetWatch()
		
		
	elseif RoundStage == "ReadyCountdown" then
		-- do nothing (extra)
			
	elseif RoundStage == "PreRoundWait" then
		--print("DTAS: ****RoundStage PreRoundWait")
		-- default PreRoundWait round stage time is set in SetupRound() (12 seconds)
		
		self:ResetRoundScores()

		self:MakeListOfPlayersAttemptingToSpawn()

		-- was:
		self:ShowAttackersDefendersMessage("PrepareToAttack", "PrepareToDefend", self.ScreenPositionRoundInfo, 3.0)
		-- does not appear to do anything? or gets overwritten
				
		self:SetupSpawns()

		self:CheckForBadSpawnsSetTimer(true)
		-- true = first time use, wait a little longer
			
		self.PreRoundWaitWelcomeCount = 0
		timer.Set("PreRoundWaitWelcome", self, self.PreRoundWaitWelcomeTimer, 1.0, false)
			
		-- don't setup DTAS stuff yet because more players may join, and it's not clear if we'll have fox hunt instead
				
	elseif RoundStage == "FoxHuntSetup" then
		--print("DTAS: ****RoundStage FoxHuntSetup")
		self:SetupRoundFoxHunt()
		self:DisableWeaponsForAll()
		
		gamemode.SetRoundStageTime(self.ServerSettings.FoxHuntSetupTime.Value + 2.0)
		-- could make this an adjustable game setting, but it is a bit niche
		-- add a bit to time
		
		gamemode.SetDefaultRoundStageTime("InProgress", math.ceil(self.Settings.RoundTime.Value * self.FoxHuntTimeMultiple) )
		-- need to update this as ops board setting may have changed - have to do this before RoundStage InProgress to be effective
	
	
	elseif RoundStage == "DTASSetup" then
		--print("DTAS: ****RoundStage DTASSetup")
		self:SetupRoundDTAS()
		self:DisableWeaponsForAll()

		self:ShowHintsDTASSetup()
		
		gamemode.SetRoundStageTime(self.Settings.FlagPlacementTime.Value + 2.0)
		-- add a bit to the time as a bit gets eaten up
		
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
		-- need to update this as ops board setting may have changed - have to do this before RoundStage InProgress to be effective
		
	
	elseif RoundStage == "DTASInProgress" then
		--print("DTAS: ****RoundStage DTASInProgress")
		self:ClearHighlightMovingTargetTimer()
		
		timer.Set("DTASShowHint", self, self.ShowHintsDTASInProgress, math.max(12, self.Settings.FlagPlacementTime.Value + 2.0), false)
		
		if self:PlaceFlag() then
			self:EnableWeaponsForAll()

			timer.Set("DTASChecks", self, self.DTASChecksTimer, self.DTASCheckInterval, true)

			gamemode.SetRoundStageTime(self.Settings.RoundTime.Value * 60)
		end
		
		
	elseif RoundStage == "FoxHuntInProgress" then
		--print("DTAS: ****RoundStage FoxHuntInProgress")
		self:ClearHighlightMovingTargetTimer()

		self:EnableWeaponsForAll()

		timer.Set("ObjectiveInfoDisplay", self, self.ReportObjectiveLocationToGame, self.ObjectiveInfoUpdateInterval, true)
		self:ReportObjectiveLocationToGame()
		-- set timer and call it immediately also

		gamemode.SetRoundStageTime( math.ceil(self.Settings.RoundTime.Value * self.FoxHuntTimeMultiple) * 60)
		-- FoxHuntTimeMultiple messes up our time reminders. Never mind, try and set it to a round number?
		
		
	elseif RoundStage == "PostRoundWait" then
		--print("DTAS: ****RoundStage PostRoundWait")

		self.CompletedARound = true
		self.AbandonedRound = false
			
		-- finalise scoring at end of PostRoundWait
		
		gamemode.SetRoundStageTime(5)
		
		
	elseif RoundStage == "RoundAbandoned" then
		--print("DTAS: ****RoundStage RoundAbandoned")
		self:DisableWeaponsForAll()
	
		self.CompletedARound = false
	
		gamemode.SetRoundStageTime(5)	
		
	end
end


function DTAS:PreRoundWaitWelcomeTimer()
	-- this is a big faff but probably needed because players may join over the course of seconds and miss a single broadcast message

	self.PreRoundWaitWelcomeCount = self.PreRoundWaitWelcomeCount + 1
	
	self:ShowAttackersDefendersMessage("WaitForRoundStartAttacker", "WaitForRoundStartDefender", self.ScreenPositionRoundInfo, -1.5)
	-- negative time means flush last message
	
	if self.PreRoundWaitWelcomeCount == 3 then
		if self.AttackingTeam.TeamId == self.PlayerTeams.Red.TeamId then
			self:ShowAttackersDefendersMessage("YouAreAttackerRed", "YouAreDefenderBlue", self.ScreenPositionSetupStatus, math.max(3.0, self.Settings.FlagPlacementTime.Value))
		else
			self:ShowAttackersDefendersMessage("YouAreAttackerBlue", "YouAreDefenderRed", self.ScreenPositionSetupStatus, math.max(3.0, self.Settings.FlagPlacementTime.Value))
		end
	end
	
	if (self.PreRoundWaitWelcomeCount < 8) then
		timer.Set("PreRoundWaitWelcome", self, self.PreRoundWaitWelcomeTimer, 1.0, false)
	end
end


function DTAS:GiveEveryoneReadiedUpStatus()
	-- anyone who is waiting to ready up (in ops room) is assigned ReadiedUp status (just keep life simple)

	local EveryonePlayingList = self:GetPlayerListByStatus(255, true, "WaitingToReadyUp")

	if #EveryonePlayingList > 0 then
		for _, Player in ipairs(EveryonePlayingList) do
			player.SetReadyStatus(Player, "DeclaredReady")
		end
	end

end


function DTAS:ShowHintsDTASSetup()
	-- TODO - do same for fox hunt

	local Attackers = self:GetPlayerListIsPlaying(self.AttackingTeam.TeamId, true)
	local Defenders = self:GetPlayerListIsPlaying(self.DefendingTeam.TeamId, true)

	for _, Player in ipairs(Attackers) do
		player.ShowHint( Player, "DTASPlacementPhaseAttacker", "WBP_DTAS_PlacementPhaseAttacker_Hint" )
	end

	for _, Player in ipairs(Defenders) do
		if self.FlagCarrier ~= nil then
			if self.FlagCarrier == Player then
				player.ShowHint( Player, "DTASPlacementPhaseYourTurn", "WBP_DTAS_PlacementPhaseYourTurn_Hint" )
			else
				player.ShowHint( Player, "DTASPlacementPhaseDefender", "WBP_DTAS_PlacementPhaseDefender_Hint" )
			end
		else
			player.ShowHint( Player, "DTASPlacementPhaseDefender", "WBP_DTAS_PlacementPhaseDefender_Hint" )
		end
	end
end


function DTAS:ShowHintsDTASInProgress()
	-- TODO - do same for fox hunt

	local Attackers = self:GetPlayerListIsPlaying(self.AttackingTeam.TeamId, true)
	local Defenders = self:GetPlayerListIsPlaying(self.DefendingTeam.TeamId, true)

	for _, Player in ipairs(Attackers) do
		player.ShowHint( Player, "DTASInProgressPhaseAttacker", "WBP_DTAS_InProgressPhaseAttacker_Hint" )
	end

	for _, Player in ipairs(Defenders) do
		player.ShowHint( Player, "DTASInProgressPhaseDefender", "WBP_DTAS_InProgressPhaseDefender_Hint" )
	end
end


function DTAS:HandleRestartRoundCommand()
	-- we have to handle all this ourselves
	
	local RoundStage = gamemode.GetRoundStage()

	if RoundStage == "WaitingForReady"
	or RoundStage == "ReadyCountdown"
	or RoundStage == "PostRoundWait"
	or RoundStage == "RoundAbandoned" then

		gamemode.BroadcastGameMessage("CantRestartRoundNow", self.ScreenPositionError, 5.0)

		return false
		-- don't take it
	else

		self:AbandonRound("RoundRestarted")
		
		return true
		-- don't override default handling
	
	end
end


function DTAS:MakeListOfPlayersAttemptingToSpawn() 

	-- fill up self.PlayersWaitingToSpawnIn with all players currently readied up
	-- we keep trying to spawn players until all are in

	self.PlayersWaitingToSpawnIn = {}
	
	local EveryonePlayingList = self:GetPlayerListIsPlaying(255, true)

	for _, Player in ipairs(EveryonePlayingList) do
		table.insert( self.PlayersWaitingToSpawnIn, Player )
	end

end


function DTAS:CheckForBadSpawnsSetTimer(FirstTime)

	local WaitTime
	
	if FirstTime then
		--WaitTime = self.BadSpawnCheckTime * 1.5
		WaitTime = self.BadSpawnCheckTime * 2.5
		-- increased due to longer preroundwait time
	else
		WaitTime = self.BadSpawnCheckTime
	end

	-- set a timer to check for any remaining bad spawns
	timer.Set("CheckForBadSpawns", self, self.CheckForBadSpawnsTimer, self.BadSpawnCheckTime, false)

	-- not automatically repeating
	-- will only repeat (self.MaximumSpawnAttemptCycles) times
end


function DTAS:CheckForBadSpawnsTimer()

	--local AttackerPlayers = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, true)	
	--print("CheckForBadSpawnsTimer: number of attackers with lives current = " .. #AttackerPlayers)

	if #self.PlayersWaitingToSpawnIn > 0 then
		print( "CheckForBadSpawnsTimer: Cycle " .. self.NumberOfSpawnAttemptCycles .. " - " .. #self.PlayersWaitingToSpawnIn .. " players remaining to spawn in.")

		for _, Player in ipairs(self.PlayersWaitingToSpawnIn) do
			self:SpawnFailedForPlayer(Player)
			-- try to respawn
		end

		self.NumberOfSpawnAttemptCycles = self.NumberOfSpawnAttemptCycles + 1
		if self.NumberOfSpawnAttemptCycles <= self.MaximumSpawnAttemptCycles then
			print( "CheckForBadSpawnsTimer: trying another cycle of spawns")
			-- set another timer
			self:CheckForBadSpawnsSetTimer(false)
		else
			print("CheckForBadSpawnsTimer: Limit reached of attempts to spawn. Not trying again. Consider restarting round.")
		end
	
	end
end


function DTAS:GetReliablePlayerTeamCounts()
	local ReturnValue = {}
	
	local TmpList

	TmpList = self:GetPlayerListIsPlaying(self.DefendingTeam.TeamId, true)
	ReturnValue[self.DefendingTeam.TeamId] = #TmpList
	
	TmpList = self:GetPlayerListIsPlaying(self.AttackingTeam.TeamId, true)
	ReturnValue[self.AttackingTeam.TeamId] = #TmpList
	
	return ReturnValue
	
end


function DTAS:AutoBalanceIsRequired(DefendersReady, AttackersReady)

	-- BalanceTeams settings: 
	-- 0 - off
	-- 1 - light touch
	-- 2 - aggressive
	-- 3 - always

	if DefendersReady + AttackersReady <= 0 then
		-- I mean, it's all fucked up anyway
		return false
	end

	local TotalPlayers = DefendersReady + AttackersReady
	
	if "Method" == "Old" then
		local IdealDefenders = math.floor(TotalPlayers/2)
		-- rounds down if odd number of players in total - we want more attackers than defenders in this case
		local IdealAttackers = TotalPlayers - IdealDefenders

		local AutoBalanceThreshold
		
		if self.Settings.BalanceTeams.Value == 1 then
			AutoBalanceThreshold = self.AutoBalanceLightTouchSetting
		elseif self.Settings.BalanceTeams.Value == 2 then
			AutoBalanceThreshold = self.AutoBalanceAggressiveSetting
		end

		local ImbalanceRatio = math.abs(DefendersReady - IdealDefenders) / TotalPlayers
			
		--print("AutoBalanceIsRequired: DefendersReady = " .. DefendersReady .. " AttackersReady = " .. AttackersReady .. " / IdealDefenders = " .. IdealDefenders)
		--print("AutoBalanceIsRequired: ImbalanceRatio = " .. ImbalanceRatio)

		if ImbalanceRatio > AutoBalanceThreshold then
			--print("AutoBalanceIsRequired: Balancing is required. Threshold of " .. AutoBalanceThreshold .. " exceeded.")
			return true
		else
			return false
		end
	end
	-- ^ old method, mathematically more precise but would balance teams in attack that would not be balanced in defence -> annoying for everyone in a match

	-- new method, simpler to understand and symmetric:
	
	if TotalPlayers <= 2 then
		-- 1 player is special case because of AI, typically want to be attacker
		-- 2 player will always be balanced, but game can't start imbalanced anyway
		return true
	end
	
	local PlayerGapLessOne = math.max( 0, math.abs( DefendersReady - AttackersReady ) - 1 )
	-- PlayerGapLessOne = 0 for difference between defenders and attackers of 0 or 1, else 1 for gap of 2, 2 for gap of 3, ...
	-- we always tolerate a gap of 1 because in some cases this may be the 'ideal' distribution for odd numbers of players, e.g. 4 attackers, 3 defenders (1 attacker more than defender)
	-- (we don't look specifically at whether attackers > defenders or vice versa so that the method is symmetric and won't balance teams half way through a match when roles swap)
	-- (this is judged to be more important than getting perfect balance)

	if self.Settings.BalanceTeams.Value == 1 then
		-- light touch balancing
		--AutoBalanceThreshold = self.AutoBalanceLightTouchSetting
		
		local ImbalanceRatio = PlayerGapLessOne / TotalPlayers
		
		if ImbalanceRatio > self.AutoBalanceLightTouchSetting or TotalPlayers <= 6 then
			-- special exception to always balance if have 6 players or fewer (otherwise 4v2 or 2v4 won't balance, and that probably should)
				
			--print("AutoBalanceIsRequired: Balancing is required. Threshold of " .. AutoBalanceThreshold .. " exceeded.")
			return true
		else
			return false
		end
		
	elseif self.Settings.BalanceTeams.Value == 2 then
	-- or self.CurrentDTASGameMode == 'FoxHunt'
		-- aggressive balancing - don't permit more than a difference of 1 in team numbers (but a difference of 1 is ok in either direction)
		--(NO - WHY?)  use aggressive balancing for fox hunt even if balance always is selected (because that is specific to DTAS)
		
		if PlayerGapLessOne > 0 then
			-- balance if difference > 1, and that's it
			return true
		else
			return false
		end
		
		
	elseif self.Settings.BalanceTeams.Value == 3 then
	-- setting of 3 is 100% aggressive and complete balancing
		return true
		
	end
end


function DTAS:BalanceTeams() 
		
	local MovedPlayersList = {}

	local ReadyPlayerTeamCounts = self:GetReliablePlayerTeamCounts()
	
	local DefendersReady = ReadyPlayerTeamCounts[self.DefendingTeam.TeamId]
	local AttackersReady = ReadyPlayerTeamCounts[self.AttackingTeam.TeamId]

	--print("BalanceTeams: Defender count = " .. DefendersReady .. " / Attacker count = " .. AttackersReady)

	local DefendersMoved = {}
	local AttackersMoved = {}

	if self.Settings.BalanceTeams.Value >= 1 then

	-- if there is only one player in game, they will always be moved to the attacking team
	-- I think this is a good thing

		while DefendersReady > AttackersReady and self:AutoBalanceIsRequired(DefendersReady, AttackersReady) do
			--print("shifting defender to attack")
			PlayerToMove = self:PickRandomPlayerToMove(self.DefendingTeam.TeamId)
			if PlayerToMove ~= nil then
				table.insert(DefendersMoved, PlayerToMove)
				actor.SetTeamId(PlayerToMove, self.AttackingTeam.TeamId)
				player.ShowGameMessage(PlayerToMove, "MovedToAttackTeam", self.ScreenPositionAuxiliaryInfo, self.TeamBalancingMessageDuration)
				gamemode.PrepLatecomer(PlayerToMove)
			end
			
			AttackersReady = AttackersReady + 1
			DefendersReady = DefendersReady - 1
		end	

		while (AttackersReady - DefendersReady) > 1 and self:AutoBalanceIsRequired(DefendersReady, AttackersReady) do
			--print("shifting attacker to defend")
			PlayerToMove = self:PickRandomPlayerToMove(self.AttackingTeam.TeamId)
			if PlayerToMove ~= nil then
				table.insert(AttackersMoved, PlayerToMove)
				actor.SetTeamId(PlayerToMove, self.DefendingTeam.TeamId)
				player.ShowGameMessage(PlayerToMove, "MovedToDefendTeam", self.ScreenPositionAuxiliaryInfo, self.TeamBalancingMessageDuration)
				gamemode.PrepLatecomer(PlayerToMove)
			end
			
			AttackersReady = AttackersReady - 1
			DefendersReady = DefendersReady + 1
		end
	end
	
	-- now update everyone else
	
	if #DefendersMoved > 0 then
	
		local AttackingTeamList = self:GetPlayerListIsPlaying(self.AttackingTeam.TeamId, true)
		local DefendingTeamList = self:GetPlayerListIsPlaying(self.DefendingTeam.TeamId, true)
		
		-- not appropriate to replace with GetLivingPlayerList() because we want readied up people with no lives
	
		for _, Player in ipairs(AttackingTeamList) do
			if not self:IsInList(Player, DefendersMoved) then
				local InfoMessage = "PlayersMovedIntoTeam" .. #DefendersMoved
				player.ShowGameMessage(Player, InfoMessage, self.ScreenPositionAuxiliaryInfo, self.TeamBalancingMessageDuration)
			end
		end
		
		for _, Player in ipairs(DefendingTeamList) do
			local InfoMessage = "PlayersMovedOutOfTeam" .. #DefendersMoved
			player.ShowGameMessage(Player, InfoMessage, self.ScreenPositionAuxiliaryInfo, self.TeamBalancingMessageDuration)
		end
		
	elseif #AttackersMoved > 0 then
	
		local AttackingTeamList = self:GetPlayerListIsPlaying(self.AttackingTeam.TeamId, true)
		local DefendingTeamList = self:GetPlayerListIsPlaying(self.DefendingTeam.TeamId, true)
	
		for _, Player in ipairs(DefendingTeamList) do
			if not self:IsInList(Player, AttackersMoved) then
				local InfoMessage = "PlayersMovedIntoTeam" .. #AttackersMoved
				player.ShowGameMessage(Player, InfoMessage, self.ScreenPositionAuxiliaryInfo, self.TeamBalancingMessageDuration)
			end
		end
		
		for _, Player in ipairs(AttackingTeamList) do
			local InfoMessage = "PlayersMovedOutOfTeam" .. #AttackersMoved
			player.ShowGameMessage(Player, InfoMessage, self.ScreenPositionAuxiliaryInfo, self.TeamBalancingMessageDuration)
		end
		
	end
end


function DTAS:GetPlayerListByStatus(TeamId, OnlyHumans, Status)
	-- Status = "WaitingToReadyUp", "DeclaredReady" or "NotReady"
	-- anything else will just return an empty list

	local Result = {}
	
	local TeamList = gamemode.GetPlayerList(TeamId, OnlyHumans)
	
	for _,PlayerState in ipairs(TeamList) do
		if player.GetReadyStatus(PlayerState) == Status then
			table.insert(Result, PlayerState)
		end
	end

	return Result
end


function DTAS:GetPlayerListIsPlaying(TeamId, OnlyHumans)
	-- Status = "WaitingToReadyUp" or "DeclaredReady", and ignore "NotReady"
	-- anything else will just return an empty list

	local Result = {}
	
	local TeamList = gamemode.GetPlayerList(TeamId, OnlyHumans)
	
	local PlayerStatus
	
	for _,PlayerState in ipairs(TeamList) do
		PlayerStatus = player.GetReadyStatus(PlayerState)
		if PlayerStatus == "DeclaredReady" or PlayerStatus == "WaitingToReadyUp" then
			table.insert(Result, PlayerState)
		end
	end

	return Result
end


function DTAS:IsInList(Item, List)
	for _, CurrentItem in ipairs(List) do
		if CurrentItem == Item then
			return true
		end
	end
	
	return false
end


function DTAS:PickRandomPlayerToMove(TeamId)

	local TeamList = self:GetPlayerListIsPlaying(TeamId, true)
	-- picks players who are readied up (clicked board) or waiting to ready up (pulled into game because was in ops room)

	if #TeamList < 1 then
		print("empty team list")
		return nil
	end

	if #TeamList == 1 then
		print("only one in team list")
		return TeamList[1]
	end

	CandidatePlayers = {}
	for i = 1, #TeamList do
		table.insert(CandidatePlayers, TeamList[i])
	end
	-- make a quick copy of the TeamList table

	local SelectedPlayer = nil
	
	for i = 1, #self.PastTeamMovements do
		-- if only one player remains in the list, they have to be the selection
		if #CandidatePlayers == 1 then
			SelectedPlayer = CandidatePlayers[1]
			break
		end

		for j = 1, #CandidatePlayers do
			-- find past fox in current list of players, and remove it
			if self.PastTeamMovements[i] == CandidatePlayers[j] then
				table.remove(CandidatePlayers, j)
				break
			end
		end
	end

	if SelectedPlayer == nil then
		SelectedPlayer = CandidatePlayers[ umath.random(#CandidatePlayers) ]
	end

	self:RemoveValueFromTable(self.PastTeamMovements, SelectedPlayer)
	-- avoid duplicates (may not exist)

	table.insert(self.PastTeamMovements, 1, SelectedPlayer)
		
	if #self.PastTeamMovements > self.NumberOfPastTeamMovementsToTrack then
		table.remove (self.PastTeamMovements)
		-- remove highest index item, everything will shuffle down an index
	end

	return SelectedPlayer
end


function DTAS:ReportObjectiveLocationToGame()
	if self.FoxPlayer ~= nil then
		local FoxPlayerChar = player.GetCharacter(self.FoxPlayer)
		if FoxPlayerChar ~= nil then
			gamemode.SetObjectiveLocation( actor.GetLocation(FoxPlayerChar) ) 
			-- notify game of (moving) objective location
		end
	end
end


function DTAS:CheckEndRoundTimer()

	if self.CurrentDTASGameMode == "DTAS" then

		local LivingAttackers = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, true)
		local LivingDefenders = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, true)
		-- count human players
		
		self:PruneOutDeadPlayers(LivingAttackers)
		self:PruneOutDeadPlayers(LivingDefenders)
		-- temporary fix
		
		local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, self.AttackingTeam.TeamId, 255)
		local NumLivingAttackers = #LivingAttackers + #OpForControllers
		OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, self.DefendingTeam.TeamId, 255)
		local NumLivingDefenders = #LivingDefenders + #OpForControllers
		-- add in friendly AI players (I think this also counts dead players?)
		
		if NumLivingAttackers < self.ServerSettings.AttackersNeededToCap.Value
		and NumLivingAttackers < self.StartingAttackingTeamSize then
			if NumLivingDefenders > 0 then
				gamemode.AddGameStat("Result=Team" .. tostring(self.DefendingTeam.TeamId))
				gamemode.AddGameStat("Summary=AttackersEliminatedDTAS")
				gamemode.AddGameStat("CompleteObjectives=DefendObjectiveDTAS,KillAllAttackers")
				gamemode.SetRoundStage("PostRoundWait")
				
				self:ScorePlayersAtEndOfRound( self.DefendingTeam.TeamId )
			else
				gamemode.AddGameStat("Result=None")
				gamemode.AddGameStat("Summary=BothFailed")
				gamemode.SetRoundStage("PostRoundWait")
				
				self:ScorePlayersAtEndOfRound( -1 )
				-- winning team of -1 means no one won
			end
		else	
			if NumLivingDefenders < 1 then
				gamemode.AddGameStat("Result=Team" .. tostring(self.AttackingTeam.TeamId))
				gamemode.AddGameStat("Summary=DefendersEliminated")
				gamemode.AddGameStat("CompleteObjectives=CaptureObjectiveDTAS,KillAllDefenders")
				gamemode.SetRoundStage("PostRoundWait")
				
				self:ScorePlayersAtEndOfRound( self.AttackingTeam.TeamId )
			end

		end
	else
		-- Fox Hunt
		
		local FoxNumLives
		
		if self.FoxPlayer == nil then
			FoxNumLives = 1
		else
			if self.FoxPlayerIsAI then
				FoxNumLives = 0
				
				local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, self.DefendingTeam.TeamId, 255)

				for i, OpForController in ipairs(OpForControllers) do
					if OpForController == self.FoxPlayer then
						FoxNumLives = 1
						break
					end
				end
			else
				FoxNumLives = player.GetLives(self.FoxPlayer)
			end
		end
		
		local LivingAttackers = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, true)
		local LivingDefenders = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, true)
		-- count human players
		
		self:PruneOutDeadPlayers(LivingAttackers)
		self:PruneOutDeadPlayers(LivingDefenders)
		-- temporary fix
		
		local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, self.AttackingTeam.TeamId, 255)
		local NumLivingAttackers = #LivingAttackers + #OpForControllers
		OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, self.DefendingTeam.TeamId, 255)
		local NumLivingDefenders = #LivingDefenders + #OpForControllers
		-- add in friendly AI players
		
--		if NumLivingDefenders < 1 and FoxNumLives < 1 then
		if FoxNumLives < 1 or NumLivingDefenders < 1 then
			if NumLivingAttackers < 1 then
				gamemode.AddGameStat("Result=None")
				gamemode.AddGameStat("Summary=BothFailed")
				gamemode.SetRoundStage("PostRoundWait")
				
				self:ScorePlayersAtEndOfRound( -1 )
				-- -1 means no one won
			else
				gamemode.AddGameStat("Result=Team" .. tostring(self.AttackingTeam.TeamId))
				gamemode.AddGameStat("Summary=DefendersFailedFoxHunt")
				gamemode.AddGameStat("CompleteObjectives=CaptureObjectiveFoxHunt")
				gamemode.SetRoundStage("PostRoundWait")

				self:ScorePlayersAtEndOfRound( self.AttackingTeam.TeamId )
			end
		

		else
			if NumLivingAttackers < 1 then
				gamemode.AddGameStat("Result=Team" .. tostring(self.DefendingTeam.TeamId))
				gamemode.AddGameStat("Summary=AttackersEliminated")
				gamemode.AddGameStat("CompleteObjectives=DefendObjectiveFoxHunt")
				gamemode.SetRoundStage("PostRoundWait")

				self:ScorePlayersAtEndOfRound( self.DefendingTeam.TeamId )
			end		
		end
	end
end


function DTAS:ScorePlayersAtEndOfRound( WinningTeam )

	-- WinningTeam = -1 means no one won
			
	if WinningTeam == self.DefendingTeam.TeamId then
		self:AwardTeamScore( self.DefendingTeam.TeamId, "WonRound" )
	elseif WinningTeam == self.AttackingTeam.TeamId then
		self:AwardTeamScore( self.AttackingTeam.TeamId, "WonRound" )
	end

	if self.LastKiller ~= nil then
		self:AwardPlayerScore( self.LastKiller, "LastKill" )
	end
	-- don't do a team score for this

	local DefenderList = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, false)
	-- get all alive players
	
	for _, Player in ipairs(DefenderList) do
	-- iterate through all living defenders
		self:AwardPlayerScore( Player, "SurvivedRound" )
		if self.DefendingTeam.TeamId == WinningTeam then
			self:AwardPlayerScore( Player, "WonRound" )
		end
	end
		
	local AttackerList = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, false)
	-- get all alive players
	
	for _, Player in ipairs(AttackerList) do
	-- iterate through all living defenders
		self:AwardPlayerScore( Player, "SurvivedRound" )
		if self.AttackingTeam.TeamId == WinningTeam then
			self:AwardPlayerScore( Player, "WonRound" )
		end
	end
	
	if self.CurrentDTASGameMode == 'DTAS' then
		-- DTAS mode
		
		local SomeoneWasInRange = false
		
		for _, Player in ipairs(DefenderList) do
			if self:IsInFlagRange(Player) then
				self:AwardPlayerScore( Player, "SurvivedInRange")
				SomeoneWasInRange = true
			end
		end
		
		if SomeoneWasInRange then
			self:AwardTeamScore( self.DefendingTeam.TeamId, "SurvivedInRange" )
		end

	else
		-- Fox hunt mode
		for _, Player in ipairs(DefenderList) do
			if self:GetDistanceBetweenPlayers( Player, self.FoxPlayer, false ) <= self.ScoringFoxPromixity 
			and Player ~= self.FoxPlayer then
				self:AwardPlayerScore( Player, "CloseToAssetRoundEnd")
				self:AwardTeamScore( self.DefendingTeam.TeamId, "CloseToAssetRoundEnd" )
			end

			if Player == self.FoxPlayer then
				self:AwardPlayerScore( Player, "SurvivingAsset" )
				self:AwardTeamScore( self.DefendingTeam.TeamId, "AssetSurvived" )
			end
		end
	end
		
	if self.FoxPlayerIsAI then
		local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, self.DefendingTeam.TeamId, 255)
		-- AI controllers are deleted when killed so if we find one, it is alive
		for i, OpForController in ipairs(OpForControllers) do
			if OpForController == self.FoxPlayer then
				self:AwardTeamScore( self.DefendingTeam.TeamId, "AssetSurvived" )
				break
			end
		end
	end
			
end


function DTAS:PruneOutDeadPlayers(PlayerList)
	for i = #PlayerList, 1, -1 do
	-- go backwards because shrinking list as we go
		if player.GetLives(PlayerList[i]) < 1 then
			table.remove(PlayerList, i)
		end
	end
end


function DTAS:GameTimerExpired()
-- TODO copy logic from EndRoundTimer

	if self.CurrentDTASGameMode == "DTAS" then

		gamemode.AddGameStat("Result=Team" .. tostring(self.DefendingTeam.TeamId))
		gamemode.AddGameStat("Summary=AttackersFailedDTAS")
		gamemode.AddGameStat("CompleteObjectives=DefendObjectiveDTAS")
		gamemode.SetRoundStage("PostRoundWait")
		
		self:AwardTeamScore(self.DefendingTeam.TeamId, "DefenderTimeout")
		
		self:ScorePlayersAtEndOfRound( self.DefendingTeam.TeamId )
	else
		-- Fox Hunt
		
		gamemode.AddGameStat("Result=Team" .. tostring(self.DefendingTeam.TeamId))
		gamemode.AddGameStat("Summary=ProtectFoxObjective")
		gamemode.AddGameStat("CompleteObjectives=DefendObjectiveFoxHunt")
		gamemode.SetRoundStage("PostRoundWait")
				
		self:AwardPlayerScore(self.FoxPlayer, "SurvivingAssetByTime" )
		self:AwardTeamScore(self.DefendingTeam.TeamId, "AssetSurvivedByTime")
		
		self:ScorePlayersAtEndOfRound( self.DefendingTeam.TeamId )
	end

end


function DTAS:SetupRound()
-- called at start of WaitingForReady round stage, before DTAS/Fox Hunt mode is known

	if self.DefendingTeam == nil then
		-- level being run for first time, players probably all still in common area
		self.DefendingTeam = self.PlayerTeams.Blue
		self.AttackingTeam = self.PlayerTeams.Red
		
		gamemode.SetPlayerTeamRole(self.DefendingTeam.TeamId, "Defending")
		gamemode.SetPlayerTeamRole(self.AttackingTeam.TeamId, "Attacking")
	else

		if self.CompletedARound and self.Settings.AutoSwap.Value ~= 0 then
			if self.DefendingTeam == self.PlayerTeams.Blue then
				self.DefendingTeam = self.PlayerTeams.Red
				self.AttackingTeam = self.PlayerTeams.Blue
			else
				self.DefendingTeam = self.PlayerTeams.Blue
				self.AttackingTeam = self.PlayerTeams.Red
			end
			
			gamemode.SetPlayerTeamRole(self.DefendingTeam.TeamId, "Defending")
			gamemode.SetPlayerTeamRole(self.AttackingTeam.TeamId, "Attacking")
			
			-- Only show message after the first round, 
			-- at which point RandomDefenderInsertionPoint will no longer nil.
			
			local Attackers = gamemode.GetPlayerList(self.AttackingTeam.TeamId, true)
			for i = 1, #Attackers do
				player.ShowGameMessage(Attackers[i], "SwapAttacking", "Center", 3.0)
			end
			
			local Defenders = gamemode.GetPlayerList(self.DefendingTeam.TeamId, true)
			for i = 1, #Defenders do
				player.ShowGameMessage(Defenders[i], "SwapDefending", "Center", 3.0)
			end
		
		else
		
			if self.AbandonedRound then
				-- round being reset to waitingforready can happen as a result of all players readying down or leaving ops room
				-- (in this case we don't want to display these messages)
				
				local Attackers = gamemode.GetPlayerList(self.AttackingTeam.TeamId, true)
				for i = 1, #Attackers do
					player.ShowGameMessage(Attackers[i], "StillAttacking", "Center", 3.0)
				end
				
				local Defenders = gamemode.GetPlayerList(self.DefendingTeam.TeamId, true)
				for i = 1, #Defenders do
					player.ShowGameMessage(Defenders[i], "StillDefending", "Center", 3.0)
				end
			end
						
		end

	end
	
	self.LastKiller = nil
	
	self.CompletedARound = false
	self.AbandonedRound = false
	-- need to set this after swapping teams (see above)
		
	gamemode.ClearGameObjectives()
	gamemode.AddGameObjective(self.DefendingTeam.TeamId, "DefendObjectiveDTAS", 1)
	gamemode.AddGameObjective(self.AttackingTeam.TeamId, "CaptureObjectiveDTAS", 1)
	gamemode.AddGameObjective(self.DefendingTeam.TeamId, "KillAllAttackers", 2)
	gamemode.AddGameObjective(self.AttackingTeam.TeamId, "KillAllDefenders", 2)
	gamemode.SetGameModeName("DTAS")
	-- this is repeated in SetupRoundDTAS()
	-- want to avoid issues with fox hunt objectives
	-- we could dynamically update objectives depending on how many players clicked in, but that might be confusing on full servers
		
	gamemode.SetDefaultRoundStageTime("PreRoundWait", 12 )
	-- override the 5 second default (actually = 3 in practice -- take off 2 seconds any of these time limits to get actual duration)
		
	self:InitRandomSpawns()
	-- prepare for random spawning
end


function DTAS:ResetRound()
	self.FoxPlayer = nil
	self.FlagCarrier = nil
	self.FlagPlacement = nil
	self.Flag = nil

	StartingDefendingTeamSize = nil
	StartingAttackingTeamSize = nil

	if self.DefendingTeam ~= nil then
		ai.CleanUp(self.DefendingTeam.TeamId)
		ai.CleanUp(self.AttackingTeam.TeamId)
	end
	
	self.LastDTASStatus = nil
	self.CurrentFlagCaptureTime = 0
	
	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
	for i, InsertionPoint in ipairs(AllInsertionPoints) do
		actor.SetActive(InsertionPoint, false)
	end
	
	self.SpawnAttempts = {}

	--gamemode.ClearGameObjectives()
end



---- scoring stuff

function DTAS:ResetRoundScores()
	
	gamemode.ResetTeamScores()
	gamemode.ResetPlayerScores()

	LastKiller = nil

end


function DTAS:ResetAllScores()
	
	self:ResetRoundScores()
end


function DTAS:AwardPlayerScore( Player, ScoreType )
	-- Player must be a playerstate - use player.GetPlayerState ( ... ) if you need to when calling this

	if not actor.HasTag(player.GetCharacter(Player), self.OpForTeamTag) then
--		print("AwardPlayerScore: Not awarding any score to AI player")
--	else
		player.AwardPlayerScore( Player, ScoreType, 1 )		
	end
end 


function DTAS:AwardPlayerScoreToTeam( TeamId, MinLives, ScoreType )
	local TeamPlayers = gamemode.GetPlayerListByLives(TeamId, MinLives, true)
	-- only human players
	
	for _, Player in ipairs(TeamPlayers) do
		self:AwardPlayerScore( Player, ScoreType )
	end
end


function DTAS:AwardTeamScore( Team, ScoreType )
	gamemode.AwardTeamScore( Team, ScoreType, 1 )
	-- always award 1 x score (last parameter)			
end 

----------------- end scoring stuff



function DTAS:InitRandomSpawns()
	-- carry out preliminaries for random spawning, on new round/map load

	if #self.GameModeObjects == 0 then
		self:BuildGameModeObjects()
	end
end


function DTAS:SetupRoundDTAS()
	
	-- set up game objectives
	-- we might be doing this a second time - if fox hunt is selected, objectives might be whack
	
	gamemode.ClearGameObjectives()

	gamemode.AddGameObjective(self.DefendingTeam.TeamId, "DefendObjectiveDTAS", 1)
	gamemode.AddGameObjective(self.AttackingTeam.TeamId, "CaptureObjectiveDTAS", 1)

	gamemode.AddGameObjective(self.DefendingTeam.TeamId, "KillAllAttackers", 2)
	gamemode.AddGameObjective(self.AttackingTeam.TeamId, "KillAllDefenders", 2)

	self.CurrentFlagCaptureTime = 0

	-- pick flag carrier:

	self:SelectFlagCarrier()
	
	gamemode.SetWatchMode( "ObjectiveFinder", self.ServerSettings.ShowBearing.Value == 1, self.ServerSettings.ShowDistance.Value == 1, true, true )
	-- watch mode, show bearing, show distance, display up/down, measure 2D distance
	gamemode.SetCaptureZone( self.ServerSettings.CaptureRadius.Value, self.ServerSettings.CaptureHeight.Value, self.DefendingTeam.TeamId, false )
	-- cap radius, cap height, defending team, spherical zone? (else cylinder)
end


function DTAS:SetupRoundFoxHunt()

	-- set up game objectives
	
	gamemode.ClearGameObjectives()

	gamemode.AddGameObjective(self.DefendingTeam.TeamId, "DefendObjectiveFoxHunt", 1)
	gamemode.AddGameObjective(self.AttackingTeam.TeamId, "CaptureObjectiveFoxHunt", 1)

	-- pick fox:

	self:SelectFoxPlayer()
	
	-- freeze everyone except fox for duration of setup round
	
	--self:FreezeEveryoneExceptFox()
	local DisplayDistance
	
	if (self.ServerSettings.ShowDistance.Value == 0 and self.ServerSettings.ShowBearing.Value == 1 and self.FoxDisableBearing and not self.FoxDisableDistance)
		or (self.ServerSettings.ShowDistance.Value == 1 and not self.FoxDisableDistance) then
		DisplayDistance = true
	else
		DisplayDistance = false
	end
	
	gamemode.SetWatchMode( "ObjectiveFinder", not self.FoxDisableBearing, DisplayDistance, false, true )
	-- watch mode, show bearing, show distance, display up/down, measure 2D distance
	gamemode.SetCaptureZone( 0, 0, 0, false )
	-- no alerts please
	
end


function DTAS:DisableWeaponsForAll()
-- everyone can move but not shoot

	local LivingPlayers = gamemode.GetPlayerListByLives(255, 1, false)
	-- get all players including AI (though that doesn't work atm)
	
	for _, Player in ipairs(LivingPlayers) do
		player.AddIgnoreUseInputReason(Player, "FlagBeingPlaced")
	end

end


function DTAS:EnableWeaponsForAll()
-- everyone can move AND shoot now

	local LivingPlayers = gamemode.GetPlayerListByLives(255, 1, false)
	-- get all players including AI (though that doesn't work atm)
	
	for _, Player in ipairs(LivingPlayers) do
		player.RemoveIgnoreUseInputReason(Player, "FlagBeingPlaced")
	end

end


function DTAS:SelectFlagCarrier()
	local DefenderPlayers = {}

	if self.FlagCarrier ~= nil then
		print("Already have a flag carrier - aborting selection of a new one")
		return
	end

	DefenderPlayers = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, true)
	-- for some reason this doesn't pick up AI when false?
		
	if #DefenderPlayers < 1 then
		
		local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, self.DefendingTeam.TeamId, 255)

		if #OpForControllers > 0 then
			self.FlagCarrier = OpForControllers[umath.random(#OpForControllers)]
			self.FlagCarrierIsAI = true
			print("assigned AI as Flag Carrier")
			-- it's not a player though...
		else
				print("No suitable defenders found to assign as Flag Carrier")
				return
		end
	else	
	
		local SelectedPlayer = nil
		
		for i = 1, #self.PastFlagCarriers do
			-- if only one player remains in the list, they have to be the fox
			if #DefenderPlayers == 1 then
				SelectedPlayer = DefenderPlayers[1]
				break
			end

			for j = 1, #DefenderPlayers do
				-- find past fox in current list of players, and remove it
				if self.PastFlagCarriers[i] == DefenderPlayers[j] then	
					table.remove(DefenderPlayers, j)
					break
				end
			end
			
		end

		if SelectedPlayer == nil then
			SelectedPlayer = DefenderPlayers[ umath.random(#DefenderPlayers) ]
		end
	
		self.FlagCarrier = SelectedPlayer
		self.FlagCarrierIsAI = false

		self:RemoveValueFromTable(self.PastFlagCarriers, SelectedPlayer)
		-- avoid duplicates (may not exist)

		table.insert(self.PastFlagCarriers, 1, SelectedPlayer)
		
		if #self.PastFlagCarriers > self.NumberOfPastFlagCarriersToTrack then
			table.remove (self.PastFlagCarriers)
			-- remove highest index item, everything will shuffle down an index
		end

		-- TODO let players request to be flag carrier or request not to be flag carrier (using console commands?)
	end

	self:SetupHighlightMovingTargetTimer(self.FlagCarrier, "Flag Carrier", self.DefendingTeam.TeamId)
	--self:SetupHighlightMovingTargetTimer(self.FlagCarrier, "Flag Carrier", 255)
		
	if not self.FlagCarrierIsAI then
		self.Flag = player.GiveItem(self.FlagCarrier, '/Game/GroundBranch/Inventory/Equipment/Flag/BP_CarriedGameModeFlag.BP_CarriedGameModeFlag_C', true)
		-- make the flag carrier hold the flag
	else
		self.Flag = nil
	end

end


function	DTAS:SetupHighlightMovingTargetTimer(Target, TargetDescription, TeamId)
	if Target ~= nil then
		--print("Setting up HighlightMovingTargetTimer for target description " .. TargetDescription .. " / team ID = " .. TeamId)
		timer.Clear("MovingTarget")
		self.MovingTarget = Target
		self.MovingTargetTeamId = TeamId
		-- the team that sees the highlighted player
		--self.MovingTargetTeamId = 255

		self.MovingTargetDescription = TargetDescription
		timer.Set("MovingTarget", self, self.HighlightMovingTargetTimer, self.HighlightMovingTargetInterval, true)
		self:HighlightMovingTargetTimer()
		
		-- set timer and also call immediately
	else
		print ("target to highlight was nil")
	end
end


function	DTAS:ClearHighlightMovingTargetTimer()
	timer.Clear("MovingTarget")
	self.MovingTarget = nil
end


function DTAS:HighlightMovingTargetTimer()
	if self.MovingTarget ~= nil then

		local DisplayPlayers = gamemode.GetPlayerListByLives(self.MovingTargetTeamId, 1, true)
		-- thanks to TheCoder for the spot that this wasn't local (20 May 2022)
	
		for _, DisplayPlayer in ipairs(DisplayPlayers) do
			if DisplayPlayer ~= self.MovingTarget then
				local PlayerChar = player.GetCharacter(self.MovingTarget)
				if PlayerChar ~= nil then
					local TargetVector = actor.GetLocation(PlayerChar)
					
					--TargetVector.z = TargetVector.z + 100
					-- correct for height
					
					player.ShowWorldPrompt(DisplayPlayer, TargetVector, self.MovingTargetDescription, self.HighlightMovingTargetInterval + 0.0)
					-- show the flag carrier or fox to other players in his team
				--else
				--	print("skipped moving target")
				end
			end
		end
	end
end


function DTAS:SelectFoxPlayer()

	local DefenderPlayers = {}

	if self.FoxPlayer ~= nil then
		print("Already have a Fox player selected, but reselecting anyway")
	end

	DefenderPlayers = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, true)
	-- does not pick up AI for some reason when set false
	
	if DefenderPlayers == nil or #DefenderPlayers < 1 then
		
		local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, self.DefendingTeam.TeamId, 255)

		if OpForControllers == nil or #OpForControllers == 0 then
			print("No suitable defenders found to assign as Fox")
			return 
		else
			self.FoxPlayer = OpForControllers[umath.random(#OpForControllers)]
			self.FoxPlayerIsAI = true
			print("assigned AI as Fox")
			-- it's not a player though...
		end
	else	
	
		local SelectedPlayer = nil
	
		for i = 1, #self.PastFoxes do
			-- if only one player remains in the list, they have to be the fox
			if #DefenderPlayers == 1 then
				SelectedPlayer = DefenderPlayers[1]
				break
			end

			for j = 1, #DefenderPlayers do
				-- find past fox in current list of players, and remove it
				if self.PastFoxes[i] == DefenderPlayers[j] then
					table.remove(DefenderPlayers, j)
					break
				end
			end
			
		end

		if SelectedPlayer == nil then
			SelectedPlayer = DefenderPlayers[ umath.random(#DefenderPlayers) ]
		end
	
		self.FoxPlayer = SelectedPlayer
		self.FoxPlayerIsAI = false

		self:RemoveValueFromTable(self.PastFoxes, SelectedPlayer)
		-- avoid duplicates (may not exist)

		table.insert(self.PastFoxes, 1, SelectedPlayer)
		
		if #self.PastFoxes > self.NumberOfPastFoxesToTrack then
			table.remove (self.PastFoxes)
			-- remove highest index item, everything will shuffle down an index
		end

		-- TODO let players request to be fox or request not to be fox
	end

	self:SetupHighlightMovingTargetTimer(self.FoxPlayer, "Asset", self.DefendingTeam.TeamId)

end


function DTAS:RemoveValueFromTable(TableToEdit, ValueToRemove)
	-- assumes continuous table without gaps

		for i = #TableToEdit, 1, -1 do
			-- if only one player remains in the list, they have to be the fox
			if TableToEdit[i] == ValueToRemove then
				table.remove(TableToEdit, i)
			end
		end
end


function DTAS:DTASChecksTimer()
	local CurrentDTASStatus = self:GetDTASFlagStatus()
	
	if CurrentDTASStatus == 'attacked' then
		if self.LastDTASStatus == 'defended' then
			-- flag has just started being captured

			gamemode.SetCaptureState(true)
			-- notify players via watches

			self.CurrentFlagCaptureTime = 0
		else
			self.CurrentFlagCaptureTime = self.CurrentFlagCaptureTime + self.DTASCheckInterval
		end
		
		if self.CurrentFlagCaptureTime > self.Settings.CaptureTime.Value then
			-- victory!
			self:TargetCaptured()
		end
	else
		-- flag is defended
		
		if self.LastDTASStatus == 'attacked' then
			-- has just switched to defended

			gamemode.SetCaptureState(false)
			-- notify players via watches

			self.CurrentFlagCaptureTime = 0
			-- not needed but I'd rather reset it anyway
		end

	end

	self.LastDTASStatus = CurrentDTASStatus
end


function DTAS:GetDTASFlagStatus()
	-- status is 'defended' or 'attacked'

	if self.FlagPlacement == nil or gamemode.GetRoundStage() ~= "DTASInProgress" then
		return 'defended'
	end
	
	local DefenderCount, AttackerCount
	
	DefenderCount, AttackerCount = self:GetDTASFlagCounts()
	-- TODO make sure AI is included in this

	if self.ServerSettings.DefendersNeededToDefend.Value > 0 
	and DefenderCount >= math.min(self.StartingDefendingTeamSize, self.ServerSettings.DefendersNeededToDefend.Value) then
		-- flag is automatically defended if the DefendersNeededToDefend setting is non zero, and that many defenders are present 
		-- (or the number of defenders spawning into the round, if fewer)
		-- DefendersNeededToDefend = 0 means don't apply this rule
		return 'defended'
	end

	if self.ServerSettings.CaptureIfMoreAttackersThanDefenders.Value == 1 then
		-- in this variant, you need (a) a minimum of two attackers in range and (b) more attackers in range than defenders, or fewer defenders in range than the minimum specified
	
		if AttackerCount >= self.ServerSettings.AttackersNeededToCap.Value 
		and AttackerCount > DefenderCount then
			-- flag is capped if: 
			-- - at least AttackersNeededToCap number of attackers are in range, or we're in last stand mode
			-- - there are more attackers than defenders
			return 'attacked'
		end
	else
		-- in this variant there only needs to be as many attackers as AttackersNeededToCap and fewer defenders than DefendersNeededToDefend in range
		-- if DefendersNeededToDefend is 0, then there only needs to be sufficient attackers, and this cannot be defended against (except by killing attackers or them moving out of range)
			
		if AttackerCount >= math.min(self.StartingAttackingTeamSize, self.ServerSettings.AttackersNeededToCap.Value) then
			return 'attacked'
		end
		-- having this many attackers or more will cause capture unless there are more than DefendersNeededToDefend defenders in place

	end
	
	return 'defended'
	
	-- TODO option to increase cap speed, the more attackers there are (or bigger numerical advantage)
end


function DTAS:GetDTASFlagCounts()
	-- returns defenders in range of flag, attackers in range of flag
	-- TODO could redo to deliver a list of the players rather than the number?
	
	if self.FlagPlacement == nil then
		return 0, 0
	end

	local DefenderPlayers
	local DefenderAI
	local AttackerPlayers
	local AttackerAI
	
	local DefenderCount = 0
	local AttackerCount = 0

	DefenderPlayers = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, true)
	DefenderAI = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, self.DefendingTeam.TeamId, 255)
	
	AttackerPlayers = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, true)
	AttackerAI = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, self.AttackingTeam.TeamId, 255)
	
	for poop, Defender in ipairs(DefenderPlayers) do
		if self:IsInFlagRange(Defender) then
			DefenderCount = DefenderCount + 1
		end
	end

	for poop, Defender in ipairs(DefenderAI) do
		if self:IsInFlagRange(Defender) then
			DefenderCount = DefenderCount + 1
		end
	end
	
	for poop, Attacker in ipairs(AttackerPlayers) do
		if self:IsInFlagRange(Attacker) then
			AttackerCount = AttackerCount + 1
		end
	end

	for poop, Attacker in ipairs(AttackerAI) do
		if self:IsInFlagRange(Attacker) then
			AttackerCount = AttackerCount + 1
		end
	end

	return DefenderCount, AttackerCount
end


function DTAS:IsInFlagRange(PlayerToCheck)
	-- TODO add option for requiring line of sight? would need hook for that also in GB
	
	if self.FlagPlacement == nil then
		return false
	end

	local PlayerChar = player.GetCharacter(PlayerToCheck)
	
	if PlayerChar ~= nil then
		local PlayerLocation = actor.GetLocation( PlayerChar )
		
		if PlayerLocation == nil then
			return false
		end

		local FlagVector = self:VectorSubtract( self.FlagPlacement, PlayerLocation )
		
		local HorizontalDistance = vector.Size2D( FlagVector )
		local VerticalDistance = math.abs ( FlagVector.z )
		
		if	HorizontalDistance <= self.ServerSettings.CaptureRadius.Value * 100
		and VerticalDistance <= self.ServerSettings.CaptureHeight.Value * 50 then
			return true
		else
			return false
		end
	end
end

------------ end round stage stuff  --------------------------------------



----------------------- build game mode objects -------------------

function DTAS:BuildGameModeObjects()

	--print("DTAS: BuildGameModeObjects() called---------------------")

	-- the aim is to fill GameModeObjects with relevant game mode objects that will be connectable to on the navmesh
	-- we are also finding the bounding area of all these objects, which is stored in GameObjectBoundingBox

	self.GameModeObjects = {}
	--self.UnreachableGameModeObjects = {}
	self.GameModeObjectsUseForRandomSpawns = {}
	self.GameObjectBoundingBox = {}

	self.RandomNavMeshTestObject = nil

	local AllObjects
	local GameRelevantActor
	local InsertionPointsExist = false
	local CurrentGameModeObjectType

	--TODO exclude all/any actors from the ready room. Test what kind of player starts they are?

	for i = 1, #self.GameModeObjectTypes do
		-- iterate through all potentially relevant classes
		CurrentGameModeObjectType = self.GameModeObjectTypes[i]
		AllObjects = gameplaystatics.GetAllActorsOfClass(CurrentGameModeObjectType)
		
		if CurrentGameModeObjectType == 'GroundBranch.GBInsertionPoint' then
			InsertionPointsExist = true
			self.RandomNavMeshTestObject = AllObjects[ umath.random(#AllObjects) ]
		end
		
		if CurrentGameModeObjectType ~= 'GroundBranch.GBPlayerStart' or not InsertionPointsExist then
		-- basically don't add playerstarts if insertion points exist
			
			local AddToRandomSpawnsGameObjects = false
			
			for poopies, TypeName in ipairs(self.GameModeObjectTypesUseForRandomSpawns) do

				if CurrentGameModeObjectType == TypeName then
					AddToRandomSpawnsGameObjects = true
					break
					-- not sure if this breaks the outer loop also/instead
				end
			end
			
			if CurrentGameModeObjectType == 'GroundBranch.GBPlayerStart' and self.RandomNavMeshTestObject == nil then
				-- assumption is that insertion points will be named before playerstarts, and if no insertion points were found, all playerstarts will be in the playable area
				self.RandomNavMeshTestObject = AllObjects[ umath.random(#AllObjects) ]
			end
			
			--print( "DTAS: BuildGameModeObjects(): add " .. #AllObjects .. " of " .. self.GameModeObjectTypes[i] )
			
			for turd, GameRelevantActor in ipairs(AllObjects) do
				table.insert(self.GameModeObjects, GameRelevantActor)
				self:UpdateBoundingBox(self.GameObjectBoundingBox, GameRelevantActor)
				-- reminder to self that GameObjectBoundingBox is passed by reference (because it is a table)
						
				if AddToRandomSpawnsGameObjects then
					table.insert(self.GameModeObjectsUseForRandomSpawns, GameRelevantActor)
					-- also add the game object to the list of objects used for random walks and spawn accessibility tests (not all game objects e.g. patrol points are very suitable for this)
				end
		
			end
		
		end
		
	end

	-- TODO I would like to replace the game object bounding box with a bounding box containing all the navmesh in the level (should be a larger volume, but this method is designed for it)

	self.VoxelsOfInterest = {}

	local Xstart = self.GameObjectBoundingBox.x1
	local Xsize = ( self.GameObjectBoundingBox.x2 - self.GameObjectBoundingBox.x1 ) / self.VoxelsXY
	local Ystart = self.GameObjectBoundingBox.y1
	local Ysize = ( self.GameObjectBoundingBox.y2 - self.GameObjectBoundingBox.y1 ) / self.VoxelsXY
	local Zstart = self.GameObjectBoundingBox.z1
	local Zsize = ( self.GameObjectBoundingBox.z2 - self.GameObjectBoundingBox.z1 ) / self.VoxelsZ

	local QueryExtent = {}

	QueryExtent.x = Xsize / 2
	QueryExtent.y = Ysize / 2
	QueryExtent.z = Zsize / 2

	--print("Xsize = " .. Xsize)
	--print("voxel cells have extent x=" .. math.floor(Xsize / 10) / 10 .. "m, y=" .. math.floor(Ysize / 10) / 10 .. "m, z=" .. math.floor(Zsize / 10) / 10 .. "m")
	
	local TestLocation
	local CellCentreLocation = {}

	for Zindex = 1, self.VoxelsZ do
		for Yindex = 1, self.VoxelsXY do
			for Xindex = 1, self.VoxelsXY do		
				CellCentreLocation.x = Xstart + Xsize * (0.5 + Xindex)
				CellCentreLocation.y = Ystart + Ysize * (0.5 + Yindex)
				CellCentreLocation.z = Zstart + Zsize * (0.5 + Zindex)
	
				TestLocation = ai.ProjectPointToNavigation( CellCentreLocation, QueryExtent )
				-- we don't care where the navmesh is, just whether a point was found (returns vector) or not (returns nil)
				
				if TestLocation ~= nil then
				
					local VoxelData = {}
					
					VoxelData.VoxelIndex = Xindex + Yindex * self.VoxelsXY + Zindex * (self.VoxelsXY * self.VoxelsXY )
					VoxelData.BoundingBox = self:MakeBoundingBox( 
						Xstart + Xsize * Xindex, 
						Xstart + Xsize * (Xindex+1),
						Ystart + Ysize * Yindex,
						Ystart + Ysize * (Yindex+1),
						Zstart + Zsize * Zindex,
						Zstart + Zsize * (Zindex+1)
						)
					
					table.insert(self.VoxelsOfInterest, VoxelData)
					
					--print("Added cell " .. VoxelData.VoxelIndex .. " with centre " .. CellCentreLocation.x .. ", " .. CellCentreLocation.y .. ", " .. CellCentreLocation.z)
				end
			end
		end
	end

	--print("DTAS: number of voxels created = " .. #self.VoxelsOfInterest .. " out of " .. self.VoxelsXY * self.VoxelsXY * self.VoxelsZ .. " possible cells")
	-- interesting metric - the ratio of cells created to possible cells, tells us how compact the objects are

	local UE4BB = self:GetUE4BoundingBox(self.GameObjectBoundingBox)

	local LargestDiagonal = math.sqrt( (UE4BB.Extent.x * UE4BB.Extent.x) + (UE4BB.Extent.y * UE4BB.Extent.y) + (UE4BB.Extent.z * UE4BB.Extent.z) ) * 4

	self.SpawnsScorePenaliseProximityDistance = math.max ( self.SpawnsMinimumTeamSeparation, LargestDiagonal / self.SpawnsLargestDiagonalDivisor )
				
	-- MapDistanceMetric = diagonal of bounding box around all game objects (minimum is SpawnsScoreMinimumTeamSeparation = 20000.0 = 200m)
	--print("DTAS: largest Diagonal = " .. math.floor(LargestDiagonal / 100) .. "m / SpawnsScorePenaliseProximityDistance = " .. math.floor(self.SpawnsScorePenaliseProximityDistance / 100) .. "m")

	self:DumpBoundingBox(self.GameObjectBoundingBox)

	-- at this point all potentially relevant game mode objects are contained withing GameObjectBoundingBox
	-- we could also look up the NavMeshBounds actor, but this may be limited intentionally to stop the AI moving towards spawns, etc.
	-- a general weakness is that there may be a lot of map condensed into small areas of buildings, and the buildings may have a lot of z axis going on

end


function DTAS:DumpBoundingBox(BoundingBox)
	if BoundingBox == nil or BoundingBox.x1 == nil then
		print("DTAS: DumpBoundingBox: invalid bounding box")
		return
	end

	print("DTAS: DumpBoundingBox: x1=" .. BoundingBox.x1 .. ", x2=" .. BoundingBox.x2 .. ", y1=" .. BoundingBox.y1 .. ", y2=" .. BoundingBox.y2 .. ", z1=" .. BoundingBox.z1 .. ", z2=" .. BoundingBox.z2)
end


function DTAS:DumpVector(Vector)
	if Vector == nil or Vector["x"] == nil then
		print("DTAS: DumpVector: invalid vector")
		return
	end

	print("DTAS: DumpVector: x=" .. Vector.x .. ", y=" .. Vector.y .. ", z=" .. Vector.z) 
end


function DTAS:MakeBoundingBox(x1, x2, y1, y2, z1, z2)
	local BoundingBox = {}
	
	BoundingBox.x1 = x1
	BoundingBox.x2 = x2
	BoundingBox.y1 = y1
	BoundingBox.y2 = y2
	BoundingBox.z1 = z1
	BoundingBox.z2 = z2
	
	return BoundingBox
end


function DTAS:UpdateBoundingBox(BoundingBox, ActorParam)

	-- BoundingBox is a table so is passed by reference (is updated directly, no need to return it from function)

	local ActorLocation = actor.GetLocation(ActorParam)

	if ActorLocation == nil or ActorLocation.x == nil then
		print("DTAS: UpdateBoundingBox: actor location (and actor) was nil")
		return
	end
	
	if BoundingBox.x1 == nil then
		-- bounding box not yet set
		--print("DTAS: UpdateBoundingBox: first time fill of BoundingBox (was nil or incomplete)")
		
		--BoundingBox = {}
		-- if you do this ^ then it no longer passes back by reference
		BoundingBox.x1 = ActorLocation.x
		BoundingBox.x2 = ActorLocation.x
		BoundingBox.y1 = ActorLocation.y
		BoundingBox.y2 = ActorLocation.y
		BoundingBox.z1 = ActorLocation.z
		BoundingBox.z2 = ActorLocation.z
	
		return
	end

	-- check x
	if ActorLocation.x < BoundingBox.x1 then
		BoundingBox.x1 = ActorLocation.x
	end
	if ActorLocation.x > BoundingBox.x2 then
		BoundingBox.x2 = ActorLocation.x
	end

	-- check y
	if ActorLocation.y < BoundingBox.y1 then
		BoundingBox.y1 = ActorLocation.y
	end
	if ActorLocation.y > BoundingBox.y2 then
		BoundingBox.y2 = ActorLocation.y
	end

	-- check z
	if ActorLocation.z < BoundingBox.z1 then
		BoundingBox.z1 = ActorLocation.z
	end
	if ActorLocation.z > BoundingBox.z2 then
		BoundingBox.z2 = ActorLocation.z
	end

end


function DTAS:GetUE4BoundingBox( BoundingBox )

	local Result = {}

	local Centre = {}
	local Extent = {}

	if BoundingBox == nil or BoundingBox.x1 == nil then
		Extent.x = 0
		Extent.y = 0
		Extent.z = 0
		
		Centre.x = 0
		Centre.y = 0
		Centre.z = 0
	else
		Extent.x = (BoundingBox.x2 - BoundingBox.x1)/2
		Extent.y = (BoundingBox.y2 - BoundingBox.y1)/2
		Extent.z = (BoundingBox.z2 - BoundingBox.z1)/2

		Centre.x = BoundingBox.x1 + Extent.x
		Centre.y = BoundingBox.y1 + Extent.y
		Centre.z = BoundingBox.z1 + Extent.z

	end

	Result.Centre = Centre
	Result.Extent = Extent

	return Result
end

-------------------------- end build game mode objects ---------------


------------------ find spawn points ---------------------------------

function DTAS:SetupSpawns()

	--print("DTAS: SetupSpawns() called --------------------")

	self.AttackerInsertionPoints = {}
	self.DefenderInsertionPoints = {}

	local FinalSpawnListIndices = {}
	local ListOfCandidateSpawnLists = {}
	local ListOfCreationMethods = {}
	local SpawnLocationList = {}
	local CreationMethod = "Unknown"

	-- obtain N candidate spawn lists (to narrow down to a selection of 2)

	for i = 1, self.SpawnsNumberOfCandidateSpawnListsToEvaluate do
		if  i <= (self.SpawnsProportionOfGameObjectWalksToEvaluate * self.SpawnsNumberOfCandidateSpawnListsToEvaluate)
		and #self.GameModeObjectsUseForRandomSpawns >= self.SpawnsMinimumNumberOfGameModeObjectsRequiredForRandomWalk then
		
			--print("DTAS: finding spawn point based on random walk from game mode object")
			BaseSpawnLocation = self:FindBaseSpawnPoint_GameObject()
			CreationMethod = "Random walk from detected game object"
			
		else

			BaseSpawnLocation = self:FindBaseSpawnPoint_VoxelPoint()
			CreationMethod = "Picked random point in navmesh-containing-voxel"

		end
	
		if BaseSpawnLocation ~= nil then
			SpawnLocationList, SpawnsShortfall, SpawnSpread = self:FindSubSpawns(BaseSpawnLocation, self.SpawnsNumberOfSpawnPointsToFind)
			-- call even if only finding one spawn point overall (and that's the BaseSpawnLocation)
		else
			-- this is a hard fail if we couldn't find a valid spawn point in (default 10) goes

			print("DTAS: failed to find base spawn location")

			SpawnsShortfall = self.SpawnsNumberOfSpawnPointsToFind
			WorstSpawnSpread = 10000.0
			--return SpawnLocationList, SpawnsShortfall, WorstSpawnSpread
		end

		local NewSpawnSet = {}

		NewSpawnSet.LocationList = SpawnLocationList
		NewSpawnSet.Shortfall = SpawnsShortfall
		NewSpawnSet.Spread = SpawnSpread

		table.insert(ListOfCandidateSpawnLists, NewSpawnSet)
		table.insert(ListOfCreationMethods, CreationMethod)
	end

	--print("DTAS: SetupSpawns(): found " .. #ListOfCandidateSpawnLists .. " candidate spawn sets")

	-- evaluate best combination of two spawn sets

	if #ListOfCandidateSpawnLists < 2 then
		-- yikes, this is a hard fail. What to do? TODO do something better than this
		self:AbandonRound("SpawnSelectionFailed")
		return
	end

	if #ListOfCandidateSpawnLists == 2 then
		FinalSpawnListIndices = {1, 2}
		-- that was easy
	else
		local BestScore = 0

		FinalSpawnListIndices = {1, 2}
		-- not sure if needed, just to grow the array

		for i = 1, #ListOfCandidateSpawnLists-1 do
			for j = i+1, #ListOfCandidateSpawnLists do
				local SpawnSet1 = ListOfCandidateSpawnLists[i]
				local SpawnSet2 = ListOfCandidateSpawnLists[j]
				-- iterate through every unique combination of spawn lists

				local Score = self:ScoreSpawnLocationCombo( SpawnSet1, SpawnSet2, self.SpawnsLastSpawns )
				
				--print("DTAS: SetupSpawns(): score for sets " .. i .. " and " .. j .. " = " .. Score)
				
				if Score > BestScore then
					BestScore = Score
					FinalSpawnListIndices = {i, j}
				end		
			end
		end
	end

	if #FinalSpawnListIndices == 2 then
		self.AttackerInsertionPoints = ListOfCandidateSpawnLists[FinalSpawnListIndices[1]].LocationList
		self.DefenderInsertionPoints = ListOfCandidateSpawnLists[FinalSpawnListIndices[2]].LocationList
		
		--print("Chose spawn clusters:")
		--print(FinalSpawnListIndices[1] .. ": " .. ListOfCreationMethods[FinalSpawnListIndices[1]])
		--print(FinalSpawnListIndices[2] .. ": " .. ListOfCreationMethods[FinalSpawnListIndices[2]])
	end
	
	if #FinalSpawnListIndices ~= 2
	or #self.AttackerInsertionPoints == 0
	or #self.DefenderInsertionPoints == 0 then
		-- we're fair fucked, mate. TODO do something better than this (though actually this sorta works?)
		self:AbandonRound("SpawnSelectionFailed")
		return
	end

	if #self.AttackerInsertionPoints < self.SpawnsNumberOfSpawnPointsToFind
	or #self.DefenderInsertionPoints < self.SpawnsNumberOfSpawnPointsToFind then
		print("    !!!!**** at least one team has been assigned less than " .. self.SpawnsNumberOfSpawnPointsToFind .. " spawn points!")
	end

	self.CurrentInsertionPointIndex[ self.DefendingTeam.TeamId ] = 0
	self.CurrentInsertionPointIndexHasLooped[ self.DefendingTeam.TeamId ] = false
	self.CurrentInsertionPointIndex[ self.AttackingTeam.TeamId ] = 0
	self.CurrentInsertionPointIndexHasLooped[ self.AttackingTeam.TeamId ] = false
	self.NumberOfSpawnAttemptCycles = 0

	-- CurrentInsertionPointIndex[] entries are incremented before use, so first spawn index is 1 in practice
	
	table.insert( self.SpawnsLastSpawns, self.AttackerInsertionPoints[1])
	table.insert( self.SpawnsLastSpawns, self.AttackerInsertionPoints[2])
	-- stick these at the end of the list of old spawn locations
	
	if  #self.SpawnsLastSpawns > self.SpawnsLastSpawnsMaxNumber then
		for i = 1, ( #self.SpawnsLastSpawns - self.SpawnsLastSpawnsMaxNumber ) do
			table.remove( self.SpawnsLastSpawns, 1 )
			-- remove the entries at the start of the list of old spawn locations
			--print("Removed a spawn from SpawnsLastSpawns")
		end
	end

end




function DTAS:ScoreSpawnLocationCombo( SpawnSet1, SpawnSet2, LastSpawns )
	local Score = 100.0
	
	-- find distance between spawns
	local SpawnCentre1 = SpawnSet1.LocationList[1]
	local SpawnCentre2 = SpawnSet2.LocationList[1]
	
	if SpawnCentre1 == nil or SpawnCentre2 == nil then
		print("DTAS: ScoreSpawnLocationCombo: SpawnCentre1 or 2 was nil, return score = 0.0")
		return 0.0
	end

	local SpawnVector 
	local SpawnDistance 

	-- score distance from old spawns
	local OldSpawnCorrection = 1

	local MinimumDistanceToOldSpawn1 = self.SpawnsScorePenaliseProximityDistance
	local MinimumDistanceToOldSpawn2 = self.SpawnsScorePenaliseProximityDistance

	if LastSpawns ~= nil then
		
		for i=1, #LastSpawns do
			local CurrentOldSpawn = LastSpawns[i]

			SpawnVector = self:VectorSubtract(SpawnCentre1, CurrentOldSpawn)
			SpawnVector.z = SpawnVector.z * self.DistanceZMultiplier
			-- allow closer spawns if separated by Z axis
			SpawnDistance = vector.Size(SpawnVector)
					
			if SpawnDistance < MinimumDistanceToOldSpawn1 then
				MinimumDistanceToOldSpawn1 = SpawnDistance
			end	

			SpawnVector = self:VectorSubtract(SpawnCentre2, CurrentOldSpawn)
			SpawnVector.z = SpawnVector.z * self.DistanceZMultiplier
			-- allow closer spawns if separated by Z axis
			SpawnDistance = vector.Size(SpawnVector)
			
			if SpawnDistance < MinimumDistanceToOldSpawn2 then
				MinimumDistanceToOldSpawn2 = SpawnDistance
			end
		
		end	
		
		local OldSpawnCorrectionRaw1
		local OldSpawnCorrectionRaw2
	
		OldSpawnCorrectionRaw1 = math.sqrt( self:Clamp( MinimumDistanceToOldSpawn1 / self.SpawnsScorePenaliseProximityDistance, 0, 1 ) )
		OldSpawnCorrectionRaw2 = math.sqrt( self:Clamp( MinimumDistanceToOldSpawn2 / self.SpawnsScorePenaliseProximityDistance, 0, 1 ) )
		-- OldSpawnCorrectionRaw (preliminary value) - 0 = on top of old spawn, 1 = acceptably far from old spawn, with nearer positions disproportionately penalised (sqrt term)

		-- the worst thing is if both spawns are near old spawns, so try to penalise that more than only a single spawn being near an old spawn

		local OldSpawnCorrectionRaw = OldSpawnCorrectionRaw1 * OldSpawnCorrectionRaw2
		-- yes, my use of local variables is very unoptimized

		OldSpawnCorrection = 1 + ( ( 1 - OldSpawnCorrectionRaw ) * 3 * self.SpawnsScorePenaliseDistanceFromOldSpawns)
	
	end
	
	-- TODO can avoid selecting close spawns in the first place, maybe don't pick same cell as old spawns
		
	-- score proximity between spawns
	local TeamSepSquared = self.SpawnsScorePenaliseProximityDistance * self.SpawnsScorePenaliseProximityDistance
	-- SpawnsScorePenaliseProximityDistance is set in dependence on the largest diagonal of the bounding box of all relevant game objects
	-- so it scales with the map

	SpawnVector = self:VectorSubtract(SpawnCentre2, SpawnCentre1)
	SpawnDistance = vector.Size(SpawnVector)

	SpawnVector.z = SpawnVector.z * self.DistanceZMultiplier
	-- self.DistanceZMultiplier = 1 for previous version
	-- this makes vertically separated spawn locations more desirable (they appear further apart)	
	local SpawnDistanceZCorrected = vector.Size(SpawnVector)
	
	local Sep = self:Clamp( (self.SpawnsScorePenaliseProximityDistance - SpawnDistanceZCorrected) * (self.SpawnsScorePenaliseProximityDistance - SpawnDistanceZCorrected), 0, TeamSepSquared) / TeamSepSquared
	-- 0 = enough separation, 1 = no separation
		
	-- TODO simple correction for now but maybe progressively penalise distances larger than maximumseparation?
	if SpawnDistance > self.SpawnsMaximumTeamSeparation then
		Sep = Sep * 5
		-- big penalty
	end

	local ProximityCorrection = (Sep * 10 * self.SpawnsScorePenaliseProximity)

	-- score shortfall

	local ShortfallCorrection = self.SpawnsScorePenaliseShortfall * 0.43429418977 * (1 + math.log ( 1 + (SpawnSet1.Shortfall + SpawnSet2.Shortfall) ))
	-- 0.43429... is the correction from ln to log10	
	
	if (SpawnSet1.Shortfall>0 or SpawnSet2.Shortfall > 0) then
		--print("Shortfall detected")
	end

	-- score spread

	local SpreadCorrection = 1 + (0.43429418977*math.log( math.max(1, SpawnSet1.Spread))) + (0.43429418977*math.log(math.max(1, SpawnSet2.Spread)))

	-- score spawns not being reachable from each other (which is ... good?)
	
	local ReachableCorrection 
	if  ai.CheckLocationReachable( SpawnCentre1, SpawnCentre2, false ) then
		ReachableCorrection = 2.0 * self.SpawnsScoreSpawnsNotReachableFromEachOther
		--print("Spawns reachable - ReachableCorrection = " .. ReachableCorrection)
	else
		--print("Spawns are not reachable")
		ReachableCorrection = 1.0
		-- no penalty if spawns AREN'T reachable from each other
	end

	local OverallCorrection = OldSpawnCorrection * ProximityCorrection * ShortfallCorrection * SpreadCorrection * ReachableCorrection
	-- bigger correction = worse

	if OverallCorrection < 0.01 then
		OverallCorrection = 0.01
	end

	Score = 100.0 / OverallCorrection

	return Score
end


function DTAS:FindBaseSpawnPoint_RandomPoint()
	-- this function returns a random base spawn location based on a random point within a volume defined by active game objects 

	local BaseSpawnLocation = nil
	local GameObjectBoundingBoxUE4 = self:GetUE4BoundingBox( self.GameObjectBoundingBox )

	local RandomSpawnLocation 
	-- this is a random insertion point / spawn point to test reachability
	-- the name is confusing, I admit
	
	if self.RandomNavMeshTestObject ~= nil then
		RandomSpawnLocation = actor.GetLocation( self.RandomNavMeshTestObject )
	else
		RandomSpawnLocation = nil
		print("DTAS: RandomNavMeshTestObject was nil")
	end
	
	-- nil if fails to find (for example if RandomNavMeshTestObject is nil, which we probably should test for)
	
	for i = 1, self.SpawnsNumberOfTriesToFindMainSpawn do
		local SpawnLocation = self:FindCandidateSpawn(GameObjectBoundingBoxUE4)
		
		if SpawnLocation == nil then
			print("DTAS: FindCandidateSpawn() returned nil")
		else
			if RandomSpawnLocation ~= nil then
			-- if can't find a random spawn location or other entity on the playable navmesh, then take current spawn location on trust 
			-- (this may fail, but if we can't find an insertion point, the map is clearly a bit borked anyway so we'll take what we can get)
				if not self:CheckLocationReachable( SpawnLocation, RandomSpawnLocation ) then
					SpawnLocation = nil
					--print("DTAS: base spawn was not reachable, trying again")
				end

			end
		
			if SpawnLocation ~= nil then
				if self.SpawnsExtraRandomizeStep then
					SpawnLocation = ai.GetRandomReachablePointInRadius(SpawnLocation, self.SpawnsRandomPointRandomWalkLength)
						-- SpawnLocation could be nil if there was an error, need to test for this
		
						-- TODO: when available, use the height of the navmesh bounds to set the search length
						-- in conjunction with SpawnsExtraRandomizeStepSearchLengthMultiplier 
				end
			
				local IsValidSpawn
				local CorrectedSpawnLocation	
				IsValidSpawn, CorrectedSpawnLocation = self:IsValidSpawn(SpawnLocation)
				
				if not IsValidSpawn then

					--print("DTAS: base spawn was deemed not valid by Kris' function - dumping")
					-- we could alternatively use the amended result but for now I prefer not
					--self:DumpVector(BaseSpawnLocation)
					SpawnLocation = nil
				else
					--print("corrected spawn Z diff = " .. CorrectedSpawnLocation.z - SpawnLocation.z)
					SpawnLocation = CorrectedSpawnLocation
				end
			end
		
			if SpawnLocation ~= nil then
				BaseSpawnLocation = SpawnLocation
				break
				-- end the search
			end

		end
	end

	return BaseSpawnLocation
end


function DTAS:FindBaseSpawnPoint_VoxelPoint()
	-- this function returns a random base spawn location based on a random point within a game-object-containing-voxel chosen from list of voxels 

	if #self.VoxelsOfInterest == 0 then
		return nil
	end

	local BaseSpawnLocation = nil

	local RandomSpawnLocation 
	-- this is a random insertion point / spawn point to test reachability
	-- the name is confusing, I admit
	
	if self.RandomNavMeshTestObject ~= nil then
		RandomSpawnLocation = actor.GetLocation( self.RandomNavMeshTestObject )
	else
		RandomSpawnLocation = nil
		print("DTAS: RandomNavMeshTestObject was nil")
	end
	
	-- nil if fails to find (for example if RandomNavMeshTestObject is nil, which we probably should test for)

	
	for i = 1, self.SpawnsNumberOfTriesToFindMainSpawn do

		local RandomVoxel = self.VoxelsOfInterest[ umath.random( #self.VoxelsOfInterest ) ]
		local UE4BoundingBox = self:GetUE4BoundingBox( RandomVoxel.BoundingBox )

		--print("Spawn finder: picking random point in voxel cell, index " .. RandomVoxel.VoxelIndex)
				
		local SpawnLocation = self:FindCandidateSpawnMaxQueryBounds(UE4BoundingBox)
		--self:DumpVector(UE4BoundingBox.Extent)
		
		if SpawnLocation == nil then
			print("DTAS: FindCandidateSpawn() returned nil")
		else
			if RandomSpawnLocation ~= nil then
			-- if can't find a random spawn location or other entity on the playable navmesh, then take current spawn location on trust 
			-- (this may fail, but if we can't find an insertion point, the map is clearly a bit borked anyway so we'll take what we can get)
				if not self:CheckLocationReachable( SpawnLocation, RandomSpawnLocation ) then
					SpawnLocation = nil
					--print("DTAS: base spawn was not reachable, trying again")
				end

			end
		
			if SpawnLocation ~= nil then
				if self.SpawnsExtraRandomizeStep then
					SpawnLocation = ai.GetRandomReachablePointInRadius(SpawnLocation, self.SpawnsRandomPointRandomWalkLength)
						-- SpawnLocation could be nil if there was an error, need to test for this
		
						-- TODO: when available, use the height of the navmesh bounds to set the search length
						-- in conjunction with SpawnsExtraRandomizeStepSearchLengthMultiplier 
				end
			
				-- no extra randomisation step for voxel method
			
				local IsValidSpawn
				local CorrectedSpawnLocation	
				IsValidSpawn, CorrectedSpawnLocation = self:IsValidSpawn(SpawnLocation)
				
				if not IsValidSpawn then

					--print("DTAS: base spawn was deemed not valid by Kris' function - dumping")
					-- we could alternatively use the amended result but for now I prefer not
					--self:DumpVector(BaseSpawnLocation)
					SpawnLocation = nil
				else
					--print("corrected spawn Z diff = " .. CorrectedSpawnLocation.z - SpawnLocation.z)
					SpawnLocation = CorrectedSpawnLocation
				end
			end
		
			if SpawnLocation ~= nil then
				BaseSpawnLocation = SpawnLocation
				break
				-- end the search
			end

		end
	end

	return BaseSpawnLocation
end


function DTAS:FindBaseSpawnPoint_GameObject()
	-- find a base spawn point based on a random walk from a random game object of suitable type

	local BaseSpawnLocation = nil
	
	if #self.GameModeObjectsUseForRandomSpawns < 1 then
		return nil
	end

	if #self.GameModeObjectsUseForRandomSpawns <= self.SpawnsNumberOfTriesToFindMainSpawn then
	
		for j = 1, #self.GameModeObjectsUseForRandomSpawns do
			-- have a few goes to find each sub spawn
								
			local RandomGameObject = self.GameModeObjectsUseForRandomSpawns[j]
			local GameObjectLocation = actor.GetLocation( RandomGameObject )
					
			BaseSpawnLocation = ai.GetRandomReachablePointInRadius(GameObjectLocation, self.SpawnsGameObjectRandomWalkLength)

			if BaseSpawnLocation ~= nil then
				local IsValidSpawn
				local CorrectedSpawnLocation	
				IsValidSpawn, CorrectedSpawnLocation = self:IsValidSpawn(BaseSpawnLocation)
			
				if not IsValidSpawn then
					--print("DTAS: base spawn was deemed not valid by Kris' function - dumping")
					-- we could alternatively use the amended result but for now I prefer not
					--self:DumpVector(BaseSpawnLocation)
					BaseSpawnLocation = nil
				else
					--print("corrected spawn Z diff = " .. CorrectedSpawnLocation.z - BaseSpawnLocation.z)
					BaseSpawnLocation = CorrectedSpawnLocation
				end
			end

			if BaseSpawnLocation ~= nil then
				break
			end
		end
		
	else

		local IndexList = {}
		for i = 1, #self.GameModeObjectsUseForRandomSpawns do
			table.insert(IndexList, i)
		end
		-- IndexList has indices from 1 .. n to allow us to pick random objects
		-- table looks like { {1, 1}, {2, 2}, {3, 3}, ... }
		
		local RandomIndexToRemove
		local RandomIndex
		
		for j = 1, self.SpawnsNumberOfTriesToFindMainSpawn do
			-- have a few goes to find each main spawn
				
			local RandomIndexToRemove = umath.random( #IndexList )
			RandomIndex = table.remove( IndexList, RandomIndexToRemove )
			--print("Picked random number " .. RandomIndex .. " from index " .. RandomIndexToRemove .. " of indexlist, current size " .. #IndexList)
				
			local RandomGameObject = self.GameModeObjectsUseForRandomSpawns[RandomIndex]
			local GameObjectLocation = actor.GetLocation( RandomGameObject )
					
			BaseSpawnLocation = ai.GetRandomReachablePointInRadius(GameObjectLocation, self.SpawnsGameObjectRandomWalkLength)


			local IsValidSpawn
			local CorrectedSpawnLocation	
			IsValidSpawn, CorrectedSpawnLocation = self:IsValidSpawn(BaseSpawnLocation)
			
			if not IsValidSpawn then
				--print("DTAS: base spawn was deemed not valid by Kris' function - dumping")
				-- we could alternatively use the amended result but for now I prefer not
				--self:DumpVector(BaseSpawnLocation)
				BaseSpawnLocation = nil
			else
				--print("corrected spawn Z diff = " .. CorrectedSpawnLocation.z - BaseSpawnLocation.z)
				BaseSpawnLocation = CorrectedSpawnLocation
			end

			if BaseSpawnLocation ~= nil or #IndexList<1 then
				break
			end
		end
	
	end
	
	-- after self.SpawnsNumberOfTriesToFindMainSpawn number of goes, default will be that BaseSpawnLocation is nil
	
	return BaseSpawnLocation
end


function DTAS:CheckLocationReachable( SpawnLocation, RandomSpawnLocation)
	-- test if we can path to the random spawn location, but also (if necessary/possible) see if we can path to other random game objects
	-- (the issue is that random locations inside buildings with doors closed probably won't be possible to reach from spawns, but may be reachable from AI spawns or mission objects)
		
	if ai.CheckLocationReachable( SpawnLocation, RandomSpawnLocation, false ) then
		return true
	end
	-- easiest case, we have direct route to spawn
	
	--print("DTAS:CheckLocationReachable: no path to spawn. Trying game objects. #self.GameModeObjectsUseForRandomSpawns = " .. #self.GameModeObjectsUseForRandomSpawns .. ", SpawnsNumberOfTriesToFindReachableGameObject = " .. self.SpawnsNumberOfTriesToFindReachableGameObject)
	
	if #self.GameModeObjectsUseForRandomSpawns <= self.SpawnsNumberOfTriesToFindReachableGameObject then
	-- just iterate through all game objects in this case
	
		for j = 1, #self.GameModeObjectsUseForRandomSpawns do
			-- have a few goes to find a random game object
					
			local RandomGameObject = self.GameModeObjectsUseForRandomSpawns[j]
			local RandomGameObjectLocation = actor.GetLocation( RandomGameObject )
						
			if ai.CheckLocationReachable( SpawnLocation, RandomGameObjectLocation, false ) then
				--print("success: found a path to a game object after " .. j .. " tries.")
				return true
			end
		end
	else
		
		local IndexList = {}
		for i = 1, #self.GameModeObjectsUseForRandomSpawns do
			table.insert(IndexList, i)
		end
		-- IndexList has indices from 1 .. n to allow us to pick random objects
		-- table looks like { {1, 1}, {2, 2}, {3, 3}, ... }
				
		for j = 1, self.SpawnsNumberOfTriesToFindReachableGameObject do
			-- have a few goes to find a random game object
				
			local RandomIndexToRemove = umath.random( #IndexList )
			RandomIndex = table.remove( IndexList, RandomIndexToRemove )
			--print("Picked random number " .. RandomIndex .. " from index " .. RandomIndexToRemove .. " of indexlist, current size " .. #IndexList)
				
			local RandomGameObject = self.GameModeObjectsUseForRandomSpawns[RandomIndex]
			local RandomGameObjectLocation = actor.GetLocation( RandomGameObject )
					
			if ai.CheckLocationReachable( SpawnLocation, RandomGameObjectLocation, false ) then
				--print("success: found a path to a game object")
				return true
			end
		end
	end
		
	return false
end


function DTAS:IsValidSpawn(SpawnLocation)
	-- test using Kris' GB-specific spawn validation/moving function

	local CapsuleHalfHeight = 100
	local CapsuleRadius = 40
	
	if SpawnLocation == nil then
		print("IsValidSpawn(): SpawnLocation was unexpectedly nil")
		return false
	end

	local ValidatedSpawnResult = self:GetCorrectedValidatedSpawnLocation( SpawnLocation, self.PlayerCapsuleHalfHeight, self.PlayerCapsuleRadius)
	
	if ValidatedSpawnResult == nil then
		print("IsValidSpawn(): GetCorrectedValidatedSpawnLocation() unexpectedly returned nil for SpawnLocation")
		return false
	end

	if not self:DidWeActuallyValidateLocation( ValidatedSpawnResult, SpawnLocation ) then
		if not ValidatedSpawnResult.bValid or ValidatedSpawnResult.ValidatedSpawnLocation == nil then
			--print("    !!!! IsValidSpawn: FAILED because spawn location failed validation entirely")
			return false
		elseif ValidatedSpawnResult.ValidatedSpawnLocation ~= SpawnLocation then
			--print("    !!!! IsValidSpawn: FAILED because ValidatedSpawnLocation ~= SpawnLocation")
		
			return false
		end
	end

	return true, ValidatedSpawnResult.ValidatedSpawnLocation
end


function DTAS:FindSubSpawns(BaseSpawnLocation, NumSpawnPointsToFind)
	-- this function picks sub spawn points in the vicinity of the base spawn point to a total of NumSpawnPointsToFind (including base spawn point)
	-- may have a shortfall if conditions are poor

	local SpawnLocationList = {}
	local SpawnsShortfall
	local WorstSpawnSpread = 0.0

	table.insert(SpawnLocationList, BaseSpawnLocation)
	-- this one is in the bank

	-- now find sub-spawns

	local MinSeparationSquared = self.SpawnsMinimumSpawnSeparation * self.SpawnsMinimumSpawnSeparation

	if #SpawnLocationList>0 and NumSpawnPointsToFind>1 then

		local NumberOfSpawnHardFails = 0
		local NumberOfSpawnSoftFails = 0
		local WorstSpawnSpreadSquared = 0

		for i = 1, NumSpawnPointsToFind-1 do
		-- -1 because we already found one spawn point (the base location)

			for j = 1, self.SpawnsNumberOfTriesToFindEachSubSpawn do
			-- have a few goes to find each sub spawn

				local SubSpawnLocation
				local SpawnSearchRadius = self.SpawnsInitialSpawnCheckRadius * self.SpawnsMultiplySpawnCheckRadius * (1 + math.sqrt(self:Clamp(NumberOfSpawnSoftFails-2, 0, 9) + NumberOfSpawnHardFails) )

				SubSpawnLocation = ai.GetRandomReachablePointInRadius(BaseSpawnLocation, SpawnSearchRadius)

				if SubSpawnLocation ~= nil then
					local IsValidSpawn
					local CorrectedSpawnLocation	
					IsValidSpawn, CorrectedSpawnLocation = self:IsValidSpawn(SubSpawnLocation)
				
					if not IsValidSpawn then
						SubSpawnLocation = nil
					else
						SubSpawnLocation = CorrectedSpawnLocation
						-- this is a bit redundant but clearer?
					end
				end

				if SubSpawnLocation == nil then
					-- hard spawn failure condition, give up finding this sub spawn entirely

					NumberOfSpawnHardFails = NumberOfSpawnHardFails + 1
					if NumberOfSpawnHardFails > self.SpawnsNumberOfHardFailsToPermit then
						-- hard spawn point fail mode
						--print("DTAS: hard spawn fail")

						SpawnsShortfall = NumSpawnPointsToFind - #SpawnLocationList
						if WorstSpawnSpread == 0.0 then
							WorstSpawnSpread = 10000.0
						end
						return SpawnLocationList, SpawnsShortfall, WorstSpawnSpread
					end

				else
					local CandidateWorstSpawnSpreadSquared = 0
					local SpawnFailed = false
					
					for k=1, #SpawnLocationList do
					-- check not too close to any existing spawns
						
						-- I know there is a vector subtract defined in vector but I am not sure it will work?
						local SpawnVector = self:VectorSubtract( SpawnLocationList[k], SubSpawnLocation )
						local DistSq = vector.SizeSq(SpawnVector)

						if DistSq < MinSeparationSquared then
						-- soft spawn failure condition
							NumberOfSpawnSoftFails = NumberOfSpawnSoftFails + 1
							if NumberOfSpawnSoftFails > NumSpawnPointsToFind * 2 then
								-- soft spawn point fail mode
								--print("DTAS: soft spawn fail")

								SpawnsShortfall = NumSpawnPointsToFind - #SpawnLocationList
								if WorstSpawnSpread == 0.0 then
									WorstSpawnSpread = 10000.0
								end
								return SpawnLocationList, SpawnsShortfall, WorstSpawnSpread
							end

							SpawnFailed = true
							break
						else
							if DistSq > CandidateWorstSpawnSpreadSquared then
								CandidateWorstSpawnSpreadSquared = DistSq
							end 
						end 

					-- end testing a particular other spawn to check separation
					-- (ends k loop)
					end

					if not SpawnFailed then
						-- sub spawn location is valid, so save it and update worst spread

						if CandidateWorstSpawnSpreadSquared > WorstSpawnSpreadSquared then
							WorstSpawnSpreadSquared = CandidateWorstSpawnSpreadSquared
						end 

						table.insert(SpawnLocationList, SubSpawnLocation)
						break
					end

				-- end processing valid spawn location
				end

			-- end particular attempt of N to find valid spawn location
			-- (ends j loop)
			end

		-- end finding a particular sub spawn
		-- (ends i loop)
		end

		WorstSpawnSpread = math.sqrt(WorstSpawnSpreadSquared)

	-- end finding additional (sub) spawns
	end

	SpawnsShortfall = NumSpawnPointsToFind - #SpawnLocationList
	return SpawnLocationList, SpawnsShortfall, WorstSpawnSpread
end


function DTAS:FindCandidateSpawn(GameObjectBoundingBoxUE4)
	local SpawnLocation
	local RandomPoint = self:FindRandomPointInBoundingBox(GameObjectBoundingBoxUE4)

	local QueryExtent = {}
	--QueryExtent.x = GameObjectBoundingBoxUE4.Extent.x * 0.1
	--QueryExtent.y = GameObjectBoundingBoxUE4.Extent.y * 0.1
	QueryExtent.x = 1000
	QueryExtent.y = 1000
	
	QueryExtent.z = GameObjectBoundingBoxUE4.Extent.z * 1

	SpawnLocation = ai.ProjectPointToNavigation( RandomPoint, QueryExtent )

	return SpawnLocation
end


function DTAS:FindCandidateSpawnMaxQueryBounds(GameObjectBoundingBoxUE4)
	--	this is version of normal routine but looks to limits of bounding box to find navmesh
	
	local SpawnLocation

	local RandomPoint = self:FindRandomPointInBoundingBox(GameObjectBoundingBoxUE4)

	local QueryExtent = {}
	QueryExtent.x = 2 * GameObjectBoundingBoxUE4.Extent.x
	QueryExtent.y = 2 * GameObjectBoundingBoxUE4.Extent.y
	QueryExtent.z = 2 * GameObjectBoundingBoxUE4.Extent.z

	SpawnLocation = ai.ProjectPointToNavigation( RandomPoint, QueryExtent )

	return SpawnLocation
end


function DTAS:FindRandomPointInBoundingBox(BoundingBoxUE4)
	local Result = {}

	local Centre = BoundingBoxUE4.Centre
	local Extent = BoundingBoxUE4.Extent

	Result.x = umath.randomrange ( Centre.x - Extent.x, Centre.x + Extent.x)
	Result.y = umath.randomrange ( Centre.y - Extent.y, Centre.y + Extent.y)
	Result.z = umath.randomrange ( Centre.z - Extent.z, Centre.z + Extent.z)

	return Result
end


function DTAS:VectorSubtract( Vector1, Vector2 )
--	returns Vector1 - Vector2 as table { {"x", ...}, {"y",...}, {"z",...} }

	local Result = {}

	if Vector1 == nil or Vector2 == nil then
		print("DTAS: VectorSubtract(): passed nil vector, returning nil")
		return nil
	end

	local Result = {}

	Result.x = Vector1.x - Vector2.x
	Result.y = Vector1.y - Vector2.y
	Result.z = Vector1.z - Vector2.z

	return Result
end


function DTAS:Clamp(val, min, max)
	if val <= min then
		val = min
	elseif max <= val then
		val = max
	end
	return val
end


function DTAS:GetSpawnInfo(PlayerState)
	--print("DTAS: GetSpawnInfo() called -------------------")
	
	local Result = {}
	local CurrentTeamId = actor.GetTeamId(PlayerState)

	Result.Rotation = self:GetRandomUprightRotation()
	-- maybe TODO: set Yaw rotation such that players face towards centre of map

	Result.Location = self:GetNextSpawnLocation(CurrentTeamId)
	-- could be nil

	local CurrentSpawnIndex = self.CurrentInsertionPointIndex[CurrentTeamId]
	-- first spawn index will be 1 (GetNextSpawnLocation() increments it before use)

	local SpawnRecordIndex = self:FindSpawnAttemptsIndex(PlayerState)
	
	if SpawnRecordIndex == nil then
		--print("GetSpawnInfo: making new spawnrecord entry")

		local SpawnRecord = {}

		SpawnRecord.SpawnInfo = Result
		SpawnRecord.AttemptsMade = 1
		SpawnRecord.PlayerState = PlayerState
		SpawnRecord.TeamId = CurrentTeamId
		SpawnRecord.SpawnIndex = CurrentSpawnIndex
		SpawnRecord.HasLooped = self.CurrentInsertionPointIndexHasLooped[CurrentTeamId]
		-- if has looped, don't remove it as a bad spawn (it will have worked for someone, who is probably blocking it right now)
	
		table.insert(self.SpawnAttempts, SpawnRecord)
		SpawnRecordIndex = #self.SpawnAttempts
		-- add spawn attempt to list
	else
		-- edit existing spawn attempt
		
		self.SpawnAttempts[SpawnRecordIndex].SpawnInfo = Result
		self.SpawnAttempts[SpawnRecordIndex].AttemptsMade = self.SpawnAttempts[SpawnRecordIndex].AttemptsMade + 1
		-- this is the number of attempts to spawn the player, not spawn at this index
		self.SpawnAttempts[SpawnRecordIndex].SpawnIndex = CurrentSpawnIndex
		self.SpawnAttempts[SpawnRecordIndex].HasLooped = self.CurrentInsertionPointIndexHasLooped[CurrentTeamId]
		-- if has looped, don't remove it as a bad spawn (it will have worked for someone, who is probably blocking it right now)
		
		-- playerstate and teamid remain unchanged
	end

    return Result;
end


function DTAS:SpawnFailedForPlayer(PlayerState)

	local SpawnRecordIndex = self:FindSpawnAttemptsIndex(PlayerState)
	local SpawnAttempt = 1
	
	if SpawnRecordIndex ~= nil then
		local SpawnRecord = self.SpawnAttempts[SpawnRecordIndex]
		
		if SpawnRecord.AttemptsMade >= self.MaximumSpawnAttemptsForPlayer then
			print("SpawnFailedForPlayer: Exceeded limit of " .. self.MaximumSpawnAttemptsForPlayer .. " spawn attempts for player - giving up")
			player.ShowGameMessage(PlayerState, "Spawn attempts failed - giving up.", self.ScreenPositionError, 5.0)
			return
		end
	
		SpawnAttempt = SpawnRecord.AttemptsMade	+ 1
	
		table.insert( self.FailedSpawns, SpawnRecord )
		--table.remove(self.SpawnAttempts, SpawnRecordIndex)

		print("SpawnFailedForPlayer: SpawnRecordIndex = " .. SpawnRecordIndex .. ", SpawnAttempts = " .. SpawnAttempt .. ", SpawnRecord.HasLooped = " .. tostring(SpawnRecord.HasLooped) )
		
		if SpawnRecord.HasLooped == false then
			-- this is the first time this spawn has been used, and it has failed, so we conclude it is a bad spawn
			-- we would like to remove it but that will bugger up the stored spawn indices for other spawns
			-- instead we could set it to a known bad spawn location
			-- but let's do it the slow but better way
			if SpawnRecord.SpawnIndex ~= nil then
				self:RemoveBadSpawnFromInsertionPointList( SpawnRecord.TeamId, SpawnRecord.SpawnIndex )
			end
		end
		
		player.ShowGameMessage(PlayerState, "Previous spawn attempt failed - trying attempt " .. SpawnAttempt, self.ScreenPositionError, 5.0)
	else
		-- player was never spawned? error
		print("Could not find saved spawn record for failed spawn - this is unexpected")
		-- actually we can get here if there is an admin startround command
	end

	print("SpawnFailedForPlayer: Attempting to respawn player")

	gamemode.EnterPlayArea(PlayerState)
	-- cause respawn, this will in turn call GetSpawnInfo again
end


function DTAS:RemoveBadSpawnFromInsertionPointList( TeamId, SpawnIndex )

	if SpawnIndex == nil then
		return
	end

	if TeamId == self.DefendingTeam.TeamId then
	
		print("RemoveBadSpawnFromInsertionPointList: Removing insertion point " .. SpawnIndex .. " for defending team (ID " .. TeamId .. ")")
	
		if #self.DefenderInsertionPoints <= 1 then
			-- at this point, spawns are fair buggered
			-- TODO could generate whole new set of spawns? 
			-- for now, just do nothing so other things don't break (array is empty)
			return
		end
		-- first the easy bit - remove it from the list
		table.remove( self.DefenderInsertionPoints, SpawnIndex )
		print("RemoveBadSpawnFromInsertionPointList: " .. #self.DefenderInsertionPoints .. " spawn points remain for defending team")
	else
	
		print("RemoveBadSpawnFromInsertionPointList: Removing insertion point " .. SpawnIndex .. " for attacking team (ID " .. TeamId .. ")")
	
		if #self.AttackerInsertionPoints <= 1 then
			-- at this point, spawns are fair buggered
			-- TODO could generate whole new set of spawns? 
			-- for now, just do nothing so other things don't break (array is empty)
			return
		end
	
		-- TeamId = self.AttackingTeam.TeamId by process of elimination
		table.remove( self.AttackerInsertionPoints, SpawnIndex )
		print("RemoveBadSpawnFromInsertionPointList: " .. #self.AttackerInsertionPoints .. " spawn points remain for attacking team")
	
	end
			
	-- adjust the current insertion point if needed
	if self.CurrentInsertionPointIndex[TeamId] >= SpawnIndex then
		self.CurrentInsertionPointIndex[TeamId] = self.CurrentInsertionPointIndex[TeamId] - 1
	end	
		
		
	-- now iterate through all spawns to adjust other stored spawn indices
	for i = 1, #self.SpawnAttempts do
		if self.SpawnAttempts[i].TeamId == TeamId and self.SpawnAttempts[i].CurrentSpawnIndex ~= nil then
			if self.SpawnAttempts[i].CurrentSpawnIndex == SpawnIndex then
				-- this is same spawn that we just deleted. Chances are this is the spawn we're currently dealing with (but there could be others)
				self.SpawnAttempts[i].CurrentSpawnIndex = nil
				-- we better test for this
				print("RemoveBadSpawnFromInsertionPointList: set SpawnIndex of spawn attempt index " .. i .. " to nil")
			elseif self.SpawnAttempts[i].CurrentSpawnIndex > SpawnIndex then
				self.SpawnAttempts[i].CurrentSpawnIndex = self.SpawnAttempts[i].CurrentSpawnIndex - 1
			end
		end
	end

end


function DTAS:FindSpawnAttemptsIndex(PlayerState)
-- find the index of the (last) spawn record for player PlayerState
		
	for i = 1, #self.SpawnAttempts do
		if self.SpawnAttempts[i].PlayerState == PlayerState then
			return i
		end
	end
	
	return nil
end


function DTAS:GetRandomUprightRotation()
	local Result = {}
		
	Result = {}
	
	Result.Pitch = 0.0
    Result.Yaw = umath.randomrange(-180.0, 180.0);
    Result.Roll = 0.0
		    
    return Result;

end


function DTAS:GetNextSpawnLocation(TeamId)

	local Location = nil
	
	if TeamId == self.DefendingTeam.TeamId then
		if #self.DefenderInsertionPoints == 0 then
			-- bad spawns, hard fail
		else
			self.CurrentInsertionPointIndex[TeamId] = self.CurrentInsertionPointIndex[TeamId] + 1
			if self.CurrentInsertionPointIndex[TeamId] > #self.DefenderInsertionPoints then
				self.CurrentInsertionPointIndex[TeamId] = 0
				self.CurrentInsertionPointIndexHasLooped[TeamId] = true
				--TODO delay until spawn is clear? test for clear spawns?
			end
			
			Location = {}
			Location = self.DefenderInsertionPoints[self.CurrentInsertionPointIndex[TeamId]]
			
			if Location == nil then
				print("DTAS:GetNextSpawnLocation - DefenderInsertionPoints[" .. self.CurrentInsertionPointIndex[TeamId] .. "] is nil")
				return nil
			else
				Location.z = Location.z + self.PlayerCapsuleHalfHeight + 10
				--Location.z = Location.z + 70
			end
			
		end
	else
		if #self.AttackerInsertionPoints == 0 then
			-- bad spawns, hard fail
		else
			self.CurrentInsertionPointIndex[TeamId] = self.CurrentInsertionPointIndex[TeamId] + 1
			if self.CurrentInsertionPointIndex[TeamId] > #self.AttackerInsertionPoints then
				self.CurrentInsertionPointIndex[TeamId] = 0
				self.CurrentInsertionPointIndexHasLooped[TeamId] = true

				--TODO delay until spawn is clear? test for clear spawns?
						-- bad spawns?
			end
			
			Location = {}
			Location = self.AttackerInsertionPoints[self.CurrentInsertionPointIndex[TeamId]]
			
			if Location == nil then
				print("DTAS:GetNextSpawnLocation - AttackerInsertionPoints[" .. self.CurrentInsertionPointIndex[TeamId] .. "] is nil")
				return nil
			else
				Location.z = Location.z + self.PlayerCapsuleHalfHeight + 10
				--Location.z = Location.z + 70
			end
		end
	end

	return Location

end

------------ end find spawn points -----------------------------------



function DTAS:OnCharacterDied(Character, CharacterController, KillerController)
	-- TODO determine if this is an 'admin kill' and do not award a TK if so

	if gamemode.GetRoundStage() == "PreRoundWait" 
	or gamemode.GetRoundStage() == "DTASSetup"
	or gamemode.GetRoundStage() == "DTASInProgress"
	or gamemode.GetRoundStage() == "FoxHuntSetup" 
	or gamemode.GetRoundStage() == "FoxHuntInProgress" then
		if CharacterController ~= nil then
			local LivesLeft
			if not actor.HasTag(CharacterController, self.OpForTeamTag) then
				LivesLeft = math.max(0, player.GetLives(CharacterController) - 1)
				player.SetLives(CharacterController, LivesLeft)
				--print("Human died")
			else
				LivesLeft = 0
				actor.RemoveTag(CharacterController, self.OpForTeamTag)
				-- clear this AI from future consideration
				--print("AI died")
			end

			if gamemode.GetRoundStage() == "DTASSetup" and 
			self.FlagCarrierIsAI == false and
			CharacterController == self.FlagCarrier and
			self.FlagPlacement == nil then

				-- self.FlagPlacement == nil means flag is not placed yet
				self:AbandonRound("FlagCarrierDiedOrLeft")

			end

			if gamemode.GetRoundStage() ~= "PostRoundWait" then
				-- don't want to do scoring once round is over

				local KillerPlayerState = nil
				local KilledPlayerState = player.GetPlayerState(CharacterController)
				
				if KillerController ~= nil then
					KillerPlayerState = player.GetPlayerState(KillerController)
				end
				
				local KillerTeam = actor.GetTeamId( KillerController ) 
				local KilledTeam = actor.GetTeamId( CharacterController )

				-- do scoring stuff
				if KillerController ~= nil then
							
					if KillerTeam ~= KilledTeam then
						self:AwardPlayerScore( KillerPlayerState, "Killed" )
						self:AwardTeamScore( KillerTeam, "Killed" )
						
						-- award score to everyone in proximity of killer
						local KillerTeamList = gamemode.GetPlayerListByLives(KillerTeam, 1, true)
						-- list of player states
						
						local SomeoneWasInRange = false
						
						for _, Player in ipairs(KillerTeamList) do
							if Player ~= KillerPlayerState then
								if self:GetDistanceBetweenPlayers(Player, KillerPlayerState, false) <= self.ScoringKillProximity then
									self:AwardPlayerScore( Player, "InRangeOfKill" )
									SomeoneWasInRange = true
								end
							end
						end
						
						if SomeoneWasInRange then
							self:AwardTeamScore( KillerTeam, "InRangeOfKill" )
						end
						
						self.LastKiller = KillerPlayerState
					
					else
						-- suicides count as TKs
						self:AwardPlayerScore( KillerPlayerState, "TeamKill" )
						self:AwardTeamScore( KillerTeam, "TeamKill" )
						
					end

				end
				
				if self.CurrentDTASGameMode == 'DTAS' then
					-- DTAS mode
					
					if not actor.HasTag(CharacterController, self.OpForTeamTag)
					and self.FlagPlacement ~= nil then
	
						if self:IsInFlagRange( CharacterController ) and KillerTeam ~= KilledTeam then
						-- died in range, currently we'll give points to either side (att/def)
						-- TKs and suicides don't count
							self:AwardPlayerScore( KilledPlayerState, "DiedInRange")
							
							if KillerTeam == self.DefendingTeam.TeamId then
								self:AwardPlayerScore( KillerPlayerState, "PreventedCapture")
								self:AwardTeamScore( KillerTeam, "PreventedCapture")
								-- can only be awarded once
							end
						end
					end
				else
					-- fox hunt mode
			
					if self.FoxPlayer ~= nil and
					(KilledPlayerState == self.FoxPlayer or CharacterController == self.FoxPlayer) then
					-- KilledPlayer is the asset, CharacterController is FoxPlayer if it is AI
						--print("OnCharacterDied: fox was killed, KillerTeam = " .. KillerTeam)
					
						if KillerTeam == self.AttackingTeam.TeamId then
						-- suicides and TKs don't count
							self:AwardPlayerScore( KillerPlayerState, "KilledAsset")
						end
						
						self:AwardTeamScore( self.AttackingTeam.TeamId, "AssetKilled" )
						
						local LivingDefenders = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, true)
						if #LivingDefenders > 0 then
							self:AwardPlayerScore( KilledPlayerState, "DyingAssetDefsAlive")
							self:AwardTeamScore(  self.DefendingTeam.TeamId, "AssetDiedDefsAlive" )
						end
					end
				end

			end

			local PlayersWithLives = gamemode.GetPlayerListByLives(255, 1, false)
			if #PlayersWithLives == 0 then
				self:CheckEndRoundTimer()
				-- call immediately because round is about to end and nothing more can happen
			else
				timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
			end

		end
	end
end


function DTAS:GetDistanceBetweenPlayers(Player1, Player2, TwoDimensional)
-- returns distance in metres between the players

	if Player1 == nil or Player2 == nil then
		return 1000 * 100
	end
	
	local Character1 = player.GetCharacter(Player1)
	local Character2 = player.GetCharacter(Player2)

	if Character1 == nil or Character2 == nil then
		return 10000
	end
	
	local Location1 = actor.GetLocation( Character1 )
	local Location2 = actor.GetLocation( Character2 )
	
	local DifferenceVector = self:VectorSubtract( Location1, Location2 )
	
	if TwoDimensional then
		return vector.Size2D(DifferenceVector) / 100
	else
		return vector.Size(DifferenceVector) / 100
	end
end


function DTAS:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "DTASInProgress" 
	or gamemode.GetRoundStage() == "DTASSetup"
	or gamemode.GetRoundStage() == "FoxHuntInProgress"
	or gamemode.GetRoundStage() == "FoxHuntSetup" then
		return true
	end
	return false
end


function DTAS:PlayerCanEnterPlayArea(PlayerState)
	if self.Settings.BalanceTeams.Value == 0 then
		-- if balance teams is OFF then let players join any time (that they normally can) e.g. during PreRoundWait
		return true
	end

	if gamemode.GetRoundStage() == "ReadyCountdown"
	or gamemode.GetRoundStage() == "WaitingForReady" then
		return true
	end

	for i = 1, #self.PlayersWaitingToSpawnIn do
		if self.PlayersWaitingToSpawnIn[i] == PlayerState then
			-- if player is waiting to spawn in, then yes they can enter play area
			return true
		end
	end

	return false
	-- return true
end



-- Game Round Stages:

-- WaitingForReady	-- players are in ready room at start of game/map/set of rounds
-- ReadyCountdown	-- at least one player has clicked on map
-- PreRoundWait		-- players have been spawned into the level but are frozen (to allow all other players to spawn in)
-- FoxHuntSetup		-- all players are frozen and can't shoot except Fox
-- FoxHuntInProgress	-- Fox Hunt round is in progress
-- FoxHuntTransitionToDTAS	-- Fox Hunt is about to transition to DTAS - this might be too complex? just end round?
-- DTASSetup		-- both sides can move but neither can shoot. Defenders are finding place for flag
-- DTASInProgress	-- DTAS round is in progress
-- PostRoundWait	-- round has ended, post round info is displayed
-- TimeLimitReached	-- round timed out    ** setting this stage will cause server to go to next map **


function DTAS:DetermineRoundType()
	
	local BluePlayers = self:GetPlayerListIsPlaying(self.PlayerTeams.Blue.TeamId, false)
	local RedPlayers = self:GetPlayerListIsPlaying(self.PlayerTeams.Red.TeamId, false)
	-- we assume no one has died yet
	
	if #BluePlayers >= self.ServerSettings.MinPlayersOnEachTeamForDTAS.Value and #RedPlayers >= self.ServerSettings.MinPlayersOnEachTeamForDTAS.Value then
		return "DTAS"
	else
		return "FoxHunt"
	end
end


function DTAS:GetTotalPlayersOnTeamIncludingAI(TeamId)

		local LivingHumans = gamemode.GetPlayerListByLives(TeamId, 1, true)
		local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, TeamId, 255)
		return #LivingHumans + #OpForControllers
end


function DTAS:OnRoundStageTimeElapsed(RoundStage)
	if RoundStage == "ReadyCountdown" then
		self:GiveEveryoneReadiedUpStatus()
		-- do this before balancing teams
		self:BalanceTeams()

	elseif RoundStage == "PreRoundWait" then

		if #self.PlayersWaitingToSpawnIn>0 and self.NumberOfSpawnAttemptCycles <= self.MaximumSpawnAttemptCycles then
			print("OnRoundStageTimeElapsed: still waiting for players to spawn in - resetting round stage")
			self:ShowAttackersDefendersMessage("WaitingForSpawns","WaitingForSpawns", self.ScreenPositionRoundInfo, 2.0)	
			gamemode.SetRoundStage("PreRoundWait")
			gamemode.SetRoundStageTime(5.0)
			return true
		end

		self:GiveEveryoneReadiedUpStatus()
		-- do this again in case we had late joiners
		
		
		--self:BalanceTeams()
		-- disabled 2022/3/6 by MF because getting people switching teams after spawning with other team
		-- to compensate for this, ideally need to stop late joiners, but we need that mechanism for when spawns fail and we retry
		
		-- do this a second time? but person switching will have knowledge of spawns
		-- otherwise can get unbalanced teams and maybe fox hunt (1v3) instead of dtas (2v2)

		self.CurrentDTASGameMode = self:DetermineRoundType()
		if self.Settings.ForceDTAS.Value == 1 then
			self.CurrentDTASGameMode = 'DTAS'
			--print("Overriding to DTAS mode")
		end
		if self.Settings.ForceDTAS.Value == 2 then
			self.CurrentDTASGameMode = 'FoxHunt'
			--print("Overriding to Fox Hunt mode")
		end

		-- self.CurrentDTASGameMode is now definitive
		gamemode.SetGameModeName(self.CurrentDTASGameMode)
		-- this function allows us to tell the game that we are different game modes, as and when we wish

		if self.CurrentDTASGameMode == "DTAS" then
			gamemode.SetRoundStage("DTASSetup")

			gamemode.BroadcastGameMessage("DTAS ROUND " .. self.CurrentRoundNumber, self.ScreenPositionRoundInfo, math.max(3.0, self.Settings.FlagPlacementTime.Value))
			
			self:ShowDTASMessage("DTASBeginSetupAttack","DTASBeginSetupDefend", "DTASBeginSetupFlagCarrier", self.ScreenPositionRoundInfo, math.max(3.0, self.Settings.FlagPlacementTime.Value))

			if self.AttackingTeam.TeamId == self.PlayerTeams.Red.TeamId then
				self:ShowAttackersDefendersMessage("YouAreAttackerRed", "YouAreDefenderBlue", self.ScreenPositionSetupStatus, math.max(3.0, self.Settings.FlagPlacementTime.Value))
			else
				self:ShowAttackersDefendersMessage("YouAreAttackerBlue", "YouAreDefenderRed", self.ScreenPositionSetupStatus, math.max(3.0, self.Settings.FlagPlacementTime.Value))
			end
			
			timer.Set("FinaliseDTASSetup", self, self.FinaliseDTASSetup, 0.2, false)

		else
			gamemode.SetRoundStage("FoxHuntSetup")
			
			gamemode.SetRoundIsTemporaryGameMode(true)
			-- stops round counter being incremented or match scores being updated. Is reset by the game each round at WaitingForReady
			
			if self:GetTotalPlayersOnTeamIncludingAI(self.DefendingTeam.TeamId) > 1 then
				self:ShowFoxHuntMessage("FoxHuntSetupAttack","FoxHuntSetupDefend","FoxHuntSetupFox", self.ScreenPositionRoundInfo, math.max(3.0, self.ServerSettings.FoxHuntSetupTime.Value ))	
			else
				self:ShowFoxHuntMessage("FoxHuntSetupAttack","FoxHuntSetupDefend","FoxHuntSetupFoxSolo", self.ScreenPositionRoundInfo, math.max(3.0, self.ServerSettings.FoxHuntSetupTime.Value ))
			end
			
			if self.AttackingTeam.TeamId == self.PlayerTeams.Red.TeamId then
				self:ShowAttackersDefendersMessage("YouAreAttackerRed", "YouAreDefenderBlue", self.ScreenPositionSetupStatus, math.max(3.0, self.ServerSettings.FoxHuntSetupTime.Value))
			else
				self:ShowAttackersDefendersMessage("YouAreAttackerBlue", "YouAreDefenderRed", self.ScreenPositionSetupStatus, math.max(3.0, self.ServerSettings.FoxHuntSetupTime.Value))
			end
			
			--self:ShowFoxHuntMessage("FoxHuntSetupAttackSmallText","FoxHuntSetupDefendSmallText","FoxHuntSetupFoxSmallText", self.ScreenPositionSetupStatus, math.max(3.0, self.ServerSettings.FoxHuntSetupTime.Value ))	

			timer.Set("FinaliseFoxHuntSetup", self, self.FinaliseFoxHuntSetup, 0.2, false)
		end
		
		--return true
		-- true for handled (otherwise apply default behaviour)
	end

	if RoundStage == "DTASSetup" then
		self:ShowAttackersDefendersMessage("DTASBeginAttack","DTASBeginDefend", self.ScreenPositionRoundInfo, 3.0)	
		gamemode.SetRoundStage("DTASInProgress")
		return true
	elseif RoundStage == "FoxHuntSetup" then
		self:ShowFoxHuntMessage("FoxHuntAttack","FoxHuntDefend","FoxHuntDefendFox", self.ScreenPositionRoundInfo, 3.0)			
		gamemode.SetRoundStage("FoxHuntInProgress")	
		return true
	end


	if RoundStage == "DTASInProgress" or RoundStage == "FoxHuntInProgress" then
	
		self:GameTimerExpired()
		-- this will set the round stage to PostRoundWait
		
		--gamemode.SetRoundStage("TimeLimitReached")
		--do not set round stage to this! Will cause server to move on to next map
		return true
		-- handled
		
	elseif RoundStage == "RoundAbandoned" then
		
		timer.ClearAll()
		
		gamemode.SendEveryoneToReadyRoom()
		gamemode.SetRoundStage("WaitingForReady")
		return true
	
	elseif RoundStage == "PostRoundWait" then
			
		timer.ClearAll()
	end

	return false
end


function DTAS:FinaliseDTASSetup()
	local LivingAttackers = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, false)
	local LivingDefenders = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, false)

	-- spawn in AI if needed
	
	--TODO revisit this - spawns AI when players are in level

	if #LivingAttackers < 1  then
		--print("Spawning in an attacker")
		local DuffSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
		local RandomSpawnPoint = umath.random(#DuffSpawns)
		actor.SetTeamId(DuffSpawns[RandomSpawnPoint], self.AttackingTeam.TeamId)
		ai.Create(DuffSpawns[RandomSpawnPoint], self.OpForTeamTag, 3.0)
		-- TODO replace this (hopefully) with a command specifying TeamID and location rather than requiring an AI spawnpoint
	elseif #LivingDefenders < 1 then
		--print("Spawning in a defender")
		local DuffSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
		local RandomSpawnPoint = umath.random(#DuffSpawns)
		actor.SetTeamId(DuffSpawns[RandomSpawnPoint], self.DefendingTeam.TeamId)
		ai.Create(DuffSpawns[RandomSpawnPoint], self.OpForTeamTag, 3.0)
		-- TODO replace this (hopefully) with a command specifying TeamID and location rather than requiring an AI spawnpoint
	end

	gamemode.SetTeamAttitude(self.DefendingTeam.TeamId, self.AttackingTeam.TeamId, "hostile")
	gamemode.SetTeamAttitude(self.AttackingTeam.TeamId, self.DefendingTeam.TeamId, "hostile")

	if self.FlagCarrier == nil then
		self:SelectFlagCarrier()
	-- call this fella again to pick a flag carrier
	end

	self.StartingDefendingTeamSize = self:GetTotalPlayersOnTeamIncludingAI(self.DefendingTeam.TeamId)
	self.StartingAttackingTeamSize = self:GetTotalPlayersOnTeamIncludingAI(self.AttackingTeam.TeamId)
end


function DTAS:DidWeActuallyValidateLocation( ValidationResult, PlayerLocation )

	if ValidationResult == nil or PlayerLocation == nil then
		return false
	end
	-- added 10/7/21

	if ValidationResult.bValid == false or ValidationResult.ValidatedSpawnLocation == nil then
		return false
	end

	local ValidatedLocation = ValidationResult.ValidatedSpawnLocation
	
	local VD = self:VectorSubtract (ValidatedLocation, PlayerLocation)
	
	if VD.x == 0 and VD.y == 0 and VD.z < 150 and VD.z > -150 then
	-- typically VD.z = 93 point blah
		return true
	else
		print("    !!!! Location Not Validated. Vector difference: x=" .. VD.x .. ", y=" .. VD.y .. ", z= " .. VD.z)
			
		return false
	end
end





function DTAS:GetCorrectedValidatedSpawnLocation( PlayerLocation, PlayerCapsuleHalfHeight, PlayerCapsuleRadius )

	if PlayerLocation ~= nil then
		PlayerLocation.z = PlayerLocation.z + PlayerCapsuleHalfHeight
		-- this is around the size of the normal correction made by the function
	end

	return gameplaystatics.GetValidatedSpawnLocation( PlayerLocation, PlayerCapsuleHalfHeight, PlayerCapsuleRadius )
end





function DTAS:PlaceFlag()
-- return true is successful, return false for failure (end round)

    -- place the flag in the level:
	if self.FlagCarrierIsAI and self.FlagCarrier ~= nil then

	-- deal with AI flag carrier scenario first
	
		-- don't physically place flag (yet)
		local PlayerChar = player.GetCharacter( self.FlagCarrier )
		if PlayerChar ~= nil then
			local PlayerLocation = actor.GetLocation( PlayerChar )	
			PlayerLocation.z = PlayerLocation.z - 80
			self.Flag = gameplaystatics.PlaceItemAt( '/Game/GroundBranch/Inventory/Equipment/Flag/BP_CarriedGameModeFlag.BP_CarriedGameModeFlag_C', PlayerLocation, self:GetRandomUprightRotation() )
		end
	end

	if self.FlagCarrier == nil or self.Flag == nil then
		-- hmmm this shouldn't happen
		
		self:SelectFlagCarrier()
		
		if self.FlagCarrier == nil or self.Flag == nil then
			self:AbandonRound("UnexpectedFlagPlacementError")
			return false
		end
	end
	
	-- self.Flag has been validated as being non-nil
	
	GetLuaComp(self.Flag).Place()
	-- is reference to Flag still valid? Does it persist as an object?
	-- what if flag is already placed by player? -> this still seems to work, or at least, not to fail

	local FlagLocation = actor.GetLocation( self.Flag )

	local QueryExtent = {}
	
	-- we're using less than the full radius and less than half the height because ideally we should have navmesh fairly close to flag
	-- theoretically you only need a bit of navmesh within the radius and height, but that would be a sucky placement regardless
	
	QueryExtent.x = self.ServerSettings.CaptureRadius.Value * 100 * 0.7
	QueryExtent.y = self.ServerSettings.CaptureRadius.Value * 100 * 0.7
	QueryExtent.z = self.ServerSettings.CaptureHeight.Value * 100 * 0.35
		
	local TestLocation
			
	TestLocation = ai.ProjectPointToNavigation( FlagLocation, QueryExtent )
	-- we don't care where the navmesh is, just whether a point was found (returns vector) or not (returns nil)
					
	if TestLocation == nil then
		-- no viable navmesh found closeish to flag - = bad placement
		self:AbandonRound("FlagPlacementOutOfBoundsError")
		return false
	end
	
	-- valid placement
	self.FlagPlacement = FlagLocation
	gamemode.SetObjectiveLocation( FlagLocation )
	-- this is static so don't update it any more

	-- show all defenders the location of the flag (for a while)
	local DefenderPlayers = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, true)
	for _, Defender in ipairs(DefenderPlayers) do
		player.ShowWorldPrompt(Defender, self.FlagPlacement, "Placed Flag", 15.0)
	end
	
	return true
	-- success
end


function DTAS:FinaliseFoxHuntSetup()
	local LivingAttackers = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, false)
	local LivingDefenders = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, false)

	-- spawn in AI if needed

	if #LivingAttackers < 1  then
		--print("Spawning in an attacker")
		local DuffSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
		local RandomSpawnPoint = umath.random(#DuffSpawns)
		actor.SetTeamId(DuffSpawns[RandomSpawnPoint], self.AttackingTeam.TeamId)
		ai.Create(DuffSpawns[RandomSpawnPoint], self.OpForTeamTag, 3.0)
		-- TODO replace this (hopefully) with a command specifying TeamID and location rather than requiring an AI spawnpoint
	elseif #LivingDefenders < 1 then
		--print("Spawning in a defender")
		local DuffSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
		local RandomSpawnPoint = umath.random(#DuffSpawns)
		actor.SetTeamId(DuffSpawns[RandomSpawnPoint], self.DefendingTeam.TeamId)
		ai.Create(DuffSpawns[RandomSpawnPoint], self.OpForTeamTag, 3.0)
		-- TODO replace this (hopefully) with a command specifying TeamID and location rather than requiring an AI spawnpoint
	end

	gamemode.SetTeamAttitude(self.DefendingTeam.TeamId, self.AttackingTeam.TeamId, "hostile")
	gamemode.SetTeamAttitude(self.AttackingTeam.TeamId, self.DefendingTeam.TeamId, "hostile")

	if self.FoxPlayer == nil then
		self:SelectFoxPlayer()
	-- call this fella again to pick a fox
	end


	self.StartingDefendingTeamSize = self:GetTotalPlayersOnTeamIncludingAI(self.DefendingTeam.TeamId)
	self.StartingAttackingTeamSize = self:GetTotalPlayersOnTeamIncludingAI(self.AttackingTeam.TeamId)

end


function DTAS:ShowAttackersDefendersMessage(AttackerMessage, DefenderMessage, Location, Duration)
	local Attackers = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, true)
	local Defenders = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, true)

	if Attackers ~= nil and Defenders ~= nil then
		
		for i = 1, #Attackers do
			player.ShowGameMessage(Attackers[i], AttackerMessage, Location, Duration)
		end
		
		for i = 1, #Defenders do
			player.ShowGameMessage(Defenders[i], DefenderMessage, Location, Duration)
		end

	end
end


function DTAS:ShowFoxHuntMessage(AttackerMessage, DefenderMessage, FoxMessage, Location, Duration)
	local Attackers = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, true)
	local Defenders = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, true)

	if Attackers ~= nil and Defenders ~= nil then

		for i = 1, #Attackers do
			player.ShowGameMessage(Attackers[i], AttackerMessage, Location, Duration)
		end
		
		for i = 1, #Defenders do
			if Defenders[i] == self.FoxPlayer then
				player.ShowGameMessage(Defenders[i], FoxMessage, Location, Duration)
			else
				player.ShowGameMessage(Defenders[i], DefenderMessage, Location, Duration)
			end
		end

	end
end


function DTAS:ShowDTASMessage(AttackerMessage, DefenderMessage, FlagCarrierMessage, Location, Duration)
	local Attackers = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1,  true)
	local Defenders = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, true)

	if Attackers ~= nil and Defenders ~= nil then
		for i = 1, #Attackers do
			player.ShowGameMessage(Attackers[i], AttackerMessage, Location, Duration)
		end
		
		for i = 1, #Defenders do
			if Defenders[i] == self.FlagCarrier then
				player.ShowGameMessage(Defenders[i], FlagCarrierMessage, Location, Duration)
			else
				player.ShowGameMessage(Defenders[i], DefenderMessage, Location, Duration)
			end
		end
	end
end


function DTAS:OnProcessCommand(Command, Params)
--	if Command == "defendersetuptime" then
--		if Params ~= nil then
--			self.DefenderSetupTime = math.max(tonumber(Params), self.MinDefenderSetupTime)
--			self.DefenderSetupTime = math.min(self.DefenderSetupTime, self.MaxDefenderSetupTime)
--		end
--	elseif Command == "capturetime" then
--		self.CaptureTime = math.max(tonumber(Params), self.MinCaptureTime)
--		self.CaptureTime = math.min(self.CaptureTime, self.MaxCaptureTime)
--	elseif Command == "autoswap" then
--		if Params ~= nil then
--			self.AutoSwap = (tonumber(Params) == 1)
--		end
--	end

-- original DTAS console commands:
--
--mutate TASstatus - sends you a reminder about your mission in the current round
--mutate DTAShelp - displays a brief help text
--mutate RTSMySpawn - displays information about your current spawnpoint (admins will see spawns of both teams)
--NOTE: if anything bad happens to any member of your team due to a bad spawnpoint, 
-- use this command and relay the information to a server admin or post it in the Inf Forum "New DTAS" thread
-- mutate iamthechosenone - will tell DTAS that you are interested in being the fox/flag placer 
-- mutate iamnotworthy - will tell DTAS that you are no longer interested in being the fox/flag placer
-- NOTE: this won't protect you from becoming the fox/flag placer if all entered the command
-- mutate DTASFoxOn - enables Fox mode (admin only)
-- mutate DTASFoxOff - disables Fox mode (admin only)
-- mutate PlayFox - activate Fox mode
-- mutate PlayDTAS - activate DTAS mode
-- mutate DTASBeDefender - sets the team of the admin entering this command to defender, logs him out and restarts the round
-- mutate DTASBeAttacker - sets the team of the admin entering this command to defender, logs him out and restarts the round
end


function DTAS:TargetCaptured()
	gamemode.AddGameStat("Result=Team" .. tostring(self.AttackingTeam.TeamId))
	gamemode.AddGameStat("Summary=CaptureObjective")
	gamemode.AddGameStat("CompleteObjectives=CaptureObjective")
	
	local AttackerPlayers = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, true)	
	for _,Player in ipairs(AttackerPlayers) do
		if self:IsInFlagRange(Player) then
			self:AwardPlayerScore( Player, "CapturedFlag" )
		end
	end
	
	self:AwardTeamScore( self.AttackingTeam.TeamId, "CapturedFlag" )
	
	local ThereWasADefenderOutOfRange = false
	
	local DefenderPlayers = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, true)	
	for _,Player in ipairs(DefenderPlayers) do
		if not self:IsInFlagRange(Player) then
			self:AwardPlayerScore( Player, "DefenderOutsideRange" )
			ThereWasADefenderOutOfRange = true
		end
	end

	if ThereWasADefenderOutOfRange then
		self:AwardTeamScore( self.DefendingTeam.TeamId, "DefenderOutsideRange" )
	end
	
	self:ScorePlayersAtEndOfRound( self.AttackingTeam.TeamId )
	
	gamemode.SetRoundStage("PostRoundWait")
end


function DTAS:PlayerEnteredPlayArea(PlayerState)

	-- this is not reached if spawns fail, so we use this to determined failed spawns

	for i = 1, #self.PlayersWaitingToSpawnIn do
		if self.PlayersWaitingToSpawnIn[i] == PlayerState then
			-- remove player from the list of people waiting to spawn in -  they have now spawned
			table.remove( self.PlayersWaitingToSpawnIn, i )
			--print("PlayerEnteredPlayArea: removed 1 player from list waiting to spawn. " .. #self.PlayersWaitingToSpawnIn .. " remaining in list.")
			break
		end
	end

	local FreezeTime = gamemode.GetRoundStageTime()

	-- doh, at this point we haven't yet assigned fox/flag carrier
	-- all we can do is totally freeze everyone till spawned in (end of PreRoundWait time)
	
	-- then we will allow movement but disable weapons (if DTAS) or freeze everyone but the fox (if Fox Hunt)

	player.FreezePlayer(PlayerState, FreezeTime)
	
end


function DTAS:DisableSpawnProtection()
	-- TODO: not applicable but maybe we could create spawn protection volumes?
--	if gamemode.GetRoundStage() == "InProgress" then
--		for i, SpawnProtectionVolume in ipairs(self.SpawnProtectionVolumes) do
--			actor.SetActive(SpawnProtectionVolume, false)
--		end
--	end
end


function DTAS:AbandonRound(Reason)
	self:ShowAttackersDefendersMessage(Reason, Reason, self.ScreenPositionError, 5.0)	
	AbandonedRound = true
	gamemode.SetRoundStage("RoundAbandoned")
end


function DTAS:PrunePlayerFromList(Player, List)
	-- basically a copy (with reversed arguments) of self:RemoveValueFromTable(TableToEdit, ValueToRemove)
	-- oh well

	for i = #List, 1, -1 do
	-- need to go backwards because list will shrink when we delete something
		if List[i] == Player then
			table.remove(List, i)
		end
	end
end




function DTAS:LogOut(Exiting)
	-- TODO should DTASSetup and FoxHuntSetup be in this list?
	-- TODO check if player is the fox or flag carrier - reassign in both cases if in setup time
	
	if gamemode.GetRoundStage() == "PreRoundWait" 
	or gamemode.GetRoundStage() == "DTASInProgress" 
	or gamemode.GetRoundStage() == "FoxHuntInProgress" then
		timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
	end
	
	local PlayerExiting = player.GetPlayerState(Exiting)
	
	-- remove player from any lists
	--print ("LogOut: a player has left the server. Checking/pruning player from lists...")
	
	-- clear fox player
	if self.FoxPlayer ~= nil and PlayerExiting ~= nil then
		if self.FoxPlayer == PlayerExiting then

			if gamemode.GetRoundStage() == "FoxHuntSetup" or gamemode.GetRoundStage() == "FoxHuntInProgress" then
				-- reselect the fox, pronto
			
				local count = 0
				while self.FoxPlayer == PlayerExiting and count<4 do
					count = count + 1
					print("attempt " .. count .. " to select new flag carrier after player left")
					self:SelectFoxPlayer()
				end
				
				if self.FoxPlayer == nil or self.FoxPlayer == PlayerExiting then
					self:AbandonRound("FoxLeftGame")
				end
			else
				print("resetting fox after player left - not in fox hunt setup or in progress round though")

				self.FoxPlayer = nil
			end
				
		end
	end

	-- clear flag carrier
	if self.FlagCarrier ~= nil and PlayerExiting ~= nil then
		if  self.FlagCarrier == PlayerExiting
		and self.FlagPlacement == nil then
			-- new behaviour:
			-- abandon round if flag carrier has left game before flag is placed
			-- otherwise carry on
			
			self:AbandonRound("FlagCarrierLeftGame")
		end
	end


	self:PrunePlayerFromList(PlayerExiting, self.PastFoxes)

	self:PrunePlayerFromList(PlayerExiting, self.PastFlagCarriers)
	
	self:PrunePlayerFromList(PlayerExiting, self.PastTeamMovements) 
	
	--for i = #self.NonClickersIn, 1, -1 do
	-- need to go backwards because list will shrink when we delete something
	--	if self.NonClickersIn[i].Player == Player then
	--		table.remove(self.NonClickersIn, i)
	--	end
	--end
end



	-- DTAS credits:

	-- I stand on the shoulders of giants: many thanks to Cleeus, Crowze, Yurch, Harper, Khutan, and all the 
	-- original testers and players for their work on the original DTAS game mode for Infiltration. Thanks to Beppo,
	-- of course, for being the driving force on Infiltration itself. You all did an awesome job, and your game mode 
	-- was super fun to play. Thank you also to the next generation of devs and playtesters...
	
	-- Thanks to kris, John, Scopey, mikson, Will, Mike, Alex et al on the official Ground Branch team for their
	-- help in various forms and for making a great game. I am sure I have annoyed kris more than anyone else -
	-- thanks kris...
	
	-- Huge thanks to Ram, V2, Easy, AV, Spooky, John, mikson, BTH and others for the intensive initial playtesting 
	-- and other support. Thanks to the larger community of testers for doing their best to break DTAS. 
	-- At the time of writing (13 July 2021), thanks to the following people in the wider testing group for helping out
	-- (you may not have played, but you turned up, and that's half the battle won):
	
	-- Unit, Spectre and Tactical Gaming Elite (TGE) clans in general, and in particular: 
	-- Aspect, BlackFly, Ceb, Christmas, Cinzo, clark, Eagle Eye, eelSkillz, Fusion, GreyFox, Jason, Kilo_Forte,
	-- Kuzco, lt_delay, MagesticBuck, mr zerkhan, mrbombastic, MrTrickie, Prowlaz, r1FT, Raven212, RENKZ, Sandman,
	-- Skarin96, Trav, Vip3r, Winston

	-- Sorry for anyone I missed off, and special thanks to the clan leaders for being so well organised and giving
	-- so much of their time to the cause.

	-- Special mention to *Zeep*, for working so hard to support the project and for sharing the DTAS faith when 
	-- all we had to show for it was salty seadog tales of this weird old game mode. DTAS buddies till the end :)
	-- That said, V2 and Ram probably also deserve another mention for embracing the new faith with such energy.
	
	-- Shout out to DavidB, Zee, SarcasticSweetie, r1FT, heromanofe, and others for their work in championing 
	-- and/or cracking on with GB modding. This list will surely grow significantly.
	
	-- Thanks to all the 'content creators' for giving publicity to Ground Branch and/or my stuff in particular
	-- (I expect you will like this one). Thanks in particular to Prowlaz, Justinred87, Jeza, karmakut and many
	-- others for being so supportive (especially anyone I forgot - sorry).
		
	-- Final note: everything in this game mode has been recoded from scratch and I have not strictly followed the
	-- original DTAS rules and setup. Some stuff has been adapted - of necessity - to the Ground Branch setup.
	-- However, I have tried to respect the spirit of the original game mode, and I salute those who made it,
	-- and those who are still playing it to this day.
	
	-- Postscript: funny how life changes, and I found myself finishing the integration of DTAS into Ground Branch
	-- as an official contractor. I don't think I want to hear about an After Action Report ever again in my life...
	
	-- Best of luck to the next person who takes this on, or makes their own version of DTAS, based on this weird
	-- old game mode in Ground Branch...

return DTAS
