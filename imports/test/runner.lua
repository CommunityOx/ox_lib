-- The runner. Walks the registry, races each test against a per-test timeout,
-- collects results, and dispatches reporter callbacks. runIsolated swaps the
-- registry + spy state so tests can verify run-level behavior without
-- disturbing the active run.

local Registry = require '@ox_lib/imports/test/registry'
local Mock = require '@ox_lib/imports/test/mock'
local Reporter = require '@ox_lib/imports/test/reporter'
local helpers = require '@ox_lib/imports/test/helpers'
local nodePath = helpers.nodePath

---@alias TestStatus 'pass' | 'fail' | 'skip' | 'timeout'

---@class TestCaseResult
---@field name string
---@field path string
---@field status TestStatus
---@field error? string
---@field duration number

---@class SuiteResult
---@field name string
---@field tests TestCaseResult[]
---@field children SuiteResult[]
---@field duration number

---@class TestResult
---@field passed integer
---@field failed integer
---@field skipped integer
---@field timedOut integer
---@field duration number
---@field suites SuiteResult[]
---@field failures TestCaseResult[]

---@class TestRunOptions
---@field reporter? 'console' | 'json' | TestReporter
---@field filter? string
---@field timeout? integer
---@field bail? boolean

---@class TestReporter
---@field onRunStart? fun(self, root: TestNode)
---@field onSuiteStart? fun(self, suite: TestNode, depth: integer)
---@field onSuiteEnd? fun(self, suite: TestNode, depth: integer)
---@field onTestEnd? fun(self, test: TestNode, result: TestCaseResult, depth: integer)
---@field onRunEnd? fun(self, result: TestResult)

local DEFAULT_TIMEOUT <const> = 5000

local function isPromise(v)
    return type(v) == 'table' and type(v.next) == 'function' and v.state ~= nil
end

---@param test TestNode
---@param defaultTimeout integer
---@return boolean ok, string? err
local function runTestBody(test, defaultTimeout)
    -- Three completion modes:
    --   1. sync       function() ... end                 done on return
    --   2. promise    function() ... return p end        done when p settles
    --   3. done()     function(done) ... done() end      done when done is called
    -- nparams == 0 means mode 1 or 2 (no done arg). nparams > 0 means mode 3.
    -- `settled` no-ops whichever of {timeout, completion} arrives second.
    local p = promise.new()
    local settled = false
    local timeoutMs = test.timeout or defaultTimeout
    local timedOut = false

    local function complete(err)
        if settled then return end
        settled = true
        if err ~= nil then
            p:reject(err)
        else
            p:resolve(true)
        end
    end

    -- Timeout always fires; `settled` no-ops it if the test finished first.
    SetTimeout(timeoutMs, function()
        if settled then return end
        timedOut = true
        complete(('test timed out after %dms'):format(timeoutMs))
    end)

    CreateThread(function()
        local nparams = debug.getinfo(test.body, 'u').nparams
        local doneCalled = false
        local function done(err)
            if doneCalled then return end
            doneCalled = true
            complete(err)
        end

        local ok, ret
        if nparams > 0 then
            ok, ret = pcall(test.body, done)
        else
            ok, ret = pcall(test.body)
        end

        if not ok then return complete(ret) end
        if isPromise(ret) then
            ret:next(function() complete() end, function(e) complete(e) end)
            return
        end
        -- sync test, no promise returned: resolve. done-callback tests fall
        -- through and wait for `done`.
        if nparams == 0 then complete() end
    end)

    local ok, err = pcall(Citizen.Await, p)
    if not ok then
        if timedOut then return false, ('TIMEOUT: %s'):format(tostring(err)) end
        return false, tostring(err)
    end
    return true
end

---@param hooks function[]
---@return boolean ok, string? err
local function runHooks(hooks)
    for i = 1, #hooks do
        local ok, err = pcall(hooks[i])
        if not ok then return false, tostring(err) end
    end
    return true
end

---@param suite TestNode
---@return boolean
local function suiteContainsOnly(suite)
    for _, child in ipairs(suite.children) do
        if child.only then return true end
        if child.kind == 'suite' and suiteContainsOnly(child) then return true end
    end
    return false
end

---@param test TestNode
---@param onlyMode boolean
---@return boolean
local function shouldRunTest(test, onlyMode)
    -- onlyMode is the global `hasOnly` flag, set during registration when any
    -- it.only / describe.only is seen. Safe to read at run time because
    -- registration is sync and finishes before run() walks the tree.
    if not onlyMode then return true end
    if test.only then return true end
    -- A test also runs if any *ancestor* suite was marked .only.
    local cur = test.parent
    while cur do
        if cur.only then return true end
        cur = cur.parent
    end
    return false
