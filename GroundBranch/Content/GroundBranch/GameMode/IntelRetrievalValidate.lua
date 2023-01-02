local intelretrievalvalidate = {

	PriorityTags = { "AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5",
		"AISpawn_6_10", "AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40", "AISpawn_41_50" },
		
	SpawnPriorityGroupIDs = { "AISpawn_11_20", "AISpawn_31_40" },
	-- these define the start of priority groups, e.g. group 1 = everything up to AISPawn_11_20 (i.e. from AISpawn_1 to AISpawn_6_10), group 2 = AISpawn_11_20 onwards, group 3 = AISpawn_31_40 onwards
	-- everything in the first group is spawned as before. Everything is spawned with 100% certainty until the T count is reached
	-- subsequent priority groups are capped, ensuring that some lower priority AI is spawned, and everything else is randomised as much as possible
	-- so overall the must-spawn AI will spawn (priority group 1) and a random mix of more important and (a few) less important AI will spawn fairly randomly
}


function intelretrievalvalidate:ActorHasTagInList( CurrentActor, TagList ) 
	if CurrentActor == nil then
		print("intelretrievalvalidate:ActorHasTagInList(): CurrentActor unexpectedly nil")
		return false
	end
	if TagList == nil then
		print("intelretrievalvalidate:ActorHasTagInList(): TagList unexpectedly nil")
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


function intelretrievalvalidate:ValueIsInTable(Table, Value)
	if Table == nil then
		print("intelretrievalvalidate:ValueIsInTable(): Table unexpectedly nil")
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


function intelretrievalvalidate:StripNumbersFromName(ObjectName)
	while string.len(ObjectName)>1 and ((string.sub(ObjectName, -1, -1)>='0' and string.sub(ObjectName, -1, -1)<='9') or string.sub(ObjectName, -1, -1)=='_') do
		ObjectName = string.sub(ObjectName, 1, -2)
	end
	
	return ObjectName
end


