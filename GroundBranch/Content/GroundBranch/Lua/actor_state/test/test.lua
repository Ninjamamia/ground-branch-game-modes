-- package path is used to look for required files, prepend the parent directory
package.path = "../?.lua;" .. package.path

-- this is supposed to be global and before other require calls
actor = require('test.mocks').Actor

local ActorStateAction = require('actor_state_action')
local all              = require('common.Tables').all
local count            = require('common.Tables').count
local filter           = require('common.Tables').filter
local isEmpty          = require('common.Tables').isEmpty
local test             = require('common.UnitTest')

-- function returning a list of 10 mocked actor instances
local function getTargets()
    return {
        actor:new(), actor:new(), actor:new(), actor:new(), actor:new(),
        actor:new(), actor:new(), actor:new(), actor:new(), actor:new(),
    }
end

-- functions to test the state of mocked actors
local function visibleIsTrue(item) return item.visible == true end
local function visibleIsFalse(item) return item.visible == false end
local function visibleIsNil(item) return item.visible == nil end
local function collideIsTrue(item) return item.collide == true end
local function collideIsFalse(item) return item.collide == false end
local function collideIsNil(item) return item.collide == nil end
local function visibleEqCollide(item) return item.collide == item.visible end
local function activeIsTrue(item) return item.active == true end
local function activeIsFalse(item) return item.active == false end
local function activeIsNil(item) return item.active == nil end

-- function to print ActorStateAction params nicely
local function debugParams(params)
    if params == nil then return 'params=nil' end
    if isEmpty(params) then return 'params={}' end

    local out = {}
    -- order of params (just for predictable output during tests)
    local paramsIndex = { 'group', 'act', 'prob', 'num', 'min', 'max' }
    for _, paramName in ipairs(paramsIndex) do
        local paramValue = params[paramName]
        if paramValue ~= nil then
            table.insert(out, string.format('%s=%s', paramName, paramValue))
        end
    end
    return 'params={ '..table.concat(out, ', ')..' }'
end

-- function to print list of targets nicely
function debugTargets(targets)
    local out = {}
    for _, target in pairs(targets) do table.insert(out, tostring(target)) end
    return table.concat(out, string.char(10))
end

-- the entry point with setup and some printing
local function main()
    print('ActorState module test')
    print('----------------------')
    
    -- logger debug level to DEBUG for the package to test
    local log = require('actor_state.actor_state_logger')
    log:SetLogLevel('OFF')
    -- log:SetLogLevel('NOTICE')
    -- log:SetLogLevel('DEBUG')

    -- do not print successful tests
    -- test.OmitPrintPass(true)
    -- test.OmitPrintFail(true)

    math.randomseed(os.time())

    print()
    print('Testing ActorStateAction:exec()...')
    print()

    testActorStateAction_exec()

    print(' ') -- dunno why but UnitTest.lua changes print behavior, have to print a space
    print('Test summary')
    print('------------')
    test.PrintSummary()
end

