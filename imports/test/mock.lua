-- Mock functions (lib.test.fn) and spies (lib.test.spy). Spies push their
-- restoration entries onto a module-level array; the runner drains it after
-- every test so suites stay isolated.

local M = {
    pendingRestores = {},
}

---@generic R
---@param impl? fun(...): R
---@return MockFn<R>
function M.fn(impl)
    local mock
    mock = setmetatable({
        _isMock = true,
        _impl = impl,
        _returnValue = nil,
        _hasReturnValue = false,
        calls = {},
        callCount = 0,
        lastCall = nil,
    }, {
        __call = function(self, ...)
            local args = { ... }
            self.calls[#self.calls + 1] = args
            self.callCount = self.callCount + 1
            self.lastCall = args
            if self._hasReturnValue then return self._returnValue end
            if self._impl then return self._impl(...) end
        end,
    })

    function mock:mockReturnValue(v)
        self._returnValue = v
        self._hasReturnValue = true
        return self
    end

    function mock:mockImplementation(f)
        self._impl = f
        self._hasReturnValue = false
        return self
    end

    function mock:mockClear()
        self.calls = {}
        self.callCount = 0
        self.lastCall = nil
        return self
    end

    function mock:mockReset()
        self:mockClear()
        self._impl = nil
        self._hasReturnValue = false
        self._returnValue = nil
        return self
    end

    return mock
end

---@param obj table
---@param key string
---@return MockFn
function M.spy(obj, key)
    if type(obj) ~= 'table' then error("spy(obj, key): obj must be a table", 2) end
    if type(key) ~= 'string' then error("spy(obj, key): key must be a string", 2) end
    local original = rawget(obj, key)
    if original == nil then
        local mt = getmetatable(obj)
        if mt and type(mt.__index) == 'table' and mt.__index[key] ~= nil then
            lib.print.warn(('spy on inherited method %q, patching directly on object'):format(key))
            original = mt.__index[key]
        end
    end
    local m = M.fn(original)
    obj[key] = m
    M.pendingRestores[#M.pendingRestores + 1] = { obj = obj, key = key, original = original }
    return m
end

function M.restoreAll()
    local list = M.pendingRestores
    for i = #list, 1, -1 do
        local r = list[i]
        r.obj[r.key] = r.original
        list[i] = nil
    end
end

return M