function intelretrievalvalidate:ValidateLevel()
	-- new feature to help mission editor validate levels

	local ErrorsFound = {}
	
	------- phase 1 - check priority tags of the ai spawns, make sure they are allocated evenly

	local AllSpawns = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')

	if #AllSpawns == 0 then
		table.insert(ErrorsFound, "No AI spawns found")
	else
		if #AllSpawns < 30 then
			table.insert(ErrorsFound, "Only " .. #AllSpawns .. " AI spawn points provided. This is a little low - aim for at least 30 and ideally 50+")
		end
		
		local CurrentPriorityGroup = 1
		local CurrentGroupTotal = 0
		local CurrentPriorityGroupSpawns = {}
		-- this needs to be outside the loop
	
		-- check the priorities of the ai spawns
		for i, PriorityTag in ipairs(self.PriorityTags) do
			if CurrentPriorityGroup <= #self.SpawnPriorityGroupIDs then
				if PriorityTag == self.SpawnPriorityGroupIDs[CurrentPriorityGroup] then
					-- we found the priority tag corresponding to the start of the next priority group
					
					local StartPriority
					local EndPriority
					if CurrentPriorityGroup == 1 then
						StartPriority = "AISpawn_1"
					else
						StartPriority = self.SpawnPriorityGroupIDs[CurrentPriorityGroup - 1]
					end
					EndPriority = self.SpawnPriorityGroupIDs[CurrentPriorityGroup]
					
					if CurrentGroupTotal == 0 then
						table.insert(ErrorsFound, "(Non ideal) No spawns found within priority range " .. StartPriority .. " to " .. EndPriority)
					elseif CurrentPriorityGroup > 1 and CurrentGroupTotal < 0.15 * #AllSpawns then
						-- it's ok if the first priority group is small
						local pcnumber = tonumber(string.format("%.0f", 100 * (CurrentGroupTotal / #AllSpawns)))
						table.insert(ErrorsFound, "(Non ideal) Relatively few spawns (" .. CurrentGroupTotal .. " of " .. #AllSpawns ..", or " .. pcnumber.. "% of total) are assigned a priority within priority range " .. StartPriority .. " to " .. EndPriority)
					end

					CurrentPriorityGroup = CurrentPriorityGroup + 1
					CurrentGroupTotal = 0
				end
			end
		
			for j, SpawnPoint in ipairs(AllSpawns) do
				if actor.HasTag(SpawnPoint, PriorityTag) then
					CurrentGroupTotal = CurrentGroupTotal + 1
				end
			end

		end
	end
		
	-- now do a more straightforward iteration through spawn points
	
	local SquadsByName = {}
	local SquadsBySquadId = {}
	local SpawnInfo
	local SquadIdProblem = false
	local SquadNameProblem = false

	for _, SpawnPoint in ipairs(AllSpawns) do
		SpawnInfo = ai.GetSpawnPointInfo(SpawnPoint)
		
		local CurrentSquad
		local SpawnPointName = actor.GetName(SpawnPoint)
		CleanName = self:StripNumbersFromName(SpawnPointName)
		--print(SpawnPointName .. " -> " .. CleanName .. ", SquadID = " .. SpawnInfo.SquadId)
		
		if SquadsByName[CleanName] == nil then
			CurrentSquad = {}
			CurrentSquad.Count = 1
			CurrentSquad.WarnedSquadId = false
			CurrentSquad.WarnedSquadOrders = false
			CurrentSquad.WarnedNoOrders = false
			CurrentSquad.SquadId = SpawnInfo.SquadId
			CurrentSquad.SquadOrders = SpawnInfo.SquadOrders
			SquadsByName[CleanName] = CurrentSquad
		else
			CurrentSquad = SquadsByName[CleanName]
			CurrentSquad.Count = CurrentSquad.Count + 1
			if CurrentSquad.SquadId ~= SpawnInfo.SquadId and not CurrentSquad.WarnedSquadId then
				SquadIdProblem = true
				CurrentSquad.WarnedSquadId = true
				table.insert(ErrorsFound, "AI Spawn points '" .. CleanName .. "' have multiple squad IDs")
			end
			if CurrentSquad.SquadOrders ~= SpawnInfo.SquadOrders and not CurrentSquad.WarnedSquadOrders then
				CurrentSquad.WarnedSquadOrders = true
				table.insert(ErrorsFound, "AI Spawn points '" .. CleanName .. "' have multiple squad orders")
			end
			if SpawnInfo.SquadOrders == "None" and not CurrentSquad.WarnedNoOrders then
				CurrentSquad.WarnedNoOrders = true
				table.insert(ErrorsFound, "AI Spawn points '" .. CleanName .. "' have no squad orders" )
			end
		end
		
		if SquadsBySquadId[SpawnInfo.SquadId] == nil then
			CurrentSquad = {}
			CurrentSquad.Count = 1
			CurrentSquad.WarnedSquadName = false
			CurrentSquad.WarnedSquadOrders = false
			CurrentSquad.CleanName = CleanName
			CurrentSquad.SquadOrders = SpawnInfo.SquadOrders
			SquadsBySquadId[SpawnInfo.SquadId] = CurrentSquad
		else
			CurrentSquad = SquadsBySquadId[SpawnInfo.SquadId]
			CurrentSquad.Count = CurrentSquad.Count + 1
			if CurrentSquad.CleanName ~= CleanName and not CurrentSquad.WarnedSquadName then
				SquadNameProblem = true
				CurrentSquad.WarnedSquadName = true
				table.insert(ErrorsFound, "AI Spawn points for SquadID " .. SpawnInfo.SquadId .. " have multiple spawn point names")
			end
			if CurrentSquad.SquadOrders ~= SpawnInfo.SquadOrders and not CurrentSquad.WarnedSquadOrders then
				CurrentSquad.WarnedSquadOrders = true
				table.insert(ErrorsFound, "AI Spawn points for SquadID " .. SpawnInfo.SquadId .. " have multiple squad orders")
			end
		end
	end

	if SquadIdProblem or SquadNameProblem then
		table.insert(ErrorsFound, "Squad IDs do not appear to match name sets. To fix: select all AI spawn points, and click Determine Squad Ids")
	end
	
	-- count squads guarding and patrolling for later tests
	local GuardSquadCount = 0
	local PatrolSquadCount = 0
	
	for _, CurrentSquad in pairs(SquadsBySquadId) do
		if CurrentSquad.SquadOrders == 'Guard' then
			GuardSquadCount = GuardSquadCount + 1
		elseif CurrentSquad.SquadOrders == 'Patrol' then
			PatrolSquadCount = PatrolSquadCount + 1
		end
	end
	
	----- phase 2 check insertion points and player starts

	local AllAttackerInsertionPointNames = {}
	local AllDefenderInsertionPointNames = {}

	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
	if #AllInsertionPoints == 0 then
		table.insert(ErrorsFound, "No insertion points found (player or 'Defender'-tagged)")
	else
		local AllPlayerStarts = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPlayerStart')
		if #AllPlayerStarts == 0 then
			table.insert(ErrorsFound, "No player starts found - click Add Player Starts on insertion point(s) to create")
		else
			local InsertionPointHasBlankName = false
			local PlayerStartNoGroup = false
					
			for _, InsertionPoint in ipairs(AllInsertionPoints) do
			
				local PlayerStartCount = 0
			
				local InsertionPointName = gamemode.GetInsertionPointName(InsertionPoint)
				if InsertionPointName == "" then
					InsertionPointHasBlankName = true
				else
					if actor.HasTag(InsertionPoint, "Defenders") then
						table.insert(AllDefenderInsertionPointNames, InsertionPointName)
						--print("validation: adding defender insertion point name " .. InsertionPointName)
					else
						table.insert(AllAttackerInsertionPointNames, InsertionPointName)
						--print("validation: adding attacker insertion point name " .. InsertionPointName)
					end
				end
				
				local InsertionPointTeam = actor.GetTeamId(InsertionPoint)
				
				if not actor.HasTag(InsertionPoint, "Defenders") then
					if InsertionPointTeam ~= 1 then
						table.insert(ErrorsFound, "Insertion point '" .. InsertionPointName .. "' should have team set to 1")
					end
				end
			
				local PlayerStartCount = 0
				
				for __, PlayerStart in ipairs(AllPlayerStarts) do
					local AssociatedInsertionPointName = gamemode.GetInsertionPointName(PlayerStart)
					
					if AssociatedInsertionPointName == "" or  AssociatedInsertionPointName == "None" then
						PlayerStartNoGroup = true
					elseif InsertionPointName ~= "" and AssociatedInsertionPointName == InsertionPointName then	
					-- if playerstart is associated with InsertionPoint
						PlayerStartCount = PlayerStartCount + 1
					end
				end
					
				if not actor.HasTag(InsertionPoint, "Defenders") then
					-- player insertion point
					if PlayerStartCount == 0 then
						table.insert(ErrorsFound, "No player starts provided for insertion point '" .. InsertionPointName .. "'")
					elseif PlayerStartCount < 8 then
						table.insert(ErrorsFound, "Fewer than 8 player starts provided for insertion point '" .. InsertionPointName .. "'")
					elseif PlayerStartCount > 8 then
						table.insert(ErrorsFound, "More than 8 player starts provided for insertion point '" .. InsertionPointName .. "'")
					end
				else
					-- defender insertion point
					if PlayerStartCount > 0 then
						table.insert(ErrorsFound, "Insertion point '" .. InsertionPointName .. "' is a defender insertion point so should not have any associated player spawns")
					end
				end
			end
			
			if InsertionPointHasBlankName then
				table.insert(ErrorsFound, "At least one insertion point has a blank name")
			end
			
			if PlayerStartNoGroup then
				table.insert(ErrorsFound, "At least one player start has a blank group name")
			end
		end
		
		
		if #AllAttackerInsertionPointNames == 0 then
			table.insert(ErrorsFound, "No player insertion points found")
		end
		
		if #AllDefenderInsertionPointNames == 0 then
			table.insert(ErrorsFound, "No 'Defenders'-tagged insertion points found")
		end
	end
	
	--- phase 3 check laptops

	-- laptop scripts are checked separately in the "WBP_Dialogue_ValidationErrors" widget because reasons (laptop is a BP not c++)

	local LaptopsPerInsertionPoint = {}
	for _, InsertionPointName in ipairs(AllDefenderInsertionPointNames) do
		LaptopsPerInsertionPoint[ InsertionPointName] = 0
	end
	
	local AllLaptops = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/Electronics/MilitaryLaptop/BP_Laptop_Usable.BP_Laptop_Usable_C')
	if #AllLaptops == 0 then
		table.insert(ErrorsFound, "No laptops placed")
	else
		for _, Laptop in ipairs(AllLaptops) do
			if not self:ActorHasTagInList( Laptop, AllDefenderInsertionPointNames ) then
				table.insert(ErrorsFound, "Laptop '" .. actor.GetName(Laptop) .. "' does not have a tag corresponding to a defender insertion point")
			end

			for __, InsertionPointName in ipairs(AllDefenderInsertionPointNames) do
				if actor.HasTag( Laptop, InsertionPointName ) then
					LaptopsPerInsertionPoint[ InsertionPointName ] = LaptopsPerInsertionPoint[ InsertionPointName ] + 1
				end
			end
		end

		for _, InsertionPointName in ipairs(AllDefenderInsertionPointNames) do
			local AverageLaptopsPerInsertionPoint = #AllLaptops / #AllDefenderInsertionPointNames
			local LaptopNumberDeviation = math.abs( LaptopsPerInsertionPoint[InsertionPointName] - AverageLaptopsPerInsertionPoint )
			local LaptopProportionDeviation = LaptopNumberDeviation / #AllLaptops
			local avgint = tonumber(string.format("%.1f", AverageLaptopsPerInsertionPoint))
			
			if LaptopsPerInsertionPoint[InsertionPointName] == 0 then
				table.insert(ErrorsFound, "Defender insertion point '" .. InsertionPointName .. "' does not have any laptops assigned to it")
			elseif LaptopProportionDeviation > 0.04 and LaptopsPerInsertionPoint[InsertionPointName] < AverageLaptopsPerInsertionPoint then
				table.insert(ErrorsFound, "Defender insertion point '" .. InsertionPointName .. "' has relatively few laptops assigned to it (" .. LaptopsPerInsertionPoint[InsertionPointName] .. ", compared to average of " .. avgint .. ")")
			elseif LaptopProportionDeviation > 0.04 and LaptopsPerInsertionPoint[InsertionPointName] > AverageLaptopsPerInsertionPoint then
				table.insert(ErrorsFound, "Defender insertion point '" .. InsertionPointName .. "' has relatively many laptops assigned to it (" .. LaptopsPerInsertionPoint[InsertionPointName] .. ", compared to average of " .. avgint .. ")")
			end
		end
	end

	--- phaes 4 check extractions
	
	local AllExtractionPoints = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/GameMode/BP_ExtractionPoint.BP_ExtractionPoint_C')

	local AllExtractionMarkerNames = {}

	if #AllExtractionPoints == 0 then
		table.insert(ErrorsFound, "No extraction points defined")
	else
		for _,ExtractionPoint in ipairs(AllExtractionPoints) do
			local ExtractionPointTags = actor.GetTags( ExtractionPoint )
			for __, Tag in ipairs(ExtractionPointTags) do
				if string.lower( string.sub(Tag, 1, 7) ) == "extract" then
					table.insert(AllExtractionMarkerNames, Tag)	
				elseif Tag == "None" then
					table.insert(ErrorsFound, "Extraction point '" .. actor.GetName(ExtractionPoint) .. "' has a blank tag")
				elseif string.lower( string.sub(Tag, 1, 3) ) ~= 'add' and Tag ~= "MissionActor" then
					if not self:ValueIsInTable( AllAttackerInsertionPointNames, Tag) then
						-- if an attacker insertion point name is used as a tag, that insertion point is disabled if the extraction zone is enabled
						table.insert(ErrorsFound, "Extraction point '" .. actor.GetName(ExtractionPoint) .. "' has an apparently superfluous tag '" .. Tag .. "'. Use a tag beginning 'Extract' to attach AI spawns to this extraction point")
					end
				end
			end
		end
	end
		
	--- phase 5 check AI associated with laptops and extractions

	local AllAIExtractionMarkerNames = {}
	
	for _, SpawnPoint in ipairs(AllSpawns) do
		local SpawnPointTags = actor.GetTags( SpawnPoint )
		for __, Tag in ipairs(SpawnPointTags) do
			if string.lower( string.sub(Tag, 1, 8) ) ~= 'aispawn_' and Tag ~= "MissionActor" then
				if string.lower( string.sub(Tag, 1, 7) ) == "extract" then
					table.insert(AllAIExtractionMarkerNames, Tag)
					if not self:ValueIsInTable( AllExtractionMarkerNames, Tag) and not self:ValueIsInTable( AllDefenderInsertionPointNames, Tag) then
						table.insert(ErrorsFound, "AI spawn point '" .. actor.GetName(SpawnPoint) .. "' has an 'extract' tag (" .. Tag .. ") not matching an extraction point")
					end
				else
					if Tag == "None" then
						table.insert(ErrorsFound, "AI spawn point '" .. actor.GetName(SpawnPoint) .. "' has a blank tag")
					elseif not self:ValueIsInTable( AllDefenderInsertionPointNames, Tag) then
						table.insert(ErrorsFound, "AI spawn point '" .. actor.GetName(SpawnPoint) .. "' has an apparently superfluous tag '" .. Tag .. "' that does not match a laptop location or extraction zone")
					end
				end
			end
		end
	end
	
	for _, ExtractionMarkerName in ipairs(AllExtractionMarkerNames) do
		if not self:ValueIsInTable( AllAIExtractionMarkerNames, ExtractionMarkerName ) then
			table.insert(ErrorsFound, "Extraction tag '" .. ExtractionMarkerName .. "' was attached to an extraction point but not used anywhere else")
		end
	end
	
	--- phase 6 check guard groups, check all AI in group have same role, check for guard group None, check for AI assigned to things (laptops, extractions)

	local AllGuardPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAIGuardPoint')
	
	local GuardPointNames = {}
	local GuardPointName
	local GuardPointCount = 0
	
	for _,GuardPoint in ipairs(AllGuardPoints) do
		GuardPointName = ai.GetGuardPointName(GuardPoint)
		if GuardPointName == 'None' then
			table.insert(ErrorsFound, "AI guard point '" .. actor.GetName(GuardPoint) .. "' has group name set to None")
		else
			if GuardPointNames[GuardPointName] == nil then
				GuardPointNames[GuardPointName] = false
				GuardPointCount = GuardPointCount + 1
			end	
		end
	end

	local DumpGuardPoints = false

	if #AllGuardPoints == 0 then
		table.insert(ErrorsFound, "Warning: no AI guard points found")
	elseif GuardPointCount < GuardSquadCount then
		table.insert(ErrorsFound, "There are fewer groups of guard points (" .. GuardPointCount.. ") than squads set to Guard (" .. GuardSquadCount .. "). This may be ok if guard points have been reused for different conditional AI spawns. [Dumping guard points and guard squads to log.]")
		DumpGuardPoints = true
	elseif GuardPointCount > GuardSquadCount then
		table.insert(ErrorsFound, "There are more groups of guard points (" .. GuardPointCount.. ") than squads set to Guard (" .. GuardSquadCount .. "). You want a one to one correspondence. [Dumping guard points and guard squads to log.]")
		DumpGuardPoints = true
	end

	if DumpGuardPoints then
		print("GuardPoints")
		print("-----------")
		for GuardPointName, _ in pairs(GuardPointNames) do
			print (GuardPointName)
		end
		
		print("Guard squads")
		print("------------")
		for _, CurrentSquad in pairs(SquadsBySquadId) do
			if CurrentSquad.SquadOrders == 'Guard' then
				print(CurrentSquad.CleanName)
			end
		end
	end

	---- phase 7: quick check of patrol routes
	local AllPatrolRoutes = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAIPatrolRoute')
	if #AllPatrolRoutes == 0 then
		table.insert(ErrorsFound, "Warning: no AI patrol routes found")
	end


	return ErrorsFound
end


return intelretrievalvalidate