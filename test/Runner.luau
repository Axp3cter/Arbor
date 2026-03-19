--!strict
--!optimize 2
-- Runner.luau — Minimal test framework for Arbor.

-- State ------------------------------------------------------------------

local _suites: { Suite } = {}
local _current: Suite? = nil
local _passed = 0
local _failed = 0
local _skipped = 0
local _errors: { string } = {}

-- Types ------------------------------------------------------------------

type TestEntry = {
    name: string,
    fn: (() -> ())?,
    skipped: boolean,
}

type Suite = {
    name: string,
    tests: { TestEntry },
}

type Expectation = {
    toBe: (self: Expectation, expected: any) -> (),
    toEqual: (self: Expectation, expected: any) -> (),
    toBeNil: (self: Expectation) -> (),
    toBeCloseTo: (self: Expectation, expected: number, tolerance: number?) -> (),
    toThrow: (self: Expectation, pattern: string?) -> (),
    toBeTruthy: (self: Expectation) -> (),
    toBeFalsy: (self: Expectation) -> (),
    toBeGreaterThan: (self: Expectation, n: number) -> (),
    toBeLessThan: (self: Expectation, n: number) -> (),
    toHaveLength: (self: Expectation, n: number) -> (),
    toBeType: (self: Expectation, t: string) -> (),
    never: Expectation,
}

-- Private ----------------------------------------------------------------

local function deepEqual(a: any, b: any): boolean
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    for k, v in a do
        if not deepEqual(v, (b :: any)[k]) then
            return false
        end
    end
    for k in b do
        if (a :: any)[k] == nil then
            return false
        end
    end
    return true
end

local function fmt(value: any): string
    if type(value) == "string" then
        return `"{value}"`
    end
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function createExpectation(actual: any, negated: boolean): Expectation
    local function check(ok: boolean, msg: string): ()
        if negated then
            ok = not ok
        end
        if not ok then
            error(msg, 3)
        end
    end

    local expectation = {} :: any

    expectation.toBe = function(_s: Expectation, expected: any): ()
        local prefix = if negated then "not " else ""
        check(actual == expected, `expected {fmt(actual)} {prefix}to be {fmt(expected)}`)
    end

    expectation.toEqual = function(_s: Expectation, expected: any): ()
        local prefix = if negated then "not " else ""
        check(
            deepEqual(actual, expected),
            `expected {fmt(actual)} {prefix}to equal {fmt(expected)}`
        )
    end

    expectation.toBeNil = function(_s: Expectation): ()
        local prefix = if negated then "not " else ""
        check(actual == nil, `expected {fmt(actual)} {prefix}to be nil`)
    end

    expectation.toBeCloseTo = function(_s: Expectation, expected: number, tolerance: number?): ()
        local tol = tolerance or 0.001
        local prefix = if negated then "not " else ""
        check(
            math.abs((actual :: number) - expected) <= tol,
            `expected {actual} {prefix}to be close to {expected}`
        )
    end

    expectation.toThrow = function(_s: Expectation, pattern: string?): ()
        local ok, err = pcall(actual :: () -> ())
        local threw = not ok
        if pattern and threw then
            threw = string.find(tostring(err), pattern, 1, true) ~= nil
        end
        local prefix = if negated then "not " else ""
        check(threw, `expected function {prefix}to throw`)
    end

    expectation.toBeTruthy = function(_s: Expectation): ()
        local prefix = if negated then "not " else ""
        check(actual ~= nil and actual ~= false, `expected {fmt(actual)} {prefix}to be truthy`)
    end

    expectation.toBeFalsy = function(_s: Expectation): ()
        local prefix = if negated then "not " else ""
        check(actual == nil or actual == false, `expected {fmt(actual)} {prefix}to be falsy`)
    end

    expectation.toBeGreaterThan = function(_s: Expectation, n: number): ()
        local prefix = if negated then "not " else ""
        check((actual :: number) > n, `expected {actual} {prefix}to be greater than {n}`)
    end

    expectation.toBeLessThan = function(_s: Expectation, n: number): ()
        local prefix = if negated then "not " else ""
        check((actual :: number) < n, `expected {actual} {prefix}to be less than {n}`)
    end

    expectation.toHaveLength = function(_s: Expectation, n: number): ()
        local prefix = if negated then "not " else ""
        check(#(actual :: any) == n, `expected length {#(actual :: any)} {prefix}to be {n}`)
    end

    expectation.toBeType = function(_s: Expectation, t: string): ()
        local prefix = if negated then "not " else ""
        check(type(actual) == t, `expected type "{type(actual)}" {prefix}to be "{t}"`)
    end

    if not negated then
        expectation.never = createExpectation(actual, true)
    end

    return expectation :: Expectation
end

-- Public -----------------------------------------------------------------

local Runner = {}

function Runner.describe(name: string, fn: () -> ()): ()
    local suite: Suite = { name = name, tests = {} }
    table.insert(_suites, suite)
    _current = suite
    fn()
    _current = nil
end

function Runner.it(name: string, fn: () -> ()): ()
    assert(_current, "`it` must be called inside `describe`")
    table.insert((_current :: Suite).tests, { name = name, fn = fn, skipped = false })
end

function Runner.skip(name: string, _fn: () -> ()): ()
    assert(_current, "`skip` must be called inside `describe`")
    table.insert((_current :: Suite).tests, { name = name, fn = nil, skipped = true })
end

function Runner.expect(actual: any): Expectation
    return createExpectation(actual, false)
end

function Runner.run(): boolean
    print(
        "\n\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}"
    )
    print("  Arbor v2 Test Suite")
    print(
        "\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\n"
    )

    local totalStart = os.clock()
    for _, suite in _suites do
        print(`  {suite.name}`)
        local suiteStart = os.clock()
        for _, test in suite.tests do
            if test.skipped then
                _skipped += 1
                print(`    \u{25CB} skipped: {test.name}`)
                continue
            end
            local ok, err = pcall(test.fn :: () -> ())
            if ok then
                _passed += 1
                print(`    \u{2713} {test.name}`)
            else
                _failed += 1
                print(`    \u{2717} {test.name} - {err}`)
                table.insert(_errors, `{suite.name} > {test.name}: {err}`)
            end
        end
        print(`    ({string.format("%.1f", (os.clock() - suiteStart) * 1000)}ms)\n`)
    end

    local totalMs = (os.clock() - totalStart) * 1000
    local total = _passed + _failed + _skipped
    print(
        "\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}"
    )
    print(
        `  {_passed} passed, {_failed} failed, {_skipped} skipped, {total} total ({string.format(
            "%.0f",
            totalMs
        )}ms)`
    )

    if #_errors > 0 then
        print("\n  Failures:")
        for _, e in _errors do
            print(`    {e}`)
        end
    end

    print(
        "\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}"
    )
    return _failed == 0
end

return table.freeze(Runner)
