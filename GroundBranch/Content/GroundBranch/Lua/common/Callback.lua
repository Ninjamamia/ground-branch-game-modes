local Callback = {
}

Callback.__index = Callback

function Callback:Create(Owner, Function)
    local self = setmetatable({}, Callback)
	self.Function = Function
	self.Owner = Owner
	return self
end

function Callback:Call(...)
	self.Function(self.Owner, ...)
end

return Callback