local AdminTools = require('AdminTools')
local Tables = require("Common.Tables")

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("GroundBranch.GameMode.TerroristHunt"))

-- Our sub-class of the singleton
local Mode = setmetatable({}, { __index = super })

Mode.Settings.NumberOfWaves = {
	Min = 0,
	Max = 10,
	Value = 2,
	AdvancedSetting = false,
}
Mode.Settings.WaveSpawnAtPercent = {
	Min = 00,
	Max = 90,
	Value = 20,
	AdvancedSetting = false,
}
Mode.Settings.WaveSizePercent = {
	Min = 10,
	Max = 100,
	Value = 80,
	AdvancedSetting = false,
}
Mode.WaveNumber = 0

function Mode:OnRoundStageSet(RoundStage)
	super.OnRoundStageSet(self, RoundStage)
	if RoundStage == "PreRoundWait" then
		self.WaveNumber = 0
	end
end

function Mode:OnOpForDied(killData)
	local OpForAliveCount = self.Teams.OpFor:GetAliveAgentsCount()
	super.OnOpForDied(self, killData)
	if self.WaveNumber < self.Settings.NumberOfWaves.Value then
		local OpForAliveRatio = (OpForAliveCount * 100) / self.Settings.OpForCount.Value
		print("WaveCondition: OpForAliveRatio=" .. OpForAliveRatio .. " %")
		if OpForAliveRatio <= self.Settings.WaveSpawnAtPercent.Value or OpForAliveCount <= 1 then
			self.WaveNumber = self.WaveNumber + 1
			local WaveSize = math.floor((self.Settings.OpForCount.Value * self.Settings.WaveSizePercent.Value) / 100)
			AdminTools:ShowDebug("Spawning reinforcement wave " .. self.WaveNumber .. " (" .. WaveSize .. " OpFor)")
			self.AISpawns.OpFor:SelectSpawnPoints()
			self.AISpawns.OpFor:Spawn(0.0, 0.4, WaveSize)
		end
	end
end

return Mode