local teameliminationvalidate = {
}

function teameliminationvalidate:ValidateLevel()
	-- new feature to help mission editor validate levels

	local ErrorsFound = {}
		
	----- phase 1 check insertion points and player starts

	local FoundTeam1Use = false
	local FoundTeam2Use = false
	local InsertionPointTagCount = {}

	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
	if #AllInsertionPoints == 0 then
		table.insert(ErrorsFound, "No insertion points found for either team")
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
					local InsertionPointTeam = actor.GetTeamId(InsertionPoint)
					
					if InsertionPointTeam == 1 then
						FoundTeam1Use = true
					elseif InsertionPointTeam == 2 then
						FoundTeam2Use = true
					elseif InsertionPointTeam ~= 255 then
						table.insert(ErrorsFound, "Insertion point '" .. actor.GetName(InsertionPoint) .. "' has invalid team ID " .. InsertionPointTeam .. " (should be 1 for Blue Team, 2 for Red Team, or 255 for either)")
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
				
				-- now check insertion point tags
				local InsertionPointTags = actor.GetTags( InsertionPoint )
				for __, Tag in ipairs(InsertionPointTags) do
				if Tag ~= "MissionActor" then
						if Tag == "None" then
							table.insert(ErrorsFound, "Insertion point '" .. actor.GetName(InsertionPoint) .. "' has a blank tag")
						else
							if InsertionPointTagCount[ Tag ] == nil then
								InsertionPointTagCount[ Tag ] = 1
							else
								InsertionPointTagCount[ Tag ] = InsertionPointTagCount[ Tag ] + 1
							end
						end
					end
				end
				
			end
		end
			
		if FoundTeam1Use and FoundTeam2Use and #AllInsertionPoints == 2 then
			-- this is set up correctly for a map like Paintball
			table.insert(ErrorsFound, "Warning: spawns are set up as fixed spawns (2 spawns, set as teams 1 and 2) and won't be rotated/randomised")
		else
		
			if FoundTeam1Use then
				table.insert(ErrorsFound, "Warning: found insertion points for team 1 - team IDs are now disregarded (use Team Id 255 instead)")
			end
			if FoundTeam2Use then
				table.insert(ErrorsFound, "Warning: found insertion points for team 2 - team IDs are now disregarded (use Team Id 255 instead)")
			end
			
			for Tag, TagCount in pairs(InsertionPointTagCount) do
				if TagCount == 1 then
					table.insert(ErrorsFound, "Warning: only found one insertion point with group tag '" .. Tag .. "'")
				end
			end
		end
	
	end
			
		
	return ErrorsFound
end


return teameliminationvalidate