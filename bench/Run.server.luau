--!strict
--!optimize 2
-- Benchmark runner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Scenarios =
    require(ReplicatedStorage:WaitForChild("bt"):WaitForChild("bench"):WaitForChild("Scenarios"))
local bt = require(ReplicatedStorage:WaitForChild("bt"))

-- Constants --------------------------------------------------------------

local DURATION = 3
local TICKS_PER_FRAME = 1000

-- Private ----------------------------------------------------------------

local function bench(name: string, setup: () -> () -> ()): ()
    local tickFn = setup()
    local samples: { number } = {}
    local startTime = os.clock()

    while os.clock() - startTime < DURATION do
        local frameStart = os.clock()
        for _ = 1, TICKS_PER_FRAME do
            tickFn()
        end
        table.insert(samples, os.clock() - frameStart)
        RunService.Heartbeat:Wait()
    end

    table.sort(samples)
    local n = #samples
    local median = samples[math.ceil(n / 2)]
    local p99 = samples[math.ceil(n * 0.99)]
    local tps = TICKS_PER_FRAME / median

    print(`  {name}`)
    print(`    Median: {string.format("%.3f", median * 1000)}ms / {TICKS_PER_FRAME} ticks`)
    print(`    P99:    {string.format("%.3f", p99 * 1000)}ms`)
    print(`    Throughput: {string.format("%.0f", tps)} ticks/sec`)
    print("")
end

-- Run --------------------------------------------------------------------

local LINE = string.rep("\u{2550}", 60)

print(`\n{LINE}`)
print("  bt Benchmark Suite")
print(`{LINE}\n`)

-- Leaf cost isolation
print("  --- Leaf Nodes ---\n")

bench("Check (predicate + board read)", function()
    local ctx = bt.bind(Scenarios.CheckLeaf, { hp = 100 }, nil)
    return function()
        ctx:tick(0)
    end
end)

bench("Simple action (function + board write)", function()
    local ctx = bt.bind(Scenarios.SimpleAction, { x = 0 }, nil)
    return function()
        ctx:tick(0)
    end
end)

bench("Running action (returns running every tick)", function()
    local ctx = bt.bind(Scenarios.RunningAction, {}, nil)
    return function()
        ctx:tick(0)
    end
end)

bench("Wait (dt accumulation, always running)", function()
    local ctx = bt.bind(Scenarios.WaitLeaf, {}, nil)
    return function()
        ctx:tick(0.016)
    end
end)

bench("Poll (os.clock + interval check)", function()
    local ctx = bt.bind(Scenarios.PollLeaf, { scanned = false }, nil)
    return function()
        ctx:tick(0)
    end
end)

-- Composite overhead
print("  --- Composites ---\n")

bench("Selector (5 fail + 1 running, re-eval from top)", function()
    local board = { a = false, b = false, c = false, d = false, e = false }
    local ctx = bt.bind(Scenarios.SelectorFallthrough, board, nil)
    ctx:tick(0) -- prime
    return function()
        ctx:tick(0)
    end
end)

bench("Sequence (2 pass + 1 running, sticky resume)", function()
    local ctx = bt.bind(Scenarios.SequenceResume, {}, nil)
    ctx:tick(0) -- prime: first 2 pass, child 3 running → stores index
    return function()
        ctx:tick(0)
    end
end)

bench("Parallel (1 resolved + 2 running)", function()
    local ctx = bt.bind(Scenarios.ParallelMixed, {}, nil)
    ctx:tick(0) -- prime
    return function()
        ctx:tick(0)
    end
end)

bench("Deep nesting (20 levels of sequence → check)", function()
    local ctx = bt.bind(Scenarios.DeepNesting, {}, nil)
    return function()
        ctx:tick(0)
    end
end)

bench("Wide selector (50 children, last succeeds)", function()
    local ctx = bt.bind(Scenarios.WideFallthrough, {}, nil)
    return function()
        ctx:tick(0)
    end
end)

-- Decorator cost
print("  --- Decorators ---\n")

bench("Single decorator (invert)", function()
    local ctx = bt.bind(Scenarios.SingleDecorator, {}, nil)
    return function()
        ctx:tick(0)
    end
end)

bench("Chained decorators (timeout → retry → guard)", function()
    local ctx = bt.bind(Scenarios.ChainedDecorators, {}, nil)
    return function()
        ctx:tick(0)
    end
end)

-- Halt cost
print("  --- Halt Cost ---\n")

bench("Priority switch: halt 10-deep subtree", function()
    --[[
        Setup: child 2 (10-deep running subtree) is active.
        Each measured tick: toggle win=true → child 1 succeeds → halt cascade.
        Then toggle win=false → child 2 re-enters.
        This measures the actual cost of a priority switch.
    ]]
    local board = { win = false }
    local ctx = bt.bind(Scenarios.HaltCascade, board, nil)
    ctx:tick(0) -- prime: child 1 fails, deep subtree running
    local flip = false
    return function()
        flip = not flip
        board.win = flip
        ctx:tick(0)
    end
end)

-- Real-world
print("  --- Real World ---\n")

bench("Combat tree (polls + cooldowns + parallel)", function()
    local combat = Scenarios.CombatTree
    local board = table.clone(combat.board)
    local ctx = bt.bind(combat.tree, board, nil)
    ctx:tick(0.016)
    return function()
        ctx:tick(0.016)
    end
end)

-- Multi-context
do
    local AGENT_COUNT = 100
    local combat = Scenarios.CombatTree
    local contexts: { bt.Context } = {}
    for _ = 1, AGENT_COUNT do
        local board = table.clone(combat.board)
        local ctx = bt.bind(combat.tree, board, nil)
        ctx:tick(0.016) -- prime
        table.insert(contexts, ctx)
    end

    bench(`Multi-agent ({AGENT_COUNT} contexts, shared tree)`, function()
        return function()
            for _, ctx in contexts do
                ctx:tick(0.016)
            end
        end
    end)

    for _, ctx in contexts do
        ctx:destroy()
    end
end

print(LINE)
