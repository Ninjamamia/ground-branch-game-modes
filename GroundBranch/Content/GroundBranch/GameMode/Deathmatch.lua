local deathmatch = {
	UseReadyRoom = true,
	UseRounds = true,
	
	-- Limit dead bodies and dropped items. Not sure we use this any more?
	MaxDeadBodies = 1,
	MaxDroppedItems = 1,
	
	-- override other values
	
	StringTables = { "Deathmatch" },
	
	GameModeAuthor = "(c) BlackFoot Studios, 2021-2022",
	GameModeType = "PVP FFA",
	-- PVP FFA (Free-for-all) is a new category as of 1033 - player vs player not team vs team

	Settings = {
		RoundTime = {
			Min = 3,
			Max = 60,
			Value = 60,
			AdvancedSetting = false,
		},
		-- number of minutes in each round
		
		FragLimit = {
			Min = 0,
			Max = 7,
			Value = 3,
			AdvancedSetting = false,
		},
		-- number of frags to win (0 = no limit, just time based)
		-- 0 = no limit
		-- 1 = 3
		-- 2 = 5
		-- 3 = 10
		-- 4 = 20
		-- 5 = 30
		-- 6 = 50
		-- 7 = 100
		
        -- fill in with AI if less than this value
		MinPlayers = {
			Min = 1,
			Max = 8,
			Value = 4,
			AdvancedSetting = true,
		},
        Difficulty = {
        	Min = 0,
        	Max = 4,
        	Value = 2,
            AdvancedSetting = true,
        },
		BotsCanScore = {
        	Min = 0,
        	Max = 1,
        	Value = 1,
            AdvancedSetting = true,
        },
	},
	
	FragLimitValues = { 0, 3, 5, 10, 20, 30, 50, 100, },
	-- nicer to have a drop-down menu than to have to fiddle with spinbox for this
	
	PlayerStarts = {},
	RecentlyUsedPlayerStarts = {},
	MaxRecentlyUsedPlayerStarts = 0,
	TooCloseSq = 1000000,	
	
	-- player score types includes score types for both attacking and defending players
	PlayerScoreTypes = {
		WonRound = {
			Score = 10,
			OneOff = true,
			Description = "You won the round!",
		},
		Kills = {
			Score = 1,
			OneOff = false,
			Description = "Kills",
		},
	},
	
	NextSpawnIndex = 1,
	FragDisplayUpdateInterval = 2.0,
	
	CheckPlayerKillCountQueue = {},
}

function deathmatch:PreInit()
	self.PlayerStarts = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBPlayerStart')
	
	self.MaxRecentlyUsedPlayerStarts = #self.PlayerStarts / 2
	
	gamemode.SetPlayerScoreTypes( self.PlayerScoreTypes )
	-- just in case needed for AI
end

function deathmatch:PostInit()
	gamemode.AddGameObjective(0, "KillEveryone", 1)
end

function deathmatch:WasRecentlyUsed(PlayerStart)
	for i = 1, #self.RecentlyUsedPlayerStarts do
		if self.RecentlyUsedPlayerStarts[i] == PlayerStart then
			return true
		end
	end
	return false
end

function deathmatch:RateStart(PlayerStart)
	local StartLocation = actor.GetLocation(PlayerStart)
	local PlayersWithLives = gamemode.GetPlayerListByLives(255, 1, true)
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

function deathmatch:GetSpawnInfo(PlayerState)
	return self:GetBestSpawn()
end

function deathmatch:GetBestSpawn()
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

function deathmatch:PlayerCanEnterPlayArea(PlayerState)
    return true 
end

function deathmatch:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
    -- Sent when a player clicks on the ops board, or a bot declares ready at start of round.
	if ReadyStatus == "DeclaredReady" then
		print("Player " .. player.GetName(PlayerState) .. " declared ready")
		gamemode.EnterPlayArea(PlayerState)

		if not player.IsABot(PlayerState) then
			timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.1, false)
		end
	end
end

function deathmatch:PlayerEnteredPlayArea(PlayerState)
    -- Can always restart in Deathmatch. 
	player.SetAllowedToRestart(PlayerState, true)
end

