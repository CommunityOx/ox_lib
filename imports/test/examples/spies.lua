-- lib.test.spy(obj, key) replaces obj[key] with a mock that wraps the original.
-- Spies are auto-restored after each test ends, so suites stay isolated.

local Inventory = {
    add = function(self, item, qty) self.items[item] = (self.items[item] or 0) + qty end,
    count = function(self, item) return self.items[item] or 0 end,
}

local function newInventory()
    return setmetatable({ items = {} }, { __index = Inventory })
end

lib.test.describe('spies', function()
    lib.test.it('spies on a method and forwards to original', function()
        local inv = newInventory()
        local spy = lib.test.spy(Inventory, 'add')

        inv:add('bread', 2)
        inv:add('milk', 1)

        lib.test.expect(spy):toHaveBeenCalledTimes(2)
        lib.test.expect(spy.calls[1][2]):toBe('bread')
        lib.test.expect(spy.calls[1][3]):toBe(2)
        -- original ran too: items table updated
        lib.test.expect(inv:count('bread')):toBe(2)
    end)

    lib.test.it('spy is restored after the previous test', function()
        -- After the previous test ended, Inventory.add was restored to the
        -- original function. A live mock would be a callable table, so the
        -- type() check is the cleanest way to verify restoration.
        lib.test.expect(type(Inventory.add)):toBe('function')
    end)

    lib.test.it('mockReturnValue on a spy short-circuits the original', function()
        local inv = newInventory()
        local spy = lib.test.spy(Inventory, 'count')
        spy:mockReturnValue(999)

        lib.test.expect(inv:count('anything')):toBe(999)
        lib.test.expect(spy):toHaveBeenCalledWith(inv, 'anything')
    end)

    lib.test.it('spies on inherited methods (with warning)', function()
        -- The instance only has its own `items` field; `add` is inherited from
        -- the metatable's __index. Spy should still patch it on the instance
        -- and a warning is printed (visible above this line in the console).
        local inv = newInventory()
        local spy = lib.test.spy(inv, 'add')

        inv:add('cheese', 1)

        lib.test.expect(spy):toHaveBeenCalledTimes(1)
        lib.test.expect(spy.calls[1][2]):toBe('cheese')
        lib.test.expect(inv:count('cheese')):toBe(1)
    end)
end)
