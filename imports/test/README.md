# lib.test

Unit-test framework for FiveM resources. Server-side, runs inside the FiveM runtime, modeled on Vitest.

```lua
lib.test.describe('math', function()
    lib.test.it('adds', function()
        lib.test.expect(1 + 1):toBe(2)
    end)
end)
```

## Setup

In your `fxmanifest.lua`:

```lua
dependency 'ox_lib'

ox_test_dir 'tests'

server_scripts {
    '@ox_lib/init.lua',
    'server/your_code.lua',
}
```

Drop test files anywhere under `tests/`, named `*.test.lua`. They auto-load when discovery runs.

## Run

From the server console:

```
oxtest                       # run ox_lib's bundled examples
oxtest my_resource           # run tests in my_resource
oxtest my_resource auth      # filter by substring
```

For JSON output (CI):

```
set ox:test:reporter "json"
oxtest my_resource
```

Or programmatically:

```lua
local result = exports['my_resource']:runOxTests('auth', 'console')
print(result.passed, result.failed)
```

## Writing tests

### `describe` / `it`

```lua
lib.test.describe('Inventory', function()
    lib.test.it('starts empty', function()
        local inv = Inventory:new()
        lib.test.expect(inv:count('bread')):toBe(0)
    end)
end)
```

### `it.skip`, `it.only`, `it.each`

```lua
lib.test.it.skip('not ready', function() end)

lib.test.it.only('focused', function() end) -- skips everything else

lib.test.it.each({ {1,1,2}, {2,3,5} })('adds %s + %s = %s', function(case)
    lib.test.expect(case[1] + case[2]):toBe(case[3])
end)
```

### Hooks

```lua
lib.test.describe('db', function()
    local db
    lib.test.beforeAll(function() db = Database.connect() end)
    lib.test.afterAll(function() db:close() end)
    lib.test.beforeEach(function() db:reset() end)
    lib.test.afterEach(function() end)
end)
```

Outer `beforeEach` runs before inner. `afterEach` reverses.

## Matchers

Every matcher chains with `.never` to invert.

| Matcher                                         | Passes when                                                   |
| ----------------------------------------------- | ------------------------------------------------------------- |
| `:toBe(x)`                                      | `actual == x` (reference equality)                            |
| `:toEqual(x)`                                   | deep equal, handles cycles                                    |
| `:toBeTruthy()` / `:toBeFalsy()` / `:toBeNil()` | obvious                                                       |
| `:toBeGreaterThan(n)` / `:toBeLessThan(n)`      | numeric                                                       |
| `:toBeCloseTo(n, decimals?)`                    | within `0.5 * 10^-decimals`, default 2                        |
| `:toBeCallable()`                               | function, or table with `__call` (FiveM function refs, mocks) |
| `:toContain(x)`                                 | string contains substring, or table contains element (deep)   |
| `:toHaveLength(n)`                              | strings or arrays                                             |
| `:toMatch(pattern)`                             | Lua pattern, not regex                                        |
| `:toThrow(pattern?)`                            | calling actual throws; optional pattern matches the error     |
| `:toHaveBeenCalled()`                           | mock called at least once                                     |
| `:toHaveBeenCalledTimes(n)`                     | exact count                                                   |
| `:toHaveBeenCalledWith(...)`                    | any call deep-equals these args                               |

```lua
lib.test.expect(value).never:toBe(0)
lib.test.expect({1,2}).never:toEqual({1,2,3})
```

### Asymmetric matchers

For partial matches inside `:toEqual` or `:toHaveBeenCalledWith`:

```lua
lib.test.expect(user):toEqual({
    id = 1,
    name = 'alice',
    createdAt = lib.test.expect.any('number'),
})

lib.test.expect(emit):toHaveBeenCalledWith(
    lib.test.expect.objectContaining({ event = 'login' })
)
```

| Matcher                           | Matches                                       |
| --------------------------------- | --------------------------------------------- |
| `expect.any(typeName)`            | any value where `type(v) == typeName`         |
| `expect.anything()`               | any non-nil                                   |
| `expect.callable()`               | any callable: function or table with `__call` |
| `expect.objectContaining(subset)` | table where every key in `subset` matches     |
| `expect.arrayContaining(subset)`  | array containing every element of `subset`    |

## Mocks

```lua
local m = lib.test.fn():mockReturnValue(42)
m('hello')
lib.test.expect(m):toHaveBeenCalledWith('hello')
lib.test.expect(m()):toBe(42)
```

