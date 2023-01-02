local uplink = {
	UseReadyRoom = true,
	UseRounds = true,
	StringTables = { "Uplink" },
	
	GameModeAuthor = "(c) BlackFoot Studios, 2021-2022",
	GameModeType = "PVP",
	
	-- Player teams
	
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
	
	-- Mission settings
	
	Settings = {
		RoundTime = {
			Min = 3,
			Max = 30,
			Value = 10,
			AdvancedSetting = false,
		},
		DefenderSetupTime = {
			Min = 10,
			Max = 120,
			Value = 30,
			AdvancedSetting = true,
		},
		CaptureTime = {
			Min = 1,
			Max = 60,
			Value = 10,
			AdvancedSetting = true,
		},
		AutoSwap = {
			Min = 0,
			Max = 1,
			Value = 1,
			AdvancedSetting = false,
		},
	},
	
	-- Custom 'global' variables
	
	DefenderInsertionPoints = {},
	DefenderInsertionPointNames = {},
	-- a bit redundant but used for shuffling locations

	RandomDefenderInsertionPoint = nil,
	AttackerInsertionPoints = {},
	GroupedLaptops = {},
	DefendingTeam = {},
	AttackingTeam = {},
	RandomLaptop = nil,
	SpawnProtectionVolumes = {},
	ShowAutoSwapMessage = false,
	
	--LaptopObjectiveMarkerName = "OBJ?",
	LaptopObjectiveMarkerName = "",
	
	DefenderInsertionPointModifiers = {},
	NumberOfSearchLocations = 2,
	MissionLocationMarkers = {},
	LaptopLocationNameList = {},
	AllInsertionPointNames = {},
	
	CompletedARound = true,
	
	DebugMode = false,
	-- allows attackers to see laptop location at start of round and move immediately
}

function uplink:PreInit()
	self.SpawnProtectionVolumes = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBSpawnProtectionVolume')
	
	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
	--local DefenderInsertionPointNames = {}

	for i, InsertionPoint in ipairs(AllInsertionPoints) do
		if actor.HasTag(InsertionPoint, "Defenders") then
			local InsertionPointName = gamemode.GetInsertionPointName(InsertionPoint)
			table.insert(self.DefenderInsertionPoints, InsertionPoint)
			table.insert(self.DefenderInsertionPointNames, InsertionPointName)
			
			self.DefenderInsertionPointModifiers[ InsertionPointName ] = self:GetModifierTextForObjective( InsertionPoint )
			-- store modifiers associated with defender insertion points for use down below in relation to objectivemarkers
			
		elseif actor.HasTag(InsertionPoint, "Attackers") then
			table.insert(self.AttackerInsertionPoints, InsertionPoint)
		end
	end
	
	local AllLaptops = gameplaystatics.GetAllActorsOfClass('/Game/GroundBranch/Props/Electronics/MilitaryLaptop/BP_Laptop_Usable.BP_Laptop_Usable_C')
		
	for i, DefenderInsertionPointName in ipairs(self.DefenderInsertionPointNames) do
		self.GroupedLaptops[DefenderInsertionPointName] = {}
		for j, Laptop in ipairs(AllLaptops) do
			if actor.HasTag(Laptop, DefenderInsertionPointName) then
				table.insert(self.GroupedLaptops[DefenderInsertionPointName], Laptop)
			end
		end
	end	
	
	
	------------------------------------------
	-- now add laptop markers to opsboard
	-- (added by MF 2021/9/22)
	

	-- laptops are grouped (mandatory)
	-- rather than rely on more complex mission setup, just calculate geographical average location of all bombs in the group
	-- and use that to position the intel marker
	-- use modifier tags e.g. AddUpArrow on the associated defender insertion point to set modifiers on the laptop objective markers

	for InsertionPointName, LaptopList in pairs(self.GroupedLaptops) do
	-- InsertionPointName is the key/index in the table (crazy lua huh)
	-- the table of laptops associated with that insertion point is the value/data

		local IntelMarkerLocation = {}
		local AverageLocation = {}

		if #LaptopList > 0 then

			AverageLocation.x = 0
			AverageLocation.y = 0
			AverageLocation.z = 0
			
			for j = 1, #LaptopList do
				local LaptopLocation = actor.GetLocation ( LaptopList[j] )

				AverageLocation.x = AverageLocation.x + LaptopLocation.x
				AverageLocation.y = AverageLocation.y + LaptopLocation.y
				AverageLocation.z = AverageLocation.z + LaptopLocation.z
			end
			
			IntelMarkerLocation.x = AverageLocation.x / #LaptopList
			IntelMarkerLocation.y = AverageLocation.y / #LaptopList
			IntelMarkerLocation.z = AverageLocation.z / #LaptopList
			
			-- now add the marker

			local Prefix = self.DefenderInsertionPointModifiers[ InsertionPointName ]

			self.MissionLocationMarkers[ InsertionPointName ] = {}
			self.MissionLocationMarkers[ InsertionPointName ][self.PlayerTeams.Red.TeamId] = gamemode.AddObjectiveMarker(IntelMarkerLocation, self.PlayerTeams.Red.TeamId, Prefix .. self.LaptopObjectiveMarkerName, "MissionLocation", true)
			self.MissionLocationMarkers[ InsertionPointName ][self.PlayerTeams.Blue.TeamId] = gamemode.AddObjectiveMarker(IntelMarkerLocation, self.PlayerTeams.Blue.TeamId, Prefix .. self.LaptopObjectiveMarkerName, "MissionLocation", true)

			-- add markers for both teams (TeamId = 255 doesn't work)

		else
			-- shouldn't happen but hey
			print("Uplink: shouldn't get here, laptop list was empty. No marker added.")
		end
	end

	
	---------------------------
	
end

function uplink:PostInit()
	-- Set initial defending & attacking teams.
	self.DefendingTeam = self.PlayerTeams.Red
	self.AttackingTeam = self.PlayerTeams.Blue
	
	gamemode.SetPlayerTeamRole(self.DefendingTeam.TeamId, "Defending")
	gamemode.SetPlayerTeamRole(self.AttackingTeam.TeamId, "Attacking")
end

function uplink:PlayerInsertionPointChanged(PlayerState, InsertionPoint)
	if InsertionPoint == nil then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false);
	else
		timer.Set("CheckReadyUp", self, self.CheckReadyUpTimer, 0.25, false);
	end
