local Tables = require("Common.Tables")

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("PvEBase"))

-- Our sub-class of the singleton
local Mode = setmetatable({}, { __index = super })

Mode.MissionTypeDescription = "[Solo/Co-Op] Locate and eliminate a (somewhat) predetermined number of enemies in the area of operations."
Mode.Settings.ShowRemaining = {
	Min = 0,
	Max = 50,
	Value = 10,
	AdvancedSetting = true,
}
Mode.Timers.CheckOpForCount = {
	Name = 'CheckOpForCount',
	TimeStep = 1.0,
}

function Mode:PreInit()
	super.PreInit(self)
	self.Settings.ShowRemaining.Max = TotalSpawns
	self.Settings.ShowRemaining.Value = math.min(self.Settings.ShowRemaining.Value, TotalSpawns)
end

function Mode:PostInit()
	super.PostInit(self)
	self.Teams.BluFor:AddGameObjective("EliminateOpFor", 1)
end


function Mode:OnOpForDied(killData)
	timer.Set(
		self.Timers.CheckOpForCount.Name,
		self,
		self.CheckOpForCountTimer,
		self.Timers.CheckOpForCount.TimeStep,
		false
	)
end

function Mode:CheckOpForCountTimer()
	local OpForAliveCount = self.Teams.OpFor:GetAliveAgentsCount()
	if OpForAliveCount == 0 then
		timer.Clear("ShowRemaining")
		gamemode.AddGameStat("Result=Team1")
		gamemode.AddGameStat("Summary=OpForEliminated")
		gamemode.AddGameStat("CompleteObjectives=EliminateOpFor")
		gamemode.SetRoundStage("PostRoundWait")
	elseif self.Settings.ShowRemaining.Value > 0 and OpForAliveCount <= self.Settings.ShowRemaining.Value then
		local FormatTable = {}
		FormatTable.FormatString = "RemainingOpfor"
		-- "FormatString" is a reserved and mandatory field name
		-- "RemainingOpfor" is expanded into a proper formatting string (in .csv file): "format_RemainingOpfor","{NumberRemaining} {NumberRemaining}|plural(one=enemy,other=enemies) remaining",formatted string
		FormatTable.NumberRemaining = self.AgentsManager.AliveAICount
		-- important not to convert #OpForControllers to string so that it can be used by the plural() formatting function
		self.RemainingMessage = gamemode.FormatString(FormatTable)
		timer.Set("ShowRemaining", self, self.ShowRemainingTimer, 10, false)
	end
end

function Mode:ShowRemainingTimer()
	gamemode.BroadcastGameMessage(self.RemainingMessage, "Engine", 2.0)
end

return Mode