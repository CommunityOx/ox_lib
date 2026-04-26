-- Tests that should all pass sanity checks on the framework itself.

lib.test.describe('passing examples', function()
    lib.test.it('compares primitives with toBe', function()
        lib.test.expect(1 + 1):toBe(2)
        lib.test.expect('hello'):toBe('hello')
        lib.test.expect(true):toBe(true)
    end)

    lib.test.it('does deep equality with toEqual', function()
        lib.test.expect({ a = 1, b = { 2, 3 } }):toEqual({ a = 1, b = { 2, 3 } })
    end)

    lib.test.it('supports the .never modifier', function()
        lib.test.expect(1).never:toBe(2)
        lib.test.expect({ 1, 2 }).never:toEqual({ 1, 2, 3 })
    end)

    lib.test.it('truthiness checks', function()
        lib.test.expect('any string'):toBeTruthy()
        lib.test.expect(0):toBeTruthy()
        lib.test.expect(false):toBeFalsy()
        lib.test.expect(nil):toBeNil()
    end)

    lib.test.it('numeric comparisons', function()
        lib.test.expect(10):toBeGreaterThan(5)
        lib.test.expect(3):toBeLessThan(7)
        lib.test.expect(1.0001):toBeCloseTo(1, 3)
    end)

    lib.test.it('strings and tables', function()
        lib.test.expect('the quick brown fox'):toContain('quick')
        lib.test.expect({ 'apple', 'banana' }):toContain('banana')
        lib.test.expect('abcd'):toHaveLength(4)
        lib.test.expect({ 1, 2, 3 }):toHaveLength(3)
        lib.test.expect('foo123'):toMatch('%d+')
    end)

    lib.test.it('toThrow catches errors', function()
        lib.test.expect(function() error('boom') end):toThrow('boom')
        lib.test.expect(function() return 1 end).never:toThrow()
    end)
end)
