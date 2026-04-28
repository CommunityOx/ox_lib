-- Console (default) and JSON reporters. A reporter is any table with optional
-- onRunStart / onSuiteStart / onSuiteEnd / onTestEnd / onRunEnd methods.

local helpers = require '@ox_lib/imports/test/helpers'
local indent = helpers.indent
local stripColors = helpers.stripColors

local M = {}

---@type TestReporter
M.console = {
    onRunStart = function(_, rootNode)
        print(('^5[ox_lib:test]^7 running %d top-level suite(s)'):format(#rootNode.children))
    end,
    onSuiteStart = function(_, suite, depth)
        if suite.parent then
            print(('%s^6%s^7'):format(indent(depth - 1), suite.name))
        end
    end,
    onTestEnd = function(_, _, result, depth)
        local marker, color
        if result.status == 'pass' then
            marker, color = '✔', '^2'
        elseif result.status == 'fail' then
            marker, color = '✘', '^1'
        elseif result.status == 'timeout' then
            marker, color = '⏱', '^1'
        else
            marker, color = '○', '^3'
        end
        local dur = result.duration > 0 and (' ^8(%.1fms)^7'):format(result.duration) or ''
        print(('%s%s%s^7 %s%s'):format(indent(depth - 1), color, marker, result.name, dur))
        if result.error then
            for line in tostring(result.error):gmatch('[^\n]+') do
                print(('%s  ^1%s^7'):format(indent(depth - 1), line))
            end
        end
    end,
    onRunEnd = function(_, result)
        local function suiteHasFailure(suite)
            for _, t in ipairs(suite.tests) do
                if t.status == 'fail' or t.status == 'timeout' then return true end
            end
            for _, c in ipairs(suite.children) do
                if suiteHasFailure(c) then return true end
            end
            return false
        end

        local totalSuites = #result.suites
        local failedSuites = 0
        for _, s in ipairs(result.suites) do
            if suiteHasFailure(s) then failedSuites = failedSuites + 1 end
        end
        local passedSuites = totalSuites - failedSuites
        local totalTests = result.passed + result.failed + result.skipped + result.timedOut

        if #result.failures > 0 then
            print('')
            print('^1Failures:^7')
            for i, f in ipairs(result.failures) do
                print(('  ^1%d) %s^7'):format(i, f.path))
                if f.error then
                    for line in tostring(f.error):gmatch('[^\n]+') do
                        print(('     %s'):format(line))
                    end
                end
            end
        end

        print('')
        print('^5[ox_lib:test]^7 ─── summary ───')

        local suiteParts = {}
        if failedSuites > 0 then suiteParts[#suiteParts + 1] = ('^1%d failed^7'):format(failedSuites) end
        if passedSuites > 0 then suiteParts[#suiteParts + 1] = ('^2%d passed^7'):format(passedSuites) end
        suiteParts[#suiteParts + 1] = ('%d total'):format(totalSuites)
        print(('Test Suites: %s'):format(table.concat(suiteParts, ', ')))

        local testParts = {}
        if result.failed > 0 then testParts[#testParts + 1] = ('^1%d failed^7'):format(result.failed) end
        if result.timedOut > 0 then testParts[#testParts + 1] = ('^1%d timeout^7'):format(result.timedOut) end
        if result.skipped > 0 then testParts[#testParts + 1] = ('^3%d skipped^7'):format(result.skipped) end
        if result.passed > 0 then testParts[#testParts + 1] = ('^2%d passed^7'):format(result.passed) end
        testParts[#testParts + 1] = ('%d total'):format(totalTests)
        print(('Tests:       %s'):format(table.concat(testParts, ', ')))

        local seconds = result.duration / 1000
        print(('Time:        %.3fs'):format(seconds))
    end,
}

---@type TestReporter
M.json = {
    _output = nil,
    onRunEnd = function(reporter, result)
        local function clean(r)
            return {
                name = stripColors(r.name),
                tests = (function()
                    local out = {}
                    for i, t in ipairs(r.tests) do
                        out[i] = {
                            name = stripColors(t.name),
                            path = stripColors(t.path),
                            status = t.status,
                            error = t.error and stripColors(t.error) or nil,
                            duration = t.duration,
                        }
                    end
                    return out
                end)(),
                children = (function()
                    local out = {}
                    for i, c in ipairs(r.children) do out[i] = clean(c) end
                    return out
                end)(),
                duration = r.duration,
            }
        end
        local payload = {
            passed = result.passed,
            failed = result.failed,
            skipped = result.skipped,
            timedOut = result.timedOut,
            duration = result.duration,
            suites = (function()
                local out = {}
                for i, s in ipairs(result.suites) do out[i] = clean(s) end
                return out
            end)(),
        }
        reporter._output = json.encode(payload, { indent = true, sort_keys = true })
        print(reporter._output)
    end,
}

-- Empty reporter: every `if reporter.onX then` guard sees nil and skips.
M.silent = {}

return M
