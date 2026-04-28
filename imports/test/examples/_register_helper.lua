-- Loaded by run_options.lua to verify lib.test.register works. Must define
-- exactly two passing tests (the test asserts result.passed == 2).
-- Underscore-prefixed so the /oxtest demo loop ignores it.

lib.test.it('registered helper test 1', function()
    lib.test.expect(true):toBe(true)
end)

lib.test.it('registered helper test 2', function()
    lib.test.expect(1 + 1):toBe(2)
end)
