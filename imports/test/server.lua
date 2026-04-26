-- lib.test entry point. Composes lib.test from its submodules, registers the
-- runOxTests export in every VM that loads this file, and registers the
-- /oxtest console command inside ox_lib only.

local helpers  = require '@ox_lib/imports/test/helpers'
local Registry = require '@ox_lib/imports/test/registry'
local DSL      = require '@ox_lib/imports/test/dsl'
local expect   = require '@ox_lib/imports/test/expect'
local Mock     = require '@ox_lib/imports/test/mock'
local Discover = require '@ox_lib/imports/test/discover'
local Runner   = require '@ox_lib/imports/test/runner'

---@class TestModule
---@field describe fun(name: string, body: fun()): nil
---@field it OxTestIt
---@field expect TestExpect
---@field fn fun<R>(impl?: fun(...): R): MockFn<R>
---@field spy fun(obj: table, key: string): MockFn
---@field isCallable fun(v: any): boolean
---@field run fun(opts?: TestRunOptions): TestResult
---@field runIsolated fun(setupFn: fun(), opts?: TestRunOptions): TestResult
---@field discover fun(resource?: string): integer
---@field register fun(path: string): nil
---@field reset fun(): nil
---@field beforeEach fun(cb: fun()): nil
---@field afterEach fun(cb: fun()): nil
---@field beforeAll fun(cb: fun()): nil
---@field afterAll fun(cb: fun()): nil

---@class TestExpect
---@overload fun<T>(actual: T): Expect<T>
---@field any fun(luaType: type): table
---@field anything fun(): table
---@field callable fun(): table
---@field objectContaining fun(subset: table): table
---@field arrayContaining fun(subset: any[]): table

---@class Expect<T>
---@field never Expect<T>
---@field toBe fun(self, expected: T): nil
---@field toEqual fun(self, expected: any): nil
---@field toBeTruthy fun(self): nil
---@field toBeFalsy fun(self): nil
---@field toBeNil fun(self): nil
---@field toBeGreaterThan fun(self, n: number): nil
---@field toBeLessThan fun(self, n: number): nil
---@field toBeCloseTo fun(self, n: number, decimals?: integer): nil
---@field toBeCallable fun(self): nil
---@field toContain fun(self, needle: any): nil
---@field toHaveLength fun(self, n: integer): nil
---@field toMatch fun(self, pattern: string): nil
---@field toThrow fun(self, pattern?: string): nil
---@field toHaveBeenCalled fun(self): nil
---@field toHaveBeenCalledTimes fun(self, n: integer): nil
---@field toHaveBeenCalledWith fun(self, ...): nil

---@class MockFn<R>
---@field calls any[][]
---@field callCount integer
---@field lastCall any[]?
---@field mockReturnValue fun(self, v: R): MockFn<R>
---@field mockImplementation fun(self, fn: fun(...): R): MockFn<R>
---@field mockClear fun(self): MockFn<R>
---@field mockReset fun(self): MockFn<R>

lib.test = {
    describe     = DSL.describe,
    it           = DSL.it,
    beforeEach   = DSL.beforeEach,
    afterEach    = DSL.afterEach,
    beforeAll    = DSL.beforeAll,
    afterAll     = DSL.afterAll,
    expect       = expect,
    fn           = Mock.fn,
    spy          = Mock.spy,
    isCallable   = helpers.isCallable,
    run          = Runner.run,
    runIsolated  = Runner.runIsolated,
    discover     = Discover.discover,
    register     = Discover.register,
    reset        = Registry.reset,
}

exports('runOxTests', function(filter, reporter)
    lib.test.reset()
    local count = lib.test.discover()
    if count == 0 then return nil end
    return lib.test.run({ reporter = reporter or 'console', filter = filter })
end)

if GetCurrentResourceName() == 'ox_lib' then
    lib.addCommand('oxtest', {
        help = 'Run lib.test suites discovered from a resource',
        params = {
            { name = 'resource', type = 'string', optional = true, help = 'resource to discover tests from' },
            { name = 'filter',   type = 'string', optional = true, help = 'substring filter on test paths' },
        },
    }, function(_, args)
        local target = args.resource
        local reporter = GetConvar('ox:test:reporter', 'console')

        if target then
            local state = GetResourceState(target)
            if state == 'missing' or state == 'unknown' then
                lib.print.error(('resource %q is %s, copy it into resources/ and `ensure` it first'):format(target, state))
                return
            end
            if state ~= 'started' then
                lib.print.warn(('resource %q state is %q (not started), run `ensure %s` first'):format(target, state, target))
                return
            end
            local ok, err = pcall(function()
                return exports[target]:runOxTests(args.filter, reporter)
            end)
            if not ok then
                lib.print.error(('failed to invoke runner in %q: %s'):format(target, tostring(err)))
                lib.print.warn(('does %q\'s fxmanifest declare any `ox_test_dir` entries?'):format(target))
            end
            return
        end

        -- No target: run ox_lib's bundled examples
        lib.test.reset()
        local examples = {
            'imports/test/examples/passing.lua',
            'imports/test/examples/assertion_errors.lua',
            'imports/test/examples/async.lua',
            'imports/test/examples/timeouts.lua',
            'imports/test/examples/hooks.lua',
            'imports/test/examples/mocks.lua',
            'imports/test/examples/spies.lua',
            'imports/test/examples/parameterized.lua',
            'imports/test/examples/matchers.lua',
            'imports/test/examples/run_options.lua',
        }
        for i = 1, #examples do
            local file = LoadResourceFile(cache.resource, examples[i])
            if file then
                local chunk, err = load(file, ('@@%s/%s'):format(cache.resource, examples[i]), 't', _ENV)
                if chunk then pcall(chunk) else lib.print.error(err) end
            end
        end
        lib.test.run({ reporter = reporter, filter = args.filter })
    end)
end

return lib.test
