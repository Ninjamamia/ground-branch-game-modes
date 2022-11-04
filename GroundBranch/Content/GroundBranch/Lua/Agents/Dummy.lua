local Tables = require("Common.Tables")

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("Agents.Base"))

-- Our sub-class of the singleton
local Dummy = setmetatable({}, { __index = super })

Dummy.__index = Dummy

---Creates a new Player object.
---@return table Player Newly created Player object.
function Dummy:Create(Queue)
    local self = setmetatable({}, Dummy)
    super.Create(self, Queue, nil, nil)
    return self
end

function Dummy:OnCharacterDied(KillData)
    print("Dummies dont die...")
end

function Dummy:Kill(message)
	print("Can't kill the dummy...")
end

return Dummy