local lastmanstanding = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = { "Last Man Standing" },
	GameModeAuthor = "(c) BlackFoot Studios, 2021-2022",
	GameModeType = "PVP FFA",
	Settings = {
		RoundTime = {
			Min = 3,
			Max = 60,
			Value = 10,
			AdvancedSetting = false,
		},
        Difficulty = {
        	Min = 0,
        	Max = 4,
        	Value = 2,
            AdvancedSetting = true,
        },
        MinPlayers = {
        	Min = 0,
        	Max = 8,
        	Value = 2,
            AdvancedSetting = true,
        },
        StartingLives = {
        	Min = 0,
        	Max = 10,
        	Value = 1,
            AdvancedSetting = true,
        },
	},
	
	PlayerStarts = {},
	RecentlyUsedPlayerStarts = {},
	MaxRecentlyUsedPlayerStarts = 0,
	TooCloseSq = 1000000,	
	PlayerScoreTypes = {
		WonRound = {
			Score = 10,
			OneOff = true,
			Description = "You won the round!",
		}
	},
	CheckBotInterval = 5.0,
}

function lastmanstanding:PreInit()
	self.PlayerStarts = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPlayerStart')
	self.MaxRecentlyUsedPlayerStarts = #self.PlayerStarts / 2
	gamemode.SetPlayerScoreTypes(self.PlayerScoreTypes)
end

function lastmanstanding:PostInit()
	gamemode.AddGameObjective(255, "BeTheLastManStanding", 1)
end

function lastmanstanding:WasRecentlyUsed(PlayerStart)
	for i = 1, #self.RecentlyUsedPlayerStarts do
		if self.RecentlyUsedPlayerStarts[i] == PlayerStart then
			return true
		end
	end
	return false
end

function lastmanstanding:RateStart(PlayerStart)
	local StartLocation = actor.GetLocation(PlayerStart)
	local PlayersWithLives = gamemode.GetPlayerListByLives(255, 1, false)
	local DistScalar = 5000
	local ClosestDistSq = DistScalar * DistScalar

	for i = 1, #PlayersWithLives do
		local PlayerCharacter = player.GetCharacter(PlayersWithLives[i])

		-- May have lives, but no character, alive or otherwise.
		if PlayerCharacter ~= nil then
			local PlayerLocation = actor.GetLocation(PlayerCharacter)
			local DistSq = vector.SizeSq(StartLocation - PlayerLocation)
			if DistSq < self.TooCloseSq then
				return -10.0
			end
			
			if DistSq < ClosestDistSq then
				ClosestDistSq = DistSq
			end
		end
	end
	
	return math.sqrt(ClosestDistSq) / DistScalar * umath.random(45.0, 55.0)
end

function lastmanstanding:GetSpawnInfo(PlayerState)
	return self:GetBestSpawn()
end

