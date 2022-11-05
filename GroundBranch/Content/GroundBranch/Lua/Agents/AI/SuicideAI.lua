local Tables = require("Common.Tables")
local AdminTools = require('AdminTools')

-- Create a deep copy of the singleton
local super = Tables.DeepCopy(require("Agents.AI.BasicAI"))

-- Our sub-class of the singleton
local SuicideAI = setmetatable({}, { __index = super })

SuicideAI.__index = SuicideAI
SuicideAI.Type = "Suicide AI"

---Creates a new SuicideAI object.
---@return table SuicideAI Newly created AI object.
function SuicideAI:Create(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    local self = setmetatable({}, SuicideAI)
    self:Init(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    return self
end

function SuicideAI:Init(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    super.Init(self, AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    print('  This is a Suicide AI, Parameters:')
    for _, Tag in ipairs(actor.GetTags(spawnPoint)) do
        local key
        local value
        _, _, key, value = string.find(Tag, "(%a+)%s*=%s*(%w+)")
        if key ~= nil then
            print("    " .. Tag)
            self[key] = tonumber(value)
        end
    end
end

function SuicideAI:__tostring()
    return self.Type .. ' ' .. self.Name
end

return SuicideAI