--!strict
--!optimize 2
-- Test framework for Arbor.

-- State ---------------------------------------------------------------

local _suites: { Suite } = {}
local _current: Suite? = nil
local _passed = 0
local _failed = 0
local _skipped = 0
local _errors: { string } = {}

-- Types ---------------------------------------------------------------

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

-- Private -------------------------------------------------------------

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
    for k, _ in b do
        if (a :: any)[k] == nil then
            return false
        end
    end
    return true
end

local function formatValue(value: any): string
    if type(value) == "string" then
        return `"{value}"`
    elseif value == nil then
        return "nil"
    else
        return tostring(value)
    end
end

local function pass(name: string): ()
    _passed += 1
    print(`    \u{2713} {name}`)
end

local function fail(name: string, reason: string): ()
    _failed += 1
    print(`    \u{2717} {name} - {reason}`)
    table.insert(_errors, `{_current and (_current :: Suite).name or "?"} > {name}: {reason}`)
end

local function createExpectation(actual: any, isNegated: boolean): Expectation
    local expectation = {} :: any
    expectation.toBe = function(_self: Expectation, expected: any): ()
        local ok = actual == expected
        if isNegated then
            ok = not ok
        end
        if not ok then
            local prefix = if isNegated then "not " else ""
            error(`expected {formatValue(actual)} {prefix}to be {formatValue(expected)}`)
        end
    end
    expectation.toEqual = function(_self: Expectation, expected: any): ()
        local ok = deepEqual(actual, expected)
        if isNegated then
            ok = not ok
        end
        if not ok then
            local prefix = if isNegated then "not " else ""
            error(`expected {formatValue(actual)} {prefix}to equal {formatValue(expected)}`)
        end
    end
    expectation.toBeNil = function(_self: Expectation): ()
        local ok = actual == nil
        if isNegated then
            ok = not ok
        end
        if not ok then
            local prefix = if isNegated then "not " else ""
            error(`expected {formatValue(actual)} {prefix}to be nil`)
        end
    end
    expectation.toBeCloseTo = function(_self: Expectation, expected: number, tolerance: number?): ()
        local tol = tolerance or 0.001
        local ok = math.abs((actual :: number) - expected) <= tol
        if isNegated then
            ok = not ok
        end
        if not ok then
            local prefix = if isNegated then "not " else ""
            error(`expected {actual} {prefix}to be close to {expected} (tolerance {tol})`)
        end
    end
    expectation.toThrow = function(_self: Expectation, pattern: string?): ()
        local ok, err = pcall(actual :: () -> ())
        local threw = not ok
        if pattern and threw then
            threw = string.find(tostring(err), pattern, 1, true) ~= nil
        end
        if isNegated then
            threw = not threw
        end
        if not threw then
            local prefix = if isNegated then "not " else ""
            if pattern then
                error(`expected function {prefix}to throw matching "{pattern}"`)
            else
                error(`expected function {prefix}to throw`)
            end
        end
    end
    expectation.toBeTruthy = function(_self: Expectation): ()
        local ok = actual ~= nil and actual ~= false
        if isNegated then
            ok = not ok
        end
        if not ok then
            local prefix = if isNegated then "not " else ""
            error(`expected {formatValue(actual)} {prefix}to be truthy`)
        end
    end
    expectation.toBeFalsy = function(_self: Expectation): ()
        local ok = actual == nil or actual == false
        if isNegated then
            ok = not ok
        end
        if not ok then
            local prefix = if isNegated then "not " else ""
            error(`expected {formatValue(actual)} {prefix}to be falsy`)
        end
    end
    expectation.toBeGreaterThan = function(_self: Expectation, n: number): ()
        local ok = (actual :: number) > n
        if isNegated then
            ok = not ok
        end
        if not ok then
            local prefix = if isNegated then "not " else ""
            error(`expected {actual} {prefix}to be greater than {n}`)
        end
    end
    expectation.toBeLessThan = function(_self: Expectation, n: number): ()
        local ok = (actual :: number) < n
        if isNegated then
            ok = not ok
        end
        if not ok then
            local prefix = if isNegated then "not " else ""
            error(`expected {actual} {prefix}to be less than {n}`)
        end
    end
    expectation.toHaveLength = function(_self: Expectation, n: number): ()
        local ok = #(actual :: any) == n
        if isNegated then
            ok = not ok
        end
        if not ok then
            local prefix = if isNegated then "not " else ""
            error(`expected length {#(actual :: any)} {prefix}to be {n}`)
        end
    end
    expectation.toBeType = function(_self: Expectation, t: string): ()
        local ok = type(actual) == t
        if isNegated then
            ok = not ok
        end
        if not ok then
            local prefix = if isNegated then "not " else ""
            error(`expected type "{type(actual)}" {prefix}to be "{t}"`)
        end
    end
    if not isNegated then
        expectation.never = createExpectation(actual, true)
    end
    return expectation :: Expectation
end

-- Public --------------------------------------------------------------

local Runner = {}

function Runner.describe(name: string, fn: () -> ()): ()
    local suite: Suite = { name = name, tests = {} }
    table.insert(_suites, suite)
    _current = suite
    fn()
    _current = nil
end

function Runner.it(name: string, fn: () -> ()): ()
    assert(_current, "[Arbor] `it` must be called inside `describe`")
    table.insert((_current :: Suite).tests, { name = name, fn = fn, skipped = false })
end

function Runner.skip(name: string, _fn: () -> ()): ()
    assert(_current, "[Arbor] `skip` must be called inside `describe`")
    table.insert((_current :: Suite).tests, { name = name, fn = nil, skipped = true })
end

function Runner.expect(actual: any): Expectation
    return createExpectation(actual, false)
end

function Runner.run(): boolean
    print(
        "\n\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}"
    )
    print("  Arbor Test Suite")
    print(
        "\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\n"
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
                pass(test.name)
            else
                fail(test.name, tostring(err))
            end
        end
        local suiteMs = (os.clock() - suiteStart) * 1000
        print(`    ({string.format("%.1f", suiteMs)}ms)\n`)
    end
    local totalMs = (os.clock() - totalStart) * 1000
    local total = _passed + _failed + _skipped
    print(
        "\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}"
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
        "\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}"
    )
    return _failed == 0
end

return table.freeze(Runner)
