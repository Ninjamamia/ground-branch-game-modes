-- package path is used to look for required files, prepend the parent directory
package.path = "../../?.lua;../?.lua;" .. package.path

-- -- this is supposed to be global and before other require calls
-- actor = require('test.mocks').Actor
-- gameplaystatics = require('test.mocks').Gameplaystatics

-- local log               = require('actor_state.actor_state_logger')
-- local all               = require('common.Tables').all
-- local count             = require('common.Tables').count
-- local copyTable         = require('common.Tables').Copy
-- local filter            = require('common.Tables').filter
-- local isEmpty           = require('common.Tables').isEmpty

local test      = require('common.UnitTest')
local Functions = require('common.Functions')
local Tables    = require('common.Tables')

local PATH_SEPARATOR = package.config:sub(1,1)

function main()
	print('Test Lua/common"')
	print('----------------')
	
	test_Functions()
	test_Tables()
	
	print(' ')
	test.PrintSummary()
end

function test_Functions()
	print()
	print('Testing common.Functions...')
	print()

	test('Functions.pipe', function()
		-- make sure each provided function are called only once and in correct
		-- order, make sure the argument is passed and returned without being altered
		local calls = {}
		local fn1 = function(arg) table.insert(calls, 'fn1') return arg end
		local fn2 = function(arg) table.insert(calls, 'fn2') return arg end
		local fn3 = function(arg) table.insert(calls, 'fn3') return arg end
		local pipedFns = Functions.pipe(fn1, fn2, fn3)
		local arg = {}
		local res = pipedFns(arg)
		assert(#calls == 3, 'Too many function calls')
		assert(calls[1] == 'fn1', 'First provided function was not called first')
		assert(calls[2] == 'fn2', 'Second provided function was not called second')
		assert(calls[3] == 'fn3', 'Third provided function was not called third')
		assert(arg == res, 'The argument was unexpectedly altered')
	end)

	test('Functions.curry', function()
		-- make sure the function is called only once
		-- make sure the arguments are passed and returned without being altered
		local calls = {}
		local fn = function(arg1, arg2) table.insert(calls, 'fn'); return arg1, arg2 end
		local curriedFn = Functions.curry(fn)
		local arg1 = {}
		local arg2 = {}
		local res1, res2 = curriedFn(arg1)(arg2)
		assert(#calls == 1, 'The provided function was called more than once')
		assert(arg1 == res1, 'The first argument was altered')
		assert(arg2 == res2, 'The second argument was altered')
	end)

	test('Functions.curryReverse', function()
		-- make sure the function is called only once
		-- make sure the arguments are passed and returned without being altered
		local calls = {}
		local fn = function(arg1, arg2) table.insert(calls, 'fn'); return arg1, arg2 end
		local curriedFn = Functions.curryReverse(fn)
		local arg1 = {}
		local arg2 = {}
		local res1, res2 = curriedFn(arg2)(arg1)
		assert(#calls == 1, 'The provided function was called more than once')
		assert(arg1 == res1, 'The first argument was altered')
		assert(arg2 == res2, 'The second argument was altered')
	end)
end

function test_Tables()
	print()
	print('Testing common.Tables...')
	print()

	test('Tables.isEmpty', function()
		local emptyTable = {}
		local notEmptyTable = {{}}
		assert(true == Tables.isEmpty(emptyTable), 'Wrong return value for empty table')
		assert(false == Tables.isEmpty(notEmptyTable), 'Wrong return value for non empty table')
	end)

	test('Tables.notEmpty', function()
		local emptyTable = {}
		local notEmptyTable = {{}}
		assert(false == Tables.notEmpty(emptyTable), 'Wrong return value for empty table')
		assert(true == Tables.notEmpty(notEmptyTable), 'Wrong return value for non empty table')
	end)

	test('Tables.count', function()
		-- check count for empty table
		local emptyTable = {}
		assert(0 == Tables.count(emptyTable), 'Wrong return value for empty table')
		-- check count for integer indexed tables
		local list1 = {{}}
		local list3 = {{},{},{}}
		assert(1 == Tables.count(list1), 'Wrong return value for integer indexed table with 1 element')
		assert(3 == Tables.count(list3), 'Wrong return value for integer indexed table with 3 elements')
		-- check count for string indexed tables
		local map1 = {key={}}
		local map3 = {key1={},key2={},key3={}}
		assert(1 == Tables.count(map1), 'Wrong return value for string indexed table with 1 element')
		assert(3 == Tables.count(map3), 'Wrong return value for string indexed table with 3 elements')

		-- check count for mix-indexed tables
		local mixed3 = {key1={},{},key3={}}
		local mixed5= {{},key2={},{},key4={}, {}}
		assert(3 == Tables.count(mixed3), 'Wrong return value for mix-indexed table with 3 elements')
		assert(5 == Tables.count(mixed5), 'Wrong return value for mix-indexed table with 5 elements')
	end)

	test('Tables.all', function()
		-- check function is called with the correct arguments the correct number of times
		local calls = {}
		local items = {'item1', 'item2', 'item3'}
		local logCalls = function(arg) table.insert(calls, arg); return true end
		local res = Tables.all(items, logCalls)
		assert(#calls == 3)
		assert(calls[1] == items[1])
		assert(calls[2] == items[2])
		assert(calls[3] == items[3])
		
		-- check with different table content
		local isTrue = function(arg) return arg == true end
		
		assert(true == Tables.all({}, isTrue))
		assert(true == Tables.all({true}, isTrue))
		assert(true == Tables.all({true,true,true}, isTrue))
		assert(false == Tables.all({false}, isTrue))
		assert(false == Tables.all({false,true,true}, isTrue))
		assert(false == Tables.all({true,true,false}, isTrue))
	end)

	test('Tables.every', function()
		-- check function is called with the correct arguments the correct number of times
		local calls = {}
		local items = {'item1', 'item2', 'item3'}
		local logCalls = function(arg) table.insert(calls, arg); return true end
		local res = Tables.every(items, logCalls)
		assert(#calls == 3)
		assert(calls[1] == items[1])
		assert(calls[2] == items[2])
		assert(calls[3] == items[3])
		
		-- check with different table content
		local isTrue = function(arg) return arg == true end
		
		assert(true == Tables.every({}, isTrue))
		assert(true == Tables.every({true}, isTrue))
		assert(true == Tables.every({true,true,true}, isTrue))
		assert(false == Tables.every({false}, isTrue))
		assert(false == Tables.every({false,true,true}, isTrue))
		assert(false == Tables.every({true,true,false}, isTrue))
	end)

	test('Tables.any', function()
		-- check function is called with the correct arguments the correct number of times
		local calls = {}
		local items = {'item1', 'item2', 'item3'}
		local logCalls = function(arg) table.insert(calls, arg); return false end
		local res = Tables.any(items, logCalls)
		assert(#calls == 3)
		assert(calls[1] == items[1])
		assert(calls[2] == items[2])
		assert(calls[3] == items[3])
		
		-- check with different table content
		local isTrue = function(arg) return arg == true end
		
		assert(false == Tables.any({}, isTrue))
		assert(false == Tables.any({false}, isTrue))
		assert(false == Tables.any({false,false,false}, isTrue))
		assert(true == Tables.any({true}, isTrue))
		assert(true == Tables.any({true,false,false}, isTrue))
		assert(true == Tables.any({false,false,true}, isTrue))
	end)

	test('Tables.some', function()
		do
			-- check function is called with the correct arguments the correct number of times
			local calls = {}
			local items = {'item1', 'item2', 'item3'}
			local logCalls = function(arg) table.insert(calls, arg); return false end
			local res = Tables.some(items, logCalls)
			assert(#calls == 3)
			assert(calls[1] == items[1])
			assert(calls[2] == items[2])
			assert(calls[3] == items[3])
		end
		
		-- check with different table content
		local isTrue = function(arg) return arg == true end
		
		assert(false == Tables.some({}, isTrue))
		assert(false == Tables.some({false}, isTrue))
		assert(false == Tables.some({false,false,false}, isTrue))
		assert(true == Tables.some({true}, isTrue))
		assert(true == Tables.some({true,false,false}, isTrue))
		assert(true == Tables.some({false,false,true}, isTrue))
	end)

	test('Tables.naiveMergeAssocTables', function()		
		do
			local tbl1 = {key1={},key2={},key3={}}
			local tbl2 = {key1={},key2={},key3={}}
			local res = Tables.naiveMergeAssocTables(tbl1, tbl2)
			assert(3 == Tables.count(res))
			assert(tbl2.key1 == res.key1)
			assert(tbl2.key2 == res.key2)
			assert(tbl2.key3 == res.key3)
		end
		do
			local tbl1 = {key1={},key2={},key3={}}
			local tbl2 = {key4={},key5={},key6={}}
			local res = Tables.naiveMergeAssocTables(tbl1, tbl2)
			assert(6 == Tables.count(res))
			assert(tbl1.key1 == res.key1)
			assert(tbl1.key2 == res.key2)
			assert(tbl1.key3 == res.key3)
			assert(tbl2.key4 == res.key4)
			assert(tbl2.key5 == res.key5)
			assert(tbl2.key6 == res.key6)
		end
	end)

	test('Tables.setDefault', function()
		local tbl = {'value1', key2='value2'}
		local defaultValue = {}
		Tables.setDefault(tbl, defaultValue)
		assert(tbl[1] == 'value1')
		assert(tbl.key2 == 'value2')
		assert(tbl.unsetKey == defaultValue)
	end)

	--- @todo add test for Tables.reduce
	--- @todo add test for Tables.map
	--- @todo add test for Tables.filterIf
	--- @todo add test for Tables.filter
	--- @todo add test for Tables.filterNot
	--- @todo add test to make sure no functions mutates the tables
end

main()
