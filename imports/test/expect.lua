-- Matchers (toBe, toEqual, ...), the chainable .never modifier, and asymmetric
-- matchers (expect.any, expect.objectContaining, ...).

local helpers = require '@ox_lib/imports/test/helpers'
local formatValue = helpers.formatValue
local deepEqual = helpers.deepEqual
local isCallable = helpers.isCallable

local Matchers = {}

---@param negated boolean
---@param pass boolean
---@param matcher string
---@param actual any
---@param expected any
---@param hint? string
local function asserts(negated, pass, matcher, actual, expected, hint)
    if negated then pass = not pass end
    if pass then return end
    local nv = negated and 'not ' or ''
    local msg
    if hint then
        msg = ('expected %s %s%s'):format(formatValue(actual), nv, hint)
    elseif expected ~= nil then
        msg = ('expected %s %sto %s %s'):format(formatValue(actual), nv, matcher, formatValue(expected))
    else
        msg = ('expected %s %sto %s'):format(formatValue(actual), nv, matcher)
    end
    error('AssertionError: ' .. msg, 0)
end

function Matchers:toBe(expected)
    asserts(self._negated, rawequal(self.actual, expected), 'be', self.actual, expected)
end

function Matchers:toEqual(expected)
    asserts(self._negated, deepEqual(self.actual, expected), 'equal (deep)', self.actual, expected)
end

function Matchers:toBeTruthy()
    asserts(self._negated, self.actual ~= nil and self.actual ~= false, 'be truthy', self.actual, nil, 'be truthy')
end

function Matchers:toBeFalsy()
    asserts(self._negated, self.actual == nil or self.actual == false, 'be falsy', self.actual, nil, 'be falsy')
end

function Matchers:toBeNil()
    asserts(self._negated, self.actual == nil, 'be nil', self.actual, nil, 'be nil')
end

function Matchers:toBeGreaterThan(n)
    asserts(self._negated, type(self.actual) == 'number' and self.actual > n, 'be greater than', self.actual, n)
end

function Matchers:toBeLessThan(n)
    asserts(self._negated, type(self.actual) == 'number' and self.actual < n, 'be less than', self.actual, n)
end

function Matchers:toBeCloseTo(n, decimals)
    decimals = decimals or 2
    local diff = math.abs((self.actual or 0) - n)
    asserts(self._negated, diff < 10 ^ -decimals * 0.5, 'be close to', self.actual, n,
        ('be close to %s (within %d decimals)'):format(formatValue(n), decimals))
end

function Matchers:toBeCallable()
    asserts(self._negated, isCallable(self.actual), 'be callable', self.actual, nil, 'be callable')
end

function Matchers:toContain(needle)
    local pass = false
    if type(self.actual) == 'string' and type(needle) == 'string' then
        pass = self.actual:find(needle, 1, true) ~= nil
    elseif type(self.actual) == 'table' then
        for _, v in pairs(self.actual) do
            if v == needle or deepEqual(v, needle) then
                pass = true
                break
            end
        end
    end
    asserts(self._negated, pass, 'contain', self.actual, needle)
end

function Matchers:toHaveLength(n)
    local len
    if type(self.actual) == 'string' then
        len = #self.actual
    elseif type(self.actual) == 'table' then
        len = #self.actual
    end
    asserts(self._negated, len == n, 'have length', self.actual, n,
        ('have length %s (received %s)'):format(formatValue(n), formatValue(len)))
end

function Matchers:toMatch(pattern)
    asserts(self._negated, type(self.actual) == 'string' and self.actual:find(pattern) ~= nil,
        'match', self.actual, pattern, ('match Lua pattern %s'):format(formatValue(pattern)))
end

