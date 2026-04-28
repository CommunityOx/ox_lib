-- The suite tree, the current-context stack, and the only-mode flag.
-- State is exposed on the module table (M.root, M.stack, M.hasOnly) so other
-- modules (runner, dsl) can swap or read it.

local helpers = require '@ox_lib/imports/test/helpers'
local newHooks = helpers.newHooks

---@class TestHooks
---@field beforeAll function[]
---@field afterAll function[]
---@field beforeEach function[]
---@field afterEach function[]

---@class TestNode
---@field name string
---@field kind 'suite' | 'test'
---@field body? fun(done?: fun(err?: any)): any
---@field timeout? integer
---@field skipped boolean
---@field only boolean
---@field parent? TestNode
---@field children TestNode[]
---@field hooks TestHooks

local M = {
    ---@type TestNode
    root = nil,
    ---@type TestNode[]
    stack = nil,
    ---@type boolean
    hasOnly = false,
}

local function newRoot()
    return {
        name = '<root>',
        kind = 'suite',
        skipped = false,
        only = false,
        children = {},
        hooks = newHooks(),
    }
end

function M.reset()
    M.root = newRoot()
    M.stack = { M.root }
    M.hasOnly = false
end

M.reset()

function M.currentSuite() return M.stack[#M.stack] end

---@param name string
---@param body fun()
---@param flags? { skipped?: boolean, only?: boolean }
function M.pushSuite(name, body, flags)
    flags = flags or {}
    local suite = {
        name = name,
        kind = 'suite',
        skipped = flags.skipped or false,
        only = flags.only or false,
        parent = M.currentSuite(),
        children = {},
        hooks = newHooks(),
    }
    M.currentSuite().children[#M.currentSuite().children + 1] = suite
    M.stack[#M.stack + 1] = suite
    if flags.only then M.hasOnly = true end
    local ok, err = pcall(body)
    M.stack[#M.stack] = nil
    if not ok then
        error(("error inside describe('%s'): %s"):format(name, tostring(err)), 0)
    end
end

---@param name string
---@param body fun(done?: fun(err?: any)): any
---@param flags? { skipped?: boolean, only?: boolean, timeout?: integer }
function M.addTest(name, body, flags)
    flags = flags or {}
    if M.currentSuite().kind == 'test' then
        error("cannot nest 'it' inside another 'it'", 3)
    end
    local test = {
        name = name,
        kind = 'test',
        body = body,
        timeout = flags.timeout,
        skipped = flags.skipped or false,
        only = flags.only or false,
        parent = M.currentSuite(),
        children = {},
        hooks = newHooks(),
    }
    M.currentSuite().children[#M.currentSuite().children + 1] = test
    if flags.only then M.hasOnly = true end
end

return M
