--!strict
--!optimize 2
-- Benchmark runner for Arbor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arbor = require(ReplicatedStorage:WaitForChild("Arbor"))
local Scenarios =
    require(ReplicatedStorage:WaitForChild("Arbor"):WaitForChild("bench"):WaitForChild("Scenarios"))

-- Constants -----------------------------------------------------------

local DURATION = 5
local TICKS_PER_FRAME = 1000

-- Private -------------------------------------------------------------

type BenchConfig = {
    name: string,
    tree: Arbor.Tree,
    board: Arbor.Blackboard,
}

local function runBench(config: BenchConfig): ()
    local ctx = Arbor.createContext(config.board, nil)
    local samples: { number } = {}
    local startTime = os.clock()
    while os.clock() - startTime < DURATION do
        local frameStart = os.clock()
        for _ = 1, TICKS_PER_FRAME do
            config.tree:tick(ctx)
        end
        local elapsed = os.clock() - frameStart
        table.insert(samples, elapsed)
        RunService.Heartbeat:Wait()
    end
    table.sort(samples)
    local median = samples[math.ceil(#samples / 2)]
    local p95 = samples[math.ceil(#samples * 0.95)]
    local ticksPerSec = TICKS_PER_FRAME / median
    print(`  {config.name}`)
    print(`    Median: {string.format("%.2f", median * 1000)}ms / {TICKS_PER_FRAME} ticks`)
    print(`    P95:    {string.format("%.2f", p95 * 1000)}ms / {TICKS_PER_FRAME} ticks`)
    print(`    Throughput: {string.format("%.0f", ticksPerSec)} ticks/sec`)
    print(`    Samples: {#samples}`)
    print("")
end

-- Run -----------------------------------------------------------------

print(
    "\n══════════════════════════════════════════════════════════════"
)
print("  Arbor Benchmark Suite")
print(
    "══════════════════════════════════════════════════════════════\n"
)

runBench({
    name = "Simple Condition",
    tree = Arbor.tree(Scenarios.SimpleCondition),
    board = Arbor.createBoard({}),
})

runBench({
    name = "Shallow Sequence (3 conditions)",
    tree = Arbor.tree(Scenarios.ShallowSequence),
    board = Arbor.createBoard({}),
})

runBench({
    name = "Deep Sequence (20 levels)",
    tree = Arbor.tree(Scenarios.DeepSequence),
    board = Arbor.createBoard({}),
})

runBench({
    name = "Wide Selector (50 children, fallthrough)",
    tree = Arbor.tree(Scenarios.WideSelectorFallthrough),
    board = Arbor.createBoard({}),
})

runBench({
    name = "Combat Tree (selector + sequences)",
    tree = Arbor.tree(Scenarios.CombatTree),
    board = Arbor.createBoard(Scenarios.COMBAT_DEFAULTS),
})

-- Multi-context benchmark.
do
    local AGENT_COUNT = 100
    local tree = Arbor.tree(Scenarios.CombatTree)
    local contexts: { Arbor.Context } = {}
    for _ = 1, AGENT_COUNT do
        local board = Arbor.createBoard(Scenarios.COMBAT_DEFAULTS)
        table.insert(contexts, Arbor.createContext(board, nil))
    end
    local samples: { number } = {}
    local startTime = os.clock()
    while os.clock() - startTime < DURATION do
        local frameStart = os.clock()
        for _, ctx in contexts do
            tree:tick(ctx)
        end
        table.insert(samples, os.clock() - frameStart)
        RunService.Heartbeat:Wait()
    end
    table.sort(samples)
    local median = samples[math.ceil(#samples / 2)]
    print(`  Multi-Agent ({AGENT_COUNT} contexts, shared tree)`)
    print(`    Median: {string.format("%.4f", median * 1000)}ms / frame`)
    print(`    Samples: {#samples}`)
end

print(
    "\n══════════════════════════════════════════════════════════════"
)
