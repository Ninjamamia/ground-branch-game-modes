local BasicAI = require('Agents.AI.BasicAI')
local SuicideAI = require('Agents.AI.SuicideAI')

-- Our sub-class of the singleton
local AI = {}

AI.__index = AI

---Creates a new AI object.
---@return table AI Newly created AI object.
function AI:Create(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    if actor.HasTag(spawnPoint, 'SuicideBomber') then
        return SuicideAI:Create(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
    end
    return BasicAI:Create(AgentsManager, uuid, characterController, spawnPoint, BaseTag, eliminationCallback)
end

return AI