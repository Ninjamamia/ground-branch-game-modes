local teamelimination = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = { "TeamElimination" },
	
	-- Limit dead bodies and dropped items.
	MaxDeadBodies = 8,
	MaxDroppedItems = 32,
	
	-- override other values
	
	GameModeAuthor = "(c) BlackFoot Studios, 2021-2022",
	GameModeType = "PVP",
	
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
	Settings = {
		RoundTime = {
			Min = 5,
			Max = 30,
			Value = 10,
			AdvancedSetting = false,
		},
		TeamReinforcements = {
			Min = 0,
			Max = 200,
			Value = 0,
			AdvancedSetting = false,
		},
		PlayerReinforcements = {
			Min = 0,
			Max = 20,
			Value = 0,
			AdvancedSetting = false,
		},
		TeammateRespawns = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = true,
		},
        -- fill in with AI if less than this value
		MinPlayers = {
			Min = 1,
			Max = 10,
			Value = 4,
			AdvancedSetting = true,
		},
        Difficulty = {
        	Min = 0,
        	Max = 4,
        	Value = 2,
            AdvancedSetting = true,
        },		
	},
	
	RoundResult = "",
	InsertionPoints = {},

	LastRedSpawn = nil,
	LastBlueSpawn = nil,
	-- track last red and blue spawns to try to get different spawns next time
	
	bSpawnsAreFixed = false,
	-- true if we shouldn't move spawns around, e.g. for Paintball
	-- set true if only two spawns and they have team IDs set
	
	CurrentInsertionPoints = {},
	-- index is TeamId, value is index in InsertionPoints{} of currently selected points for red and blue teams
	
	TeamReinforcements = {},
	-- TeamID as index (1, 2) to hold current team reinforcements

	TicketDisplayUpdateInterval = 2.5,
	-- time between updates of tickets. Anything less than 5.0 will fail because reasons (min display time?)
	
	StillSpawningAtInsertionPoints = true,
	
	TeamDeathList = {},
	-- [1], [2] contain tables of players dead in that team, ordered by most recent last
	
	TeamDeathLocations = {},
	-- [1], [2] contain tables of locations where players died, ordered by most recent last

	NumberOfTeamDeathLocationsToTrack = 4,
	-- how big a history of death locations to track for each team
	
	PlayerTriedSpawningList = {},
	-- if a player is on this list, we tried spawning and they haven't died (yet)
	
	MinimumSpawnDistanceToEnemy = 15.0,
	-- in metres
	
	MinimumSpawnDistanceToDeathLocation = 7.5,
	-- in metres
		
	NavMeshWalkLengthToRespawn = 4.0,
	-- in metres, how far to take a random walk from the person you're spawning next to
	
	TeamDistanceWeight = 1.0,
	InsertionPointWeight = 0.7,
	DeathLocationWeight = 1.5,
	-- weightings for scoring which team mate is best
	
	PlayerCapsuleHalfHeight = 100,
	PlayerCapsuleRadius = 40,
	-- size for collision checking when spawning flags and players, etc
	-- ideally we would get this dynamically depending on the relevant player's stance (this will not match prone, for example)
	
	SpawningMessageDuration = 6.0,
	-- time in seconds to display spawn related messages
	
	CompletedARound = true,
	-- used to stop readying up and readying down causing spawns to randomise
	
	DebugMode = false,
	-- allows game to be started with only one player on server, and a few other tweaks for testing
}



function teamelimination:PreInit()
	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')

	-- big simplification MF 2022/2/2 to do away with internal representations of groups (but these are still checked when picking spawns)
	-- and Team IDs of insertion points are now disregarded, to ensure maximum spawn randomisation
	
	self.bSpawnsAreFixed = false
	
	if #AllInsertionPoints == 2 then
		if actor.GetTeamId(AllInsertionPoints[1]) <= 2 and actor.GetTeamId(AllInsertionPoints[2]) <= 2 then
			-- very specific case with 2 spawns with fixed team IDs - for maps like Paintball
			self.bSpawnsAreFixed = true
		end
	end
	
	self.InsertionPoints = AllInsertionPoints
end

function teamelimination:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.Blue.TeamId, "EliminateRed", 1)
	gamemode.AddGameObjective(self.PlayerTeams.Red.TeamId, "EliminateBlue", 1)
end

function teamelimination:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false);
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false);
	end
end

function teamelimination:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	end
	
	if ReadyStatus == "WaitingToReadyUp" 
	and gamemode.GetRoundStage() == "PreRoundWait" 
	and gamemode.PrepLatecomer(PlayerState) then
		gamemode.EnterPlayArea(PlayerState)
	end
end



function teamelimination:CheckReadyUpTimer()
	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local BlueReady = ReadyPlayerTeamCounts[self.PlayerTeams.Blue.TeamId]
		local RedReady = ReadyPlayerTeamCounts[self.PlayerTeams.Red.TeamId]
		
		local ShouldStartRound = false
		
		if self.DebugMode then
		    ShouldStartRound = true
		elseif gameplaystatics.GetNetMode() == "Standalone" then
            ShouldStartRound = (BlueReady > 0) or (RedReady > 0)
		else
		    ShouldStartRound = (BlueReady > 0) and (RedReady > 0) 
		end
		
		if ShouldStartRound then
			if BlueReady + RedReady >= gamemode.GetPlayerCount(true) then
				gamemode.SetRoundStage("PreRoundWait")
			else
				gamemode.SetRoundStage("ReadyCountdown")
			end
		end
	end