end

function uplink:PlayerReadyStatusChanged(PlayerState, ReadyStatus)
	if ReadyStatus ~= "DeclaredReady" then
		timer.Set("CheckReadyDown", self, self.CheckReadyDownTimer, 0.1, false)
	end
	
	if ReadyStatus == "WaitingToReadyUp" and gamemode.GetRoundStage() == "PreRoundWait" then
		if actor.GetTeamId(PlayerState) == self.DefendingTeam.TeamId then
			if self.RandomDefenderInsertionPoint ~= nil then
				player.SetInsertionPoint(PlayerState, self.RandomDefenderInsertionPoint)
				gamemode.EnterPlayArea(PlayerState)
			end
		elseif gamemode.PrepLatecomer(PlayerState) then
			gamemode.EnterPlayArea(PlayerState)
		end
	end
end

function uplink:CheckReadyUpTimer()
	if gamemode.GetRoundStage() == "WaitingForReady" or gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local DefendersReady = ReadyPlayerTeamCounts[self.DefendingTeam.TeamId]
		local AttackersReady = ReadyPlayerTeamCounts[self.AttackingTeam.TeamId]
		if DefendersReady > 0 and AttackersReady > 0 or
		(self.DebugMode and (DefendersReady > 0 or AttackersReady > 0)) then
			if DefendersReady + AttackersReady >= gamemode.GetPlayerCount(true) then
				gamemode.SetRoundStage("PreRoundWait")
			else
				gamemode.SetRoundStage("ReadyCountdown")
			end
		end
	end
end

function uplink:CheckReadyDownTimer()
	if gamemode.GetRoundStage() == "ReadyCountdown" then
		local ReadyPlayerTeamCounts = gamemode.GetReadyPlayerTeamCounts(true)
		local DefendersReady = ReadyPlayerTeamCounts[self.DefendingTeam.TeamId]
		local AttackersReady = ReadyPlayerTeamCounts[self.AttackingTeam.TeamId]
		if (not self.DebugMode and (DefendersReady < 1 or AttackersReady < 1)) or
		(self.DebugMode and (Defenders < 1 and Attackers < 1 )) then
			gamemode.SetRoundStage("WaitingForReady")
		end
	end
