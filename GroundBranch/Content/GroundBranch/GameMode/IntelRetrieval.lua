local intelretrieval = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = { "IntelRetrieval" },
	
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
			Min = 5,
			Max = 120,
			Value = 45,
			AdvancedSetting = false,
		},
		-- max round time increased to 120 from 60 by MF 2022/10/18
		SearchTime = {
			Min = 1,
			Max = 60,
			Value = 10,
			AdvancedSetting = true,
		},
		-- ^ seconds taken to hack laptop
		TeamExfil = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
		DisplaySearchLocations = {
			Min = 0,
			Max = 5,
			Value = 2,
			AdvancedSetting = true,
		},
				-- 0 = none
		-- 1 = one (true location)
		-- 2 = two
		-- 3 = half
		-- 4 = all but one
		-- 5 = all
		ProximityAlert = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
		-- 1 to make watch display alert if in proximity
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
	
	TotalNumberOfSpawnsFound = 0,
	-- simple total of spawns placed in all priority groups
		
	AlwaysUseEveryPriorityOneSpawn = false,
	-- if true, priority one spawns will be used up entirely before considering lower priorities
	-- if false, behaviour differs depending on T count and number of P1 spawns. At least N% of spawns will be not P1 spawns, preventing all P1 spawns being used if need be
	MinimumProportionOfNonPriorityOneSpawns = 0.15,
	-- in which case, always use this proportion of non P1 spawns (15% by default), rounded down
		
	PriorityGroupedSpawns = {},
	-- used for old AI spawn method
	
	MissionLocationMarkers = {},
	-- for creating rings on ops board showing probably location of laptop
	
	ExtractionPoints = {},
	ExtractionPointMarkers = {},
	ExtractionPointIndex = 0,
	
	Laptops = {},
	
	LaptopTag = "TheIntelIsALie",
	-- this variable is relied on by the IntelTarget.lua script - do not delete
	
	RandomLaptopIndex = nil,
	
	LaptopLocationNameList = {},
	-- the true location name will be first in this list, otherwise randomly shuffled
		
	LaptopObjectiveMarkerName = "",
	-- text displayed on search location marker (currently none)
	
	CurrentSearchObjectives = {},
	-- list of 'defender' insertion points corresponding to currently selected/displayed search locations (typically size 2)
	
	TeamExfilWarning = false,
	
	CompletedARound = true,
	
	LaptopProximityAlertRadius = 5.0,
	-- get a warning within 5 m of a laptop
	
	TestAllLaptops = false,

	AllNavBlocks = {},
	-- nav blockers, which we need to turn off when activating bum rush	
	BumRushModeActive = false,
	-- if true, AI will be heading towards last known location of a random player
	BumRushTargetUpdateTime = 20.0,
	-- seconds between target updates for last few AI in bum rush mode
	BumRushRandomWalkLength = 1200.0,
	-- length of random walk to take from player's actual position (in cm), so AI aren't super precise and don't cluster round a single point
	BumRushInRangeDistanceSq = 3000.0 * 3000.0,
	-- if AI are within this distance (squared) - 30m - then don't add their squad to the bum rush
	BumRushLeaveSquadsAlone = {},
	-- these squads should be ignored as they started out near extraction
}




function intelretrieval:DumbTableCopy(MyTable)
	local ReturnTable = {}
	
	for Key, TableEntry in ipairs(MyTable) do
		table.insert(ReturnTable, TableEntry)
	end
	
	return ReturnTable
end


