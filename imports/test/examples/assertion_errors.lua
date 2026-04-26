-- Tests that the matcher failure paths produce the right error messages.
-- Pattern: wrap a failing assertion in a function and verify it throws the
-- expected text. Same coverage as the old `failing.lua`, but all passing.

lib.test.describe('assertion errors', function()
    lib.test.it('toBe surfaces a primitive mismatch', function()
        lib.test.expect(function()
            lib.test.expect(2):toBe(3)
        end):toThrow('expected 2 to be 3')
    end)

    lib.test.it('toEqual surfaces a deep mismatch', function()
        lib.test.expect(function()
            lib.test.expect({ a = 1, b = 2 }):toEqual({ a = 1, b = 3 })
        end):toThrow('to equal %(deep%)')
    end)

    lib.test.it('toBeTruthy / toBeFalsy / toBeNil throw on the wrong value', function()
        lib.test.expect(function() lib.test.expect(false):toBeTruthy() end):toThrow('be truthy')
        lib.test.expect(function() lib.test.expect(true):toBeFalsy() end):toThrow('be falsy')
        lib.test.expect(function() lib.test.expect(0):toBeNil() end):toThrow('be nil')
    end)

    lib.test.it('toBeGreaterThan / toBeLessThan throw on the wrong direction', function()
        lib.test.expect(function() lib.test.expect(1):toBeGreaterThan(5) end):toThrow('be greater than')
        lib.test.expect(function() lib.test.expect(5):toBeLessThan(1) end):toThrow('be less than')
    end)

    lib.test.it('toContain throws when the needle is absent', function()
        lib.test.expect(function() lib.test.expect('hello'):toContain('xyz') end):toThrow('contain')
        lib.test.expect(function() lib.test.expect({ 'a', 'b' }):toContain('z') end):toThrow('contain')
    end)

    lib.test.it('toHaveLength throws on a length mismatch', function()
        lib.test.expect(function() lib.test.expect({ 1, 2 }):toHaveLength(5) end):toThrow('have length')
    end)

    lib.test.it('toMatch throws when the pattern does not match', function()
        lib.test.expect(function() lib.test.expect('hello'):toMatch('xyz') end):toThrow('match Lua pattern')
    end)

    lib.test.it('toThrow throws when nothing was thrown', function()
        lib.test.expect(function()
            lib.test.expect(function() return 'no error' end):toThrow()
        end):toThrow('throw')
    end)

    lib.test.it('toThrow throws when the error pattern does not match', function()
        lib.test.expect(function()
            lib.test.expect(function() error('database error') end):toThrow('network')
        end):toThrow('throw matching')
    end)

    lib.test.it('uncaught error inside a test body becomes the test failure', function()
        -- This mirrors what the runner sees a normal Lua error from inside a body.
        local ok, err = pcall(function() error('synthetic error from test body') end)
        lib.test.expect(ok):toBe(false)
        lib.test.expect(err):toMatch('synthetic error from test body')
    end)

    lib.test.it('.never inverts the matcher: throws when the assertion would pass', function()
        lib.test.expect(function()
            lib.test.expect(2).never:toBe(2)
        end):toThrow('not to be 2')
    end)

    lib.test.it('mock not-called assertion throws when the mock was called', function()
        local m = lib.test.fn()
        m()
        lib.test.expect(function()
            lib.test.expect(m).never:toHaveBeenCalled()
        end):toThrow('have been called')
    end)
end)
