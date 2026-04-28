-- Edge cases for matchers cycles, mixed types, empty values, Lua patterns.

lib.test.describe('matcher edge cases', function()
    lib.test.it('toEqual handles cyclic tables', function()
        local a = { name = 'a' }
        local b = { name = 'b' }
        a.peer = b
        b.peer = a

        local x = { name = 'a' }
        local y = { name = 'b' }
        x.peer = y
        y.peer = x

        lib.test.expect(a):toEqual(x)
    end)

    lib.test.it('toEqual differentiates extra keys', function()
        lib.test.expect({ 1, 2 }).never:toEqual({ 1, 2, 3 })
        lib.test.expect({ a = 1 }).never:toEqual({ a = 1, b = 2 })
    end)

    lib.test.it('toMatch uses Lua patterns, not regex', function()
        lib.test.expect('foo123bar'):toMatch('%a+%d+%a+')
        lib.test.expect('plain text'):toMatch('text$')
    end)

    lib.test.it('toContain on empty collections', function()
        lib.test.expect({}).never:toContain('anything')
        lib.test.expect('').never:toContain('x')
    end)

    lib.test.it('toContain uses deep equality for table elements', function()
        lib.test.expect({ { id = 1 }, { id = 2 } }):toContain({ id = 2 })
        lib.test.expect({ { id = 1 } }).never:toContain({ id = 99 })
    end)

    lib.test.it('toHaveBeenCalledWith uses deep equality on table args', function()
        local m = lib.test.fn()
        m({ user = 'alice', score = 5 })
        lib.test.expect(m):toHaveBeenCalledWith({ user = 'alice', score = 5 })
        lib.test.expect(m).never:toHaveBeenCalledWith({ user = 'alice', score = 99 })
    end)

    lib.test.it('toThrow with a pattern that does not match', function()
        local fn = function() error('database connection refused') end
        lib.test.expect(fn):toThrow('connection refused')
        lib.test.expect(fn).never:toThrow('timeout')
    end)

    lib.test.it('toBeCloseTo precision', function()
        lib.test.expect(0.1 + 0.2):toBeCloseTo(0.3, 5)
        lib.test.expect(0.1 + 0.2).never:toBe(0.3) -- floating point
    end)

    lib.test.describe('callable detection', function()
        lib.test.it('isCallable accepts plain functions', function()
            lib.test.expect(lib.test.isCallable(function() end)):toBe(true)
        end)

        lib.test.it('isCallable accepts callable tables (mocks, function refs)', function()
            local fnRef = setmetatable({}, { __call = function() end })
            lib.test.expect(lib.test.isCallable(fnRef)):toBe(true)
            lib.test.expect(lib.test.isCallable(lib.test.fn())):toBe(true)
        end)

        lib.test.it('isCallable rejects non-callables', function()
            lib.test.expect(lib.test.isCallable(nil)):toBe(false)
            lib.test.expect(lib.test.isCallable(42)):toBe(false)
            lib.test.expect(lib.test.isCallable('hello')):toBe(false)
            lib.test.expect(lib.test.isCallable({})):toBe(false)
            lib.test.expect(lib.test.isCallable({ __call = function() end })):toBe(false) -- __call must be in the metatable
        end)

        lib.test.it('toBeCallable matches functions and callable tables', function()
            lib.test.expect(function() end):toBeCallable()
            lib.test.expect(lib.test.fn()):toBeCallable()
            lib.test.expect(setmetatable({}, { __call = function() end })):toBeCallable()
            lib.test.expect({}).never:toBeCallable()
            lib.test.expect(42).never:toBeCallable()
        end)

        lib.test.it('expect.callable() works inside toEqual / toHaveBeenCalledWith', function()
            local handler = setmetatable({}, { __call = function() end })
            lib.test.expect({ id = 1, on = handler }):toEqual({
                id = 1,
                on = lib.test.expect.callable(),
            })

            local register = lib.test.fn()
            register('login', function() end)
            lib.test.expect(register):toHaveBeenCalledWith('login', lib.test.expect.callable())
        end)

        lib.test.it('toThrow accepts callable tables, not just functions', function()
            local thrower = setmetatable({}, {
                __call = function() error('boom from callable table') end,
            })
            lib.test.expect(thrower):toThrow('boom')
        end)
    end)

    lib.test.describe('asymmetric matchers', function()
        lib.test.it('expect.any matches by Lua type', function()
            lib.test.expect({ id = 1, name = 'alice' }):toEqual({
                id = lib.test.expect.any('number'),
                name = lib.test.expect.any('string'),
            })
        end)

        lib.test.it('expect.anything ignores the value but rejects nil', function()
            lib.test.expect({ value = 0 }):toEqual({ value = lib.test.expect.anything() })
            lib.test.expect({ value = nil }).never:toEqual({ value = lib.test.expect.anything() })
        end)

        lib.test.it('expect.objectContaining matches a superset', function()
            local user = { id = 1, name = 'alice', createdAt = 12345 }
            lib.test.expect(user):toEqual(lib.test.expect.objectContaining({ id = 1, name = 'alice' }))
        end)

        lib.test.it('expect.arrayContaining matches sub-elements in any order', function()
            lib.test.expect({ 'apple', 'banana', 'cherry' })
                :toEqual(lib.test.expect.arrayContaining({ 'cherry', 'apple' }))
        end)

        lib.test.it('compose with toHaveBeenCalledWith', function()
            local fn = lib.test.fn()
            fn({ event = 'login', userId = 42 })
            lib.test.expect(fn):toHaveBeenCalledWith(
                lib.test.expect.objectContaining({ event = 'login' })
            )
        end)
    end)
end)