function intelretrieval:PreInit()
	local AllSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	local PriorityIndex = 1
	local TotalSpawns = 0

	local CurrentPriorityGroup = 1
	local CurrentGroupTotal = 0
	local CurrentPriorityGroupSpawns = {}
	-- this needs to be outside the loop
	
	self.SpawnPriorityGroups = {}

	--gamemode.SetPlayerTeamRole(PlayerTeams.BluFor.TeamId, "Attackers")
	-- only need to set this once

	-- Orders spawns by priority while allowing spawns of the same priority to be randomised.
	for i, PriorityTag in ipairs(self.PriorityTags) do
		local bFoundTag = false
		
		if CurrentPriorityGroup <= #self.SpawnPriorityGroupIDs then
			if PriorityTag == self.SpawnPriorityGroupIDs[CurrentPriorityGroup] then
				-- we found the priority tag corresponding to the start of the next priority group
				self.SpawnPriorityGroups[CurrentPriorityGroup] = self:DumbTableCopy(CurrentPriorityGroupSpawns)
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
	self.TotalNumberOfSpawnsFound = TotalSpawns
	
	TotalSpawns = math.min(ai.GetMaxCount(), TotalSpawns)
	self.Settings.OpForCount.Max = TotalSpawns
	self.Settings.OpForCount.Value = math.min(self.Settings.OpForCount.Value, TotalSpawns)
	
	-- now sort extractions
	
	self.ExtractionPoints = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C')

	for i = 1, #self.ExtractionPoints do
		local Location = actor.GetLocation(self.ExtractionPoints[i])
		local ExtractionMarkerName = self:GetModifierTextForObjective( self.ExtractionPoints[i] ) .. "EXTRACTION"
		-- allow the possibility of down chevrons, up chevrons, level numbers, etc
				
		self.ExtractionPointMarkers[i] = gamemode.AddObjectiveMarker(Location, self.PlayerTeams.BluFor.TeamId, ExtractionMarkerName, "Extraction", false)
		-- NB new penultimate parameter of MarkerType ("Extraction" or "MissionLocation", at present)
	end
	
	-- now sort laptops
	
	self.Laptops = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/Electronics/MilitaryLaptop/BP_Laptop_Usable.BP_Laptop_Usable_C')

	-- set up laptop intel rings for ops board
	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
	
	self.MissionLocationMarkers = {}
	
	for i = 1, #AllInsertionPoints do
		if actor.HasTag( AllInsertionPoints[i], "Defenders" ) then
			local Location = actor.GetLocation(AllInsertionPoints[i])
			local InsertionPointName = gamemode.GetInsertionPointName(AllInsertionPoints[i])
			local MarkerName = self.LaptopObjectiveMarkerName
			
			MarkerName = self:GetModifierTextForObjective( AllInsertionPoints[i] ) .. MarkerName
			-- this checks tags on the specified actor and produces a prefix if appropriate, for interpretation within the WBP_ObjectiveMarker widget
			-- you can give the insertion point tags to add the relevant symbol before "INTEL?"
			
			self.MissionLocationMarkers[InsertionPointName] = gamemode.AddObjectiveMarker(Location, self.PlayerTeams.BluFor.TeamId, MarkerName, "MissionLocation", false)
			-- NB new penultimate parameter of MarkerType ("Extraction" or "MissionLocation", at present)
			
			actor.SetActive(AllInsertionPoints[i], false)
			-- now needed because playerstart status is now disregarded when determining what insertion points to display
		end
	end

	--- find all nav blockers
	self.AllNavBlocks = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/GameMode/BP_MissionNavBlock.BP_MissionNavBlock_C')
	
end


function intelretrieval:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "RetrieveIntel", 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateBluFor", 1)
end


function intelretrieval:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false)
	end
end


function intelretrieval:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	end
	
	if ReadyStatus == "WaitingToReadyUp" 
	and gamemode.GetRoundStage() == "PreRoundWait" 
	and gamemode.PrepLatecomer(PlayerState) then
		gamemode.EnterPlayArea(PlayerState)
	end
end


function intelretrieval:CheckReadyUpTimer()
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


function intelretrieval:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end


function intelretrieval:OnRoundStageSet(RoundStage)
	print("--intelretrieval:OnRoundStageSet() - new round stage " .. RoundStage)

	if RoundStage == "WaitingForReady" then
		timer.ClearAll()
		--timer.Clear('UpdateBumRushTargets')

		self.BumRushModeActive = false
		ai.CleanUp(self.OpForTeamTag)

		self.TeamExfilWarning = false
		
		if self.CompletedARound then
			self:RandomiseObjectives()
		end
		
		self.CompletedARound = false
		
		for _, NavBlock in ipairs(self.AllNavBlocks) do
			actor.SetActive(NavBlock, true)
		end
		-- reset nav blocks
	
	elseif RoundStage == "PreRoundWait" then
		self:SpawnOpFor()				
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
		-- need to update this as ops board setting may have changed - have to do this before RoundStage InProgress to be effective
		
		-- set up watch stuff
		if self.Settings.ProximityAlert.Value == 1 and self.RandomLaptopIndex ~= nil then
			--print("Setting up watch proximity alert data")
			gamemode.SetWatchMode( "IntelRetrieval", false, false, false, false )
			gamemode.ResetWatch()
			gamemode.SetCaptureZone( self.LaptopProximityAlertRadius, 0, 255, true )
			-- cap radius, cap height, team ID, spherical zone? (ignore height)
			local NewLaptopLocation = actor.GetLocation( self.Laptops[self.RandomLaptopIndex] )
			gamemode.SetObjectiveLocation( NewLaptopLocation ) 
			--print("Setting objective location to (" .. NewLaptopLocation.x .. ", " .. NewLaptopLocation.y .. ", " .. NewLaptopLocation.z .. ")")
		end
		-- watch is set up to create a proximity alert when within <LaptopProximityAlertRadius> m of the laptop
		
	--elseif RoundStage == "InProgress" then
	--	self:ActivateBumRush()
	-- 	-- for testing
		
	elseif RoundStage == "PostRoundWait" then
		self.CompletedARound = true
		
	end