end

function uplink:OnRoundStageSet(RoundStage)
	if RoundStage == "WaitingForReady" then
		if self.CompletedARound then
			self:SetupRound()
		end
		self.CompletedARound = false
	elseif RoundStage == "PreRoundWait" then
		gamemode.SetDefaultRoundStageTime("InProgress", self.Settings.RoundTime.Value)
		-- need to update this as ops board setting may have changed - have to do this before RoundStage InProgress to be effective
	elseif RoundStage == "BlueDefenderSetup" or RoundStage == "RedDefenderSetup" then
		gamemode.SetRoundStageTime(self.Settings.DefenderSetupTime.Value)
	elseif RoundStage == "InProgress" then
		timer.Set("DisableSpawnProtection", self, self.DisableSpawnProtectionTimer, 5.0, false);
	elseif RoundStage == "PostRoundWait" then
		if self.Settings.AutoSwap.Value ~= 0 then
			self:SwapTeams()
		end
		self.CompletedARound = true
	end
end

function uplink:OnCharacterDied(Character, CharacterController, KillerController)
	if gamemode.GetRoundStage() == "PreRoundWait" 
	or gamemode.GetRoundStage() == "InProgress"
	or gamemode.GetRoundStage() == "BlueDefenderSetup"
	or gamemode.GetRoundStage() == "RedDefenderSetup" then
		if CharacterController ~= nil then
			player.SetLives(CharacterController, player.GetLives(CharacterController) - 1)
			
			local PlayersWithLives = gamemode.GetPlayerListByLives(255, 1, false)
			if #PlayersWithLives == 0 then
				self:CheckEndRoundTimer()
			else
				timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
			end
		end
	end
end

function uplink:CheckEndRoundTimer()
	local AttackersWithLives = gamemode.GetPlayerListByLives(self.AttackingTeam.TeamId, 1, false)
	local DefendersWithLives = gamemode.GetPlayerListByLives(self.DefendingTeam.TeamId, 1, false)
	
	if #AttackersWithLives == 0 then
		if #DefendersWithLives > 0 then
			gamemode.AddGameStat("Result=Team" .. tostring(self.DefendingTeam.TeamId))
			gamemode.AddGameStat("Summary=AttackersEliminated")
			gamemode.AddGameStat("CompleteObjectives=DefendObjective")
			gamemode.AddGameStat("CompleteObjectives=EliminateAttackers")
			gamemode.SetRoundStage("PostRoundWait")
		else
			gamemode.AddGameStat("Result=None")
			gamemode.AddGameStat("Summary=BothEliminated")
			gamemode.SetRoundStage("PostRoundWait")
		end
	elseif #DefendersWithLives == 0 then
		-- zero defenders left but some attackers are left
		-- so (as of 1033) this is now a straight attacker win, no need to hack laptop
		gamemode.AddGameStat("Result=Team" .. tostring(self.AttackingTeam.TeamId))
		gamemode.AddGameStat("Summary=DefendersEliminated")
		-- capturing the objective is implicit in wiping out defenders
		gamemode.AddGameStat("CompleteObjectives=CaptureObjective")
		gamemode.AddGameStat("CompleteObjectives=EliminateDefenders")
	end
end

