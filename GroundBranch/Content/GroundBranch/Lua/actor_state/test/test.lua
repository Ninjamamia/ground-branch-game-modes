-- package path is used to look for required files, prepend the parent directory
package.path = "../../?.lua;../?.lua;" .. package.path

-- this is supposed to be global and before other require calls
actor = require('test.mocks').Actor
gameplaystatics = require('test.mocks').Gameplaystatics

local ActorStateManager = require('actor_state.actor_state_manager')
local log               = require('actor_state.actor_state_logger')
local all               = require('common.Tables').all
local count             = require('common.Tables').count
local copyTable         = require('common.Tables').Copy
local filter            = require('common.Tables').filter
local isEmpty           = require('common.Tables').isEmpty
local test              = require('common.UnitTest')

-- logger debug level to for the package to test
log:SetLogLevel('OFF')
-- log:SetLogLevel('ERROR')
-- log:SetLogLevel('INFO')
-- log:SetLogLevel('DEBUG')

-- function returning a list of 10 mocked actor instances
local function getTargets()
    return {
        actor.create(), actor.create(), actor.create(), actor.create(), actor.create(),
        actor.create(), actor.create(), actor.create(), actor.create(), actor.create(),
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

-- function to print ActorStateManager params nicely
local function debugParams(params)
    if params == nil then return 'params=nil' end
    if isEmpty(params) then return 'params={}' end

    local out = {}
    -- order of params (just for predictable output during tests)
    local paramsIndex = { 'group', 'act', 'prob', 'num', 'min', 'max', 'with' }
    for _, paramName in ipairs(paramsIndex) do
        local paramValue = params[paramName]
        if paramValue ~= nil then
            table.insert(out, string.format('%s=%s', paramName, paramValue))
        end
    end
    return 'params={ '..table.concat(out, ', ')..' }'
end

-- function to print list of targets nicely
local function debugTargets(targets)
    local out = {}
    for _, target in pairs(targets) do table.insert(out, tostring(target)) end
    return table.concat(out, string.char(10))
end

-- the entry point with setup and some printing
function main()
    math.randomseed(os.time())

    print('ActorState module test')
    print('----------------------')
    -- dunno why but UnitTest.lua changes print behaviour, have to print a space
    print(' ');print('Testing testActorStateManager:enableActor()...');print(' ')
    test_enableActor()

    print(' ');print('Testing ActorStateManager:parseActors()...');print(' ')
    test_parseActors()

    print(' ');print('Testing ActorStateManager:setStateFromList()...');print(' ')
    test_setStateFromList() 

    print(' ');print('Testing ActorStateManager:setState()...');print(' ')
    test_setState()

    print(' ')
    print('Test summary')
    print('------------')
    test.PrintSummary()
end

function test_parseActors()
    test('Parse one actor with no tags', function()
        gameplaystatics.reset()
        
        local target = actor.create()
        gameplaystatics.addActor(target)

        local actionList = ActorStateManager:create():parseActors()

        assert(#actionList == 0, 'Created unnecessary action')
    end)
    test('Parse one actor with the flag tag but no tag parameters', function()
        gameplaystatics.reset()
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())
        
        local asm = ActorStateManager:create()
        local target = actor.create()
        actor.SetTag(target, asm.flagTag)
        gameplaystatics.addActor(target)
        local actionList = asm:parseActors()

        assert(#actionList == 1, 'Did not create exactly one action')
        assert(actionList[1].targets ~= nil, 'Action contains no targets')
        assert(#actionList[1].targets == 1, 'Action does not contain exactly one target')
        assert(actionList[1].targets[1] == target, 'Action does not contain the expected target')
        assert(type(actionList[1].params) == "table", 'Action params is not a table')
        assert(isEmpty(actionList[1].params), 'Action params is not an empty table')
    end)
    test('Parse one actor with all tag parameters', function()
        gameplaystatics.reset()
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())
        
        local target = actor.create()
        actor.SetTag(target, 'ActorState')
        actor.SetTag(target, 'group=test')
        actor.SetTag(target, 'act=disable')
        actor.SetTag(target, 'prob=50')
        actor.SetTag(target, 'num=5')
        actor.SetTag(target, 'min=1')
        actor.SetTag(target, 'max=9')
        gameplaystatics.addActor(target)

        local actionList = ActorStateManager:create():parseActors()

        assert(#actionList == 1, 'Did not create exactly one action')
        assert(actionList[1].targets ~= nil, 'Action contains no targets')
        assert(#actionList[1].targets == 1, 'Action does not contain exactly one target')
        assert(actionList[1].targets[1] == target, 'Action does not contain the expected target')
        assert(type(actionList[1].params) == 'table', 'Action params is not a table')
        assert(actionList[1].params.group == 'test', 'Param group is not set to the correct value')
        assert(actionList[1].params.act == 'disable', 'Param act is not set to the correct value')
        assert(actionList[1].params.prob == 50, 'Param prob is not set to the correct value')
        assert(actionList[1].params.num == 5, 'Param num is not set to the correct value')
        assert(actionList[1].params.min == 1, 'Param min is not set to the correct value')
        assert(actionList[1].params.max == 9, 'Param max is not set to the correct value')
    end)
    test('Parse multiple lone actors', function()
        gameplaystatics.reset()
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())
        
        for i=1,3 do
            local target = actor.create()
            actor.SetTag(target, 'ActorState')
            gameplaystatics.addActor(target)
        end
    
        local actionList = ActorStateManager:create():parseActors()

        assert(#actionList == 3, 'Did not create the correct number of actions')
    end)
    test('Parse multiple actors in a group', function()
        gameplaystatics.reset()
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())
        
        for i=1,3 do
            local target = actor.create()
            actor.SetTag(target, 'ActorState')
            actor.SetTag(target, 'group=test')
            gameplaystatics.addActor(target)
        end
        
        local actionList = ActorStateManager:create():parseActors()

        assert(#actionList == 1, 'Did not create the correct number of actions')
    end)
    test('Parse multiple actors in multiple groups', function()
        gameplaystatics.reset()
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())        
        for _, group in pairs{'test1', 'test2', 'test3'} do
            for i=1,3 do
                local target = actor.create()
                actor.SetTag(target, 'ActorState')
                actor.SetTag(target, 'group='..group)
                
                gameplaystatics.addActor(target)
            end
        end
        
        local actionList = ActorStateManager:create():parseActors()

        assert(#actionList == 3, 'Did not create the correct number of actions')
    end)
    test('Parse actors with different flag tags', function()
        gameplaystatics.reset()
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())
        gameplaystatics.addActor(actor.create())
        
        for i=1,3 do
            for j=1,i do
                local target = actor.create()
                actor.SetTag(target, 'FlagTag'..i)
                gameplaystatics.addActor(target)
            end
        end
        local asm = ActorStateManager:create()
        local actionList1 = asm:parseActors('FlagTag1')
        local actionList2 = asm:create():parseActors('FlagTag2')
        local actionList3 = asm:create():parseActors('FlagTag3')

        assert(#actionList1 == 1, 'Did not create the correct number of actions')
        assert(#actionList2 == 2, 'Did not create the correct number of actions')
        assert(#actionList3 == 3, 'Did not create the correct number of actions')
        assert(actionList1[1].targets ~= nil, 'Action contains no targets')
        assert(actionList2[1].targets ~= nil, 'Action contains no targets')
        assert(actionList3[1].targets ~= nil, 'Action contains no targets')
    end)
end

function test_enableActor()
    test('Enable an actor', function()
        local target = actor.create()
        ActorStateManager:create():enableActor(target, true)

        assert(visibleIsTrue(target), 'Target visible state is not true')
        assert(collideIsTrue(target), 'Target collide state is not true')
        assert(activeIsNil(target), 'Target active state is not nil')
    end)
    test('Disable an actor', function()
        local target = actor.create()
        ActorStateManager:create():enableActor(target, false)

        assert(visibleIsFalse(target), 'Target visible state is not false')
        assert(collideIsFalse(target), 'Target collide state is not false')
        assert(activeIsNil(target), 'Target active state is not nil')
    end)
end

function test_setStateFromList()
    test('Call set state on all target groups', function()
        local actions = { 
            { params={ id=1 }},
            { params={ id=2 }},
            { params={ id=3 }},
            { params={ id=4 }},
            { params={ id=5 }},
        }
        
        local asm = ActorStateManager:create()
        asm.setState = function(self, targets, params)
            actions = filter(actions, function(action)
                return action.params.id ~= params.id
            end)
        end
        asm:setStateFromList(actions)

        assert(isEmpty(actions), 'The setState() method was not called for every target groups')
    end)
    test('Delay target groups having a with paramter', function()
        local actions = { 
            { params={ with='true' }},
            {},
            { params={ with='true' }},
            {},
            {},
        }
        -- :setStateFromList() will call :setState() method while delaying actions
        -- having a 'with' param set, so we override the :setState() methiod to test
        -- for that
        local withEncountered = false
        local setStateCount = 0
        local asm = ActorStateManager:create()
        asm.setState = function(self, targets, params)
            -- print(debugParams(params))
            setStateCount = setStateCount + 1
            assert(not withEncountered or params ~= nil and params.with ~= nil,
                'Target group having a with parameter was not delayed')

            if params ~= nil and params.with ~= nil then withEncountered = true end
        end
        
        asm:setStateFromList(actions)
    end)
end

function test_setState()
    test('Enable all targets', function()
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            -- log:SetLogLevel('DEBUG')
            
            ActorStateManager:create():setState(targets, params)

            assert(all(targets, visibleIsTrue), 'At least one target has visible not set to true')
            assert(all(targets, collideIsTrue), 'At least one target has collide not set to true')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        
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
    test('Disable all targets', function()
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            -- log:SetLogLevel('DEBUG')
            
            ActorStateManager:create():setState(targets, params)

            assert(all(targets, visibleIsFalse), 'At least one target has visible not set to false')
            assert(all(targets, collideIsFalse), 'At least one target has collide not set to false')
            assert(all(targets, activeIsNil),   'At least one target has active not set to nil')
        end

        runTest({ act='disable' })
        runTest({ act='disable', prob=100 })
        runTest({ act='disable', num=10 })
        runTest({ act='disable', prob=100, num=10 })
        runTest({ act='disable', prob=0, num=0 })

        runTest({ act='enable', prob=0 })
        runTest({ act='enable', prob=0, num=100})
        runTest({ act='enable', num=0 })
    end)
    test('Enable specific number of targets', function()
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))            
            -- print(debugParams(params))
            -- log:SetLogLevel('DEBUG')
            
            ActorStateManager:create():setState(targets, params)

            assert(count(filter(targets, visibleIsTrue)) == params.num, 'Number of targets with visible set to true is not equal to params.num')
            assert(count(filter(targets, collideIsTrue)) == params.num, 'Number of targets with collide set to true is not equal to params.num')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        runTest({ act='enable', num=0 })
        runTest({ act='enable', num=1 })
        runTest({ act='enable', num=9 })
        runTest({ act='enable', num=10 })

        -- -- make sure min and max are disregarded when num is provided
        runTest({ act='enable', num=0, min=10 })
        runTest({ act='enable', num=10, max=0 })
    end)
    test('Disable specific number of targets', function()
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            -- log:SetLogLevel('DEBUG')
            
            ActorStateManager:create():setState(targets, params)

            assert(count(filter(targets, visibleIsFalse)) == params.num, 'Number of targets with visible set to true is not equal to params.num')
            assert(count(filter(targets, collideIsFalse)) == params.num, 'Number of targets with collide set to true is not equal to params.num')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil') 
        end
        runTest({ act='disable', num=0 })
        runTest({ act='disable', num=1 })
        runTest({ act='disable', num=9 })
        runTest({ act='disable', num=10 })

        -- make sure min and max are disregarded when num is provided
        runTest({ act='disable', num=0, min=10 })
        runTest({ act='disable', num=10, max=0 })
    end)
    test('Enable a random number of targets with a max', function()
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            -- log:SetLogLevel('DEBUG')
            
            ActorStateManager:create():setState(targets, params)

            assert(count(filter(targets, visibleIsTrue)) >= params.min, 'Number of targets with visible set to true is lower than params.min')
            assert(count(filter(targets, collideIsTrue)) >= params.min, 'Number of targets with collide set to true is lower than params.min')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        runTest({ act='enable', min=0 })
        runTest({ act='enable', min=1 })
        runTest({ act='enable', min=9 })
        runTest({ act='enable', min=10 })
    end)
    test('Disable a random number of targets with a minimum', function()
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            -- log:SetLogLevel('DEBUG')
            
            ActorStateManager:create():setState(targets, params)

            assert(count(filter(targets, visibleIsFalse)) >= params.min, 'Number of targets with visible set to false is lower than params.min')
            assert(count(filter(targets, collideIsFalse)) >= params.min, 'Number of targets with collide set to false is lower than params.min')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        runTest({ act='disable', min=0 })
        runTest({ act='disable', min=1 })
        runTest({ act='disable', min=9 })
        runTest({ act='disable', min=10 })
    end)
    test('Enable a random number of targets with a maximum', function()
        local function runTest(params)
            local targets = getTargets()
            -- print(debugTargets(targets))
            -- print(debugParams(params))
            -- log:SetLogLevel('DEBUG')
            
            ActorStateManager:create():setState(targets, params)

            assert(count(filter(targets, visibleIsTrue)) <= params.max, 'Number of targets with visible set to true is greater than params.max')
            assert(count(filter(targets, collideIsTrue)) <= params.max, 'Number of targets with collide set to true is greater than params.max')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        runTest({ act='enable', max=0 })
        runTest({ act='enable', max=1 })
        runTest({ act='enable', max=9 })
        runTest({ act='enable', max=10 })
    end)
    test('Disable a random number of targets with a maximum', function()
        local function runTest(params)
            local targets = getTargets()            
            
            ActorStateManager:create():setState(targets, params)

            assert(count(filter(targets, visibleIsFalse)) <= params.max, 'Number of targets with visible set to false is lower than params.max')
            assert(count(filter(targets, collideIsFalse)) <= params.max, 'Number of targets with collide set to false is lower than params.max')
            assert(count(filter(targets, visibleIsNil)) == 0, 'At least one target has visible set to nil')
            assert(count(filter(targets, collideIsNil)) == 0, 'At least one target has collide set to nil')
            assert(all(targets, visibleEqCollide), 'At least one target has visible not set to the same value as collide')
            assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
        end
        runTest({ act='disable', max=0 })
        runTest({ act='disable', max=1 })
        runTest({ act='disable', max=9 })
        runTest({ act='disable', max=10 })
    end)
    test('Enable targets based on state of another actor', function()
        local withTarget = actor.create()
        local targets = getTargets()

        ActorStateManager:create():setState(targets, { with=actor.GetName(withTarget) })

        assert(all(targets, visibleIsTrue), 'At least one target has visible not set to true')
        assert(all(targets, collideIsTrue), 'At least one target has collide not set to true')
        assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
    end)
    test('Enable targets based on state of another explicitly enabled actor', function()
        local withTarget = actor.create()
        local targets = getTargets()
            
        local asm = ActorStateManager:create()
        asm:enableActor(withTarget, true)
        asm:setState(targets, { with=actor.GetName(withTarget) })

        assert(all(targets, visibleIsTrue), 'At least one target has visible not set to true')
        assert(all(targets, collideIsTrue), 'At least one target has collide not set to true')
        assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
    end)
    test('Enable targets based on state of another explicitly disabled actor', function()
        local withTarget = actor.create()
        local targets = getTargets()
            
        local asm = ActorStateManager:create()
        asm:enableActor(withTarget, false)
        asm:setState(targets, { with=actor.GetName(withTarget) })

        assert(all(targets, visibleIsFalse), 'At least one target has visible not set to false')
        assert(all(targets, collideIsFalse), 'At least one target has collide not set to false')
        assert(all(targets, activeIsNil), 'At least one target has active not set to nil')
    end)
end

main()
