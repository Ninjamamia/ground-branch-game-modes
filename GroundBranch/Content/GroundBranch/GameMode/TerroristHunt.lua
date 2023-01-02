local terroristhunt = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = { "TerroristHunt" },
	
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
			Max = 120,
			Value = 45,
			AdvancedSetting = false,
		},
		-- max round time increased to 120 from 60 by MF 2022/10/18
		ShowRemaining = {
			Min = 0,
			Max = 50,
			Value = 10,
			AdvancedSetting = true,
		},
		UseAIHotspots = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
		--BumRushMode = {
		--	Min = 0,
		--	Max = 1,
		--	Value = 1,
		--	AdvancedSetting = true,
		--},
		-- 0 = no bum rush mode
		-- 1 = activate bum rush at approx 1-5 AI left
	},
	
	OpForTeamTag = "OpFor",
	PriorityTags = { "AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5",
		"AISpawn_6_10", "AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40", "AISpawn_41_50" },

	SpawnPriorityGroupIDs = { "AISpawn_11_20", "AISpawn_31_40" },
	-- these define the start of priority groups, e.g. group 1 = everything up to AISPawn_11_20 (i.e. from AISpawn_1 to AISpawn_6_10), group 2 = AISpawn_11_20 onwards, group 3 = AISpawn_31_40 onwards
	-- everything in the first group is spawned as before. Everything is spawned with 100% certainty until the T count is reached
	-- subsequent priority groups are capped, ensuring that some lower priority AI is spawned, and everything else is randomised as much as possible
	-- so overall the must-spawn AI will spawn (priority group 1) and a random mix of more important and (a few) less important AI will spawn fairly randomly

	SpawnPriorityGroups = {},
	-- this stores the actual groups as separate tables of spawns indexed by priority group
	
	LastSpawnPriorityGroup = 0,
	-- the last priority group in which spawns were found
	
	ProportionOfPriorityGroupToSpawn = 0.7,
	-- after processing all group 1 spawns, a total of N spawns remain. Spawn 70% of those as group 2 , then 70% of the remaining number as group 3, ... (or 100% if no more groups exist) 
	
	AllAIHotspots = {},
	-- list of AI hotspot volume actors found in the map
	AIHotspotSpawnpoints = {},
	-- index = hotspot name, value = table of contains AI spawnpoints (with hotspot tag and without)
	AIHotspotPercentageOfTotalSpawns = 0.45,
	-- how many of the total spawns to allocate to the hotspot?
	CurrentAIHotspot = nil,
	
	AllNavBlocks = {},
	-- nav blockers, which we need to turn off when activating bum rush
	
	HotspotMarkerMap = {},
	-- key is hotspot name, value is hotspot objective marker
	
	TotalNumberOfSpawnsFound = 0,
	-- simple total of spawns placed in all priority groups
		
	AlwaysUseEveryPriorityOneSpawn = false,
	-- if true, priority one spawns will be used up entirely before considering lower priorities
	-- if false, behaviour differs depending on T count and number of P1 spawns. At least N% of spawns will be not P1 spawns, preventing all P1 spawns being used if need be
	MinimumProportionOfNonPriorityOneSpawns = 0.15,
	-- in which case, always use this proportion of non P1 spawns (15% by default), rounded down
		
	PriorityGroupedSpawns = {},
	-- used for old AI spawn method
	
	BumRushModeActive = false,
	-- if true, AI will be heading towards last known location of a random player

	BumRushTargetUpdateTime = 8.0,
	-- seconds between target updates for last few AI in bum rush mode
	
	BumRushTargetAICount = 0,
	-- this is set at the start of each round when the number of active AI is known
	
	BumRushRandomWalkLength = 1000.0,
	-- length of random walk to take from player's actual position (in cm), so AI aren't super precise and don't cluster round a single point
	
	PlayerCapsuleHalfHeight = 100,
	PlayerCapsuleRadius = 40,
	-- size for collision checking
}


function terroristhunt:DumbTableCopy(MyTable)
	local ReturnTable = {}
	
	for Key, TableEntry in ipairs(MyTable) do
		table.insert(ReturnTable, TableEntry)
	end
	
	return ReturnTable
end


