local terroristhuntvalidate = {

	PriorityTags = { "AISpawn_1", "AISpawn_2", "AISpawn_3", "AISpawn_4", "AISpawn_5",
		"AISpawn_6_10", "AISpawn_11_20", "AISpawn_21_30", "AISpawn_31_40", "AISpawn_41_50" },

	SpawnPriorityGroupIDs = { "AISpawn_11_20", "AISpawn_31_40" },
	-- these define the start of priority groups, e.g. group 1 = everything up to AISPawn_11_20 (i.e. from AISpawn_1 to AISpawn_6_10), group 2 = AISpawn_11_20 onwards, group 3 = AISpawn_31_40 onwards
	-- everything in the first group is spawned as before. Everything is spawned with 100% certainty until the T count is reached
	-- subsequent priority groups are capped, ensuring that some lower priority AI is spawned, and everything else is randomised as much as possible
	-- so overall the must-spawn AI will spawn (priority group 1) and a random mix of more important and (a few) less important AI will spawn fairly randomly

}


function terroristhuntvalidate:StripNumbersFromName(ObjectName)
	while string.len(ObjectName)>1 and ((string.sub(ObjectName, -1, -1)>='0' and string.sub(ObjectName, -1, -1)<='9') or string.sub(ObjectName, -1, -1)=='_') do
		ObjectName = string.sub(ObjectName, 1, -2)
	end
	
	return ObjectName
end


function terroristhuntvalidate:ValidateLevel()
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

	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
	if #AllInsertionPoints == 0 then
		table.insert(ErrorsFound, "No insertion points found")
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
				end
				
				local InsertionPointTeam = actor.GetTeamId(InsertionPoint)
				if InsertionPointTeam ~= 1 then
					if InsertionPointName == "" then
						table.insert(ErrorsFound, "Unnamed insertion point should have team set to 1")
					else
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
								
				if PlayerStartCount == 0 then
					table.insert(ErrorsFound, "No player starts provided for insertion point '" .. InsertionPointName .. "'")
				elseif PlayerStartCount < 8 then
					table.insert(ErrorsFound, "Fewer than 8 player starts provided for insertion point '" .. InsertionPointName .. "'")
				elseif PlayerStartCount > 8 then
					table.insert(ErrorsFound, "More than 8 player starts provided for insertion point '" .. InsertionPointName .. "'")
				end
			end
			
			if InsertionPointHasBlankName then
				table.insert(ErrorsFound, "At least one insertion point has a blank name")
			end
			
			if PlayerStartNoGroup then
				table.insert(ErrorsFound, "At least one player start has a blank group name")
			end
		end
	end

	--- phase 3 check guard groups
	
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
		table.insert(ErrorsFound, "There are fewer groups of guard points (" .. GuardPointCount.. ") than squads set to Guard (" .. GuardSquadCount .. "). Some will be unused. [Dumping guard points and guard squads to log.]")
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

	---- phase 4: quick check of patrol routes
	local AllPatrolRoutes = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAIPatrolRoute')
	if #AllPatrolRoutes == 0 then
		table.insert(ErrorsFound, "Warning: no AI patrol routes found")
	end

	---- phase 5: quick check of new AI hotspots (new in 1033)
	local AllHotspots = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAIHotspot')
	-- it is not mandatory to have hotspots - probably best avoided on small maps
	
	for _, Hotspot in ipairs(AllHotspots) do
		local HotspotName = ai.GetAIHotspotName(Hotspot) 
		if HotspotName == nil or HotspotName == "" or HotspotName == "None" then
			table.insert(ErrorsFound, "AI hotspot '" .. actor.GetName(Hotspot) .. "' does not have a Hotspot name set")
		end
	end
	
	if #AllHotspots == 1 then
		table.insert(ErrorsFound, "Only one AI hotspot found. Are you sure about that?")
	end

	return ErrorsFound
end



return terroristhuntvalidate