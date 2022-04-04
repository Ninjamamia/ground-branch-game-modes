local Tables = require("Common.Tables2")
local Method = require("Common.Method")

local CustomMode = Tables.DeepCopy(require("KillConfirmed"))

CustomMode.Settings.RespawnCost.Value = 100000
CustomMode.PlayerScoreTypes.CollateralDamage = {
	Score = -250,
	OneOff = false,
	Description = 'Killed a non-combatant'
}
CustomMode.CollateralDamageDamageCount = 0

Method.Extend(CustomMode, 'OnRoundStageSet', function(self, super, RoundStage)
	if RoundStage == 'PreRoundWait' then
		print("Setting attitudes")
		gamemode.SetTeamAttitude(1, 10, 'Neutral')
		gamemode.SetTeamAttitude(10, 1, 'Neutral')
		gamemode.SetTeamAttitude(10, 100, 'Friendly')
		gamemode.SetTeamAttitude(100, 10, 'Friendly')
	end
	super(RoundStage)
end)

Method.Extend(CustomMode, 'OnCharacterDied', function(self, super, Character, CharacterController, KillerController)
	local goodKill = true

	if gamemode.GetRoundStage() == 'PreRoundWait' or gamemode.GetRoundStage() == 'InProgress'
	then
		if CharacterController ~= nil then
			local killedTeam = actor.GetTeamId(CharacterController)
			local killerTeam = nil
			if KillerController ~= nil then
				killerTeam = actor.GetTeamId(KillerController)
			end
			if killedTeam == 10 and killerTeam == 1 then
				self.PlayerTeams.BluFor.Script:AwardPlayerScore(KillerController, 'CollateralDamage')
				goodKill = false
			end
		end
	end

	if goodKill then
		super(Character, CharacterController, KillerController)
	end
end)



return CustomMode