-- function where the testing actually happens
function testActorStateAction_exec()
    --- About ActorStateAction parameters:
     --
     -- <state>  String 'enable' or 'disable'
     -- <prob>   Integer between 0 and 100, defaults to 100
     -- <num>    Integer greater than 0, defaults to the number of targets
     -- <max>    Integer greater than 0, defaults to the number of targets
     -- <min>    Integer greater than 0, defaults to 0
     --
     -- Executing an action with no <state> parameter will do nothing.
     --
     -- <state>  The state we want the targets to be set to. All targets not set to
     --          this state (because of the impact of other parameters) will be set
     --          to the opposite state.
     --
     -- <prob>   Defines the probability (in percent) that the <state> is set to the
     --          the targets.
     --
     -- <num>    Number of targets to apply the <state> to. Selected targets are
     --          chosen randomly (math.random). Cannot be used at the same time as
     --          <max> or <min>.
     --
     -- <max>    Maximum number of targets to apply the <state> to. The number of
     --          selected targets is chosen randomly, then targets are chosen
     --          randomly. Cannot be greater than <min>. Cannot be used with <num>.
     --
     -- <min>    Minimum number of targets to apply the <state> to. The number of
     --          selected targets is chosen randomly, then targets are chosen
     --          randomly. Cannot be lower than <max>.
     --
    ---
    do -- should not change state of targets
        local function runTest(params)
            local targets = getTargets()
            -- print(debugParams(params))
            -- print(debugTargets(targets))
            ActorStateAction:new({ targets = targets, params = params }):exec()
            assert(all(targets, visibleIsNil), 'At least one target has visible not set to nil')
            assert(all(targets, collideIsNil), 'At least one target has collide not set to nil')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        -- test('Should not change state of targets ', function()            
            -- no test for this case
        -- end)
    end
    do -- should enable all targets
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            ActorStateAction:new({ targets = targets, params = params }):exec()
            assert(all(targets, visibleIsTrue), 'At least one target has visible not set to true')
            assert(all(targets, collideIsTrue), 'At least one target has collide not set to true')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        test('Should enable all targets', function()

            -- enable all
            runTest()
            runTest({})
            runTest({ prob=100 })
            runTest({ num=10 })
            runTest({ prob=100, num=10 })
            runTest({ prob=0, num=0 })

            runTest({ act='enable' })
            runTest({ act='enable', prob=100 })
            runTest({ act='enable', num=10 })
            runTest({ act='enable', prob=100, num=10 })
            runTest({ act='enable', prob=0, num=0 })

            runTest({ act='disable', prob=0 })
            runTest({ act='disable', prob=0, num=100})
            runTest({ act='disable', num=0 })
        end)
    end
    do -- should disable all targets
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            ActorStateAction:new({ targets = targets, params = params }):exec()
            assert(all(targets, visibleIsFalse), 'At least one target has visible not set to false')
            assert(all(targets, collideIsFalse), 'At least one target has collide not set to false')
            assert(all(targets, activeIsNil),   'At least one target has active not set to nil')
        end
        test('Should disable all targets', function()
            -- disable all
            runTest({ act='disable' })
            runTest({ act='disable', prob=100 })
            runTest({ act='disable', num=10 })
            runTest({ act='disable', prob=100, num=10 })
            runTest({ act='disable', prob=0, num=0 })

            runTest({ act='enable', prob=0 })
            runTest({ act='enable', prob=0, num=100})
            runTest({ act='enable', num=0 })
        end)
    end
    do -- should enable specific number of targets
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))            
            -- print(debugParams(params))
            ActorStateAction:new({ targets = targets, params = params }):exec()
            assert(count(filter(targets, visibleIsTrue)) == params.num, 'Number of targets with visible set to true is not equal to params.num')
            assert(count(filter(targets, collideIsTrue)) == params.num, 'Number of targets with collide set to true is not equal to params.num')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        test('Should enable specific number of targets', function()
            runTest({ act='enable', num=0 })
            runTest({ act='enable', num=1 })
            runTest({ act='enable', num=9 })
            runTest({ act='enable', num=10 })

            -- -- make sure min and max are disregarded when num is provided
            runTest({ act='enable', num=0, min=10 })
            runTest({ act='enable', num=10, max=0 })
        end)
    end
    do -- should disable specific number of targets
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            ActorStateAction:new({ targets = targets, params = params }):exec()
            assert(count(filter(targets, visibleIsFalse)) == params.num, 'Number of targets with visible set to true is not equal to params.num')
            assert(count(filter(targets, collideIsFalse)) == params.num, 'Number of targets with collide set to true is not equal to params.num')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil') 
        end
        test('Should disable specific number of targets', function()
            runTest({ act='disable', num=0 })
            runTest({ act='disable', num=1 })
            runTest({ act='disable', num=9 })
            runTest({ act='disable', num=10 })

            -- make sure min and max are disregarded when num is provided
            runTest({ act='disable', num=0, min=10 })
            runTest({ act='disable', num=10, max=0 })
        end)
    end
    do -- should enable a random number of targets with a max
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            ActorStateAction:new({ targets = targets, params = params }):exec()
            assert(count(filter(targets, visibleIsTrue)) >= params.min, 'Number of targets with visible set to true is lower than params.min')
            assert(count(filter(targets, collideIsTrue)) >= params.min, 'Number of targets with collide set to true is lower than params.min')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        test('Should enable a random number of targets with a max', function()
            runTest({ act='enable', min=0 })
            runTest({ act='enable', min=1 })
            runTest({ act='enable', min=9 })
            runTest({ act='enable', min=10 })
        end)
    end
    do -- should disable a random number of targets with a minimum
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            ActorStateAction:new({ targets = targets, params = params }):exec()
            assert(count(filter(targets, visibleIsFalse)) >= params.min, 'Number of targets with visible set to false is lower than params.min')
            assert(count(filter(targets, collideIsFalse)) >= params.min, 'Number of targets with collide set to false is lower than params.min')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        test('Should disable a random number of targets with a minimum', function()
            runTest({ act='disable', min=0 })
            runTest({ act='disable', min=1 })
            runTest({ act='disable', min=9 })
            runTest({ act='disable', min=10 })
        end)
    end
    do -- should enable a random number of targets with a maximum
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            ActorStateAction:new({ targets = targets, params = params }):exec()
            
            assert(count(filter(targets, visibleIsTrue)) <= params.max, 'Number of targets with visible set to true is greater than params.max')
            assert(count(filter(targets, collideIsTrue)) <= params.max, 'Number of targets with collide set to true is greater than params.max')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        test('Should enable a random number of targets with a maximum', function()
            runTest({ act='enable', max=0 })
            runTest({ act='enable', max=1 })
            runTest({ act='enable', max=9 })
            runTest({ act='enable', max=10 })
        end)
    end
    do -- should disable a random number of targets with a maximum
        local function runTest(params)
            -- print(debugParams(params))
            local targets = getTargets()            
            ActorStateAction:new({ targets = targets, params = params }):exec()
            
            assert(count(filter(targets, visibleIsFalse)) <= params.max, 'Number of targets with visible set to false is lower than params.max')
            assert(count(filter(targets, collideIsFalse)) <= params.max, 'Number of targets with collide set to false is lower than params.max')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        test('Should disable a random number of targets with a maximum', function()
            runTest({ act='disable', max=0 })
            runTest({ act='disable', max=1 })
            runTest({ act='disable', max=9 })
            runTest({ act='disable', max=10 })
        end)
    end
end

main()
