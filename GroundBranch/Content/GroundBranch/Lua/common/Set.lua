--[[
        Set implementation in Lua (MIT license)
        source https://github.com/EvandroLG/set-lua
        Copyright (c) 2021 Evandro Leopoldino Gonçalves

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
--]]

local utils = {
    to_array = function(hash)
        local output = {}

        for key in pairs(hash) do
            table.insert(output, key)
        end

        return output
    end
}

--- Set lets you store unique values of any type
--- @param list {table}
--- @returns {table}
function Set(list)
    local self = {}

    -- Items presented in 
    -- @type {table}
    self.items = {}

    -- Current Set length
    -- @type {number}
    self.size = 0

    if type(list) == 'table' then
        for _, value in ipairs(list) do
            self.items[value] = true
            self.size = self.size + 1
        end
    end

    -- Appends value to the Set object
    -- @param value {any}
    -- @returns {void}
    self.insert = function(value)
        if not self.items[value] then
            self.items[value] = true
            self.size = self.size + 1
        end
    end

    -- Checks if value is present in the Set object or not
    -- @param value {any}
    -- @returns {boolean}
    self.has = function(value)
        return self.items[value] == true
    end

    -- Removes all items from the Set object
    -- @returns {void}
    self.clear = function()
        self.items = {}
        self.size = 0
    end

    -- Removes item from the Set object and returns a boolean value asserting wheater item was removed or not
    -- @param value {any}
    -- @returns {boolean}
    self.delete = function(value)
        if self.items[value] then
            self.items[value] = nil
            self.size = self.size - 1
            return true
        end

        return false
    end

    -- Calls function once for each item present in the Set object without preserve insertion order
    -- @param callback {function}
    -- @returns {void}
    self.each = function(callback)
        for key in pairs(self.items) do
            callback(key)
        end
    end

    -- Returns true whether all items pass the test provided by the callback function
    -- @param callback {function}
    -- @returns {boolean}
    self.every = function(callback)
        for key in pairs(self.items) do
            if not callback(key) then
                return false
            end
        end

        return true
    end

    -- Returns a new Set that contains all items from the original Set and all items from the specified Sets
    -- @param {Set[]}
    -- @returns Set
    self.union = function(...)
        local args = {...}
        local result = Set(utils.to_array(self.items))

        for _, set in ipairs(args) do
            set.each(function(value)
                result.insert(value)
            end)
        end

        return result
    end

    -- Returns a new Set that contains all elements that are common in all Sets
    -- @param {Set[]}
    -- @returns Set
    self.intersection = function(...)
        local args = {...}
        local result = Set()

        self.each(function(value)
            local is_common = true

            for _, set in ipairs(args) do
                if not set.has(value) then
                    is_common = false
                    break
                end
            end

            if is_common then
                result.insert(value)
            end
        end)

        return result
    end

    -- Returns a new Set that contains the items that only exist in the original Set
    -- @param {Set[]}
    -- @returns Set
    self.difference = function(...)
        local args = {...}
        local result = Set()

        self.each(function(value)
            local is_common = false

            for _, set in ipairs(args) do
                if set.has(value) then
                    is_common = true
                    break
                end
            end

            if not is_common then
                result.insert(value)
            end
        end)

        return result
    end

    -- Returns a symetric difference of two Sets
    -- @param {Set}
    -- @returns {Set}
    self.symmetric_difference = function(set)
        local difference = Set(utils.to_array(self.items))

        set.each(function(value)
            if difference.has(value) then
                difference.delete(value)
            else
                difference.insert(value)
            end
        end)

        return difference
    end

    -- Returns true if set has all items present in the subset
    -- @param {Set}
    -- @returns {boolean}
    self.is_superset = function(subset)
        return self.every(function(value)
            return subset.has(value)
        end)
    end

    --[[
        Code below Copyright (c) 2022 Ninjamamia

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
    --]]


    local getKeys = require('common.Tables').getKeys
    
    self.list = function()
        return getKeys(self.items)
    end
    
    setmetatable(self, {
        __tostring = function()
            return table.concat({
                '<Set> { ', table.concat(getKeys(self.items), ', '), ' }'
            })
        end,
        __eq = function(set1, set2)
            return set1.size == set2.size and set1.is_superset(set2)
        end
    })

    return self
end

return Set