function uplink:SetupRound()
	if #self.AttackerInsertionPoints == nil then
		self:ReportError("Could not find any attacker insertion points")
		return
	end
	if #self.DefenderInsertionPoints == nil then
		self:ReportError("Could not find any defender insertion points")
		return
	end


	if self.ShowAutoSwapMessage == true then
		self.ShowAutoSwapMessage = false
		
		local Attackers = gamemode.GetPlayerList(self.AttackingTeam.TeamId, false)
		for i = 1, #Attackers do
			player.ShowGameMessage(Attackers[i], "SwapAttacking", "Center", 10.0)
		end
		
		local Defenders = gamemode.GetPlayerList(self.DefendingTeam.TeamId, false)
		for i = 1, #Defenders do
			player.ShowGameMessage(Defenders[i], "SwapDefending", "Center", 10.0)
		end
	end

	for i, SpawnProtectionVolume in ipairs(self.SpawnProtectionVolumes) do
		actor.SetTeamId(SpawnProtectionVolume, self.AttackingTeam.TeamId)
		actor.SetActive(SpawnProtectionVolume, true)
	end

	gamemode.ClearGameObjectives()
	gamemode.ClearSearchLocations()

	gamemode.AddGameObjective(self.DefendingTeam.TeamId, "DefendObjective", 1)
	gamemode.AddGameObjective(self.AttackingTeam.TeamId, "CaptureObjective", 1)
	gamemode.AddGameObjective(self.DefendingTeam.TeamId, "EliminateDefenders", 2)
	gamemode.AddGameObjective(self.AttackingTeam.TeamId, "EliminateAttackers", 2)

	for i, InsertionPoint in ipairs(self.AttackerInsertionPoints) do
		actor.SetActive(InsertionPoint, true)
		actor.SetTeamId(InsertionPoint, self.AttackingTeam.TeamId)
	end

	if #self.DefenderInsertionPoints > 1 then
		local NewRandomDefenderInsertionPoint = self.RandomDefenderInsertionPoint

		while (NewRandomDefenderInsertionPoint == self.RandomDefenderInsertionPoint) do
			NewRandomDefenderInsertionPoint = self.DefenderInsertionPoints[umath.random(#self.DefenderInsertionPoints)]
		end
		
		self.RandomDefenderInsertionPoint = NewRandomDefenderInsertionPoint
	else
		self.RandomDefenderInsertionPoint = self.DefenderInsertionPoints[1]
	end
	
	for i, InsertionPoint in ipairs(self.DefenderInsertionPoints) do
		if InsertionPoint == self.RandomDefenderInsertionPoint then
			actor.SetActive(InsertionPoint, true)
			actor.SetTeamId(InsertionPoint, self.DefendingTeam.TeamId)
		else
			actor.SetActive(InsertionPoint, false)
			actor.SetTeamId(InsertionPoint, 255)
		end
	end

	local RealInsertionPointName = gamemode.GetInsertionPointName(self.RandomDefenderInsertionPoint)
	if RealInsertionPointName == nil then
		self:ReportError("Insertion point name was unexpectedly nil")
		return
	end

	local PossibleLaptops = self.GroupedLaptops[RealInsertionPointName]
	if #PossibleLaptops == 0 then
		self:ReportError("List of laptops for insertion point name " .. RealInsertionPointName .. " was unexpectedly nil")
		return
	end

	self.RandomLaptop = PossibleLaptops[umath.random(#PossibleLaptops)]

	for Group, Laptops in pairs(self.GroupedLaptops) do
		for j, Laptop in ipairs(Laptops) do
			local bActive = (Laptop == self.RandomLaptop)
			actor.SetActive(Laptop, bActive)
		end
	end

	-- now set up the objective markers

	for i = 1, #self.DefenderInsertionPoints do
		if actor.HasTag( self.RandomLaptop, self.DefenderInsertionPointNames[i] ) then
		-- this is the selected insertion point
			self.DefenderInsertionPointNames[i], self.DefenderInsertionPointNames[1] = self.DefenderInsertionPointNames[1], self.DefenderInsertionPointNames[i]
			-- swap 1st entry with current entry (which may be first entry)
			break
		end
	end

	if #self.DefenderInsertionPointNames > 1 then
		-- we now have the selected insertion point name as entry 1 in self.DefenderInsertionPointNames{}
		-- so we can pick a random one from the rest
		local FakeInsertionPointName = self.DefenderInsertionPointNames[1 + umath.random(#self.DefenderInsertionPointNames - 1)]
	
		print ("RealName = " .. RealInsertionPointName .. ", FakeName = " .. FakeInsertionPointName)
		
		if umath.random(2) == 1 then
			gamemode.AddSearchLocation(self.AttackingTeam.TeamId, RealInsertionPointName, 1)
			gamemode.AddSearchLocation(self.AttackingTeam.TeamId, FakeInsertionPointName, 1)
			-- type is 1 (primary), though that's not used (yet)
		else
			gamemode.AddSearchLocation(self.AttackingTeam.TeamId, FakeInsertionPointName, 1)
			gamemode.AddSearchLocation(self.AttackingTeam.TeamId, RealInsertionPointName, 1)
			-- type is 1 (primary), though that's not used (yet)
		end
	
		for _, InsertionPoint in ipairs(self.DefenderInsertionPoints) do
			local CurrentInsertionPointName = gamemode.GetInsertionPointName(InsertionPoint)
			local bActive = false
			
			if CurrentInsertionPointName == FakeInsertionPointName
			or CurrentInsertionPointName == RealInsertionPointName then
				bActive = true
			end

			local BothTeamMarkers = self.MissionLocationMarkers[ CurrentInsertionPointName ]

			if BothTeamMarkers ~= nil then
				actor.SetActive( BothTeamMarkers[ self.AttackingTeam.TeamId ], bActive )
				actor.SetActive( BothTeamMarkers[ self.DefendingTeam.TeamId ], false ) 
			else
				self:ReportError("No location marker info found in connection with insertion point " .. CurrentInsertionPointName)
			end
		end
		
	else
		-- only one defender location so just display it
		gamemode.AddSearchLocation(self.AttackingTeam.TeamId, "The whole area", 1)

		local BothTeamMarkers = self.MissionLocationMarkers[ self.DefenderInsertionPointNames[1] ]
		
		if BothTeamMarkers ~= nil then
			actor.SetActive( BothTeamMarkers[ self.AttackingTeam.TeamId ], true )
			actor.SetActive( BothTeamMarkers[ self.DefendingTeam.TeamId ], false ) 
		else
			self:ReportError("No location marker info found in connection with insertion point " .. CurrentInsertionPointName)
		end
	end
	
end


function uplink:GetInsertionPointNameForLaptop(Laptop)
	local AllInsertionPoints = gameplaystatics.GetAllActorsOfClass('GroundBranch.GBInsertionPoint')
	local InsertionPointName

	for i, InsertionPoint in ipairs(AllInsertionPoints) do
		if actor.HasTag(InsertionPoint, "Defenders") then
			InsertionPointName = gamemode.GetInsertionPointName(InsertionPoint)
			if actor.HasTag(Laptop, InsertionPointName) then
				return InsertionPointName
			end
		end
	end
	
	print("uplink: selected laptop did not have a tag corresponding to a defender insertion point, so no intel can be provided.")
	
	return nil
end





function uplink:ReportError(ErrorMessage)
	gamemode.BroadcastGameMessage("Error! " .. ErrorMessage, "Upper", 5.0)
	print("-- Uplink game mode error!: " .. ErrorMessage)
end

function uplink:SwapTeams()
	if self.DefendingTeam == self.PlayerTeams.Blue then
		self.DefendingTeam = self.PlayerTeams.Red
		self.AttackingTeam = self.PlayerTeams.Blue
	else
		self.DefendingTeam = self.PlayerTeams.Blue
		self.AttackingTeam = self.PlayerTeams.Red
	end
	
	gamemode.SetPlayerTeamRole(self.DefendingTeam.TeamId, "Defending")
	gamemode.SetPlayerTeamRole(self.AttackingTeam.TeamId, "Attacking")
	
	self.ShowAutoSwapMessage = true
end

function uplink:ShouldCheckForTeamKills()
	if gamemode.GetRoundStage() == "InProgress" 
	or gamemode.GetRoundStage() == "BlueDefenderSetup"
	or gamemode.GetRoundStage() == "RedDefenderSetup" then
		return true
	end
	return false
end

function uplink:PlayerCanEnterPlayArea(PlayerState)
	if player.GetInsertionPoint(PlayerState) ~= nil then
		return true
	end
	return false
end

function uplink:OnRoundStageTimeElapsed(RoundStage)
	if RoundStage == "PreRoundWait" then
		if self.DefendingTeam == self.PlayerTeams.Blue then
			gamemode.SetRoundStage("BlueDefenderSetup")
		else
			gamemode.SetRoundStage("RedDefenderSetup")
		end
		return true
	elseif RoundStage == "BlueDefenderSetup"
		or RoundStage == "RedDefenderSetup" then
		gamemode.SetRoundStage("InProgress")
		return true
	elseif RoundStage == "InProgress" then
		-- round timeout, so defenders win (new in 1033)
		gamemode.AddGameStat("Result=Team" .. tostring(self.DefendingTeam.TeamId))
		gamemode.AddGameStat("Summary=DefendObjective")
		gamemode.AddGameStat("CompleteObjectives=DefendObjective")
		gamemode.SetRoundStage("PostRoundWait")
	end
	return false
end

function uplink:TargetCaptured()
	gamemode.AddGameStat("Summary=CaptureObjective")
	gamemode.AddGameStat("CompleteObjectives=CaptureObjective")
	gamemode.AddGameStat("Result=Team" .. tostring(self.AttackingTeam.TeamId))
	gamemode.SetRoundStage("PostRoundWait")
end

function uplink:PlayerEnteredPlayArea(PlayerState)
	if actor.GetTeamId(PlayerState) == self.AttackingTeam.TeamId and not self.DebugMode then
		local FreezeTime = self.Settings.DefenderSetupTime.Value + gamemode.GetRoundStageTime()
		player.FreezePlayer(PlayerState, FreezeTime)
	elseif actor.GetTeamId(PlayerState) == self.DefendingTeam.TeamId or self.DebugMode then
		local LaptopLocation = actor.GetLocation(self.RandomLaptop)
		player.ShowWorldPrompt(PlayerState, LaptopLocation, "DefendTarget", self.Settings.DefenderSetupTime.Value - 2)
	end
end

function uplink:DisableSpawnProtectionTimer()
	if gamemode.GetRoundStage() == "InProgress" then
		for i, SpawnProtectionVolume in ipairs(self.SpawnProtectionVolumes) do
			actor.SetActive(SpawnProtectionVolume, false)
		end
	end
end




function uplink:GetModifierTextForObjective( TaggedActor )
	-- consider moving to gamemode
			
	if actor.HasTag( TaggedActor, "AddUpArrow") then
		return "(U)" 
	elseif actor.HasTag( TaggedActor, "AddDownArrow") then
		return "(D)" 
	elseif actor.HasTag( TaggedActor, "AddUpStaircase") then
		return "(u)" 
	elseif actor.HasTag( TaggedActor, "AddDownStaircase") then
		return "(d)"
	elseif actor.HasTag( TaggedActor, "Add1") then
		return "(1)" 
	elseif actor.HasTag( TaggedActor, "Add2") then
		return "(2)" 
	elseif actor.HasTag( TaggedActor, "Add3") then
		return "(3)"
	elseif actor.HasTag( TaggedActor, "Add4") then
		return "(4)" 
	elseif actor.HasTag( TaggedActor, "Add5") then
		return "(5)" 
	elseif actor.HasTag( TaggedActor, "Add6") then
		return "(6)" 
	elseif actor.HasTag( TaggedActor, "Add7") then
		return "(7)" 
	elseif actor.HasTag( TaggedActor, "Add8") then
		return "(8)" 
	elseif actor.HasTag( TaggedActor, "Add9") then
		return "(9)" 
	elseif actor.HasTag( TaggedActor, "Add0") then
		return "(0)" 
	elseif actor.HasTag( TaggedActor, "Add-1") then
		return "(-)"
	elseif actor.HasTag( TaggedActor, "Add-2") then
		return "(=)"
	end
		
	return ""
end



function uplink:LogOut(Exiting)
	if gamemode.GetRoundStage() == "PreRoundWait" 
	or gamemode.GetRoundStage() == "InProgress"
	or gamemode.GetRoundStage() == "BlueDefenderSetup"
	or gamemode.GetRoundStage() == "RedDefenderSetup" then
		timer.Set("CheckEndRound", self, self.CheckEndRoundTimer, 1.0, false);
	end
end


function uplink:GetLaptopInPlay()
	-- pass to BP_LaptopUsable the currently selected laptop (if any)
	
	return self.RandomLaptop
	-- may be nil
end



return uplink