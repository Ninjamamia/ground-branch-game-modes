local uplinkvalidate = {
}




function uplinkvalidate:ActorHasTagInList( CurrentActor, TagList ) 
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


function uplinkvalidate:ValueIsInTable(Table, Value)
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


function uplinkvalidate:ValidateLevel()
	-- new feature to help mission editor validate levels

	local ErrorsFound = {}
		
	----- phase 1 check insertion points and player starts

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
					
			for _, InsertionPoint in ipairs(AllInsertionPoints) do
			
				local PlayerStartCount = 0
			
				local InsertionPointName = gamemode.GetInsertionPointName(InsertionPoint)
				if InsertionPointName == "" then
						table.insert(ErrorsFound, "Insertion point '" .. actor.GetName(InsertionPoint) .. "' has a blank name")
				else
									
					if actor.HasTag(InsertionPoint, "Attackers") then
						table.insert(AllAttackerInsertionPointNames, InsertionPointName)
					elseif actor.HasTag(InsertionPoint, "Defenders") then
						table.insert(AllDefenderInsertionPointNames, InsertionPointName)
					else
						table.insert(ErrorsFound, "Insertion point '" .. actor.GetName(InsertionPoint) .. "' is not tagged as 'Attackers' or 'Defenders'")
					end
				end
			
				local PlayerStartCount = 0
				
				for __, PlayerStart in ipairs(AllPlayerStarts) do
					local AssociatedInsertionPointName = gamemode.GetInsertionPointName(PlayerStart)
					
					if AssociatedInsertionPointName == "" or  AssociatedInsertionPointName == "None" then
						table.insert(ErrorsFound, "Player start '" .. actor.GetName(PlayerStart) .. "' has a blank group name")
					elseif InsertionPointName ~= "" and AssociatedInsertionPointName == InsertionPointName then	
					-- if playerstart is associated with InsertionPoint
						PlayerStartCount = PlayerStartCount + 1
					end
				end
					
				-- player insertion point
				if PlayerStartCount == 0 then
					table.insert(ErrorsFound, "No player starts provided for insertion point '" .. InsertionPointName .. "'")
				elseif PlayerStartCount < 8 then
					table.insert(ErrorsFound, "Fewer than 8 player starts provided for insertion point '" .. InsertionPointName .. "'")
				elseif PlayerStartCount > 8 then
					table.insert(ErrorsFound, "More than 8 player starts provided for insertion point '" .. InsertionPointName .. "'")
				end

			end
		end
		
		
		if #AllAttackerInsertionPointNames == 0 then
			table.insert(ErrorsFound, "No insertion points provided for attacking team (-> add 'Attackers' tag to insertion point - team ID is disregarded)")
		end
		if #AllDefenderInsertionPointNames == 0 then
			table.insert(ErrorsFound, "No insertion points provided for defending team (-> add 'Defenders' tag to insertion point - team ID is disregarded)")
		end
	end
	
	
	--- phase 2 check laptops

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
			if LaptopsPerInsertionPoint[InsertionPointName] == 0 then
				table.insert(ErrorsFound, "Defender insertion point '" .. InsertionPointName .. "' does not have any laptops assigned to it")
			end
		end
	end
	
	
	--- phase 3 check spawn protection volumes
	
	local AllSPV = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBSpawnProtectionVolume')
	if #AllSPV == 0 then
		table.insert(ErrorsFound, "No spawn protection volumes found (NB TeamID for volumes is disregarded - it is automatically set by game script each round)")
	end
		
	return ErrorsFound
end

return uplinkvalidate