function terroristhunt:PreInit()
	local AllSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	local PriorityIndex = 1
	local TotalSpawns = 0

	local CurrentPriorityGroup = 1
	local CurrentGroupTotal = 0
	local CurrentPriorityGroupSpawns = {}
	-- this needs to be outside the loop
	
	self.SpawnPriorityGroups = {}
	
	-- Orders spawns by priority while allowing spawns of the same priority to be randomised.
	for i, PriorityTag in ipairs(self.PriorityTags) do
		local bFoundTag = false

		if CurrentPriorityGroup <= #self.SpawnPriorityGroupIDs then
			if PriorityTag == self.SpawnPriorityGroupIDs[CurrentPriorityGroup] then
				-- we found the priority tag corresponding to the start of the next priority group
				self.SpawnPriorityGroups[CurrentPriorityGroup] = self:DumbTableCopy(CurrentPriorityGroupSpawns)
				print("PreInit(): " .. CurrentGroupTotal .. " total spawns found for priority group " .. CurrentPriorityGroup )
				CurrentPriorityGroup = CurrentPriorityGroup + 1
				CurrentGroupTotal = 0
				CurrentPriorityGroupSpawns = {}
			end
		end

		for j, SpawnPoint in ipairs(AllSpawns) do
			if actor.HasTag(SpawnPoint, PriorityTag) then
				bFoundTag = true
				if self.PriorityGroupedSpawns[PriorityIndex] == nil then
					self.PriorityGroupedSpawns[PriorityIndex] = {}
				end
				-- Ensures we can't spawn more AI then this map can handle.
				TotalSpawns = TotalSpawns + 1 
				table.insert(self.PriorityGroupedSpawns[PriorityIndex], SpawnPoint)
				-- this is the table for the old method, which we may still want to use e.g. at low T counts

				table.insert(CurrentPriorityGroupSpawns, SpawnPoint)
				CurrentGroupTotal = CurrentGroupTotal + 1
				-- also store in the table of spawnpoints for the new method
			end
		end

		-- Ensures we don't create empty tables for unused priorities.
		if bFoundTag then
			PriorityIndex = PriorityIndex + 1
			self.LastSpawnPriorityGroup = CurrentPriorityGroup
		end
	end
	
	self.SpawnPriorityGroups[CurrentPriorityGroup] = CurrentPriorityGroupSpawns
	print("PreInit(): " .. CurrentGroupTotal .. " total spawns found for priority group " .. CurrentPriorityGroup )
	self.TotalNumberOfSpawnsFound = TotalSpawns
	
	TotalSpawns = math.min(ai.GetMaxCount(), TotalSpawns)
	self.Settings.OpForCount.Max = TotalSpawns
	self.Settings.OpForCount.Value = math.min(self.Settings.OpForCount.Value, TotalSpawns)

	self.Settings.ShowRemaining.Max = TotalSpawns
	self.Settings.ShowRemaining.Value = math.min(self.Settings.ShowRemaining.Value, TotalSpawns)

	---------------------------------
	-- set up hotspots (new in 1033):
	
	self.AllAIHotspots = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAIHotspot')
	-- list of AI hotspot volume actors found in the map
	
	self.AIHotspotSpawnpoints = {}
	self.HotspotMarkerMap = {}
	
	for _, Hotspot in ipairs(self.AllAIHotspots) do
		local HotspotName = ai.GetAIHotspotName(Hotspot)
		if HotspotName ~= nil and HotspotName ~= "" then
			local SpawnpointList = {}
			--print("Processing hotspot " .. HotspotName)

			for __, AISpawnPoint in ipairs(AllSpawns) do
				if ai.IsSpawnPointInHotspot(AISpawnPoint, Hotspot) then
					table.insert(SpawnpointList, AISpawnPoint)
					--print("Added spawnpoint " .. actor.GetName(AISpawnPoint))
				end
			end

			self.AIHotspotSpawnpoints[HotspotName] = SpawnpointList
			-- store spawnpoint list for hotspot
			
			local NewObjectiveMarker = gamemode.AddObjectiveMarker(actor.GetLocation(Hotspot), self.PlayerTeams.BluFor.TeamId, HotspotName, "Hotspot", false)
			
			self.HotspotMarkerMap[HotspotName] = NewObjectiveMarker
			-- create location marker for hotspot (for ops board map). Last parameter is whether set active or not. Location is centre of hotspot, but not really used.
			
			if NewObjectiveMarker == nil then
				print("Failed to create objective marker")
			end
		else
			print("Error: hotspot name was nil/empty")
		end
	end
	
	
	--- find all nav blockers
	self.AllNavBlocks = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/GameMode/BP_MissionNavBlock.BP_MissionNavBlock_C')
	
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
	if RoundStage == "WaitingForReady" then
		ai.CleanUp(self.OpForTeamTag)
		self.BumRushModeActive = false
		timer.Clear('UpdateBumRushTargets')
		self:PickHotspot()
		
		for _, NavBlock in ipairs(self.AllNavBlocks) do
			actor.SetActive(NavBlock, true)
		end
		-- reset nav blocks
		
	elseif RoundStage == "PreRoundWait" then
		self:SpawnOpFor()
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
		-- need to update this as ops board setting may have changed - have to do this before RoundStage InProgress to be effective
	end