end

function teamelimination:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local BlueReady = ReadyPlayerTeamCounts[self.PlayerTeams.Blue.TeamId]
		local RedReady = ReadyPlayerTeamCounts[self.PlayerTeams.Red.TeamId]
		if (not self.DebugMode and (BlueReady < 1 or RedReady < 1))
		or (    self.DebugMode and (BlueReady < 1 and RedReady < 1)) then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function teamelimination:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
	
		timer.Clear("DisplayTickets")
	
		if self.CompletedARound and not self.bSpawnsAreFixed then
		-- simplified MF 2022/2/2 to remove old groups stuff
			self:RandomiseInsertionPoints(self.InsertionPoints)
		end
		
		-- spawn picking system now greatly simplified
		
		self.StillSpawningAtInsertionPoints = true

		self.CompletedARound = false
		
	elseif RoundStage == "PreRoundWait" then
		
		self.TeamDeathList[ self.PlayerTeams.Blue.TeamId ]  = {}
		self.TeamDeathList[ self.PlayerTeams.Red.TeamId ]  = {}
		-- reset deathlist
		
		self.TeamDeathLocations[ self.PlayerTeams.Blue.TeamId ]  = {}
		self.TeamDeathLocations[ self.PlayerTeams.Red.TeamId ]  = {}
		-- reset death locations
		
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
		-- need to update this as ops board setting may have changed - have to do this before RoundStage InProgress to be effective
		-- credit to trav (tjl9987612) for spotting this was missing

	elseif RoundStage == "InProgress" then

		if self.TeamReinforcements[ self.PlayerTeams.Blue.TeamId ] == nil then
			print("OnRoundStageSet(): team reinforcements unexpectedly nil, setting to appropriate values (should have been set in OnRoundStageTimeElapsed)")
			self.TeamReinforcements[ self.PlayerTeams.Blue.TeamId ] = self.Settings.TeamReinforcements.Value
			self.TeamReinforcements[ self.PlayerTeams.Red.TeamId  ] = self.Settings.TeamReinforcements.Value
		end

		self.StillSpawningAtInsertionPoints = false
		-- from now on, respawns are at the oldest surviving player

		-- broadcast number of reinforcements available:
		
		if self.Settings.PlayerReinforcements.Value > 0 then
			if self.Settings.TeamReinforcements.Value > 0 then
				gamemode.BroadcastGameMessage("You have " .. self.Settings.PlayerReinforcements.Value .. " player reinforcement(s) and " .. self.Settings.TeamReinforcements.Value .. " team reinforcement(s) available.", "Upper", 5.0)
			else
				gamemode.BroadcastGameMessage("You have " .. self.Settings.PlayerReinforcements.Value .. " player reinforcement(s) available.", "Upper", 5.0)
			end
		else
			if self.Settings.TeamReinforcements.Value > 0 then
				gamemode.BroadcastGameMessage("You have " .. self.Settings.TeamReinforcements.Value .. " team reinforcement(s) available.", "Upper", 5.0)
			end
		end
		-- TODO: get this localised somehow

	elseif RoundStage == "PostRoundWait" then

		self.CompletedARound = true
		-- cause randomisation of objectives

	end
end



function teamelimination:OnRoundStageTimeElapsed(RoundStage)


	if RoundStage == "PreRoundWait" then
	
	-- wait till the end of PreRoundWait rather than doing this at the start, 
	-- so as to make sure all players have spawned in first
	
		self.PlayerTriedSpawningList = {}
		self.TeamDeathLocations [ self.PlayerTeams.Blue.TeamId ] = {}
		self.TeamDeathLocations [ self.PlayerTeams.Red.TeamId ] = {}
		self.PlayerTriedSpawningList = {}
	
		---- set up player lives
		--local AllPlayers = gamemode.GetPlayerListByLives(255, 1, true)
		local AllPlayers = gamemode.GetPlayerList(255, true)
		
		for i = 1, #AllPlayers do
	
			self:AddPlayerToDeathList(AllPlayers[i])
			-- get this set up for all players at start, arbitrary order
			
			--table.insert(self.PlayerTriedSpawningList, AllPlayers[i])
			-- add to players we tried to spawn (for initial setup)
			
			player.SetLives(AllPlayers[i], 1 + self.Settings.PlayerReinforcements.Value)
			--print("----setting lives for player " .. i)
			
			
			if self.Settings.PlayerReinforcements.Value > 0 then
				player.SetAllowedToRestart(AllPlayers[i], true)
			else
				player.SetAllowedToRestart(AllPlayers[i], false)
			end
		end
		
		--print("OnRoundStageTimeElapsed: Setting up team tickets")
		---- set up team tickets
		self.TeamReinforcements[ self.PlayerTeams.Blue.TeamId ] = self.Settings.TeamReinforcements.Value
		self.TeamReinforcements[ self.PlayerTeams.Red.TeamId  ] = self.Settings.TeamReinforcements.Value

		---- start ticker display timer
		if self.Settings.TeamReinforcements.Value > 0 then
		
			timer.Set("DisplayTickets", self, self.DisplayTicketsTimer, self.TicketDisplayUpdateInterval, true);
			-- repeating timer which is cleared when entering WaitingForReady phase
			
			self:DisplayTicketsTimer()
			-- call now as well
			
		end
		
		return false
		
	end
