-- Timeouts: the runner races each test against a per-test timeout (default 5000ms).
-- These tests use runIsolated so the assertion about *timeout detection* is
-- itself a passing test, not a real timeout in the outer run.

lib.test.describe('timeouts', function()
    lib.test.it('a test that never calls done() is marked as timeout', function()
        local result = lib.test.runIsolated(function()
            -- never invoke the done callback runner should detect timeout
            lib.test.it('hangs', function(_) end, 100)
        end)
        lib.test.expect(result.timedOut):toBe(1)
        lib.test.expect(result.passed):toBe(0)
        lib.test.expect(result.failures[1].status):toBe('timeout')
        lib.test.expect(result.failures[1].error):toMatch('TIMEOUT')
    end)

    lib.test.it('a returned promise that never settles times out', function()
        local result = lib.test.runIsolated(function()
            lib.test.it('promise never settles', function() return promise.new() end, 100)
        end)
        lib.test.expect(result.timedOut):toBe(1)
    end)

    lib.test.it('Citizen.Await on an unresolved promise times out', function()
        local result = lib.test.runIsolated(function()
            lib.test.it('await unresolved', function()
                Citizen.Await(promise.new())
            end, 100)
        end)
        lib.test.expect(result.timedOut):toBe(1)
    end)

    lib.test.it('a test that resolves in time passes', function()
        local result = lib.test.runIsolated(function()
            lib.test.it('quick', function(done)
                SetTimeout(20, function() done() end)
            end, 200)
        end)
        lib.test.expect(result.passed):toBe(1)
        lib.test.expect(result.timedOut):toBe(0)
    end)

    lib.test.it('per-test timeout overrides the run-level default', function()
        -- run() default is 5000ms; we lower it to 50ms via opts and the per-test
        -- override of 500ms wins, so the test passes.
        local result = lib.test.runIsolated(function()
            lib.test.it('takes 100ms but allows 500ms', function(done)
                SetTimeout(100, function() done() end)
            end, 500)
        end, { timeout = 50 })
        lib.test.expect(result.passed):toBe(1)
    end)

    lib.test.it('the run-level timeout default applies when the test does not set one', function()
        local result = lib.test.runIsolated(function()
            lib.test.it('no override', function(_) end) -- never resolves
        end, { timeout = 80 })
        lib.test.expect(result.timedOut):toBe(1)
    end)
end)
