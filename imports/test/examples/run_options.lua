-- Run-level options: it.only, bail, filter, custom reporter, JSON reporter,
-- register, reset. Each test uses runIsolated so the option's effect on the
-- whole run can be observed without disturbing the outer suite.

lib.test.describe('run options', function()

    lib.test.describe('it.only', function()
        lib.test.it('skips non-only tests when any only is registered', function()
            local result = lib.test.runIsolated(function()
                lib.test.it('not run',          function() error('should be skipped') end)
                lib.test.it.only('focused',     function() end)
                lib.test.it('also not run',     function() error('should be skipped') end)
            end)
            lib.test.expect(result.passed):toBe(1)
            lib.test.expect(result.skipped):toBe(2)
            lib.test.expect(result.failed):toBe(0)
        end)

        lib.test.it('only-mode visits only suites that contain a focused test', function()
            local result = lib.test.runIsolated(function()
                lib.test.describe('group A', function()
                    lib.test.it('a1', function() error('whole suite should be skipped') end)
                end)
                lib.test.describe('group B', function()
                    lib.test.it.only('b1', function() end)
                    lib.test.it('b2',      function() error('non-focused sibling') end)
                end)
            end)
            -- group A is skipped entirely (not iterated, so no skipped count for a1).
            -- Inside group B, only b1 runs; b2 is iterated and counted as skipped.
            lib.test.expect(result.passed):toBe(1)
            lib.test.expect(result.skipped):toBe(1)
            lib.test.expect(result.failed):toBe(0)
        end)
    end)

    lib.test.describe('it.skip', function()
        lib.test.it('skipped tests are not executed', function()
            local result = lib.test.runIsolated(function()
                lib.test.it.skip('disabled', function() error('should be skipped') end)
                lib.test.it('runs', function() end)
            end)
            lib.test.expect(result.passed):toBe(1)
            lib.test.expect(result.skipped):toBe(1)
        end)
    end)

    lib.test.describe('bail', function()
        lib.test.it('stops on the first failure when bail = true', function()
            local result = lib.test.runIsolated(function()
                lib.test.it('passes',          function() end)
                lib.test.it('fails',           function() error('boom') end)
                lib.test.it('would also pass', function() end)
            end, { bail = true })
            lib.test.expect(result.passed):toBe(1)
            lib.test.expect(result.failed):toBe(1)
            -- third test never ran (was not registered as skipped or passed)
            local total = result.passed + result.failed + result.skipped + result.timedOut
            lib.test.expect(total):toBe(2)
        end)

        lib.test.it('runs everything when bail is omitted', function()
            local result = lib.test.runIsolated(function()
                lib.test.it('passes',     function() end)
                lib.test.it('fails',      function() error('boom') end)
                lib.test.it('also passes',function() end)
            end)
            lib.test.expect(result.passed):toBe(2)
            lib.test.expect(result.failed):toBe(1)
        end)
    end)

    lib.test.describe('filter', function()
        lib.test.it('only runs tests whose path matches the substring', function()
            local result = lib.test.runIsolated(function()
                lib.test.describe('auth', function()
                    lib.test.it('login works',  function() end)
                    lib.test.it('logout works', function() end)
                end)
                lib.test.describe('inventory', function()
                    lib.test.it('add works',    function() end)
                end)
            end, { filter = 'auth' })
            lib.test.expect(result.passed):toBe(2)
            lib.test.expect(result.skipped):toBe(1)
        end)

        lib.test.it('filter is case-insensitive', function()
            local result = lib.test.runIsolated(function()
                lib.test.it('LoginFlow handles errors', function() end)
                lib.test.it('something else',           function() end)
            end, { filter = 'loginflow' })
            lib.test.expect(result.passed):toBe(1)
            lib.test.expect(result.skipped):toBe(1)
        end)
    end)

    lib.test.describe('custom reporter', function()
        lib.test.it('invokes reporter callbacks at the right times', function()
            local events = {}
            local reporter = {
                onRunStart   = function() events[#events + 1] = 'runStart' end,
                onSuiteStart = function() events[#events + 1] = 'suiteStart' end,
                onTestEnd    = function() events[#events + 1] = 'testEnd' end,
                onSuiteEnd   = function() events[#events + 1] = 'suiteEnd' end,
                onRunEnd     = function() events[#events + 1] = 'runEnd' end,
            }
            lib.test.runIsolated(function()
                lib.test.describe('s', function()
                    lib.test.it('a', function() end)
                    lib.test.it('b', function() end)
                end)
            end, { reporter = reporter })
            lib.test.expect(events):toEqual({
                'runStart', 'suiteStart', 'testEnd', 'testEnd', 'suiteEnd', 'runEnd',
            })
        end)

        lib.test.it('a reporter without all callbacks still works (silent reporter)', function()
            -- runIsolated's default is an empty reporter table every method
            -- is nil. The run still completes and produces a TestResult.
            local result = lib.test.runIsolated(function()
                lib.test.it('x', function() end)
            end)
            lib.test.expect(result.passed):toBe(1)
        end)
    end)

    lib.test.describe('json reporter', function()
        lib.test.it('produces parseable JSON output', function()
            -- The json reporter prints the encoded payload. Spy on print so we
            -- can capture it and round-trip through json.decode.
            local captured = {}
            local printSpy = lib.test.spy(_G, 'print')
            printSpy:mockImplementation(function(...)
                local parts = { ... }
                for i = 1, select('#', ...) do parts[i] = tostring(parts[i]) end
                captured[#captured + 1] = table.concat(parts, '\t')
                return nil
            end)

            lib.test.runIsolated(function()
                lib.test.describe('demo', function()
                    lib.test.it('passes', function() end)
                    lib.test.it('fails',  function() error('intentional') end)
                end)
            end, { reporter = 'json' })

            -- The JSON payload is printed in one print() call. Find it.
            local payload
            for i = 1, #captured do
                local ok, decoded = pcall(json.decode, captured[i])
                if ok and type(decoded) == 'table' and decoded.suites then
                    payload = decoded
                    break
                end
            end

            lib.test.expect(payload).never:toBeNil()
            lib.test.expect(payload.passed):toBe(1)
            lib.test.expect(payload.failed):toBe(1)
        end)
    end)

    lib.test.describe('register', function()
        lib.test.it('register loads a file and registers its tests', function()
            -- _register_helper.lua adds two tests to the registry when loaded.
            local result = lib.test.runIsolated(function()
                lib.test.register('@ox_lib/imports/test/examples/_register_helper.lua')
            end)
            lib.test.expect(result.passed):toBe(2)
        end)
    end)

    lib.test.describe('reset', function()
        lib.test.it('reset wipes any previously registered tests', function()
            -- Inside the isolated run we register a test, then reset, then
            -- register a different one. Only the second should run.
            local result = lib.test.runIsolated(function()
                lib.test.it('first',  function() error('should not run') end)
                lib.test.reset()
                lib.test.it('second', function() end)
            end)
            lib.test.expect(result.passed):toBe(1)
            lib.test.expect(result.failed):toBe(0)
        end)
    end)
end)