end




function teamelimination:DisplayTicketsTimer()
	gamemode.BroadcastGameMessage("Team reinforcements remaining  -  RED  " .. self.TeamReinforcements[self.PlayerTeams.Red.TeamId] .. "  :  " .. self.TeamReinforcements[self.PlayerTeams.Blue.TeamId] .. "  BLUE", "Engine", -self.TicketDisplayUpdateInterval)
	-- negative display duration -> flush all messages first then display for (abs) this amount of time (avoids fade/message stack up)
end



function teamelimination:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			local PlayerLives = player.GetLives(CharacterController)
			local PlayerTeam = actor.GetTeamId(Character)
			-- does this need playerstate instead?
			
			-- first test whether spawnkilled
			-- @@@ currently not a thing with respawning at teammates
			
			--- next see if we can take a ticket
			
			--print ("----player died, has " .. PlayerLives .. " lives.")
			
			if PlayerTeam == nil then
				print("PlayerTeam unexpectedly nil")
			elseif PlayerTeam ~= self.PlayerTeams.Blue.TeamId and PlayerTeam ~= self.PlayerTeams.Red.TeamId then
				print("PlayerTeam (" .. PlayerTeam .. ") was unexpectedly not a known team")
			elseif self.TeamReinforcements[ PlayerTeam ] == nil then
				print("TeamReinforcements for team " .. PlayerTeam .. " were unexpectedly nil")
			else			
				if PlayerLives == 1 and self.TeamReinforcements[ PlayerTeam ] > 0 then
					self.TeamReinforcements[ PlayerTeam ] = self.TeamReinforcements[ PlayerTeam ] - 1
					-- player is about to die, can we use a ticket?
					player.ShowGameMessage( Character, "TeamReinforcementInbound", "Upper", 4.0)
				else
				
					if PlayerLives > 1 then
						player.ShowGameMessage( Character, "PlayerReinforcementInbound", "Upper", 4.0)

					else
						if self.Settings.TeamReinforcements.Value > 0 then
							player.ShowGameMessage( Character, "YourGameIsOver", "Upper", 4.0)
						end
						
						local PlayersWithLives = gamemode.GetPlayerListByLives(255, 1, false)
						if #PlayersWithLives == 0 then
							self:CheckEndRoundTimer()
						else
							timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
						end
					end
		
					PlayerLives = PlayerLives - 1
		
					player.SetLives(CharacterController, PlayerLives)
					--print("----reducing lives by 1")
				end
			end
			
			
			local KilledPlayerState = player.GetPlayerState(CharacterController)
			-- safest to switch to this I think
			
			self:AddPlayerToDeathList(KilledPlayerState)
			
			for i = #self.PlayerTriedSpawningList, 1, -1 do
				if self.PlayerTriedSpawningList[i] == KilledPlayerState then
					table.remove(self.PlayerTriedSpawningList, i)
					-- remove player from list of players who tried spawning if they die (which they can't do unless they spawned)
					--print("----Removing player from PlayerTriedSpawningList at index " .. i)
				end
			end

			local TeamDeathLocations = self.TeamDeathLocations [ PlayerTeam ]
			-- a reference to the table, so modifying this modifies the relevant part of the global variable
			
			local PlayerLocation = actor.GetLocation( Character ) 
		
			if #TeamDeathLocations >= self.NumberOfTeamDeathLocationsToTrack then
				for i = 1, #TeamDeathLocations-1 do
					TeamDeathLocations[i] = TeamDeathLocations[i+1]
				end
				TeamDeathLocations[#TeamDeathLocations] = PlayerLocation
			else
				table.insert(TeamDeathLocations, PlayerLocation)
			end
			
			-- at this point it would be nice to delay respawn for x seconds (5?)
			
			if PlayerLives > 0 then
				player.SetAllowedToRestart(KilledPlayerState, true)
			else
				player.SetAllowedToRestart(KilledPlayerState, false)
			end
		end
	end
end



function teamelimination:PlayerBecomesSpectator(Player)
	--print ("----PlayerBecomesSpectator() called")

	local RoundStage = gamemode.GetRoundStage()
	
	if RoundStage == 'InProgress'
	or RoundStage == 'PreRoundWait' then
		timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);	
	end
	
	-- this new callback catches a game over condition that was otherwise lost (last player on team who still has lives/reinforcements chooses to spectate rather than respawn)
end


function teamelimination:PlayerEnteredReadyRoom(Player)
	local RoundStage = gamemode.GetRoundStage()
	
	if RoundStage == 'InProgress'
	or RoundStage == 'PreRoundWait' then
		--timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
		self:CheckEndRoundTimer()
		--print("----PlayerEnteredReadyRoom(): completed CheckEndRoundTimer() check")
		--print("----current RoundStage: " .. gamemode.GetRoundStage())
		-- we can't put this on a timer because the game mode immediately resets to WaitingForReady
	end
end


function teamelimination:AddPlayerToDeathList(Player)
	-- add player to list (if not on it yet) or move player to end of list (most recent)

	local TeamId = actor.GetTeamId(Player)
	
	local FoundPlayerInList = false
	
	local DeathList = self.TeamDeathList[ TeamId ]
	-- this is a reference, so any changes made to DeathList will be made in the global variable
	
	if DeathList ~= nil then
		for i = 1, #DeathList do
			if DeathList[i] == Player then
				FoundPlayerInList = true
				DeathList[i], DeathList[#DeathList] = DeathList[#DeathList], DeathList[i]
				-- move player to end of list (most recently dead)
				break
			end
		end
	end

	if not FoundPlayerInList then
		table.insert(DeathList, Player)
		-- add at the end
	end

end




function teamelimination:CheckEndRoundTimer()
	local BluePlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.Blue.TeamId, 1, false)
	local RedPlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.Red.TeamId, 1, false)
	
	if self.DebugMode == true then
		return
		-- the round never ends!
	end
	
	if #BluePlayersWithLives > 0 and #RedPlayersWithLives == 0 then
		gamemode.AddGameStat("Result=Team1")
		gamemode.AddGameStat("Summary=RedEliminated")
		gamemode.AddGameStat("CompleteObjectives=EliminateBlue")
		gamemode.SetRoundStage("PostRoundWait")
	elseif #BluePlayersWithLives == 0 and #RedPlayersWithLives > 0 then
		gamemode.AddGameStat("Result=Team2")
		gamemode.AddGameStat("Summary=BlueEliminated")
		gamemode.AddGameStat("CompleteObjectives=EliminateRed")
		gamemode.SetRoundStage("PostRoundWait")
	elseif #BluePlayersWithLives == 0 and #RedPlayersWithLives == 0 then
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BothEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end