end

---@param suite TestNode
---@param onlyMode boolean
---@return boolean
local function shouldVisitSuite(suite, onlyMode)
    if not onlyMode then return true end
    if suite.only then return true end
    return suiteContainsOnly(suite)
end

---@param node TestNode
---@param filter? string
---@return boolean
local function matchesFilter(node, filter)
    if not filter or filter == '' then return true end
    local path = nodePath(node):lower()
    return path:find(filter:lower(), 1, true) ~= nil
end

---@param ctx { reporter: TestReporter, result: TestResult, defaultTimeout: integer, filter?: string, bail: boolean, bailed: boolean, onlyMode: boolean }
---@return SuiteResult
local function runSuite(suite, depth, ctx)
    if ctx.reporter.onSuiteStart then ctx.reporter:onSuiteStart(suite, depth) end
    local suiteResult = { name = suite.name, tests = {}, children = {}, duration = 0 }
    local startTime = GetGameTimer()

    if not suite.skipped then
        local ok, err = runHooks(suite.hooks.beforeAll)
        if not ok then
            local function markFail(s)
                for _, child in ipairs(s.children) do
                    if child.kind == 'test' then
                        local tr = {
                            name = child.name,
                            path = nodePath(child),
                            status = 'fail',
                            error = ('beforeAll failed: %s'):format(err),
                            duration = 0,
                        }
                        suiteResult.tests[#suiteResult.tests + 1] = tr
                        ctx.result.failed = ctx.result.failed + 1
                        ctx.result.failures[#ctx.result.failures + 1] = tr
                        if ctx.reporter.onTestEnd then ctx.reporter:onTestEnd(child, tr, depth + 1) end
                    else
                        markFail(child)
                    end
                end
            end
            markFail(suite)
            suiteResult.duration = GetGameTimer() - startTime
            if ctx.reporter.onSuiteEnd then ctx.reporter:onSuiteEnd(suite, depth) end
            return suiteResult
        end
    end

    local function collectBeforeEach(node)
        local out = {}
        local chain = {}
        local cur = node.parent
        while cur do
            chain[#chain + 1] = cur
            cur = cur.parent
        end
        for i = #chain, 1, -1 do
            for _, h in ipairs(chain[i].hooks.beforeEach) do out[#out + 1] = h end
        end
        return out
    end

    local function collectAfterEach(node)
        local out = {}
        local cur = node.parent
        while cur do
            for _, h in ipairs(cur.hooks.afterEach) do out[#out + 1] = h end
            cur = cur.parent
        end
        return out
    end

    for _, child in ipairs(suite.children) do
        if ctx.bailed then break end

        if child.kind == 'suite' then
            if shouldVisitSuite(child, ctx.onlyMode) then
                local sub = runSuite(child, depth + 1, ctx)
                suiteResult.children[#suiteResult.children + 1] = sub
            end
        else
            local skipNode = suite.skipped or child.skipped or
                not shouldRunTest(child, ctx.onlyMode) or
                not matchesFilter(child, ctx.filter)

            if skipNode then
                local tr = {
                    name = child.name,
                    path = nodePath(child),
                    status = 'skip',
                    duration = 0,
                }
                suiteResult.tests[#suiteResult.tests + 1] = tr
                ctx.result.skipped = ctx.result.skipped + 1
                if ctx.reporter.onTestEnd then ctx.reporter:onTestEnd(child, tr, depth + 1) end
            else
                local hookOk, hookErr = runHooks(collectBeforeEach(child))
                local testStart = GetGameTimer()
                local ok, err
                if hookOk then
                    ok, err = runTestBody(child, ctx.defaultTimeout)
                else
                    ok = false
                    err = ('beforeEach failed: %s'):format(hookErr)
                end
                local duration = GetGameTimer() - testStart

                local afterOk, afterErr = runHooks(collectAfterEach(child))
                Mock.restoreAll()

                local status = 'pass'
                local errMsg
                if not ok then
                    if type(err) == 'string' and err:sub(1, 7) == 'TIMEOUT' then
                        status = 'timeout'
                        ctx.result.timedOut = ctx.result.timedOut + 1
                    else
                        status = 'fail'
                    end
                    errMsg = err
                elseif not afterOk then
                    status = 'fail'
                    errMsg = ('afterEach failed: %s'):format(afterErr)
                end

                local tr = {
                    name = child.name,
                    path = nodePath(child),
                    status = status,
                    error = errMsg,
                    duration = duration,
                }
                suiteResult.tests[#suiteResult.tests + 1] = tr
                if status == 'pass' then
                    ctx.result.passed = ctx.result.passed + 1
                elseif status == 'fail' then
                    ctx.result.failed = ctx.result.failed + 1
                    ctx.result.failures[#ctx.result.failures + 1] = tr
                    if ctx.bail then ctx.bailed = true end
                else -- 'timeout' (already counted in result.timedOut)
                    ctx.result.failures[#ctx.result.failures + 1] = tr
                    if ctx.bail then ctx.bailed = true end
                end
                if ctx.reporter.onTestEnd then ctx.reporter:onTestEnd(child, tr, depth + 1) end
            end
        end
    end

    if not suite.skipped then
        local ok, err = runHooks(suite.hooks.afterAll)
        if not ok then
            local tr = {
                name = '<afterAll>',
                path = nodePath(suite) .. ' > <afterAll>',
                status = 'fail',
                error = err,
                duration = 0,
            }
            suiteResult.tests[#suiteResult.tests + 1] = tr
            ctx.result.failed = ctx.result.failed + 1
            ctx.result.failures[#ctx.result.failures + 1] = tr
        end
    end

    suiteResult.duration = GetGameTimer() - startTime
    if ctx.reporter.onSuiteEnd then ctx.reporter:onSuiteEnd(suite, depth) end
    return suiteResult
end

local M = {}

---@param opts? TestRunOptions
---@return TestResult
function M.run(opts)
    opts = opts or {}
    local reporterOpt = opts.reporter or 'console'
    local reporter
    if reporterOpt == 'console' then
        reporter = Reporter.console
    elseif reporterOpt == 'json' then
        reporter = Reporter.json
    elseif type(reporterOpt) == 'table' then
        reporter = reporterOpt
    else
        error(("unknown reporter '%s'"):format(tostring(reporterOpt)), 2)
    end

    local result = {
        passed = 0,
        failed = 0,
        skipped = 0,
        timedOut = 0,
        duration = 0,
        suites = {},
        failures = {},
    }
    local startTime = GetGameTimer()

    if reporter.onRunStart then reporter:onRunStart(Registry.root) end

    local ctx = {
        reporter = reporter,
        result = result,
        defaultTimeout = opts.timeout or DEFAULT_TIMEOUT,
        filter = opts.filter,
        bail = opts.bail or false,
        bailed = false,
        onlyMode = Registry.hasOnly,
    }

    for _, child in ipairs(Registry.root.children) do
        if ctx.bailed then break end
        if child.kind == 'suite' and shouldVisitSuite(child, ctx.onlyMode) then
            result.suites[#result.suites + 1] = runSuite(child, 1, ctx)
        elseif child.kind == 'test' then
            -- top-level test (no enclosing describe): wrap in a synthetic suite
            local synth = {
                name = '<root>',
                kind = 'suite',
                skipped = false,
                only = false,
                parent = Registry.root,
                children = { child },
                hooks = helpers.newHooks(),
            }
            child.parent = synth
            result.suites[#result.suites + 1] = runSuite(synth, 1, ctx)
        end
    end

    result.duration = GetGameTimer() - startTime
    if reporter.onRunEnd then reporter:onRunEnd(result) end
    return result
end

---Run a self-contained mini-suite against a fresh registry, then restore the
---outer registry. Used to test framework features that affect the whole run
---(it.only, bail, filter, custom reporters) without disturbing the active run.
---@param setupFn fun()
---@param opts? TestRunOptions
---@return TestResult
function M.runIsolated(setupFn, opts)
    if type(setupFn) ~= 'function' then error('runIsolated: setupFn must be a function', 2) end

    -- Also swap pendingRestores: inner runs call restoreAll() after each test,
    -- which would otherwise wipe spies set up in the outer test.
    local savedRoot, savedStack, savedHasOnly = Registry.root, Registry.stack, Registry.hasOnly
    local savedRestores = Mock.pendingRestores
    Registry.reset()
    Mock.pendingRestores = {}

    local result, runErr
    local setupOk, setupErr = pcall(setupFn)
    if setupOk then
        local runOpts = {}
        if opts then
            for k, v in pairs(opts) do runOpts[k] = v end
        end
        if runOpts.reporter == nil then runOpts.reporter = Reporter.silent end
        local runOk, ret = pcall(M.run, runOpts)
        if runOk then result = ret else runErr = ret end
    end

    Registry.root, Registry.stack, Registry.hasOnly = savedRoot, savedStack, savedHasOnly
    Mock.pendingRestores = savedRestores

    if not setupOk then error('runIsolated setup error: ' .. tostring(setupErr), 2) end
    if runErr then error('runIsolated run error: ' .. tostring(runErr), 2) end
    return result
end

return M
