-- describe / it / hooks. Pure registration; nothing runs until run() walks
-- the tree.

local Registry = require '@ox_lib/imports/test/registry'
local helpers = require '@ox_lib/imports/test/helpers'

---@alias TestBodyDone fun(err?: any)
---@alias TestBody fun(done?: TestBodyDone): any

---@class OxTestIt
---@overload fun(name: string, body: TestBody, timeout?: integer): nil
---@field skip fun(name: string, body?: TestBody): nil
---@field only fun(name: string, body: TestBody, timeout?: integer): nil
---@field each fun<T>(cases: T[]): fun(nameFmt: string, body: fun(case: T)): nil

local M = {}

---@param name string
---@param body fun()
function M.describe(name, body)
    if type(name) ~= 'string' then error("describe(name, body): name must be a string", 2) end
    if type(body) ~= 'function' then error("describe(name, body): body must be a function", 2) end
    Registry.pushSuite(name, body)
end

local it = setmetatable({}, {
    __call = function(_, name, body, timeout)
        if type(name) ~= 'string' then error("it(name, body, timeout?): name must be a string", 2) end
        if type(body) ~= 'function' then error("it(name, body, timeout?): body must be a function", 2) end
        Registry.addTest(name, body, { timeout = timeout })
    end,
})

function it.skip(name, body)
    Registry.addTest(name, body or function() end, { skipped = true })
end

function it.only(name, body, timeout)
    Registry.addTest(name, body, { only = true, timeout = timeout })
end

function it.each(cases)
    return function(nameFmt, body)
        if type(nameFmt) ~= 'string' then error("it.each(...)(name, body): name must be a string", 2) end
        if type(body) ~= 'function' then error("it.each(...)(name, body): body must be a function", 2) end
        for i = 1, #cases do
            local case = cases[i]
            local name
            if type(case) == 'table' then
                local args = {}
                for j = 1, #case do args[j] = helpers.formatValue(case[j]) end
                local ok, formatted = pcall(string.format, nameFmt, table.unpack(args))
                name = ok and formatted or ('%s [%d]'):format(nameFmt, i)
            else
                local ok, formatted = pcall(string.format, nameFmt, helpers.formatValue(case))
                name = ok and formatted or ('%s [%d]'):format(nameFmt, i)
            end
            Registry.addTest(name, function() body(case) end, {})
        end
    end
end

M.it = it

function M.beforeEach(cb) local h = Registry.currentSuite().hooks; h.beforeEach[#h.beforeEach + 1] = cb end
function M.afterEach(cb)  local h = Registry.currentSuite().hooks; h.afterEach[#h.afterEach + 1] = cb end
function M.beforeAll(cb)  local h = Registry.currentSuite().hooks; h.beforeAll[#h.beforeAll + 1] = cb end
function M.afterAll(cb)   local h = Registry.currentSuite().hooks; h.afterAll[#h.afterAll + 1] = cb end

return M