function teamelimination:GetSpawnInfo(PlayerState)
	-- this function is called to get alternative spawn location and rotation (was provided for DTAS)
	
	--print("----called GetSpawnInfo()")
	
	if self.StillSpawningAtInsertionPoints then
		return nil
		-- let the normal spawning routine take place at insertion point
	end
	
	for _, PlayerWeTriedToSpawnAlready in ipairs( self.PlayerTriedSpawningList ) do
		if PlayerWeTriedToSpawnAlready == PlayerState then
			print("previous spawn failed - falling back to insertion point")
			return nil
			-- fall back on insertion point, because we already tried to do custom spawn and failed
		end
	end
	-- ^^^ actually this will not work. In DTAS there was a way to detect if a player failed to spawn (still stuck in RR)
	-- here I think the player will simply come back to life where they died?
	
	table.insert( self.PlayerTriedSpawningList, PlayerState )
	-- if we get a spawn info request and this player is already on the list, we already tried spawning and it failed
	-- players are removed from this list when they die
	
	local Result = {}

	local CurrentTeamId = actor.GetTeamId(PlayerState)
	Result = self:GetNextSpawnLocation(CurrentTeamId, PlayerState)
	-- could be nil
	-- sets Result.Location and Result.Rotation
		
	-- TODO make the newly spawned player face the person they've spawned next to
	
	local PlayerLives = player.GetLives(PlayerState)
	if PlayerLives > 1 then
		if self.TeamReinforcements[ CurrentTeamId ] > 0 then
			player.ShowGameMessage( PlayerState, "PlayerTeamReinforcementsRemain", "Lower", self.SpawningMessageDuration)
			--player.ShowGameMessage( PlayerState, PlayerLives - 1 .. " player reinforcement(s) / " .. self.TeamReinforcements[ CurrentTeamId ] .. " team reinforcement(s) remain.", "Lower", self.SpawningMessageDuration)
		else
			if PlayerLives>1 then
				player.ShowGameMessage( PlayerState, "PlayerReinforcementsRemain", "Lower", self.SpawningMessageDuration)
			else
				player.ShowGameMessage( PlayerState, "PlayerReinforcementRemains", "Lower", self.SpawningMessageDuration)
			end
			
			--player.ShowGameMessage( PlayerState, PlayerLives - 1 .. " player reinforcement(s) remain.", "Lower", self.SpawningMessageDuration)
		end
	else
		if self.TeamReinforcements[ CurrentTeamId ] > 0 then
			if self.TeamReinforcements[ CurrentTeamId ] >1 then
				player.ShowGameMessage( PlayerState, "TeamReinforcementsRemain", "Lower", self.SpawningMessageDuration)
			else
				player.ShowGameMessage( PlayerState, "TeamReinforcementRemains", "Lower", self.SpawningMessageDuration)
			end
			--player.ShowGameMessage( PlayerState,  self.TeamReinforcements[ CurrentTeamId ] .. " team reinforcement(s) remain.", "Lower", self.SpawningMessageDuration)
		else
			player.ShowGameMessage( PlayerState,  "NoPlayerOrTeamReinforcementsRemain", "Lower", self.SpawningMessageDuration)
		end
	end
	
	if Result == nil then
		player.ShowGameMessage( PlayerState, "ReturningToInsertionPoint", "Lower", self.SpawningMessageDuration)
		return nil
	else
		player.ShowGameMessage( PlayerState, "InsertingNextToTeamMate", "Lower", self.SpawningMessageDuration)
	end
	
    return Result;
