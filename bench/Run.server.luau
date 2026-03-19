--!strict
--!optimize 2
-- Benchmark runner for Arbor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arbor = require(ReplicatedStorage:WaitForChild("Arbor"))
local Scenarios =
    require(ReplicatedStorage:WaitForChild("Arbor"):WaitForChild("bench"):WaitForChild("Scenarios"))

-- Constants --------------------------------------------------------------

local DURATION = 5
local TICKS_PER_FRAME = 1000

-- Private ----------------------------------------------------------------

type BenchConfig = {
    name: string,
    root: Arbor.Node,
    defaults: { [string]: any },
}

local function runBench(config: BenchConfig): ()
    local board = Arbor.board(config.defaults)
    local ctx = Arbor.context(config.root, board, nil)
    local samples: { number } = {}
    local startTime = os.clock()

    while os.clock() - startTime < DURATION do
        local frameStart = os.clock()
        for _ = 1, TICKS_PER_FRAME do
            ctx:tick()
        end
        table.insert(samples, os.clock() - frameStart)
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

    ctx:destroy()
end

-- Run --------------------------------------------------------------------

print(
    "\n\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}"
)
print("  Arbor Benchmark Suite")
print(
    "\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\n"
)

runBench({ name = "Simple Condition", root = Scenarios.SimpleCondition, defaults = {} })
runBench({
    name = "Shallow Sequence (3 conditions)",
    root = Scenarios.ShallowSequence,
    defaults = {},
})
runBench({ name = "Deep Sequence (20 levels)", root = Scenarios.DeepSequence, defaults = {} })
runBench({
    name = "Wide Selector (50 children, fallthrough)",
    root = Scenarios.WideSelectorFallthrough,
    defaults = {},
})
runBench({
    name = "Combat Tree (selector + sequences)",
    root = Scenarios.CombatTree,
    defaults = Scenarios.COMBAT_DEFAULTS,
})

-- Multi-context benchmark.
do
    local AGENT_COUNT = 100
    local root = Scenarios.CombatTree
    local contexts: { Arbor.Context } = {}
    for _ = 1, AGENT_COUNT do
        local board = Arbor.board(Scenarios.COMBAT_DEFAULTS)
        table.insert(contexts, Arbor.context(root, board, nil))
    end

    local samples: { number } = {}
    local startTime = os.clock()
    while os.clock() - startTime < DURATION do
        local frameStart = os.clock()
        for _, ctx in contexts do
            ctx:tick()
        end
        table.insert(samples, os.clock() - frameStart)
        RunService.Heartbeat:Wait()
    end
    table.sort(samples)
    local median = samples[math.ceil(#samples / 2)]
    print(`  Multi-Agent ({AGENT_COUNT} contexts, shared tree)`)
    print(`    Median: {string.format("%.4f", median * 1000)}ms / frame`)
    print(`    Samples: {#samples}`)

    for _, ctx in contexts do
        ctx:destroy()
    end
end

print(
    "\n\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}"
)
