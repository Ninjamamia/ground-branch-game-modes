local DTASvalidate = {

	GameModeObjectTypes = { 'GroundBranch.GBPlayerStart', 'GroundBranch.GBAISpawnPoint', 'GroundBranch.GBAIGuardPoint', 'GroundBranch.GBAIPatrolRoute', },
	-- insertion points must be listed before player starts, because reasons
	
	}

function DTASvalidate:ValidateLevel()
	-- new feature to help mission editor validate levels

	local ErrorsFound = {}
	
	--local PlayerStarts = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPlayerStart')
	--if #PlayerStarts < 1 then
	--	
	
	local NumGameModeObjects = 0
	local NumInsertionPointsOrSpawns = 0

	local AllObjects
	local CurrentGameModeObjectType

	--TODO exclude all/any actors from the ready room. Test what kind of player starts they are?

	for i = 1, #self.GameModeObjectTypes do
		-- iterate through all potentially relevant classes
		CurrentGameModeObjectType = self.GameModeObjectTypes[i]
		AllObjects = gameplaystatics.GetAllActorsOfClass(CurrentGameModeObjectType)
		
		NumGameModeObjects = NumGameModeObjects + #AllObjects
				
		if (CurrentGameModeObjectType == 'GroundBranch.GBPlayerStart' or CurrentGameModeObjectType == 'GroundBranch.GBInsertionPoint') and #AllObjects>0 then
			NumInsertionPointsOrSpawns = NumInsertionPointsOrSpawns + #AllObjects
		end
	end

	if NumGameModeObjects == 0 then
		table.insert(ErrorsFound, "You need to place a few AI spawns, patrol points or guard points to define the extent of the playing area")
	end
	
	if NumInsertionPointsOrSpawns == 0 then
		table.insert(ErrorsFound, "Ideally you should place at least one insertion point or player spawn point to help with random spawn validation")
	end

	local AISpawnPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBAISpawnPoint')
	if #AISpawnPoints < 1 then
		table.insert(ErrorsFound, "No AI spawn points found. You need at least 1 (ideally more) to play vs AI in single player mode")
	end

	return ErrorsFound
end


return DTASvalidate