function deathmatch:OnRoundStageSet(RoundStage)
	print(RoundStage)

	if RoundStage == "WaitingForReady" then
		timer.ClearAll()
		CheckPlayerKillCountQueue = {}
		gamemode.ClearGameStats()
		
		gamemode.BroadcastGameMessage(" ", "Engine", -0.5)
		-- clear the engine text (summary of frag leader)
		
		-- freeze bots.
    	gamemode.FreezeBots(255);
	
	elseif RoundStage == "PreRoundWait" then
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
		-- need to update this as ops board setting may have changed - have to do this before RoundStage InProgress to be effective
	elseif RoundStage == "InProgress" then
		-- unfreeze bots.
    	gamemode.UnFreezeBots(255);
	
		timer.Set("DisplayFrags", self, self.DisplayFragsTimer, self.FragDisplayUpdateInterval, true);
		-- repeating timer which is cleared when entering WaitingForReady phase
			
		self:DisplayFragsTimer()
		-- call now as well
	
	elseif RoundStage == "PostRoundWait" then
		timer.Clear("DisplayFrags")
		timer.Clear("EndRoundTimer")
		CheckPlayerKillCountQueue = {}

		-- freeze bots.
    	gamemode.FreezeBots(255);

		-- stop people getting higher kills in the post round period
    	local HumanPlayerList = gamemode.GetPlayerList(255, true)
		for _,PlayerState in ipairs(HumanPlayerList) do
		    player.AddIgnoreUseInputReason(PlayerState, 'PostRound')
		end	
	end
end

function deathmatch:OnCharacterDied(Character, CharacterController, KillerController)
	if CharacterController ~= nil and KillerController ~= nil then
		local KillerPlayerState = player.GetPlayerState(KillerController)
		local KillerName = player.GetName(KillerPlayerState)

		local KilledPlayerState = player.GetPlayerState(CharacterController)
		local KilledName = player.GetName(KilledPlayerState)
		
		local FormatTable = {}
		FormatTable.FormatString = "XKilledY"
		FormatTable.killername = KillerName
		FormatTable.killedname = KilledName
		local KilledText = gamemode.FormatString(FormatTable)
		
		gamemode.BroadcastGameMessage(KilledText, "Lower", 3.0)
		
		if KillerPlayerState ~= nil then
			-- no points for killing yourself
			local KillerIsABot = player.IsABot(KillerPlayerState)
			if CharacterController ~= KillerController and (not KillerIsABot or self.Settings.BotsCanScore.Value == 1) then
                player.AwardPlayerScore( KillerPlayerState, "Kills", 1 )		
    
                if self.Settings.FragLimit.Value ~= 0 then
                    table.insert(self.CheckPlayerKillCountQueue, KillerPlayerState)
                    timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);			
                end
			end
		end
	end
end

function deathmatch:LogOut(Exiting)
	--timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
end

function deathmatch:PlayerBecomesSpectator(Player)
	--timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
end

function deathmatch:CheckReadyUpTimer()
	-- simplified 2022/12/20 by MF and only called if a human has spawned in (not bot)
	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		gamemode.SetRoundStage("PreRoundWait")
	end
end

function deathmatch:CheckEndRoundTimer()
	-- because reasons, this doesn't always work, so we also check when updating frag count display

	if #self.CheckPlayerKillCountQueue > 0 then
		KillerPlayerState = self.CheckPlayerKillCountQueue[1]
		table.remove(self.CheckPlayerKillCountQueue, 1)
		
		local NumberKills = player.GetPlayerStat(KillerPlayerState, "Kills")
		if NumberKills ~= nil then
			local ActualFragLimit = self.FragLimitValues[ (self.Settings.FragLimit.Value)+1 ]
								
			if NumberKills >= ActualFragLimit then
				timer.Clear("DisplayFrags")
				self:DisplayFragsTimer()
				-- update with final kill score
			
				local WinningPlayerStates = {}
				table.insert(WinningPlayerStates, KillerPlayerState)
				--gamemode.AddGameStat("CompleteObjectives=KillEveryone")
				self:AwardWinToPlayerAndEndGame(WinningPlayerStates, "ReachedFragLimit")
			end
		end
	end
