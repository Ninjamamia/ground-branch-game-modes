local CallbackList = {
}

CallbackList.__index = CallbackList

function CallbackList:Create()
    local self = setmetatable({}, CallbackList)
	self.Callbacks = {}
	return self
end

function CallbackList:Add(Callback)
	table.insert(self.Callbacks, Callback)
end

function CallbackList:Call(...)
	for _, Callback in ipairs(self.Callbacks) do
		Callback:Call(...)
	end
end

return CallbackList