local Tables = require("Common.Tables")

local super = Tables.DeepCopy(require("KillConfirmed"))
local KillConfirmedSP = setmetatable({}, { __index = super })

KillConfirmedSP.Settings.RespawnCost.Value = 100000
KillConfirmedSP.PlayerScoreTypes.CollateralDamage = {
	Score = -250,
	OneOff = false,
	Description = 'Killed a non-combatant'
}
KillConfirmedSP.CollateralDamageDamageCount = 0

function KillConfirmedSP:OnRoundStageSet(RoundStage)
	if RoundStage == 'PreRoundWait' then
		print("Setting attitudes")
		gamemode.SetTeamAttitude(1, 10, 'Neutral')
		gamemode.SetTeamAttitude(10, 1, 'Neutral')
		gamemode.SetTeamAttitude(10, 100, 'Friendly')
		gamemode.SetTeamAttitude(100, 10, 'Friendly')
	end
	super.OnRoundStageSet(self, RoundStage)
end

function KillConfirmedSP:OnCharacterDied(Character, CharacterController, KillerController)
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
		super.OnCharacterDied(self, Character, CharacterController, KillerController)
	end
end

return KillConfirmedSP
