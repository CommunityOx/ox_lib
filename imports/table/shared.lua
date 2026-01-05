--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

-- Add additional functions to the standard table library

---@class oxtable : tablelib
lib.table = table
local pairs = pairs

---@param tbl table
---@param value any
---@return boolean
---Checks if tbl contains the given values. Only intended for simple values and unnested tables.
local function contains(tbl, value)
    if type(value) ~= 'table' then
        for _, v in pairs(tbl) do
            if v == value then
                return true
            end
        end

        return false
    else
        local set = {}

        for _, v in pairs(tbl) do
            set[v] = true
        end

        for _, v in pairs(value) do
            if not set[v] then
                return false
            end
        end

        return true
    end
end

---@param t1 any
---@param t2 any
---@return boolean
---Compares if two values are equal, iterating over tables and matching both keys and values.
local function table_matches(t1, t2)
	local type1, type2 = type(t1), type(t2)

	if type1 ~= type2 then return false end
	if type1 ~= 'table' and type2 ~= 'table' then return t1 == t2 end

    for k, v1 in pairs(t1) do
        local v2 = t2[k]
        if v2 == nil or not table_matches(v1, v2) then
            return false
        end
    end

    for k in pairs(t2) do
        if t1[k] == nil then
            return false
        end
    end

    return true
end

---@generic T
---@param tbl T
---@return T
---Recursively clones a table to ensure no table references.
local function table_deepclone(tbl)
    tbl = table.clone(tbl)

    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            tbl[k] = table_deepclone(v)
        end
    end

    return tbl
end

---@param t1 table
---@param t2 table
---@param addDuplicateNumbers boolean? add duplicate number keys together if true, replace if false. Defaults to true.
---@return table
---Merges two tables together. Defaults to adding duplicate keys together if they are numbers, otherwise they are overriden.
local function table_merge(t1, t2, addDuplicateNumbers)
    addDuplicateNumbers = addDuplicateNumbers == nil or addDuplicateNumbers
    for k, v2 in pairs(t2) do
        local v1 = t1[k]
        local type1 = type(v1)
        local type2 = type(v2)

        if type1 == 'table' and type2 == 'table' then
            table_merge(v1, v2, addDuplicateNumbers)
        elseif addDuplicateNumbers and (type1 == 'number' and type2 == 'number') then
            t1[k] = v1 + v2
        else
            t1[k] = v2
        end
    end

    return t1
end

---@param tbl table
---@return table
---Shuffles the elements of a table randomly using the Fisher-Yates algorithm.
local function shuffle(tbl)
    local len = #tbl
    for i = len, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

<<<<<<< HEAD
-- ADDED FUNCTIONS BY DABZ --

--- Returns a json table in a readable format
---@param tbl table The table to be formatted
---@param indent number The number of spaces to indent the output
---@return string
local function jsonPrettyPrint(tbl, indent)
    indent = indent or 0
    local to_print = "{\n"
    local pad = string.rep("  ", indent + 1)
    local first = true
    for k, v in pairs(tbl) do
        if not first then to_print = to_print .. ",\n" end
        first = false
        local key = type(k) == "string" and ('"%s"'):format(k) or tostring(k)
        if type(v) == "table" then
            to_print = to_print .. ("%s%s: %s"):format(pad, key, jsonPrettyPrint(v, indent + 1))
        elseif type(v) == "string" then
            to_print = to_print .. ("%s%s: \"%s\""):format(pad, key, v)
        else
            to_print = to_print .. ("%s%s: %s"):format(pad, key, tostring(v))
        end
    end
    to_print = to_print .. "\n" .. string.rep("  ", indent) .. "}"
    return to_print
end


---@param tbl table The table to remove the value from
---@param value any The value to be removed from the table
---Removes the first occurrence of a value from a table.
local function removeValue(tbl, value)
    for k, v in pairs(tbl) do
        if v == value then
            tbl[k] = nil
            break
        end
    end
end

---@param tbl table The table to search through
---@param object any The object whose index in the table is to be found
---@return integer? The index of the object in the table, or nil if not found
---Gets the index of a value in a sequential (array-like) table.
local function indexOf(tbl, object)
    if type(tbl) == 'table' then
        for i, value in ipairs(tbl) do
            if object == value then
                return i
            end
        end
    end
    return nil
end

---@param tbl table The table to add the value to
---@param value any The value to be added to the table if it's unique
---Adds a value to a table if it does not already exist.
local function addUnique(tbl, value)
    if not contains(tbl, value) then
        table.insert(tbl, value)
    end
