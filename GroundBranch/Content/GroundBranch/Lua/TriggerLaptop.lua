local laptop = {
	CurrentTime = 0,
}

function laptop:ServerUseTimer(User, DeltaTime)
	self.CurrentTime = self.CurrentTime + DeltaTime
	local SearchTime = 10.0
	if gamemode.script.Settings.SearchTime ~= nil then
		SearchTime = gamemode.script.Settings.SearchTime.Value
	end
	self.CurrentTime = math.max(self.CurrentTime, 0)
	self.CurrentTime = math.min(self.CurrentTime, SearchTime)

	local Result = {}
	Result.Message = "Are you in for surprises?"
	Result.Equip = false
	Result.Percentage = self.CurrentTime / SearchTime
	if Result.Percentage == 1.0 then
		Result.Message = "There you go..."
		gamemode.script:OnLaptopTriggered(self.Object)
	end
	return Result
end

function laptop:OnReset()
	self.CurrentTime = 0
end

function laptop:LaptopPickedUp()
	gamemode.script:OnLaptopPickedUp(self.Object)
end

function laptop:LaptopPlaced(NewLaptop)
	gamemode.script:OnLaptopPlaced(NewLaptop)
end


function laptop:CarriedLaptopDestroyed()
	gamemode.script:OnLaptopDestroyed(self.Object)
end

return laptop