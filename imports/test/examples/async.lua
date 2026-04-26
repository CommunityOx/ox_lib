-- Three flavors of async tests:
--   1. Return a promise runner awaits it.
--   2. Use the `done` callback call done() to pass, done(err) to fail.
--   3. Citizen.Await inside the body synchronous-looking, still async under the hood.
--
-- Failure cases (rejected promise, done(err)) are tested via runIsolated below
-- so the assertions about *failure* are themselves passing tests.

lib.test.describe('async tests', function()
    lib.test.it('returned promise resolves', function()
        local p = promise.new()
        SetTimeout(50, function() p:resolve(42) end)
        return p:next(function(value)
            lib.test.expect(value):toBe(42)
        end, function(err) error(err) end)
    end)

    lib.test.it('done() callback happy path', function(done)
        SetTimeout(30, function()
            local ok = (1 + 2 == 3)
            done(not ok and 'math is broken' or nil)
        end)
    end)

    lib.test.it('Citizen.Await inside body', function()
        local p = promise.new()
        SetTimeout(40, function() p:resolve('inline') end)
        local result = Citizen.Await(p)
        lib.test.expect(result):toBe('inline')
    end)

    lib.test.describe('failure paths', function()
        lib.test.it('a rejected returned promise marks the test failed', function()
            local result = lib.test.runIsolated(function()
                lib.test.it('rejects', function()
                    local p = promise.new()
                    SetTimeout(10, function() p:reject('async error') end)
                    return p
                end)
            end)
            lib.test.expect(result.failed):toBe(1)
            lib.test.expect(result.passed):toBe(0)
            lib.test.expect(result.failures[1].error):toMatch('async error')
        end)

        lib.test.it('done(err) marks the test failed', function()
            local result = lib.test.runIsolated(function()
                lib.test.it('done with err', function(done)
                    SetTimeout(10, function() done('explicit error') end)
                end)
            end)
            lib.test.expect(result.failed):toBe(1)
            lib.test.expect(result.failures[1].error):toMatch('explicit error')
        end)

        lib.test.it('a synchronous error in the body marks the test failed', function()
            local result = lib.test.runIsolated(function()
                lib.test.it('throws', function() error('boom') end)
            end)
            lib.test.expect(result.failed):toBe(1)
            lib.test.expect(result.failures[1].error):toMatch('boom')
        end)
    end)
end)
