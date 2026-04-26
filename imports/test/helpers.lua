-- Pure functions used across the test framework. No state.

local M = {}

---@param v any
---@return boolean
-- Returns true for plain functions and for tables with a __call metamethod
-- (FiveM cross-resource function refs, lib.test.fn() / spy() mocks).
function M.isCallable(v)
    local t = type(v)
    if t == 'function' then return true end
    if t == 'table' then
        local mt = getmetatable(v)
        return mt and type(mt.__call) == 'function' or false
    end
    return false
end

---@param value any
---@param depth? integer
---@param seen? table
---@return string
function M.formatValue(value, depth, seen)
    depth = depth or 0
    local t = type(value)
    if t == 'string' then return ("'%s'"):format(value) end
    if t == 'nil' then return 'nil' end
    if t == 'boolean' or t == 'number' then return tostring(value) end
    if t == 'function' then return '<function>' end
    if t == 'table' then
        if value._isAsymmetric then return value:toString() end
        if depth > 3 then return '{...}' end
        seen = seen or {}
        if seen[value] then return '<cycle>' end
        seen[value] = true
        local parts = {}
        local count = 0
        for k, val in pairs(value) do
            count = count + 1
            if count > 8 then
                parts[#parts + 1] = '...'; break
            end
            parts[#parts + 1] = ('[%s]=%s'):format(M.formatValue(k, depth + 1, seen), M.formatValue(val, depth + 1, seen))
        end
        return '{' .. table.concat(parts, ', ') .. '}'
    end
    return tostring(value)
end

---@param a any
---@param b any
---@param seen? table<table, table>
---@return boolean
function M.deepEqual(a, b, seen)
    -- Asymmetric matchers (expect.any, expect.objectContaining, ...) match
    -- anywhere in the comparison tree on either side.
    if type(a) == 'table' and a._isAsymmetric then return a:match(b) end
    if type(b) == 'table' and b._isAsymmetric then return b:match(a) end

    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return false end
    seen = seen or {}
    if seen[a] then return seen[a] == b end
    seen[a] = b
    local aCount = 0
    for k, v in pairs(a) do
        aCount = aCount + 1
        if not M.deepEqual(v, b[k], seen) then return false end
    end
    local bCount = 0
    for _ in pairs(b) do bCount = bCount + 1 end
    return aCount == bCount
end

---@param node TestNode
---@return string
function M.nodePath(node)
    local parts = {}
    local cur = node
    while cur and cur.parent do
        parts[#parts + 1] = cur.name
        cur = cur.parent
    end
    local out = {}
    for i = #parts, 1, -1 do out[#out + 1] = parts[i] end
    return table.concat(out, ' > ')
end

---@return TestHooks
function M.newHooks()
    return { beforeAll = {}, afterAll = {}, beforeEach = {}, afterEach = {} }
end

function M.indent(depth) return string.rep('  ', depth) end

---@param s any
---@return any
function M.stripColors(s)
    if type(s) ~= 'string' then return s end
    return (s:gsub('%^%d', ''))
end

return M