function lastmanstanding:GetBestSpawn()
	local StartsToConsider = {}
	local BestStart = nil
	
	for i, PlayerStart in ipairs(self.PlayerStarts) do
		if not self:WasRecentlyUsed(PlayerStart) then
			table.insert(StartsToConsider, PlayerStart)
		end
	end
	
	local BestScore = 0
	
	for i = 1, #StartsToConsider do
		local Score = self:RateStart(StartsToConsider[i])
		if Score > BestScore then
			BestScore = Score
			BestStart = StartsToConsider[i]
		end
	end
	
	if BestStart == nil then
		BestStart = StartsToConsider[umath.random(#StartsToConsider)]
	end
	
	if BestStart ~= nil then
		table.insert(self.RecentlyUsedPlayerStarts, BestStart)
		if #self.RecentlyUsedPlayerStarts > self.MaxRecentlyUsedPlayerStarts then
			table.remove(self.RecentlyUsedPlayerStarts, 1)
		end
	end
	
	return BestStart
end

function lastmanstanding:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
    print(player.GetName(PlayerState) .. " ready status set to " .. ReadyStatus)
    
	if ReadyStatus == "DeclaredReady" then
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.1, false)
	else
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	end
	
	if ReadyStatus == "WaitingToReadyUp" and gamemode.GetRoundStage() == "PreRoundWait" then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function lastmanstanding:PlayerCanEnterPlayArea(PlayerState)
	if gamemode.GetRoundStage() == "InProgress" then
        print("lastmanstanding:PlayerCanEnterPlayArea(): " .. player.GetName(PlayerState) .. " false") 
		return false
    end
    print("lastmanstanding:PlayerCanEnterPlayArea(): " .. player.GetName(PlayerState) .. " true") 
    return true 
end

function lastmanstanding:PlayerEnteredPlayArea(PlayerState)
    -- Nothing to do here unless we should start with more then a single life.
    if (self.Settings.StartingLives.Value > 1) then
        player.SetLives(PlayerState, self.Settings.StartingLives.Value)
    	print(player.GetName(PlayerState) ..  " lives have been set to " .. player.GetLives(PlayerState))
        player.SetAllowedToRestart(PlayerState, true)
    end
end

function lastmanstanding:OnRoundStageSet(RoundStage)
	print("lastmanstanding:OnRoundStageSet() - new stage " .. RoundStage)
	if RoundStage == "WaitingForReady" then
		timer.ClearAll()
		gamemode.ClearGameStats()
	elseif RoundStage == "PreRoundWait" then
		-- need to update this as ops board setting may have changed - have to do this before RoundStage InProgress to be effective
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
	elseif RoundStage == "PostRoundWait" then
	    -- Round has already ended.
		timer.Clear("EndRoundTimer")

   		-- Freezing bots and disabling player input stop anyone getting higher kills in the post round period.
    	gamemode.FreezeBots(255);

    	local HumanPlayerList = gamemode.GetPlayerList(255, true)
    	
		for _,PlayerState in ipairs(HumanPlayerList) do
		    player.AddIgnoreUseInputReason(PlayerState, 'PostRound')
		end
	end
end

function lastmanstanding:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
	    if CharacterController ~= nil then
	        local PlayerState = player.GetPlayerState(CharacterController)
		    local PlayerLives = player.GetLives(PlayerState)
		    PlayerLives = PlayerLives - 1
		    player.SetLives(PlayerState, PlayerLives)

        	print(player.GetName(PlayerState) ..  " died - lives remaining " .. player.GetLives(PlayerState))
			
            if PlayerLives > 0 then
                print(player.GetName(PlayerState) .. " can still respawn")
                player.SetAllowedToRestart(PlayerState, true)
            else
                print(player.GetName(PlayerState) .. " can no longer respawn")
                player.SetAllowedToRestart(PlayerState, false)
	    	end
	    	
            timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
    	end
    end	
end

function lastmanstanding:OnRoundStageTimeElapsed(RoundStage)
	if RoundStage == "InProgress" then
		gamemode.AddGameStat("Result=Team" .. 0)
		gamemode.AddGameStat("Summary=ReachedTimeLimit")

    	local PlayersWithLives = gamemode.GetPlayerListByLives(255, 1, false)
    	
    	if #PlayersWithLives == 1 then
   			gamemode.AddGameStat("CompleteObjectives=BeTheLastManStanding")
		    -- Last living gets points
    		player.AwardPlayerScore(PlayersWithLives[0], "WonRound", 1)
        else
       		gamemode.AddGameStat("Summary=NoWinner")
    	end		

		gamemode.SetRoundStage("PostRoundWait")
		
		return true
	end
end

function lastmanstanding:LogOut(Exiting)
	local RoundStage = gamemode.GetRoundStage()
	if RoundStage == "PreRoundWait" or RoundStage == "InProgress" then
		timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
    else
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	end
end

function lastmanstanding:PlayerBecomesSpectator(Player)
	local RoundStage = gamemode.GetRoundStage()
	if RoundStage == 'InProgress' or RoundStage == 'PreRoundWait' then
		timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
    else
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	end
end

function lastmanstanding:CheckReadyUpTimer()
    print("lastmanstanding:CheckReadyUpTimer() : RoundStage: " .. gamemode.GetRoundStage())

	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local PlayersReady = ReadyPlayerTeamCounts[0]

        print("PlayersReady: " .. PlayersReady)

		local MinReady = 2
		
		-- Lone human player will do when standalone.
		if gameplaystatics.GetNetMode() == "Standalone" then
		    MinReady = 1
		end  
		
		if (PlayersReady >= MinReady) then
			if PlayersReady >= gamemode.GetPlayerCount(true) then
				gamemode.SetRoundStage("PreRoundWait")
			else
				gamemode.SetRoundStage("ReadyCountdown")
			end
		end
	end
end

function lastmanstanding:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local MinReady = 2
		
		-- Lone human player will do when standalone.
		if gameplaystatics.GetNetMode() == "Standalone" then
		    MinReady = 1
		end  

		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local PlayersReady = ReadyPlayerTeamCounts[0]
		if PlayersReady < MinReady then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function lastmanstanding:CheckEndRoundTimer()
    local PlayersWithLives = gamemode.GetPlayerListByLives(255, 1, false)
    if #PlayersWithLives <= 1 then
        gamemode.SetRoundStage("PostRoundWait")
    end
end

return lastmanstanding