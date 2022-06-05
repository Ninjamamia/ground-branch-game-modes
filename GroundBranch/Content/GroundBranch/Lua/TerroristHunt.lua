local AdminTools = require('AdminTools')

local terroristhunt = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = { "TerroristHunt" },
	
	MissionTypeDescription = "[Solo/Co-Op] Locate and eliminate a predetermined number of enemies in the area of operations.",
	
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
			Min = 3,
			Max = 60,
			Value = 60,
			AdvancedSetting = false,
		},
		ShowRemaining = {
			Min = 0,
			Max = 50,
			Value = 10,
			AdvancedSetting = true,
		},
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
	
	BumRushMode = false,
}


function terroristhunt:DumbTableCopy(MyTable)
	local ReturnTable = {}
	
	for Key, TableEntry in ipairs(MyTable) do
		table.insert(ReturnTable, TableEntry)
	end
	
	return ReturnTable
end


function terroristhunt:PreInit()
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
				print("PreInit(): " .. CurrentGroupTotal .. " total spawns found for priority group " .. CurrentPriorityGroup )
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
	print("PreInit(): " .. CurrentGroupTotal .. " total spawns found for priority group " .. CurrentPriorityGroup )
	self.TotalNumberOfSpawnsFound = TotalSpawns
	
	TotalSpawns = math.min(ai.GetMaxCount(), TotalSpawns)
	self.Settings.OpForCount.Max = TotalSpawns
	self.Settings.OpForCount.Value = math.min(self.Settings.OpForCount.Value, TotalSpawns)

	self.Settings.ShowRemaining.Max = TotalSpawns
	self.Settings.ShowRemaining.Value = math.min(self.Settings.ShowRemaining.Value, TotalSpawns)

end

function terroristhunt:PostInit()
	gamemode.AddGameObjective(self.PlayerTeams.BluFor.TeamId, "EliminateOpFor", 1)
end

function terroristhunt:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false)
	end
end

function terroristhunt:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	end
	
	if ReadyStatus == "WaitingToReadyUp" 
	and gamemode.GetRoundStage() == "PreRoundWait" 
	and gamemode.PrepLatecomer(PlayerState) then
		gamemode.EnterPlayArea(PlayerState)
	end
end

function terroristhunt:CheckReadyUpTimer()
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

function terroristhunt:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
	
		if ReadyPlayerTeamCounts[self.PlayerTeams.BluFor.TeamId] < 1 then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function terroristhunt:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		ai.CleanUp(self.OpForTeamTag)
		self.BumRushMode = false
	elseif RoundStage == "PreRoundWait" then
		self:SpawnOpFor()
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
		-- need to update this as ops board setting may have changed - have to do this before RoundStage InProgress to be effective
	elseif RoundStage == "InProgress" then
		--gamemode.SetRoundStageTime(self.Settings.RoundTime.Value * 60.0)
		--does not work because round stage time is set immediately afterwards based on RoundTime
	end
end

