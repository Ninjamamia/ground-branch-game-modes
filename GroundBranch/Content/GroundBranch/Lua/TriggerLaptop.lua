local AdminTools = require('AdminTools')

local laptop = {
	CurrentTime = 0,
	OnSearch = "Are you in for surprises?",
	OnSuccess = "There you go...",
	SearchTime = 10.0,
	Name = "TriggerLaptop",
	Timers = {
		Timeout = {
			Name = 'Timeout',
			TimeStep = 1.0,
		}
	}
}

function laptop:ServerUseTimer(User, DeltaTime)
	self.CurrentTime = self.CurrentTime + DeltaTime
	self.CurrentTime = math.max(self.CurrentTime, 0)
	self.CurrentTime = math.min(self.CurrentTime, self.SearchTime)

	local Result = {}
	Result.Message = self.OnSearch
	Result.Equip = false
	Result.Percentage = self.CurrentTime / self.SearchTime
	if Result.Percentage == 1.0 then
		timer.Clear(self.Timers.Timeout.Name, self)
		Result.Message = self.OnSuccess
		if gamemode.script.AmbushManager ~= nil then
			gamemode.script.AmbushManager:OnLaptopSuccess(self.Object, gamemode.script.AgentsManager:GetAgent(User))
		else
			AdminTools:ShowDebug("TriggerLaptop: gamemode doesn't define AmbushManager")
		end
	else
		timer.Set(
			self.Timers.Timeout.Name,
			self,
			self.CheckTimeoutTimer,
			self.Timers.Timeout.TimeStep,
			false
		)
	end
	return Result
end

function laptop:CheckTimeoutTimer()
	print(self.Name .. ": Timeout")
	self.CurrentTime = 0
end

function laptop:OnReset()
	self.Name = actor.GetName(self.Object)
	print(self.Name .. ": Reset")
	self.CurrentTime = 0
	self.Timers.Timeout.Name = "Timeout_" .. actor.GetName(self.Object)
	if gamemode.script.Settings.SearchTime ~= nil then
		SearchTime = gamemode.script.Settings.SearchTime.Value
	end
	for _, Tag in ipairs(actor.GetTags(self.Object)) do
		local key
		local value
		_, _, key, value = string.find(Tag, "(%a+)%s*=%s*(.*)")
		if key ~= nil then
			if key == "OnSearch" then
				self.OnSearch = value
			elseif key == "OnSuccess" then
				self.OnSuccess = value
			elseif key == "SearchTime" then
				self.SearchTime = tonumber(value)
			elseif key == "Timeout" then
				self.Timers.Timeout.TimeStep = tonumber(value)
			end
		end
	end
end

function laptop:LaptopPickedUp()
	print(self.Name .. ": Picked up")
	gamemode.script:OnLaptopPickedUp(self.Object)
end

function laptop:LaptopPlaced(NewLaptop)
	print(self.Name .. ": Placed")
	gamemode.script:OnLaptopPlaced(NewLaptop)
end


function laptop:CarriedLaptopDestroyed()
	print(self.Name .. ": Destroyed")
	gamemode.script:OnLaptopDestroyed(self.Object)
end

return laptop