end

---@param tbl1 table The first table to merge into (modified in-place)
---@param tbl2 table The second table whose values will be added to the first table
---Merges the contents of tbl2 into tbl1 (shallow merge, array-style).
local function mergeTables(tbl1, tbl2)
    for _, value in ipairs(tbl2) do
        table.insert(tbl1, value)
    end
end

---@param tbl table The table to be filtered
---@param predicate fun(value:any, key:any):boolean The predicate function
---@return table A new table containing only elements that satisfy the predicate function
---Filters a table based on a predicate function.
local function filter(tbl, predicate)
    local filtered = {}
    for k, v in pairs(tbl) do
        if predicate(v, k) then
            table.insert(filtered, v)
        end
    end
    return filtered
end

---@param tbl table The table to be mapped
---@param transform fun(value:any, key:any):any The transformation function
---@return table A new table containing the results of applying the transform function
---Maps a table to a new table based on a transformation function.
local function map(tbl, transform)
    local mapped = {}
    for k, v in pairs(tbl) do
        mapped[k] = transform(v, k)
    end
    return mapped
end

---@param user table? The user table (overrides)
---@param default table The default table (fallbacks)
---@return table A new table with user values overriding default values, merged recursively
---Deep merges two tables, returning a new table. Does not mutate inputs.
local function safeMerge(user, default)
    if not lib.assert.type(default, 'table', 'Default') then
        return {}
    end

    if user == nil then
        return table_deepclone(default)
    end

    if not lib.assert.type(user, 'table', 'User options') then
        return table_deepclone(default)
    end

    local out = {}

    for k, v in pairs(default) do
        if type(v) == "table" then
            if user[k] ~= nil then
                if not lib.assert.type(user[k], 'table', ('Key "%s"'):format(k)) then
                    out[k] = table_deepclone(v)
                else
                    out[k] = safeMerge(user[k], v)
                end
            else
                out[k] = table_deepclone(v)
            end
        else
            if user[k] ~= nil then
                out[k] = user[k]
            else
                out[k] = v
            end
        end
    end

    -- Copy any extra keys from user not in default
    for k, v in pairs(user) do
        if out[k] == nil then
            out[k] = type(v) == "table" and table_deepclone(v) or v
        end
    end

    return out
end

---@param tbl table? The table to count
---@return number The number of key-value pairs in the table
---Counts the number of elements in a table.
local function count(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Assign existing functions
=======

---@param tbl table
---@param fn function(value: any, key: any): any
---@return table
local function map(tbl, fn)
    local result = {}
    for k, v in pairs(tbl) do
        result[k] = fn(v, k)
    end
    return result
end

>>>>>>> upstream/main
table.contains = contains
table.matches = table_matches
table.deepclone = table_deepclone
table.merge = table_merge
table.shuffle = shuffle
<<<<<<< HEAD
table.prettyprint = jsonPrettyPrint

-- Assign new functions - Dabz
table.removeValue = removeValue
table.indexOf = indexOf
table.addUnique = addUnique
table.mergeTables = mergeTables
table.filter = filter
table.map = map
table.safeMerge = safeMerge
table.count = count
=======
table.map = map
>>>>>>> upstream/main

local frozenNewIndex = function(self) error(('cannot set values on a frozen table (%s)'):format(self), 2) end
local _rawset = rawset

---@param tbl table
---@param index any
---@param value any
---@return table
function rawset(tbl, index, value)
    if table.isfrozen(tbl) then
        frozenNewIndex(tbl)
    end

    return _rawset(tbl, index, value)
end

---Makes a table read-only, preventing further modification. Unfrozen tables stored within `tbl` are still mutable.
---@generic T : table
---@param tbl T
---@return T
function table.freeze(tbl)
    local copy = table.clone(tbl)
    local metatbl = getmetatable(tbl)

    table.wipe(tbl)
    setmetatable(tbl, {
        __index = metatbl and setmetatable(copy, metatbl) or copy,
        __metatable = 'readonly',
        __newindex = frozenNewIndex,
        __len = function() return #copy end,
        ---@diagnostic disable-next-line: redundant-return-value
        __pairs = function() return next, copy end,
    })

    return tbl
end

---Return true if `tbl` is set as read-only.
---@param tbl table
---@return boolean
function table.isfrozen(tbl)
    return getmetatable(tbl) == 'readonly'
end

return lib.table