end


function terroristhunt:PickHotspot()
	-- pick a hotspot, if present - new in 1033:
	
	gamemode.ClearSearchLocations()
	
	if #self.AllAIHotspots > 0 and self.Settings.UseAIHotspots.Value == 1 then
		-- first, pick an active hotspot and set active states accordingly:
		self.CurrentAIHotspot = self.AllAIHotspots[math.random(#self.AllAIHotspots)]
		
		local CurrentHotspotName = ai.GetAIHotspotName( self.CurrentAIHotspot )
		local CurrentHotspotSpawns = self.AIHotspotSpawnpoints[CurrentHotspotName]
		print ("Picked hotspot " .. CurrentHotspotName .. " with " .. #CurrentHotspotSpawns .. " spawns.")
		
		gamemode.AddSearchLocation(self.PlayerTeams.BluFor.TeamId, CurrentHotspotName, 2)
		-- add secondary search location
		-- TODO: change name of 'search location' to 'hot spot' or similar
	else
		self.CurrentAIHotspot = nil
	end
	
	-- need to deactivate all objective markers and hotspots, whether or not AI hotspots are enabled as an option:
	
	if #self.AllAIHotspots > 0 then		
		for _, Hotspot in ipairs(self.AllAIHotspots) do
			local TempHotspotName = ai.GetAIHotspotName(Hotspot)
			local TempObjectiveMarker = self.HotspotMarkerMap[TempHotspotName]
			
			if self.CurrentAIHotspot ~= nil and Hotspot == self.CurrentAIHotspot then
				actor.SetActive(Hotspot, true)
				actor.SetActive(TempObjectiveMarker, true)
			else
				actor.SetActive(Hotspot, false)
				actor.SetActive(TempObjectiveMarker, false)
			end
		end
	end
end


function terroristhunt:SpawnOpFor()
	-- reorganised 8/9 September 2021 by MF to improve randomisation and use of all spawns while still respecting priorities
	-- (it gets quite complicated)

	local OrderedSpawns = {}
	local RejectedSpawns = {}
	local Group 
	local AILeftToSpawn

	local AllocatedSpawnMap = {}
	-- we can't use the spawn point objects as keys unfortunately, but the names of the spawnpoints will be unique, so we'll use those


	-- allocate AI to hotspots, new in 1033:
		
	if self.CurrentAIHotspot ~= nil then
	
		local CurrentHotspotName = ai.GetAIHotspotName( self.CurrentAIHotspot )
		local CurrentHotspotSpawns = self.AIHotspotSpawnpoints[CurrentHotspotName]
		
		if #CurrentHotspotSpawns > 0 then
			-- determine what % of the total to allocate to the hotspot
			local HotspotNumberAvailableToSpawn = math.floor(math.max( 1, self.Settings.OpForCount.Value * self.AIHotspotPercentageOfTotalSpawns ))
			local HotspotNumberToSpawn = math.min( HotspotNumberAvailableToSpawn, #CurrentHotspotSpawns )

			print("Allocating " .. HotspotNumberToSpawn .. " spawns out of total " .. self.Settings.OpForCount.Value .. " available to hotspot " .. CurrentHotspotName)
			
			if HotspotNumberToSpawn > 0 then
				for i = #CurrentHotspotSpawns, #CurrentHotspotSpawns - (HotspotNumberToSpawn-1), -1 do
					local j = umath.random(i)
					CurrentHotspotSpawns[i], CurrentHotspotSpawns[j] = CurrentHotspotSpawns[j], CurrentHotspotSpawns[i]
					-- shuffle
					
					local SpawnName = actor.GetName(CurrentHotspotSpawns[i])
					table.insert(OrderedSpawns, CurrentHotspotSpawns[i])
					AllocatedSpawnMap[ SpawnName ] = true
				end
			end
		end
	end


	for CurrentPriorityGroup = 1, self.LastSpawnPriorityGroup do
						
		AILeftToSpawn =  math.max( 0, self.Settings.OpForCount.Value - #OrderedSpawns )
		-- this will be zero if the T count is already reached
		
		local CurrentAISpawnTarget 
		-- number of spawns to try and add from this priority group
		
		-- determine how many spawns we're aiming for:
		if AILeftToSpawn > 0 then
			if CurrentPriorityGroup == 1 then
				if self.AlwaysUseEveryPriorityOneSpawn then
					CurrentAISpawnTarget = AILeftToSpawn
				else
					CurrentAISpawnTarget = math.ceil( AILeftToSpawn * (1 - self.MinimumProportionOfNonPriorityOneSpawns) )
					-- leave a few slots spare for lower priorities (default 15%)
					-- if the number of priority 1 spawns is lower than this number, then all priority 1 spawns will be used
					-- (this only has an effect if there are lots of P1 spawns and not a big T count)
				end
				
			elseif CurrentPriorityGroup == self.LastSpawnPriorityGroup then
				CurrentAISpawnTarget = AILeftToSpawn
				-- if this is the first group, or the last group, then try spawn all of the AI
				
			else
				local CurrentNumberOfSpawns = #self.SpawnPriorityGroups[CurrentPriorityGroup]
				local RemainingSpawnsInLowerPriorities = math.max( 0, self.TotalNumberOfSpawnsFound - CurrentNumberOfSpawns - #OrderedSpawns)
				local CurrentProportionOfSpawnsLeft =  CurrentNumberOfSpawns / ( CurrentNumberOfSpawns + (RemainingSpawnsInLowerPriorities * self.ProportionOfPriorityGroupToSpawn) ) 
				-- spawn a suitable number of spawns in dependence on the number of spawns in this group vs number of spawns remaining in lower groups, but fudge it to be bigger than the actual proportion
				
				CurrentAISpawnTarget = math.ceil(AILeftToSpawn * CurrentProportionOfSpawnsLeft)
				
				-- starting with 70%, so if 10 AI are left to spawn, we will attempt to spawn 7 of them from this group
			end
		else
			CurrentAISpawnTarget = 0
			-- no AI left to spawn so don't bother spawning any - just dump straight into RejectedSpawns{}
		end

		print("SpawnOpFor(): Picking max " .. CurrentAISpawnTarget .. " AI from priority group " .. CurrentPriorityGroup .. " with " .. AILeftToSpawn .. " AI left to spawn out of " .. self.Settings.OpForCount.Value .. " total.")

		-- now transfer the appropriate number of spawns (randomly picked) to the target list (OrderedSpawns)
		-- and dump the remainder in the RejectedSpawns table (to be added to the end of the target list once completed)
		
		Group = self.SpawnPriorityGroups[CurrentPriorityGroup]

		if Group == nil then
			print("SpawnOpFor(): Table entry for priority group " .. CurrentPriorityGroup.. " was unexpectedly nil")
		else
			print("SpawnOpFor(): actually found " .. #Group .. " AI in group " .. CurrentPriorityGroup)
		
			if #Group > 0 then
				for i = #Group, 1, -1 do
					local j = umath.random(i)
					Group[i], Group[j] = Group[j], Group[i]

					local SpawnName = actor.GetName(Group[i])
					if CurrentAISpawnTarget > 0 and AllocatedSpawnMap[SpawnName] == nil then
						table.insert(OrderedSpawns, Group[i])
						AllocatedSpawnMap[SpawnName] = true
						CurrentAISpawnTarget = CurrentAISpawnTarget - 1
					else
						table.insert(RejectedSpawns, Group[i])
					end
				end
				-- ^ shuffle this group to randomise
					
			else
				print("SpawnOpFor(): Priority group " .. CurrentPriorityGroup.. " was unexpectedly empty")
			end
			
		end
		
	end
	
	-- now add all the rejected spawns onto the list, in case extra spawns are needed
	-- if we ran out of spawns in the above process, this will still provide a sensible selection of spawns
	
	for i = 1, #RejectedSpawns do
		table.insert(OrderedSpawns, RejectedSpawns[i])
	end

	ai.CreateOverDuration(4.0, self.Settings.OpForCount.Value, OrderedSpawns, self.OpForTeamTag)
	
	-- now set bum rush count, new in 1033:
	
	local BumRushCountMax = math.floor(math.max( 3, (self.Settings.OpForCount.Value / 8) ))
	-- math.floor() to force to integer
			
	self.BumRushTargetAICount = math.random( 2, BumRushCountMax )
	print("BumRushTargetAICount = " .. self.BumRushTargetAICount .. " (max=" .. BumRushCountMax .. ")")
	-- set threshold for activating AI bum rush
end


function terroristhunt:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.OpForTeamTag) then
				timer.Set("CheckOpForCount", self, self.CheckOpForCountTimer, 1.0, false)
			else
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


function terroristhunt:CheckOpForCountTimer()
	local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, 255, 255)

	if #OpForControllers == 0 then
		timer.Clear("ShowRemaining")
		gamemode.AddGameStat("Result=Team1")
		gamemode.AddGameStat("Summary=OpForEliminated")
		gamemode.AddGameStat("CompleteObjectives=EliminateOpFor")
		gamemode.SetRoundStage("PostRoundWait")
		return
	elseif self.Settings.ShowRemaining.Value > 0 and #OpForControllers <= self.Settings.ShowRemaining.Value then
		-- we now delegate formatting to the UE4 FText format command, also allowing us to localise it via the .csv file
		-- we do this using a table, because lua
		
		local FormatTable = {}
		FormatTable.FormatString = "RemainingOpfor"
		-- "FormatString" is a reserved and mandatory field name
		-- "RemainingOpfor" is expanded into a proper formatting string (in .csv file): "format_RemainingOpfor","{NumberRemaining} {NumberRemaining}|plural(one=enemy,other=enemies) remaining",formatted string
		FormatTable.NumberRemaining = #OpForControllers
		-- important not to convert #OpForControllers to string so that it can be used by the plural() formatting function
		self.RemainingMessage = gamemode.FormatString(FormatTable)
		
		timer.Set("ShowRemaining", self, self.ShowRemainingTimer, 10, false)
	end
	
	--if self.Settings.BumRushMode.Value == 1 and #OpForControllers <= self.BumRushTargetAICount then
	-- hide bum rush setting -> add to the mystique of the AI
	
	if #OpForControllers <= self.BumRushTargetAICount then
		self:ActivateBumRush()
	end
end


function terroristhunt:ActivateBumRush()
	if not self.BumRushModeActive then
		self.BumRushModeActive = true
		print("Activated bum rush mode")
		
		for _, NavBlock in ipairs(self.AllNavBlocks) do
			if not actor.HasTag(NavBlock, "DoNotDisable") then
				actor.SetActive(NavBlock, false)
			end
		end
		-- turn off all nav blocks on the map, to free all the AI, will take a short while to propagate - might need to delay first bumrush call?
		
		timer.Set("UpdateBumRushTargets", self, self.UpdateBumRushTargetsTimer, self.BumRushTargetUpdateTime, true)
		self:UpdateBumRushTargetsTimer()
		-- set timer and call function immediately to set targets for bum rushing AI
	end
end


function terroristhunt:UpdateBumRushTargetsTimer()
	local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, 255, 255)
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, false)
		
	for _, AIController in ipairs(OpForControllers) do
		local RandomPlayer = PlayersWithLives[math.random(#PlayersWithLives)]
		local PlayerCharacter = player.GetCharacter(RandomPlayer)
		local PlayerLocation = actor.GetLocation(PlayerCharacter)
		
		if PlayerCharacter ~= nil then
			ai.SetSquadOrdersForAIController(AIController, 'Search')
			-- override any current squad orders (e.g. guard, patrol, idle)
			-- we don't have to worry about other AI in the squad, because if they're alive, they'll be set a search location also
			-- currently AI can only be set orders at the whole squad level (in lua)

			local SearchTargetLocation = ai.GetRandomReachablePointInRadius(PlayerLocation, self.BumRushRandomWalkLength)
			-- get a random point near the player, so the AI don't converge on a single point precisely

			if SearchTargetLocation == nil then
				print("SearchTargetLocation was not valid - using player position")
				SearchTargetLocation = PlayerLocation
			end
			
			--print("TerroristHunt: bumrush setting search target to " .. SearchTargetLocation.x .. ", " ..  SearchTargetLocation.y .. ", " ..  SearchTargetLocation.z  )
			ai.SetSearchTarget(AIController, SearchTargetLocation, self.BumRushTargetUpdateTime)
			-- make AI go to that player's last known location (i.e. current location)
			-- last parameter is search time duration (seconds?)
		else
			print("TerroristHunt: bumrush playercharacter target was nil")
		end
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


function terroristhunt:OnMissionSettingsChanged(ChangedSettingsTable)
	-- NB this may be called before some things are initialised
	-- need to avoid infinite loops by setting new mission settings
    if ChangedSettingsTable['UseAIHotspots'] ~= nil then
        print("OnMissionSettingsChanged(): UseAIHotspots value changed.")
		self:PickHotspot()
		-- force update
	end
end


function terroristhunt:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
	end
end


return terroristhunt