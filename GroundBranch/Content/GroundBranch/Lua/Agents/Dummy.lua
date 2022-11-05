local Tables = require("Common.Tables")

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("Agents.Base"))

-- Our sub-class of the singleton
local Dummy = setmetatable({}, { __index = super })

Dummy.__index = Dummy
Dummy.Type = "Dummy"

---Creates a new Player object.
---@return table Player Newly created Player object.
function Dummy:Create(AgentsManager)
    local self = setmetatable({}, Dummy)
    self:Init(AgentsManager or gamemode.script.AgentsManager)
    return self
end

function Dummy:Init(AgentsManager)
    super.Init(self, AgentsManager, nil, nil)
end

function Dummy:__tostring()
    return self.Type .. ' ' .. self.Name
end

function Dummy:OnCharacterDied(KillData)
    print("Dummies dont die...")
end

function Dummy:Kill(message)
	print("Can't kill the dummy...")
end

return Dummy