end


function intelretrieval:RandomiseObjectives()
	-- called to reset and randomise the mission objectives

	-- first, pick a random extraction point
	
	self.ExtractionPointIndex = umath.random(#self.ExtractionPoints)
	-- this is the current extraction point

	for i = 1, #self.ExtractionPoints do
		local bActive = (i == self.ExtractionPointIndex)
		actor.SetActive(self.ExtractionPointMarkers[i], bActive)
		actor.SetActive(self.ExtractionPoints[i], false)
		-- set extraction marker to active but don't turn on flare yet
	end

	gamemode.ClearGameObjectives()
	gamemode.ClearSearchLocations()
	
	self.CurrentSearchObjectives = {}
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "RetrieveIntel", 1)
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "ExfiltrateBluFor", 1)

	-- second, pick a random laptop

	self.LaptopLocationNameList = {}
	local AllFakeLocationNames = {}
	local LocationName

	self.RandomLaptopIndex = umath.random(#self.Laptops);
	
	print("----picking laptop " .. self.RandomLaptopIndex .. " (" .. actor.GetName(self.Laptops[self.RandomLaptopIndex]) .. ") out of " .. #self.Laptops .. " possible")
	
	--actor.AddTag(self.Laptops[self.RandomLaptopIndex], self.LaptopTag)
	LocationName = self:GetInsertionPointNameForLaptop(self.Laptops[self.RandomLaptopIndex])
	table.insert(self.LaptopLocationNameList, LocationName)
			
	if not self.TestAllLaptops then
			
		for i = 1, #self.Laptops do
			--actor.SetActive(self.Laptops[i], true)
			if (i == self.RandomLaptopIndex) then
				actor.AddTag(self.Laptops[i], self.LaptopTag)
				actor.SetActive(self.Laptops[i], true)
				-- make laptop visible and usable
			else
				actor.SetActive(self.Laptops[i], false)
				-- make laptop disappear
				
				actor.RemoveTag(self.Laptops[i], self.LaptopTag)
				LocationName = self:GetInsertionPointNameForLaptop(self.Laptops[i])
				if LocationName ~= self.LaptopLocationNameList[1] then
					self:AddToTableIfNotAlreadyPresent( AllFakeLocationNames, LocationName )
				end
			end
		end
	
	else

		for i = 1, #self.Laptops do
			actor.AddTag(self.Laptops[i], self.LaptopTag)
			actor.SetActive(self.Laptops[i], true)
				-- make laptop visible and usable
				
			LocationName = self:GetInsertionPointNameForLaptop(self.Laptops[i])
			if LocationName ~= self.LaptopLocationNameList[1] then
				self:AddToTableIfNotAlreadyPresent( AllFakeLocationNames, LocationName )
			end
		end
	
	end
	
	for i = #AllFakeLocationNames, 1, -1 do
		local j = umath.random(i)
		AllFakeLocationNames[i], AllFakeLocationNames[j] = AllFakeLocationNames[j], AllFakeLocationNames[i]
		table.insert(self.LaptopLocationNameList, AllFakeLocationNames[i])
	end
	-- LaptopLocationNames contains random sequence of laptop locations, with the true location at [1]
	
	local NumberOfSearchLocations = self:GetNumberOfSearchLocations()
	
	for i = 1, #self.LaptopLocationNameList do
		local bActive
		if i <= NumberOfSearchLocations then
			bActive = true
		else
			bActive = false
		end
		
		actor.SetActive( self.MissionLocationMarkers[ self.LaptopLocationNameList[i] ], bActive )
	end
	
	if math.min( #self.LaptopLocationNameList, NumberOfSearchLocations ) > 3 then
	-- just too many locations
		local NewObjective = "The marked area"
		table.insert(self.CurrentSearchObjectives, NewObjective)
		gamemode.AddSearchLocation(self.PlayerTeams.BluFor.TeamId, NewObjective, 1)
	else
		local LocationIndices = {}

		-- this is convoluted but we can't shuffle order of LaptopLocationNameList because that screws up AI spawns
		for i = 1, math.min( #self.LaptopLocationNameList, NumberOfSearchLocations ) do
			LocationIndices[i] = i
		end
		
		-- now one last shuffly thing to create objective names
		for i = math.min( #self.LaptopLocationNameList, NumberOfSearchLocations ), 1, -1 do
			local j = umath.random(i)
			LocationIndices[i], LocationIndices[j] = LocationIndices[j], LocationIndices[i]
			
			local NewObjective = self.LaptopLocationNameList[ LocationIndices[i] ]
			table.insert(self.CurrentSearchObjectives, NewObjective)
			gamemode.AddSearchLocation(self.PlayerTeams.BluFor.TeamId, NewObjective, 1)
			-- need to add objectives in random order else attackers get a big clue...
		end
	end
			
	-- new MF 2021/10/11 allow disabling of insertion points that are too close to the currently selected extraction zone
	
	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
		
	for i, InsertionPoint in ipairs(AllInsertionPoints) do
		-- any insertion point matching a tag of the extraction point will be disabled (i.e. is in proximity)
		
		if actor.GetTeamId(InsertionPoint) == self.PlayerTeams.BluFor.TeamId then
			local InsertionPointName = gamemode.GetInsertionPointName(InsertionPoint)
			
			if actor.HasTag( self.ExtractionPoints[self.ExtractionPointIndex], InsertionPointName) then
				bActive = false
			else
				bActive = true
			end

			-- new in 1033 (2022/9/25): allow disabling of attacker insertion points if a current search location insertion point is a tag on the attacker IP
			-- not terribly efficient but it'll do
			for j, ForbiddenInsertionPointName in ipairs(self.CurrentSearchObjectives) do
				if actor.HasTag( InsertionPoint, ForbiddenInsertionPointName) then
					bActive = false
				end
			end

			actor.SetActive(InsertionPoint, bActive)
		end
	end
	
end


function intelretrieval:ReportError(ErrorMessage)
	gamemode.BroadcastGameMessage("Error! " .. ErrorMessage, "Upper", 5.0)
	print("-- IntelRetrieval game mode error!: " .. ErrorMessage)
end


function intelretrieval:GetInsertionPointNameForLaptop(Laptop)
	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
	local InsertionPointName

	for i, InsertionPoint in ipairs(AllInsertionPoints) do
		if actor.HasTag(InsertionPoint, "Defenders") then
			InsertionPointName = gamemode.GetInsertionPointName(InsertionPoint)
			if actor.HasTag(Laptop, InsertionPointName) then
				return InsertionPointName
			end
		end
	end
	
	self:ReportError("Selected laptop did not have a tag corresponding to a defender insertion point, so no intel can be provided.")
	return nil
end


function intelretrieval:AddToTableIfNotAlreadyPresent( AllLocationNames, NewLocationName )
	if NewLocationName ~= nil then
		for _, LocationName in ipairs(AllLocationNames) do
			if LocationName == NewLocationName then
				return
			end
		end

		table.insert( AllLocationNames, NewLocationName )
	end
end


function intelretrieval:IsItemInTable( TableToCheck, ItemToCheck )
	-- not actually used right now
	for _, TableItem in ipairs(TableToCheck) do
		if TableItem == ItemToCheck then
			return true
		end
	end
	return false
end


function intelretrieval:SpawnOpFor()
	local OrderedSpawns = {}

	local RejectedSpawns = {}
	local Group 
	local AILeftToSpawn

	local ProcessAITagsOnFirstPass = {}
	-- tags to spawn on the first pass, which wouldn't normally spawn

	local IgnoreAITagsOnSecondPass = {}
	-- tags to ignore on the second pass (which will include all of ProcessAITagsOnFirstPass)
	
	-- first add laptop location names to the selected/excluded tags list (ProcessAITagsOnFirstPass, IgnoreAITagsOnSecondPass)
	if  #self.LaptopLocationNameList > 0 then
		--print("IntelRetrieval: Including AI with tag " .. self.LaptopLocationNameList[1])
		table.insert(ProcessAITagsOnFirstPass, self.LaptopLocationNameList[1])	
		table.insert(IgnoreAITagsOnSecondPass, self.LaptopLocationNameList[1])
		-- spawn AI if their tag matches the current/active laptop group
		-- have to add tag to ignore list as well (for phase 2)
		
		for i = 2, #self.LaptopLocationNameList do
			table.insert(IgnoreAITagsOnSecondPass, self.LaptopLocationNameList[i])
			--print("IntelRetrieval: Excluding AI with tag " .. self.LaptopLocationNameList[i])
		end
		-- add all other laptop location names to the ignore list
	end

	-- second add extraction zone location names to the selected/excluded tags list (ProcessAITagsOnFirstPass, IgnoreAITagsOnSecondPass)
	for i = 1, #self.ExtractionPoints do
		local ExtractionPointTags = actor.GetTags( self.ExtractionPoints[i] )
		for _, Tag in ipairs(ExtractionPointTags) do
			if string.lower( string.sub(Tag, 1, 7) ) == "extract" then
			
				if i == self.ExtractionPointIndex then
					-- selected extraction point
			
					--print("IntelRetrieval: Including AI with tag " .. Tag)
					table.insert(ProcessAITagsOnFirstPass, Tag)
					table.insert(IgnoreAITagsOnSecondPass, Tag)
				else
					--print("IntelRetrieval: Excluding AI with tag " .. Tag)
					table.insert(IgnoreAITagsOnSecondPass, Tag)
					-- disregard modifier tags such as AddUpArrow, Add3, etc
				end
			end
		end
		-- spawn AI if their tag matches the current/active laptop group
	end

	-- we're now setup to add optional/conditional AI for the selected laptop and extraction zone only
	-- the optional AI is added on Pass 1 (to ensure all spawns). Normal spawning proceeds in Pass 2.

	for SpawnOpForPass = 1, 2 do
	-- pass 1: add AI with tag equal to current laptop tag
	-- pass 2: add everything else

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
				end
			else
				CurrentAISpawnTarget = 0
				-- no AI left to spawn so don't bother spawning any - just dump straight into RejectedSpawns{}
			end

			-- now transfer the appropriate number of spawns (randomly picked) to the target list (OrderedSpawns)
			-- and dump the remainder in the RejectedSpawns table (to be added to the end of the target list once completed)
			
			Group = self.SpawnPriorityGroups[CurrentPriorityGroup]

			if Group == nil then
				print("SpawnOpFor(): Table entry for priority group " .. CurrentPriorityGroup.. " was unexpectedly nil")
			else

				if #Group > 0 then
					for i = #Group, 1, -1 do

						if SpawnOpForPass == 1 then
							-- only shuffle once, on pass 1
							-- this pass is to add conditional spawns for current laptop and extraction
							
							local j = umath.random(i)
							Group[i], Group[j] = Group[j], Group[i]
						
							if self:ActorHasTagInList( Group[i], ProcessAITagsOnFirstPass ) then
							-- add the spawns if they have the tag matching the current laptop or extraction point
							
								if CurrentAISpawnTarget > 0 then
									table.insert(OrderedSpawns, Group[i])
									CurrentAISpawnTarget = CurrentAISpawnTarget - 1
								else
									table.insert(RejectedSpawns, Group[i])
								end
							
							end
						
						else
						-- opfor pass 2, for anything without an insertion point tag

							if not self:ActorHasTagInList( Group[i], IgnoreAITagsOnSecondPass ) then
							-- this pass for anything which wasn't associated with current laptop or extraction, and also excluding any other conditional spawns

								if CurrentAISpawnTarget > 0 then
									table.insert(OrderedSpawns, Group[i])
									CurrentAISpawnTarget = CurrentAISpawnTarget - 1
								else
									table.insert(RejectedSpawns, Group[i])
								end
			
							end
						end
						
					end
						
				else
					print("SpawnOpFor(): Priority group " .. CurrentPriorityGroup.. " was unexpectedly empty")
				end
				
			end
					
		end
					
	end
	
	-- now add all the rejected spawns onto the list, in case extra spawns are needed
	-- if we ran out of spawns in the above process, this will still provide a sensible selection of spawns
		
	for i = 1, #RejectedSpawns do
		table.insert(OrderedSpawns, RejectedSpawns[i])
	end

	ai.CreateOverDuration(4.0, math.min( self.Settings.OpForCount.Value, #OrderedSpawns), OrderedSpawns, self.OpForTeamTag)
	-- OrderedSpawns may be smaller than expected because of the conditional spawning, so just use the size of that list directly. It won't be bigger than self.Settings.OpForCount.Value.
end


function intelretrieval:ActorHasTagInList( CurrentActor, TagList ) 
	if CurrentActor == nil then
		print("intelretrieval:ActorHasTagInList(): CurrentActor unexpectedly nil")
		return false
	end
	if TagList == nil then
		print("intelretrieval:ActorHasTagInList(): TagList unexpectedly nil")
		return false
	end

	local ActorTags = actor.GetTags ( CurrentActor )
	for _, Tag in ipairs ( ActorTags ) do
		if self:ValueIsInTable( TagList, Tag ) then
			return true
		end
	end
	return false
end							


function intelretrieval:ValueIsInTable(Table, Value)
	if Table == nil then
		print("intelretrieval:ValueIsInTable(): Table unexpectedly nil")
		return false
	end
	
	for _, val in ipairs(Table) do
		if Value == nil then
			if val == nil then
				return true
			end
		else
			if val == Value then
				return true
			end
		end
	end
	return false
end


function intelretrieval:OnCharacterDied(Character, CharacterController, KillerController)
	--print("IntelRetrieval:OnCharacterDied()")
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if not actor.HasTag(CharacterController, self.OpForTeamTag) then
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


function intelretrieval:CheckBluForCountTimer()
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, false)
	if #PlayersWithLives == 0 then
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BluForEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end


function intelretrieval:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end


function intelretrieval:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end


function intelretrieval:OnGameTriggerBeginOverlap(GameTrigger, Character)
	if player.HasItemWithTag(Character, self.LaptopTag) == true then
		if self.Settings.TeamExfil.Value == 1 then
			timer.Set("CheckOpForExfil", self, self.CheckOpForExfilTimer, 1.0, true)
		else
			gamemode.AddGameStat("Result=Team1")
			gamemode.AddGameStat("Summary=IntelRetrieved")
			gamemode.AddGameStat("CompleteObjectives=RetrieveIntel,ExfiltrateBluFor")
			gamemode.SetRoundStage("PostRoundWait")
		end
	end
end


function intelretrieval:CheckOpForExfilTimer()
	local Overlaps = actor.GetOverlaps(self.ExtractionPoints[self.ExtractionPointIndex], 'GroundBranch.GBCharacter')
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, false)
	
	local bExfiltrated = false
	local bLivingOverlap = false
	local bLaptopSecure = false
	local PlayerWithLapTop = nil

	for i = 1, #PlayersWithLives do
		bExfiltrated = false

		local PlayerCharacter = player.GetCharacter(PlayersWithLives[i])
	
		-- May have lives, but no character, alive or otherwise.
		if PlayerCharacter ~= nil then
			for j = 1, #Overlaps do
				if Overlaps[j] == PlayerCharacter then
					bLivingOverlap = true
					bExfiltrated = true
					if player.HasItemWithTag(PlayerCharacter, self.LaptopTag) then
						bLaptopSecure = true
						PlayerWithLapTop = PlayersWithLives[i]
					end
					break
				end
			end
		end

		if bExfiltrated == false then
			break
		end
	end
	
	if bLaptopSecure then
		if bExfiltrated then
		 	timer.Clear(self, "CheckOpForExfil")
		 	gamemode.AddGameStat("Result=Team1")
		 	gamemode.AddGameStat("Summary=IntelRetrieved")
			gamemode.AddGameStat("CompleteObjectives=RetrieveIntel,ExfiltrateBluFor")
		 	gamemode.SetRoundStage("PostRoundWait")
		elseif PlayerWithLapTop ~= nil and self.TeamExfilWarning == false then
			player.ShowGameMessage(PlayerWithLapTop, "TeamExfil", "Engine", 5.0)
			self.TeamExfilWarning = true
		end
	end
end


function intelretrieval:OnTargetCaptured()
	-- this is called from the laptop IntelTarget.lua script when a laptop is successfully hacked

	actor.SetActive(self.ExtractionPoints[self.ExtractionPointIndex], true)
	-- turn on the extraction flare

	self:ActivateBumRush()
	-- pray to whatever God you believe in, because stuff is about to hit the fan
end

function intelretrieval:OnLaptopPickedUp()
	-- laptop has been picked up, so disable proximity alert 
	--print("OnLaptopPickedUp() called")
	
	if self.Settings.ProximityAlert.Value == 1  then
		gamemode.SetObjectiveLocation( nil ) 
	end
end


function intelretrieval:OnLaptopPlaced(NewLaptop)
	-- called when the laptop is dropped or replaced (e.g. carrier is killed)
	-- want to start the proximity alert again at its location
	
	-- (this is redundant the first time the laptop is captured)
	
	--print("OnLaptopPlaced() called")

	return
	-- this isn't working so let's just turn it off for now
	
	--if self.Settings.ProximityAlert.Value == 1 and NewLaptop ~= nil then
	--	local NewLaptopLocation = actor.GetLocation( NewLaptop )
	--	if NewLaptopLocation ~= nil then
	--		gamemode.SetObjectiveLocation( NewLaptopLocation ) 
	--		print("Resetting objective location to (" .. NewLaptopLocation.x .. ", " .. NewLaptopLocation.y .. ", " .. NewLaptopLocation.z .. ")")
	--	end
	--end
end


function intelretrieval:GetNumberOfSearchLocations()
		-- 0 = none
		-- 1 = one (true location)
		-- 2 = two
		-- 3 = half
		-- 4 = all but one
		-- 5 = all
		
	if self.Settings.DisplaySearchLocations.Value <= 2 then
		return self.Settings.DisplaySearchLocations.Value
	elseif self.Settings.DisplaySearchLocations.Value == 3 then
		return math.floor(#self.LaptopLocationNameList / 2)
		-- round down
	elseif self.Settings.DisplaySearchLocations.Value == 4 then
		return #self.LaptopLocationNameList - 1
	else
		return #self.LaptopLocationNameList
	end
	
	return 2
	-- shouldn't get here
end


function intelretrieval:OnMissionSettingsChanged(ChangedSettingsTable)
	-- NB this may be called before some things are initialised
	-- need to avoid infinite loops by setting new mission settings
	if ChangedSettingsTable['DisplaySearchLocations'] ~= nil then
        print("OnMissionSettingsChanged(): DisplaySearchLocations value changed.")
		self:RandomiseObjectives()
	end
end


function intelretrieval:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false);
	end
end


function intelretrieval:GetModifierTextForObjective( TaggedActor )
	-- consider moving to gamemode
			
	if actor.HasTag( TaggedActor, "AddUpArrow") then
		return "(U)" 
	elseif actor.HasTag( TaggedActor, "AddDownArrow") then
		return "(D)" 
	elseif actor.HasTag( TaggedActor, "AddUpStaircase") then
		return "(u)" 
	elseif actor.HasTag( TaggedActor, "AddDownStaircase") then
		return "(d)"
	elseif actor.HasTag( TaggedActor, "Add1") then
		return "(1)" 
	elseif actor.HasTag( TaggedActor, "Add2") then
		return "(2)" 
	elseif actor.HasTag( TaggedActor, "Add3") then
		return "(3)"
	elseif actor.HasTag( TaggedActor, "Add4") then
		return "(4)" 
	elseif actor.HasTag( TaggedActor, "Add5") then
		return "(5)" 
	elseif actor.HasTag( TaggedActor, "Add6") then
		return "(6)" 
	elseif actor.HasTag( TaggedActor, "Add7") then
		return "(7)" 
	elseif actor.HasTag( TaggedActor, "Add8") then
		return "(8)" 
	elseif actor.HasTag( TaggedActor, "Add9") then
		return "(9)" 
	elseif actor.HasTag( TaggedActor, "Add0") then
		return "(0)" 
	elseif actor.HasTag( TaggedActor, "Add-1") then
		return "(-)"
	elseif actor.HasTag( TaggedActor, "Add-2") then
		return "(=)"
	end
		
	return ""
end


function intelretrieval:GetLaptopInPlay()
	-- deprecated - to be deleted
	-- pass to BP_LaptopUsable the currently selected laptop (if any)
	
	if self.RandomLaptopIndex ~= nil then
		return self.Laptops[ self.RandomLaptopIndex ]
	else
		return nil
	end
end


function intelretrieval:StripNumbersFromName(ObjectName)
	while string.len(ObjectName)>1 and ((string.sub(ObjectName, -1, -1)>='0' and string.sub(ObjectName, -1, -1)<='9') or string.sub(ObjectName, -1, -1)=='_') do
		ObjectName = string.sub(ObjectName, 1, -2)
	end
	
	return ObjectName
end



function intelretrieval:ActivateBumRush()
	if not self.BumRushModeActive then
		self.BumRushModeActive = true
		--print("Activated bum rush mode")
		gamemode.BroadcastGameMessage("BumRushActivated", "Upper", 5.0)
		
		for _, NavBlock in ipairs(self.AllNavBlocks) do
			if not actor.HasTag(NavBlock, "DoNotDisable") then
				actor.SetActive(NavBlock, false)
			end
		end
		-- turn off all nav blocks on the map, to free all the AI, will take a short while to propagate - might need to delay first bumrush call?

		-- filter out squads which are close enough to extraction:
		
		self.BumRushLeaveSquadsAlone = {}
		
		local ExtractionPointLocation = actor.GetLocation( self.ExtractionPoints[self.ExtractionPointIndex] )
		local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, 255, 255)
		
		for _, AIController in ipairs(OpForControllers) do
		
			local AISquadID = ai.GetSquadId(AIController)
			local AICharacter = player.GetCharacter(AIController)
			local AILocation = actor.GetLocation(AICharacter)

			if self.BumRushLeaveSquadsAlone[AISquadID] == nil and vector.SizeSq(AILocation - ExtractionPointLocation) < self.BumRushInRangeDistanceSq then
				self.BumRushLeaveSquadsAlone[AISquadID] = true
			end

			ai.SetSquadOrdersForAIController(AIController, 'Search')
			-- overkill as it will do this multiple times per squad, but let's keep it simple
			-- get this done first so that AI will immediately accept search destination
		end
		
		timer.Set("UpdateBumRushTargets", self, self.UpdateBumRushTargetsTimer, self.BumRushTargetUpdateTime, true)
		self:UpdateBumRushTargetsTimer()
		-- set timer and call function immediately to set targets for bum rushing AI
	end
end


function intelretrieval:UpdateBumRushTargetsTimer()
	local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, 255, 255)
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, false)
	local ExtractionPointLocation = actor.GetLocation( self.ExtractionPoints[self.ExtractionPointIndex] )
	
	if OpForControllers == nil or PlayersWithLives == nil or ExtractionPointLocation == nil then
		return
	end
	
	local TempExtractionPointLocation = ai.ProjectPointToNavigation(ExtractionPointLocation, { x=500.0, y=500.0, z=1000.0 } )
	if TempExtractionPointLocation ~= nil then
		print("Old extract loc = (" .. ExtractionPointLocation.x .. ", " .. ExtractionPointLocation.y .. ", " .. ExtractionPointLocation.z .. ")")
		ExtractionPointLocation = TempExtractionPointLocation
		print("Next extract loc = (" .. ExtractionPointLocation.x .. ", " .. ExtractionPointLocation.y .. ", " .. ExtractionPointLocation.z .. ")")
	else
		print("Could not project extraction zone to navmesh")
	end
	-- most extraction zones are volumes with a centre that might be floating high above the ground, so we need to project to navmesh
	-- some of these zones are off the navmesh (e.g. Small Town SW extract), so bum rush to them might not work so well
	
	local AISquadList = {}
	
	for _, AIController in ipairs(OpForControllers) do
		local AISquadID = ai.GetSquadId(AIController)
		if AISquadID ~= nil then
			if AISquadList[AISquadID] == nil then
				AISquadList[AISquadID] = {}
			end
			table.insert( AISquadList[AISquadID], AIController )
		end
	end
	
	-- AISquadList now contains tables of AI controllers (ordered by SquadID) that are alive in a particular squad
		
	-- remove squads that were deemed close enough to extraction:
	for AISquadID, _ in pairs(self.BumRushLeaveSquadsAlone) do
		AISquadList[AISquadID] = nil
		-- remove controllers for that squad
		print("Removed all controllers for squad " .. AISquadID .. " because they were close enough to extraction")
	end

	-- now activate bum rush mode
		
	for AISquadID, AIControllerList in pairs(AISquadList) do
		local TargetLocation
		if math.random(2) == 1 then
			local RandomPlayer = PlayersWithLives[math.random(#PlayersWithLives)]
			local PlayerCharacter = player.GetCharacter(RandomPlayer)
			TargetLocation = actor.GetLocation(PlayerCharacter)
			print("Setting target to player " .. player.GetName(RandomPlayer) .. " for squad " .. AISquadID .. " including " .. #AIControllerList .. " AI")
		else
			TargetLocation = ExtractionPointLocation
			print("Setting target to extraction point for squad " .. AISquadID .. " including " .. #AIControllerList .. " AI")
		end
		-- set a target location for the whole squad

		if TargetLocation ~= nil then


			for _, AIController in ipairs(AIControllerList) do

				local SearchTargetLocation = ai.GetRandomReachablePointInRadius(TargetLocation, self.BumRushRandomWalkLength)
				-- get a random point near the player, so the AI don't converge on a single point precisely

				if SearchTargetLocation == nil then
					print("SearchTargetLocation was not valid - using player position")
					SearchTargetLocation = TargetLocation
				end
				
				ai.SetSearchTarget(AIController, SearchTargetLocation, self.BumRushTargetUpdateTime)
				-- make AI go to that player's last known location (i.e. current location)
				-- last parameter is search time duration (seconds)
			end
		else
			print("bumrush TargetLocation unexpectedly nil")
		end
	end
end



return intelretrieval