-- it.each(cases)(nameFmt, body) runs the same body once per case.
-- nameFmt is a string.format pattern; %s is replaced with each table element.

lib.test.describe('parameterized tests', function()
    lib.test.it.each({
        { 1, 1, 2 },
        { 2, 3, 5 },
        { 10, 20, 30 },
    })('adds %s + %s = %s', function(case)
        lib.test.expect(case[1] + case[2]):toBe(case[3])
    end)

    lib.test.it.each({
        'apple',
        'banana',
        'cherry',
    })('string %s is non-empty', function(case)
        lib.test.expect(#case):toBeGreaterThan(0)
    end)

    lib.test.it.each({
        { 'a', 0 },
        { 'b', 1 },
        { 'c', 2 },
    })('letter %s is at offset %s from a', function(case)
        lib.test.expect(case[1]:byte() - ('a'):byte()):toBe(case[2])
    end)
end)
