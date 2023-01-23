local deathmatchvalidate = {
	}
	

function deathmatchvalidate:ValidateLevel()
	-- new feature to help mission editor validate levels

	local ErrorsFound = {}
	
	local PlayerStarts = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPlayerStart')
	if #PlayerStarts < 1 then
		table.insert(ErrorsFound, "No player starts were found. You need ideally 16 or so.")
	elseif #PlayerStarts < 16 then
		table.insert(ErrorsFound, "Only " .. #PlayerStarts .. " player starts were found. This is probably too few.")
	end

	local AISpawnPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	if #AISpawnPoints < 1 then
		table.insert(ErrorsFound, "No AI spawn points found, so can't spawn AI to make up numbers.")
	elseif #AISpawnPoints < 8 then
		table.insert(ErrorsFound, "Only " .. #AISpawnPoints .. " AI spawn points found. Ideally provide 8 or so.")
	end
	
	local SquadIdList = {}
	
	if #AISpawnPoints>0 then
		for _, SpawnPoint in ipairs(AISpawnPoints) do
			SpawnInfo = ai.GetSpawnPointInfo(SpawnPoint)

			if SquadIdList[SpawnInfo.SquadId] == nil then
				SquadIdList[SpawnInfo.SquadId] = 1
			else
				SquadIdList[SpawnInfo.SquadId] = SquadIdList[SpawnInfo.SquadId] + 1
			end

			if actor.GetTeamId(SpawnPoint) ~= 100 then
				table.insert(ErrorsFound, "AI spawn point '" .. actor.GetName(SpawnPoint) .. "' is not assigned to team 100, which all AI spawn points should be")
			end
		end
	end


	for SquadId, Count in pairs(SquadIdList) do
		if Count > 1 then
			table.insert(ErrorsFound, "Multiple (" .. Count .. ") spawn points assigned to Squad ID " .. SquadId .. ". Each spawnpoint should be given a different Squad ID")
		end
	end
	
	local InsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPInsertionPoint')
	if #InsertionPoints > 0 then
		table.insert(ErrorsFound, "Insertion points are not used in this game mode")
	end

	return ErrorsFound
end


return deathmatchvalidate