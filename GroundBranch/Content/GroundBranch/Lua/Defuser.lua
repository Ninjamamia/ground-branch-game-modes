local AdminTools = require('AdminTools')

local laptop = {
	CurrentTime = 0,
	tiDefuse = 10.0,
	tiDefuseMin = 10.0,
	tiDefuseMax = 10.0,
	Name = "Defuser",
	OnSuccessCallback = nil,
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
	self.CurrentTime = math.min(self.CurrentTime, self.tiDefuse)

	local Result = {}
	Result.Message = ""
	Result.Equip = false
	Result.Percentage = self.CurrentTime / self.tiDefuse
	if Result.Percentage == 1.0 then
		timer.Clear(self.Timers.Timeout.Name, self)
		if gamemode.script.AmbushManager ~= nil then
			gamemode.script.AmbushManager:OnDefuse(self.Object)
		else
			AdminTools:ShowDebug("Defuser: gamemode doesn't define AmbushManager")
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
	for _, Tag in ipairs(actor.GetTags(self.Object)) do
		local key
		local value
		_, _, key, value = string.find(Tag, "(%a+)%s*=%s*(.*)")
		if key ~= nil then
			if key == "tiDefuseMin" then
				self.tiDefuseMin = tonumber(value)
			elseif key == "tiDefuseMax" then
				self.tiDefuseMax = tonumber(value)
			elseif key == "Timeout" then
				self.Timers.Timeout.TimeStep = tonumber(value)
			end
		end
	end
    if self.tiDefuseMin >= self.tiDefuseMax then
        self.tiDefuse = math.min(self.tiDefuseMin, self.tiDefuseMax)
    else
        self.tiDefuse = math.random(self.tiDefuseMin * 10, self.tiDefuseMax * 10) * 0.1
    end
	print('  tiDefuse = ' .. self.tiDefuse .. 's')
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