end




function teamelimination:GetNextSpawnLocation(CurrentTeamId, CurrentPlayer)
	
	-- we want to spawn next to a team-mate who is not near a previous death location, who is not near enemy, and who is alive
	-- if we fail, return nil and we will fall back to insertion point
	
	local CandidateTeamMates1 = {}
	local CandidateTeamMates2 = {}
	-- this is lousy but I'm tired
		
	local SameTeam = gamemode.GetPlayerListByLives(CurrentTeamId, 1, true)
	local OtherTeam = gamemode.GetPlayerListByLives(3 - CurrentTeamId, 1, true)
	-- being hacky with the TeamIds
		
	if self.Settings.TeammateRespawns.Value == 1 then
	
		-- test whether teammates are too close to the enemy
		for _, SameTeamPlayer in ipairs(SameTeam) do
			if SameTeamPlayer ~= CurrentPlayer then
				local TooCloseToEnemy = false

				for __, OtherTeamPlayer in ipairs( OtherTeam ) do
					if self:GetDistanceBetweenPlayers( SameTeamPlayer, OtherTeamPlayer, true ) < self.MinimumSpawnDistanceToEnemy  then
					-- we're working in units of metres, not UE units (cm)
						TooCloseToEnemy = true
					end
				end
				
				if not TooCloseToEnemy then
					table.insert(CandidateTeamMates1, SameTeamPlayer)
					--print("----adding candidate teammate (not too close to enemy)")
				end
			end
		end
				
		-- now test whether the candidate teammates are too close to where people died
		if true == true then
					for _, SameTeamPlayer in ipairs(CandidateTeamMates1) do
						local TooCloseToDeathLocation = false
						
						for __, DeathLocation in ipairs(self.TeamDeathLocations [ CurrentTeamId ]) do
							
							if self:GetDistanceBetweenPlayerAndLocation( SameTeamPlayer, DeathLocation, true ) < self.MinimumSpawnDistanceToDeathLocation  then
								-- we're working in units of metres, not UE units (cm)
									TooCloseToDeathLocation = true
							end
						end
						
						if not TooCloseToDeathLocation then
							table.insert(CandidateTeamMates2, SameTeamPlayer)
							--print("----re-adding candidate teammate (not too close to death location)")
						end
					end
		else
			CandidateTeamMates2 = CandidateTeamMates1
			-- let's skip this test for now
		end		
	else
		-- never do teammate respawns
		--player.ShowGameMessage( CurrentPlayer, "RespawningAtInsertion", "Lower", self.SpawningMessageDuration)
		return nil
	end

	
	if #CandidateTeamMates2 > 0 then
		--local SelectedPlayerIndex = umath.random( #CandidateTeamMates2 )
		-- random is not good enough, we need to pick the best
		
		local SelectedPlayerIndex = self:GetBestTeammateRespawnIndex( CandidateTeamMates2, CurrentTeamId )
		
		local SelectedPlayer = CandidateTeamMates2[ SelectedPlayerIndex ]
		
		player.ShowGameMessage( SelectedPlayer, "ReinforcementInYourVicinity", "Lower", self.SpawningMessageDuration)
		
		local SelectedPlayerLocation = actor.GetLocation( player.GetCharacter( SelectedPlayer ) )
		
		if SelectedPlayerLocation == nil then
			print("TE: SelectedPlayerLocation unexpectedly nil")
			return nil
		end
		
		local OriginalSelectedPlayerLocation = SelectedPlayerLocation
		
		SelectedPlayerLocation = ai.GetRandomReachablePointInRadius(SelectedPlayerLocation, self.NavMeshWalkLengthToRespawn * 100)
		
		if SelectedPlayerLocation == nil then
			print("TE: SelectedPlayerLocation returned from ai.GetRandomReachablePointInRadius() unexpectedly nil")
			player.ShowGameMessage( CurrentPlayer, "CouldNotRespawn", "Lower", self.SpawningMessageDuration)
			return nil
		end
		
		-- new check, added MF 2022/2/7, to avoid large vertical shifts in spawns. This may kill a lot of valid spawns (e.g. on staircases),
		-- but hopefully it will eliminate most of the bogus ones where players jump between floors.
		-- Specifically, we reject any spawns that are more than 2m vertically from the teammate's position 
		-- (smaller than any normal storey height, big enough to allow a lot of height variation regardless)
		if math.abs(SelectedPlayerLocation.z - OriginalSelectedPlayerLocation.z) > 2.0 * 100 then
			return nil
		end

		
		local IsValidSpawn
		local CorrectedSpawnLocation	
		IsValidSpawn, CorrectedSpawnLocation = self:IsValidSpawn(SelectedPlayerLocation)
		
		if not IsValidSpawn then
			player.ShowGameMessage( CurrentPlayer, "CouldNotRespawn", "Lower", self.SpawningMessageDuration)
			return nil
		else
			local Result = {}
			
			--local VectorToSpawnCentre = self:VectorSubtract( SelectedPlayerLocation, CorrectedSpawnLocation )
			--local VectorAngle = math.deg ( math.atan( VectorToSpawnCentre.y, VectorToSpawnCentre.x ) )
			--VectorAngle = math.fmod( 450 + VectorAngle, 360 )
			
			--Result.Rotation = {}
			--Result.Rotation.Pitch = 0.0
			--Result.Rotation.Yaw = VectorAngle
			--Result.Rotation.Roll = 0.0
			
			Result.Rotation = self:GetRandomUprightRotation()
			Result.Location = CorrectedSpawnLocation
			-- not working, never mind
			
			return Result
			
		end
	else
		if #CandidateTeamMates1 >0 and #CandidateTeamMates2 <1 then
			player.ShowGameMessage( CurrentPlayer, "CouldntRespawnRecentDeath", "Lower", self.SpawningMessageDuration)
		elseif #CandidateTeamMates1 == 0 and #SameTeam>1 then
			player.ShowGameMessage( CurrentPlayer, "CouldntRespawnEnemyClose", "Lower", self.SpawningMessageDuration)
		end
		--print("----none of the " .. #SameTeam-1 .. " live team mates met both criteria for acting as spawn base. Falling back to insertion point.")
	end

	return nil
		
end





function teamelimination:GetBestTeammateRespawnIndex( CandidateTeamMates, CurrentTeamId )
	local BestIndex
	local CandidateScores = {}

	if #CandidateTeamMates == 1 then
		return 1
	end

	local MaxTeamDistanceScore = 0
	local MaxInsertionPointDistanceScore = 0
	local MaxDeathLocationDistanceScore = 0

	local TeamDistanceScores = {}
	local InsertionPointDistanceScores = {}
	local DeathLocationDistanceScores = {}

	for i = 1, #CandidateTeamMates do
		
		local TeamDistanceScore = 0
		local InsertionPointDistanceScore = 0
		local DeathLocationDistanceScore = 0
		
		----------------------------------------------------
		-- determine score for distance from other teammates. Need to normalise for maximum distance
		
		for j = 1, #CandidateTeamMates do
			if i ~= j then
				local TeamDistance =  self:GetDistanceBetweenPlayers( CandidateTeamMates[i], CandidateTeamMates[j], true )
				if TeamDistance > TeamDistanceScore then
					TeamDistanceScore = TeamDistance
				end
			end
		end
		
		if TeamDistanceScore > MaxTeamDistanceScore then
			MaxTeamDistanceScore = TeamDistanceScore
		end
		
		table.insert(TeamDistanceScores, TeamDistanceScore)
		-- will need another pass to normalise this to 0..1
		
		-----------------------------------------------------
		-- determine score for distance from insertion point
	
		local InsertionPointLocation = actor.GetLocation ( self.CurrentInsertionPoints[ TeamId ] )
		InsertionPointDistanceScore = math.max( 50 * 100, self:GetDistanceBetweenPlayerAndLocation( CandidateTeamMates[i], InsertionPointLocation, true ) )
		-- max this out at 50m so we don't encourage spawn camping
		
		if InsertionPointDistanceScore > MaxInsertionPointDistanceScore then
			MaxInsertionPointDistanceScore = InsertionPointDistanceScore
		end
		
		table.insert(InsertionPointDistanceScores, InsertionPointDistanceScore)
		-- will need another pass to normalise this to 0..1
	
		-----------------------------------------------------
		-- determine score for distance from dead bodies
	
		local DeathLocations = self.TeamDeathLocations[CurrentTeamId]
		
		for j = 1, #DeathLocations do
			local DeathLocationDistance = self:GetDistanceBetweenPlayerAndLocation( CandidateTeamMates[i], DeathLocations[j], true )
			if DeathLocationDistance > DeathLocationDistanceScore then
					DeathLocationDistanceScore = DeathLocationDistance
					-- we want a big death location distance if possible
			end
		end
		
		if DeathLocationDistanceScore > MaxDeathLocationDistanceScore then
			MaxDeathLocationDistanceScore = DeathLocationDistanceScore
		end
		
		table.insert(DeathLocationDistanceScores, DeathLocationDistanceScore)
		-- will need another pass to normalise this to 0..1
	end
	
	------------------------------------------------------
	--- normalise all the scores and find best
	
	local BestScore = 0
	local BestIndex = 1
	
	for i= 1, #TeamDistanceScores do

		TeamDistanceScores[i] = TeamDistanceScores[i] / MaxTeamDistanceScore
		InsertionPointDistanceScores[i] = InsertionPointDistanceScores[i] / MaxInsertionPointDistanceScore
		DeathLocationDistanceScores[i] = DeathLocationDistanceScores[i] / MaxDeathLocationDistanceScore
		
		local CurrentScore = self.TeamDistanceWeight * TeamDistanceScores[i]   +   self.InsertionPointWeight * InsertionPointDistanceScores[i]   +   self.DeathLocationWeight * DeathLocationDistanceScores[i]
		
		--print("TE: score for teammate " .. i .. ": " .. CurrentScore .. " (Team=" .. TeamDistanceScores[i] .. ", IP=" .. InsertionPointDistanceScores[i] .. ", Death=" .. DeathLocationDistanceScores[i])
		
		if CurrentScore > BestScore then
			BestScore = CurrentScore
			BestIndex = i
		end
	
	end
	
	-- tables should all be same size
	
	return BestIndex
end





function teamelimination:IsValidSpawn(SpawnLocation)
	-- test using Kris' GB-specific spawn validation/moving function

	local CapsuleHalfHeight = 100
	local CapsuleRadius = 40
	
	if SpawnLocation == nil then
		print("TE: IsValidSpawn(): SpawnLocation was unexpectedly nil")
		return false
	end

	local ValidatedSpawnResult = self:GetCorrectedValidatedSpawnLocation( SpawnLocation, self.PlayerCapsuleHalfHeight, self.PlayerCapsuleRadius)
	
	if ValidatedSpawnResult == nil then
		print("TE: IsValidSpawn(): GetCorrectedValidatedSpawnLocation() unexpectedly returned nil for SpawnLocation")
		return false
	end

	if not self:DidWeActuallyValidateLocation( ValidatedSpawnResult, SpawnLocation ) then
		if not ValidatedSpawnResult.bValid or ValidatedSpawnResult.ValidatedSpawnLocation == nil then
			return false
		elseif ValidatedSpawnResult.ValidatedSpawnLocation ~= SpawnLocation then
			return false
		end
	end

	return true, ValidatedSpawnResult.ValidatedSpawnLocation
end



function teamelimination:GetCorrectedValidatedSpawnLocation( PlayerLocation, PlayerCapsuleHalfHeight, PlayerCapsuleRadius )
	if PlayerLocation ~= nil then
		PlayerLocation.z = PlayerLocation.z + PlayerCapsuleHalfHeight
		-- this is around the size of the normal correction made by the function
	end

	return gameplaystatics.GetValidatedSpawnLocation( PlayerLocation, PlayerCapsuleHalfHeight, PlayerCapsuleRadius )
end



function teamelimination:DidWeActuallyValidateLocation( ValidationResult, PlayerLocation )
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





function teamelimination:GetDistanceBetweenPlayers(Player1, Player2, TwoDimensional)
-- returns distance in metres between the players

	if Player1 == nil or Player2 == nil then
		print("GetDistanceBetweenPlayers(): player1 or player2 was nil")
		return math.random(3)
		-- small distance, also random in case big fuck up everywhere
		--return 1000 * 100
	end
	
	local Character1 = player.GetCharacter(Player1)
	local Character2 = player.GetCharacter(Player2)

	if Character1 == nil or Character2 == nil then
		print("GetDistanceBetweenPlayers(): Character1 or Character2 was nil")
		return math.random(3)
		-- small distance, also random in case big fuck up everywhere
		--return 10000
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




function teamelimination:GetDistanceBetweenPlayerAndLocation(Player1, Location2, TwoDimensional)
-- returns distance in metres between the player and location

	if Player1 == nil or Location2 == nil then
		print("GetDistanceBetweenPlayerAndLocation(): player1 or location2 was nil")
		return math.random(3)
		--small distance, also random in case big fuck up everywhere
		--return 1000 * 100
	end
	
	local Character1 = player.GetCharacter(Player1)

	if Character1 == nil then
		print("GetDistanceBetweenPlayerAndLocation(): Character1 was nil")
		return math.random(3)
		-- small distance, also random in case big fuck up everywhere
		--return 10000
	end
	
	local Location1 = actor.GetLocation( Character1 )
	
	local DifferenceVector = self:VectorSubtract( Location1, Location2 )
	
	if TwoDimensional then
		return vector.Size2D(DifferenceVector) / 100
	else
		return vector.Size(DifferenceVector) / 100
	end
end



function teamelimination:VectorSubtract( Vector1, Vector2 )
	local Result = {}

	if Vector1 == nil or Vector2 == nil then
		print("teamelimination: VectorSubtract(): passed nil vector, returning nil")
		return nil
	end

	local Result = {}

	Result.x = Vector1.x - Vector2.x
	Result.y = Vector1.y - Vector2.y
	Result.z = Vector1.z - Vector2.z

	return Result
end



function teamelimination:GetRandomUprightRotation()
	local Result = {}
		
	Result = {}
	
	Result.Pitch = 0.0
    Result.Yaw = umath.randomrange(-180.0, 180.0);
    Result.Roll = 0.0
		    
    return Result;

end


function teamelimination:NumMatchingTags( ActorToCheck, TagList )
	local TagsInCommon = 0
	
	if ActorToCheck == nil or TagList == nil then
		return 0
	end
	
	for _, Tag in ipairs(TagList) do
		if actor.HasTag(ActorToCheck, Tag) then
			TagsInCommon = TagsInCommon + 1
		end
	end
	
	return TagsInCommon
end


function teamelimination:RandomiseInsertionPoints(TargetInsertionPoints)
	if #TargetInsertionPoints < 2 then
		print("Error: #TargetInsertionPoints < 2")
		return
	end

	-- function revised MF 2022/2/1 to randomise everything with no restriction except not returning two spawns with the same group tag
	-- (team Ids now ignored, which solves the problem with the previous version of the routine overwriting them each round)

	local BlueSelectionOfInsertionPoints = {}
	local RedSelectionOfInsertionPoints = {}

	if self.LastBlueSpawn ~= nil then
		for _, InsertionPoint in ipairs(TargetInsertionPoints) do
			if InsertionPoint ~= self.LastBlueSpawn then
				table.insert(BlueSelectionOfInsertionPoints, InsertionPoint)
			end
		end
	else
		BlueSelectionOfInsertionPoints = TargetInsertionPoints
	end
	-- exclude from the list of insertion points the point we picked last time

	local BlueIndex = umath.random(#BlueSelectionOfInsertionPoints)
	local BlueSpawn = BlueSelectionOfInsertionPoints [ BlueIndex ]
	local BlueTags = actor.GetTags(BlueSpawn)

	for _, InsertionPoint in ipairs(TargetInsertionPoints) do
		if InsertionPoint ~= BlueSpawn and self:NumMatchingTags(InsertionPoint, BlueTags) <= 1 then
		-- list of possible spawns for red excludes currently picked blue spawn and any spawns in the same group as it
		-- (same group defined as any actors having more than one tag in common - all mission actors share a mission object identifier tag)
		-- (it is possible to have multiple, overlapping groups for fine control over mutually exclusive spawns)
			table.insert(RedSelectionOfInsertionPoints, InsertionPoint)
		end
	end
	
	local RedIndex = umath.random(#RedSelectionOfInsertionPoints)
	local RedSpawn = RedSelectionOfInsertionPoints[RedIndex]
	-- don't care about red team tags

	if self.LastRedSpawn ~= nil and self.LastBlueSpawn ~= nil then
		-- if we have had a previous round so spawns might repeat...
		
		if self.LastRedSpawn == RedSpawn or self.LastBlueSpawn == BlueSpawn then
		--  if currently a spawn is repeating for one team ...

			if self.LastBlueSpawn ~= RedSpawn and self.LastRedSpawn ~= BlueSpawn then
			-- if swapping teams won't cause the same problem to occur for the other team, then always swap
				BlueSpawn, RedSpawn = RedSpawn, BlueSpawn
			else
				-- else random chance (50%) of swapping spawns anyway (see below for reason)
				if umath.random(2) == 1 then
					BlueSpawn, RedSpawn = RedSpawn, BlueSpawn
				end
			end

		else
			-- no spawns currently repeat. If swapping won't make spawns repeat either, then randomly swap 50% of the time
			-- this is because if there is a relatively big spawn group, blue spawn is more likely to be in it
			-- could alternatively pick a random group, but now we can have multiple, overlapping groups, so it's not straightforward to do that
			if	(self.LastBlueSpawn ~= RedSpawn and self.LastRedSpawn ~= BlueSpawn) 
			and umath.random(2) == 1 then
				BlueSpawn, RedSpawn = RedSpawn, BlueSpawn
			end
		end
		
	end

	self.LastRedSpawn = RedSpawn
	self.LastBlueSpawn = BlueSpawn

	self.CurrentInsertionPoints [ self.PlayerTeams.Blue.TeamId ] = BlueSpawn
	self.CurrentInsertionPoints [ self.PlayerTeams.Red.TeamId ]  = RedSpawn
	-- store the actual insertion point actor references
	
	for _, InsertionPoint in ipairs(TargetInsertionPoints) do
		if InsertionPoint == BlueSpawn then
			actor.SetActive(InsertionPoint, true)
			actor.SetTeamId(InsertionPoint, self.PlayerTeams.Blue.TeamId)
		elseif InsertionPoint == RedSpawn then
			actor.SetActive(InsertionPoint, true)
			actor.SetTeamId(InsertionPoint, self.PlayerTeams.Red.TeamId)
		else
			actor.SetActive(InsertionPoint, false)
			actor.SetTeamId(InsertionPoint, 255)
		end
	end
	
	
	
end



function teamelimination:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end


function teamelimination:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end


function teamelimination:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
	end

	-- remove player from DeathList
	local TeamId = actor.GetTeamId( Exiting )
	local DeathList = self.TeamDeathList[ TeamId ]
	if DeathList ~= nil then
		for i = #DeathList, 1, -1 do
			if DeathList[i] == Exiting then
				table.remove( DeathList, i)
			end
		end
	end 
	
	-- remove player from PlayerTriedSpawningList
	for i = #self.PlayerTriedSpawningList, 1, -1 do
		if self.PlayerTriedSpawningList[i]  == Exiting then
			table.remove(self.PlayerTriedSpawningList, i)
			-- remove player info if that player is logging out / quitting
		end
	end
end



return teamelimination