function Matchers:toThrow(pattern)
    if not isCallable(self.actual) then
        error('AssertionError: expected actual to be callable for toThrow', 0)
    end
    local ok, err = pcall(self.actual)
    local pass
    if pattern then
        pass = (not ok) and type(err) == 'string' and err:find(pattern) ~= nil
        asserts(self._negated, pass, 'throw', '<function>', pattern,
            ('throw matching %s (got %s)'):format(formatValue(pattern), ok and 'no error' or formatValue(err)))
    else
        pass = not ok
        asserts(self._negated, pass, 'throw', '<function>', nil,
            ('throw (got %s)'):format(ok and 'no error' or 'error: ' .. tostring(err)))
    end
end

function Matchers:toHaveBeenCalled()
    if type(self.actual) ~= 'table' or not self.actual._isMock then
        error('AssertionError: expected actual to be a mock function (lib.test.fn)', 0)
    end
    asserts(self._negated, self.actual.callCount > 0, 'have been called', '<mock>', nil,
        ('have been called (was called %d times)'):format(self.actual.callCount))
end

function Matchers:toHaveBeenCalledTimes(n)
    if type(self.actual) ~= 'table' or not self.actual._isMock then
        error('AssertionError: expected actual to be a mock function (lib.test.fn)', 0)
    end
    asserts(self._negated, self.actual.callCount == n, 'have been called times', '<mock>', n,
        ('have been called %d times (was called %d)'):format(n, self.actual.callCount))
end

function Matchers:toHaveBeenCalledWith(...)
    if type(self.actual) ~= 'table' or not self.actual._isMock then
        error('AssertionError: expected actual to be a mock function (lib.test.fn)', 0)
    end
    local expected = { ... }
    local pass = false
    for i = 1, #self.actual.calls do
        if deepEqual(self.actual.calls[i], expected) then pass = true; break end
    end
    asserts(self._negated, pass, 'have been called with', '<mock>', expected)
end

---@generic T
---@param actual T
---@return Expect<T>
local function makeExpect(actual)
    -- `.never` is a property, not a method: `expect(x).never:toBe(y)` reads
    -- `.never` as a fresh negated Expect, then `:toBe` is the method call.
    local self = { actual = actual, _negated = false }
    return setmetatable(self, {
        __index = function(_, key)
            if key == 'never' then
                local neg = { actual = actual, _negated = true }
                return setmetatable(neg, { __index = function(_, k) return Matchers[k] end })
            end
            return Matchers[key]
        end,
    })
end

-- Asymmetric matchers ---------------------------------------------------------

local function expectAny(luaType)
    return {
        _isAsymmetric = true,
        match = function(_, value) return type(value) == luaType end,
        toString = function() return ('expect.any(%s)'):format(luaType) end,
    }
end

local function expectAnything()
    return {
        _isAsymmetric = true,
        match = function(_, value) return value ~= nil end,
        toString = function() return 'expect.anything()' end,
    }
end

local function expectCallable()
    return {
        _isAsymmetric = true,
        match = function(_, value) return isCallable(value) end,
        toString = function() return 'expect.callable()' end,
    }
end

local function expectObjectContaining(subset)
    return {
        _isAsymmetric = true,
        match = function(_, value)
            if type(value) ~= 'table' then return false end
            for k, v in pairs(subset) do
                if not deepEqual(v, value[k]) then return false end
            end
            return true
        end,
        toString = function() return ('expect.objectContaining(%s)'):format(formatValue(subset)) end,
    }
end

local function expectArrayContaining(subset)
    return {
        _isAsymmetric = true,
        match = function(_, value)
            if type(value) ~= 'table' then return false end
            for i = 1, #subset do
                local needle = subset[i]
                local found = false
                for j = 1, #value do
                    if deepEqual(needle, value[j]) then found = true; break end
                end
                if not found then return false end
            end
            return true
        end,
        toString = function() return ('expect.arrayContaining(%s)'):format(formatValue(subset)) end,
    }
end

local expect = setmetatable({
    any = expectAny,
    anything = expectAnything,
    callable = expectCallable,
    objectContaining = expectObjectContaining,
    arrayContaining = expectArrayContaining,
}, {
    __call = function(_, actual) return makeExpect(actual) end,
})

return expect
