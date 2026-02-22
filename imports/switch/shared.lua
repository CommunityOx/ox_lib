--[[
    https://github.com/communityox/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 KodeRed <https://github.com/Kode-Red>
]]

--- @alias SwitchMatch any|fun(val:any):boolean|"default"|any[]
--- @alias BreakFn     fun():nil
--- @class SwitchCase
--- @field match  SwitchMatch
--- @field action fun(breakFn:BreakFn, ...:any):any
--- @alias SwitchCases SwitchCase[]

local _cache = setmetatable({}, { __mode = "k" })
local t_unpack = table.unpack

-- compile once per cases to a fast dispatcher (kept local; not exported)
--- @param cases SwitchCases
--- @return fun(value:any|any[], fallthrough:boolean|nil, ...:any):any
local function compile(cases)
    local map, preds, defaultIndex = {}, {}, nil
    local n = #cases

    -- Pre-index: single values + list entries -> first matching index
    for i = 1, n do
        local m = cases[i].match
        local mt = type(m)
        if m == "default" then
            defaultIndex = i
        elseif mt == "function" then
            preds[#preds + 1] = i
        elseif mt == "table" then
            for j = 1, #m do
                local v = m[j]
                if map[v] == nil then map[v] = i end
            end
        else
            if map[m] == nil then map[m] = i end
        end
    end

    -- Find earliest matching case index for a single value
    local function resolveOne(v)
        local i = map[v]
        if i ~= nil then return i end
        for k = 1, #preds do
            local pi = preds[k]
            if cases[pi].match(v) then return pi end
        end
        return nil
    end

    -- From a list of values, pick the earliest matching index among them
    local function resolveFromList(list)
        local best
        -- exact/list map hits (O(1) each)
        for vi = 1, #list do
            local idx = map[list[vi]]
            if idx and (not best or idx < best) then best = idx end
        end
        -- predicates only if no direct hit
        if not best then
            for k = 1, #preds do
                local pi = preds[k]
                local pred = cases[pi].match
                for vi = 1, #list do
                    if pred(list[vi]) then best = pi; break end
                end
                if best then break end
            end
        end
        return best
    end

    return function(value, fallthrough, ...)
        local stop, res
        local function breakFn() stop = true end

        local startIndex
        if type(value) == "table" then
            startIndex = resolveFromList(value) or defaultIndex
        else
            startIndex = resolveOne(value) or defaultIndex
        end
        if not startIndex then return nil end

        if fallthrough then
            local i = startIndex
            while i <= n do
                res = cases[i].action(breakFn, ...)
                if stop then break end
                i = i + 1
            end
            return res
        else
            return cases[startIndex].action(breakFn, ...)
        end
    end
end

--- Switch API (value first, cases third).
--- Call as:
---   lib.switch(value, fallthrough, cases, ...)       -- value is a single value
---   lib.switch({v1, v2, ...}, true, cases, ...)      -- value is a list; picks earliest match; with fallthrough runs forward
--- @generic R
--- @param valueOrList any|any[]          -- single value OR list of values to test
--- @param fallthrough boolean|nil         -- true = allow fallthrough; false/nil = stop at first
--- @param cases SwitchCases
--- @param ... any
--- @return R|any
function lib.switch(valueOrList, fallthrough, cases, ...)
    local dispatch = _cache[cases]
    if not dispatch then
        dispatch = compile(cases)
        _cache[cases] = dispatch
    end
    return dispatch(valueOrList, fallthrough, ...)
end

return lib.switch