| API                        | Effect                          |
| -------------------------- | ------------------------------- |
| `lib.test.fn(impl?)`       | new mock, optional initial impl |
| `m:mockReturnValue(v)`     | always return `v`               |
| `m:mockImplementation(fn)` | replace impl                    |
| `m:mockClear()`            | wipe call history, keep impl    |
| `m:mockReset()`            | wipe everything                 |
| `m.calls`                  | `any[][]` of every call         |
| `m.callCount`              | integer                         |
| `m.lastCall`               | last args, or nil               |

## Spies

`lib.test.spy(obj, key)` patches `obj[key]` with a mock that wraps the original. Auto-restored after the test.

```lua
lib.test.it('emits a metric', function()
    local s = lib.test.spy(Metrics, 'emit')
    Inventory:save()
    lib.test.expect(s):toHaveBeenCalledWith('inventory.save')
end)
```

`mockReturnValue`, `mockImplementation`, etc. work on spies too.

## Async

Three styles. Pick one per test.

```lua
-- 1. Return a promise.
lib.test.it('async', function()
    local p = promise.new()
    SetTimeout(50, function() p:resolve(42) end)
    return p:next(function(v)
        lib.test.expect(v):toBe(42)
    end, function(err) error(err) end)
end)

-- 2. done() callback.
lib.test.it('callback', function(done)
    SetTimeout(30, function() done() end)
end)

-- 3. Citizen.Await inline.
lib.test.it('await', function()
    local p = promise.new()
    SetTimeout(40, function() p:resolve('ok') end)
    lib.test.expect(Citizen.Await(p)):toBe('ok')
end)
```

### Timeouts

Default 5000 ms per test. Override per test:

```lua
lib.test.it('slow', function(done)
    SetTimeout(8000, function() done() end)
end, 10000)
```

A timeout reports as `timeout`, not `fail`.

## Run options

```lua
lib.test.run({
    reporter = 'console',  -- 'console' | 'json' | TestReporter table
    filter   = 'auth',     -- substring on 'suite > test' path, case-insensitive
    timeout  = 5000,       -- default per-test timeout (ms)
    bail     = false,      -- stop on first failure
})
```

Returns:

```lua
{
    passed   = 12,
    failed   = 1,
    skipped  = 2,
    timedOut = 1,
    duration = 84.3,
    suites   = { ... },
    failures = { ... }, -- flat list of failing test results
}
```

## API

| Function                                                       | Purpose                                               |
| -------------------------------------------------------------- | ----------------------------------------------------- |
| `lib.test.describe(name, body)`                                | register a suite                                      |
| `lib.test.it(name, body, timeout?)`                            | register a test (also `.skip`, `.only`, `.each`)      |
| `lib.test.expect(actual)`                                      | chainable assertion; also exposes `expect.any` etc.   |
| `lib.test.fn(impl?)`                                           | mock function                                         |
| `lib.test.spy(obj, key)`                                       | wrap method, auto-restore                             |
| `lib.test.isCallable(v)`                                       | true if `v` is a function or callable table           |
| `lib.test.beforeEach` / `afterEach` / `beforeAll` / `afterAll` | hooks                                                 |
| `lib.test.discover(resource?)`                                 | recursively load `*.test.lua` from each `ox_test_dir` |
| `lib.test.register(path)`                                      | load one test file by `@resource/path.lua`            |
| `lib.test.run(opts?)`                                          | execute the registered tests                          |
| `lib.test.reset()`                                             | clear the registry                                    |

The `runOxTests` export gets registered automatically in any resource that declares `ox_test_dir`. That's how `oxtest <resource>` runs tests cross-VM:

```lua
exports['<resource>']:runOxTests(filter, reporter)
```

It does `reset` + `discover` + `run` inside the resource's own VM, where its globals exist.

### Custom reporters

A reporter is any table. Implement what you need:

```lua
lib.test.run({ reporter = {
    onRunStart   = function(_, root) end,
    onSuiteStart = function(_, suite, depth) end,
    onTestEnd    = function(_, test, result, depth) print(result.status, result.path) end,
    onSuiteEnd   = function(_, suite, depth) end,
    onRunEnd     = function(_, result) end,
}})
```

## Gotchas

