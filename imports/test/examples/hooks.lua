-- beforeAll / afterAll run once per suite. beforeEach / afterEach wrap every test.
-- Hooks accumulate up the suite tree: outer beforeEach runs first, inner runs second.

lib.test.describe('hooks', function()
    local counter

    lib.test.beforeAll(function()
        counter = { value = 0, beforeAllRan = true }
    end)

    lib.test.beforeEach(function()
        counter.value = counter.value + 1
    end)

    lib.test.afterEach(function()
        -- runs even when the test fails
    end)

    lib.test.afterAll(function()
        counter = nil
    end)

    lib.test.it('beforeAll initialised state', function()
        lib.test.expect(counter.beforeAllRan):toBe(true)
    end)

    lib.test.it('beforeEach incremented before this test', function()
        lib.test.expect(counter.value):toBeGreaterThan(0)
    end)

    lib.test.describe('nested suite', function()
        local nestedCounter = 0

        lib.test.beforeEach(function()
            nestedCounter = nestedCounter + 1
        end)

        lib.test.it('outer + inner beforeEach both run', function()
            lib.test.expect(counter.value):toBeGreaterThan(0)
            lib.test.expect(nestedCounter):toBeGreaterThan(0)
        end)
    end)

    lib.test.describe('hook failures', function()
        lib.test.it('a throwing beforeEach marks each test in the suite as failed', function()
            local result = lib.test.runIsolated(function()
                lib.test.describe('s', function()
                    lib.test.beforeEach(function() error('beforeEach blew up') end)
                    lib.test.it('a', function() end)
                    lib.test.it('b', function() end)
                end)
            end)
            lib.test.expect(result.failed):toBe(2)
            lib.test.expect(result.passed):toBe(0)
            lib.test.expect(result.failures[1].error):toMatch('beforeEach failed')
        end)

        lib.test.it('a throwing beforeAll fails every test in the suite', function()
            local result = lib.test.runIsolated(function()
                lib.test.describe('s', function()
                    lib.test.beforeAll(function() error('beforeAll blew up') end)
                    lib.test.it('a', function() end)
                    lib.test.it('b', function() end)
                    lib.test.it('c', function() end)
                end)
            end)
            lib.test.expect(result.failed):toBe(3)
            lib.test.expect(result.failures[1].error):toMatch('beforeAll failed')
        end)

        lib.test.it('a throwing afterEach is collected alongside test results', function()
            local result = lib.test.runIsolated(function()
                lib.test.describe('s', function()
                    lib.test.afterEach(function() error('afterEach blew up') end)
                    lib.test.it('passes its own assertions', function()
                        lib.test.expect(1):toBe(1)
                    end)
                end)
            end)
            -- The test itself passed, but afterEach failed should be marked failed.
            lib.test.expect(result.failed):toBe(1)
            lib.test.expect(result.failures[1].error):toMatch('afterEach failed')
        end)
    end)
end)