end

function deathmatch:AwardWinToPlayerAndEndGame(WinningPlayerStates, SummaryGameStat)
	-- WinningPlayerStates is a table/array of winning player states - which *should* be 1 entry long, but y'know...
	gamemode.AddGameStat("Result=Team" .. 0)
	gamemode.AddGameStat("Summary=" .. SummaryGameStat)
	gamemode.SetRoundStage("PostRoundWait")
	
	for _, WinningPlayerState in ipairs(WinningPlayerStates) do
		player.AwardPlayerScore( WinningPlayerState, "WonRound", 1 )
	end
end

function deathmatch:OnRoundStageTimeElapsed(RoundStage)
	if RoundStage == "InProgress" then
		gamemode.AddGameStat("Result=Team" .. 0)
		gamemode.AddGameStat("Summary=ReachedTimeLimit")
		
		local BestFraggers

		gamemode.AddGameStat("CompleteObjectives=KillEveryone")
		BestFraggers = self:GetBestFraggers()

		-- then award won round score (because there may be joint winners [edge case])
		for _, PlayerState in ipairs(BestFraggers) do
			player.AwardPlayerScore( PlayerState, "WonRound", 1 )
		end
		
		gamemode.SetRoundStage("PostRoundWait")
		
		return true
	end
end

function deathmatch:GetBestFraggers()
	local BestKills = -1
	local NumberKills
	local BestFraggers = {}
	local Players

	if self.Settings.BotsCanScore.Value==1 then
		Players = gamemode.GetPlayerList(255, false)
	else
		-- exclude bots
		Players = gamemode.GetPlayerList(255, true)
	end
	
	-- first find best score
	for _, PlayerState in ipairs(Players) do
		NumberKills = player.GetPlayerStat(PlayerState, "Kills")
		if NumberKills > BestKills then
			BestKills = NumberKills
		end
	end

	-- then compile list of best
	for _, PlayerState in ipairs(Players) do
		NumberKills = player.GetPlayerStat(PlayerState, "Kills")
		if NumberKills == BestKills then
			table.insert(BestFraggers, PlayerState)
		end
	end
	
	return BestFraggers, BestKills
end

function deathmatch:DisplayFragsTimer()
	local BestFraggers
	local BestKills

	BestFraggers, BestKills = self:GetBestFraggers()
	
	local NumFragsText = ""
	
	if self.Settings.FragLimit.Value > 0 then
		local FragLimit = self.FragLimitValues[ (self.Settings.FragLimit.Value)+1 ]
		NumFragsText = "/" .. FragLimit
		if BestKills >= FragLimit then
			-- this shouldn't happen but it does (replication delays?), in which case do the end round check
			timer.Clear("DisplayFrags")
			gamemode.AddGameStat("CompleteObjectives=KillEveryone")
			self:AwardWinToPlayerAndEndGame(BestFraggers, "ReachedFragLimit")
		end
	end
		
	local HumanPlayers = gamemode.GetPlayerList(255, true)

	local FormatTable = {}
	FormatTable.NumFragsText = NumFragsText
	FormatTable.BestKills = BestKills
			
	for _,PlayerState in ipairs(HumanPlayers) do
				
		if #BestFraggers > 1 then
			FormatTable.FormatString = "DMJointFirstPosition"
			local NumberKills = player.GetPlayerStat(PlayerState, "Kills")				

			if NumberKills == BestKills then
				FormatTable.PlayerName = string.upper(player.GetName(PlayerState))
			else
				local RandomBestPlayerName = player.GetName(BestFraggers[math.random(#BestFraggers)])
				FormatTable.PlayerName = string.upper(RandomBestPlayerName)
			end
		else
			FormatTable.FormatString = "DMFirstPosition"
			FormatTable.PlayerName = string.upper(player.GetName(BestFraggers[1]))
		end

		player.ShowGameMessage( PlayerState, gamemode.FormatString(FormatTable), "Engine", -self.FragDisplayUpdateInterval)
		-- negative display duration = flush all messages first and then display for (absolute) this amount of time - avoids fading issue
		-- we now use a format string to construct the leaderboard text, to allow full localisation of the game mode
	end
end

return deathmatch