function terroristhunt:SpawnOpFor()
	-- reorganised 8/9 September 2021 by MF to improve randomisation and use of all spawns while still respecting priorities
	-- (it gets quite complicated)

	local OrderedSpawns = {}

	-------------------------
	if "UseOldMethod" == "True" then
		-- just park this here for now - old method, not used
		for Key, Group in ipairs(self.PriorityGroupedSpawns) do
			for i = #Group, 1, -1 do
				local j = umath.random(i)
				Group[i], Group[j] = Group[j], Group[i]
				table.insert(OrderedSpawns, Group[i])
			end
		end
	end
	--------------------
	
	local RejectedSpawns = {}
	local Group 
	local AILeftToSpawn

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
				
				--print("SpawnOpFor(): found " .. CurrentNumberOfSpawns .. " spawns in current priority group " .. CurrentPriorityGroup .. ", vs " .. RemainingSpawnsInLowerPriorities .. " spawns in lower priorities.")
				--print("SpawnOpFor(): using fudged proportion of " .. CurrentProportionOfSpawnsLeft)
				
				-- starting with 70%, so if 10 AI are left to spawn, we will attempt to spawn 7 of them from this group
			end
		else
			CurrentAISpawnTarget = 0
			-- no AI left to spawn so don't bother spawning any - just dump straight into RejectedSpawns{}
		end


		print("SpawnOpFor(): Picking max " .. CurrentAISpawnTarget .. " AI from priority group " .. CurrentPriorityGroup .. " with " .. AILeftToSpawn .. " AI left to spawn out of " .. self.Settings.OpForCount.Value .. " total.")

		-- now transfer the appropriate number of spawns (randomly picked) to the target list (OrderedSpawns)
		-- and dump the remainder in the RejectedSpawns table (to be added to the end of the target list once completed)
		
		Group = self.SpawnPriorityGroups[CurrentPriorityGroup]

		if Group == nil then
			print("SpawnOpFor(): Table entry for priority group " .. CurrentPriorityGroup.. " was unexpectedly nil")
		else
		
			print("SpawnOpFor(): actually found " .. #Group .. " AI in group " .. CurrentPriorityGroup)
		
			if #Group > 0 then
				for i = #Group, 1, -1 do
					local j = umath.random(i)
					Group[i], Group[j] = Group[j], Group[i]

					if CurrentAISpawnTarget > 0 then
						table.insert(OrderedSpawns, Group[i])
						CurrentAISpawnTarget = CurrentAISpawnTarget - 1
					else
						table.insert(RejectedSpawns, Group[i])
					end
				end
				-- ^ shuffle this group to randomise
					
			else
				print("SpawnOpFor(): Priority group " .. CurrentPriorityGroup.. " was unexpectedly empty")
			end
			
		end
	end
	
	-- now add all the rejected spawns onto the list, in case extra spawns are needed
	-- if we ran out of spawns in the above process, this will still provide a sensible selection of spawns
	
	--print("SpawnOpFor(): topping off list of spawns with " .. #RejectedSpawns .. " excess/rejected spawns")
	
	for i = 1, #RejectedSpawns do
		table.insert(OrderedSpawns, RejectedSpawns[i])
	end

	ai.CreateOverDuration(4.0, self.Settings.OpForCount.Value, OrderedSpawns, self.OpForTeamTag)
end

function terroristhunt:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		if CharacterController ~= nil then
			if actor.HasTag(CharacterController, self.OpForTeamTag) then
				timer.Set("CheckOpForCount", self, self.CheckOpForCountTimer, 1.0, false)
			else
				AdminTools:NotifyKIA(CharacterController)
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

function terroristhunt:CheckOpForCountTimer()
	local OpForControllers = ai.GetControllers('GroundBranch.GBAIController', self.OpForTeamTag, 255, 255)

	if #OpForControllers == 0 then
		timer.Clear("ShowRemaining")
		gamemode.AddGameStat("Result=Team1")
		gamemode.AddGameStat("Summary=OpForEliminated")
		gamemode.AddGameStat("CompleteObjectives=EliminateOpFor")
		gamemode.SetRoundStage("PostRoundWait")
	elseif self.Settings.ShowRemaining.Value > 0 and #OpForControllers <= self.Settings.ShowRemaining.Value then
		self.RemainingMessage = "RemainingOpFor" .. tostring(#OpForControllers)
		timer.Set("ShowRemaining", self, self.ShowRemainingTimer, 10, false)
	end
end

function terroristhunt:ShowRemainingTimer()
	gamemode.BroadcastGameMessage(self.RemainingMessage, "Engine", 2.0)
end

function terroristhunt:CheckBluForCountTimer()
	local PlayersWithLives = gamemode.GetPlayerListByLives(self.PlayerTeams.BluFor.TeamId, 1, false)
	if #PlayersWithLives == 0 then
		gamemode.AddGameStat("Result=None")
		gamemode.AddGameStat("Summary=BluForEliminated")
		gamemode.SetRoundStage("PostRoundWait")
	end
end

function terroristhunt:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" then
		return true
	end
	return false
end

function terroristhunt:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function terroristhunt:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" or gamemode.GetRoundStage() == "InProgress" then
		timer.Set("CheckBluForCount", self, self.CheckBluForCountTimer, 1.0, false)
	end
end


return terroristhunt