-- add path to the  GB 'Lua' directory to package.path (used for requires)
if not _G['gbLuaDirInPath'] then
    local DIR_SEP = package.config:sub(1,1)
    local currentScriptPath = arg[0]
    local workingDir = os.getenv('CWD') or
                       os.getenv('PWD') or
                       os.getenv('WD') or
                       os.getenv('CD')
    if currentScriptPath ~= nil and workingDir ~= nil then
        local fullPath = workingDir..DIR_SEP..currentScriptPath
        local substrIndex = fullPath:find('[\\/]GroundBranch[\\/]Lua[\\/]')
        if substrIndex ~= nil then
            local gbLuaDir = fullPath:sub(1, substrIndex+17)
            package.path = gbLuaDir .. "?.lua;" .. package.path
            _G['gbLuaDirInPath'] = true
        end
    end
end

require('actor_state.test.test')
print(' ')
require('common.test.test')
print(' ')
