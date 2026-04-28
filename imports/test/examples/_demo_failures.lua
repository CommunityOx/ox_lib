-- Tests that intentionally fail so you can see how the reporter formats failures.
-- Useful when developing the framework itself. Keep these small and obvious.

lib.test.describe('failing examples (intentional)', function()
    lib.test.it('toBe primitive mismatch', function()
        lib.test.expect(1 + 1):toBe(3)
    end)

    lib.test.it('toEqual deep mismatch', function()
        lib.test.expect({ a = 1, b = 2 }):toEqual({ a = 1, b = 3 })
    end)

    lib.test.it('uncaught runtime error', function()
        error('this is an unexpected error from the test body')
    end)

    lib.test.it('pcall-protected error message', function()
        local _, err = pcall(function() error('inner failure') end)
        lib.test.expect(err):toMatch('different pattern')
    end)

    lib.test.it('toThrow but nothing thrown', function()
        lib.test.expect(function() return 'no error here' end):toThrow()
    end)

    lib.test.it('skipped test (informational)', function()
        error('this should never run because the next line marks it skipped')
    end)

    lib.test.it.skip('explicitly skipped', function()
        error('skipped should not run')
    end)
end)
