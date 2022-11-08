local KillData = {
}

KillData.__index = KillData

function KillData:Create(KilledAgent, KillerAgent)
    local self = setmetatable({}, KillData)
	self.KilledAgent = KilledAgent
	self.KillerAgent = KillerAgent
	self.KilledTeam = KilledAgent.Team
	self.KillerTeam = nil
	if KillerAgent ~= nil then
		self.KillerTeam = KillerAgent.Team
	end
	return self
end

function KillData:GetPosition()
	return self.KilledAgent:GetPosition()
end

function KillData:GetLocation()
	return self:GetPosition().Location
end

function KillData:HasTag(Tag)
	return self.KilledAgent:HasTag(Tag)
end

return KillData