- Lua patterns, not regex. `toMatch('foo.*bar')` is not regex.
- 50 ms tick floor per test (FiveM scheduler). Pure logic still tests fine, just don't expect microsecond timings.
- `it()` cannot nest inside `it()`. Use `describe`.
- Mocks from `fn()` are not auto-cleared. `m:mockClear()` in `beforeEach` if you reuse them. Spies are auto-restored.
- Promise rejection handler is required: `p:next(onResolve, onReject)`.
- `type(v) == 'function'` is wrong for FiveM cross-resource function references and for `lib.test.fn()` mocks (both are callable tables, so `type()` returns `'table'`). Use `lib.test.isCallable(v)` or assert via `:toBeCallable()` / `expect.callable()` in tests.

## Troubleshooting

| Symptom                                     | Cause                                                                                                        |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `No such command oxtest`                    | ox_lib was started before this feature. Restart it.                                                          |
| `resource "x" is missing`                   | Folder isn't in `resources/`, or you typed the wrong name. FiveM uses folder name, not the `name` directive. |
| `state is "stopped"`                        | Add `ensure x` to `server.cfg` or run from console.                                                          |
| `declares no ox_test_dir entries`           | Add `ox_test_dir 'tests'` to the resource's fxmanifest.                                                      |
| `0 *.test.lua file(s) found`                | Files don't end in `.test.lua` or path is wrong.                                                             |
| `failed to invoke runner in "x"`            | Resource didn't auto-load `lib.test`. Needs `dependency 'ox_lib'` and at least one `ox_test_dir`.            |
| `attempt to index a nil value (global 'X')` | Tests run in the target resource's VM. The global must be defined by that resource's `server_scripts`.       |

## Cookbook

### Test a class

```lua
-- server/inventory.lua
Inventory = lib.class('Inventory')
function Inventory:constructor(cap) self.cap = cap; self.items = {} end

-- tests/inventory.test.lua
lib.test.describe('Inventory', function()
    local inv
    lib.test.beforeEach(function() inv = Inventory:new(5) end)

    lib.test.it('starts empty', function()
        lib.test.expect(inv:count('bread')):toBe(0)
    end)
end)
```

### Test a function with global side effects

```lua
lib.test.it('logs on save', function()
    local spy = lib.test.spy(_G, 'print')
    saveUser({ id = 1 })
    lib.test.expect(spy):toHaveBeenCalledWith('saved user 1')
end)
```

### Test an async event handler

```lua
lib.test.it('updates the counter', function(done)
    Stats.reset()
    TriggerEvent('myresource:scored', 'alice', 5)
    SetTimeout(50, function()
        local ok, err = pcall(function()
            lib.test.expect(Stats.get('alice')):toBe(5)
        end)
        done(ok and nil or err)
    end)
end)
```

### Mock a dependency

```lua
lib.test.it('routes through metrics', function()
    local emit = lib.test.spy(Metrics, 'emit')
    Inventory.save({ id = 1 })
    lib.test.expect(emit):toHaveBeenCalledWith(
        'inventory.save',
        lib.test.expect.objectContaining({ id = 1 })
    )
end)
```

### Focus on one test while debugging

```lua
lib.test.it.only('the broken one', function() ... end)
```

Remove `.only` before committing.

### CI

```lua
local result = exports['my_resource']:runOxTests(nil, 'json')
if not result or result.failed > 0 or result.timedOut > 0 then
    print('TESTS FAILED')
end
```

## Examples

In `examples/`. Loaded by `oxtest` with no args.

| File                   | Covers                                                                  |
| ---------------------- | ----------------------------------------------------------------------- |
| `passing.lua`          | every matcher, happy path                                               |
| `assertion_errors.lua` | every matcher's failure message, via `:toThrow`                         |
| `async.lua`            | the three async styles, plus failure paths                              |
| `timeouts.lua`         | timeout detection                                                       |
| `hooks.lua`            | hooks and hook failures                                                 |
| `mocks.lua`            | `fn` and all mock helpers                                               |
| `spies.lua`            | spies, restoration, inherited methods                                   |
| `parameterized.lua`    | `it.each`                                                               |
| `matchers.lua`         | matcher edge cases, asymmetric matchers                                 |
| `run_options.lua`      | `it.only`, `bail`, `filter`, custom reporter, JSON, `register`, `reset` |
| `_demo_failures.lua`   | not auto-loaded; load manually to see failure output                    |
| `_register_helper.lua` | not auto-loaded; used by `run_options.lua`                              |
