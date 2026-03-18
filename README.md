<h1 align="center">Arbor</h1>
<p align="center">Composable, typed behavior trees for Roblox AI.</p>
<p align="center">
  <a href="https://github.com/Axp3cter/Arbor/releases">Releases</a> ·
  <a href="#example">Example</a> ·
  <a href="#api-reference">API Reference</a>
</p>

## Install

**Wally (Luau)**

```toml
[dependencies]
arbor = "axp3cter/arbor@0.0.0"
```

**npm (roblox-ts)**

```sh
npm install @axpecter/arbor
```

**Direct download**

Grab the latest `.rbxm` from [Releases](https://github.com/Axp3cter/Arbor/releases).

## Example

```luau
local Arbor = require(path.to.Arbor)

-- Define a typed blackboard.
local board = Arbor.createBoard({
    target = nil :: Player?,
    health = 100,
    isAlert = false,
})

-- Conditions — pure reads, never RUNNING.
local hasTarget = Arbor.condition("HasTarget", function(b)
    return b:get("target") ~= nil
end)

local isHealthLow = Arbor.condition("IsHealthLow", function(b)
    return b:get("health") < 30
end)

-- Actions — three-phase for async work.
local chaseTarget = Arbor.action("ChaseTarget", {
    onStart = function(b, agent)
        agent:requestPath(b:get("target"))
        return Arbor.RUNNING
    end,
    onRunning = function(_b, agent)
        if agent:hasReachedDestination() then
            return Arbor.SUCCESS
        end
        return Arbor.RUNNING
    end,
    onHalted = function(_b, agent)
        agent:cancelPath()
    end,
})

local attack = Arbor.action("Attack", function(_b, agent)
    agent:playAnimation("Attack")
    return Arbor.SUCCESS
end)

local patrol = Arbor.action("Patrol", function(_b, agent)
    agent:moveToNextWaypoint()
    return Arbor.RUNNING
end)

-- Compose the tree.
local tree = Arbor.tree(Arbor.selector({
    -- Flee when health is low (aborts lower-priority branches).
    Arbor.observe("IsHealthLow", function(b)
        return b:get("health") < 30
    end, Arbor.Abort.LowerPriority, { "health" },
        Arbor.action("Flee", function(_b, agent)
            agent:flee()
            return Arbor.RUNNING
        end)
    ),

    -- Combat branch.
    Arbor.sequence({
        hasTarget,
        chaseTarget,
        attack,
    }),

    -- Fallback.
    patrol,
}))

-- One tree, many agents.
local ctx = Arbor.createContext(board, myNpcAgent)

-- Manual tick:
RunService.Heartbeat:Connect(function()
    tree:tick(ctx)
end)

-- Or use the built-in runner:
local runner = Arbor.createRunner(tree, ctx, { tickRate = 10 })
runner:start()
```

## Concepts

### Status

Every node returns one of three statuses:

| Status | Value | Meaning |
|---|---|---|
| `Arbor.SUCCESS` | `1` | Node completed successfully |
| `Arbor.FAILURE` | `2` | Node failed |
| `Arbor.RUNNING` | `3` | Node is still working, tick again next frame |

### Blackboard

Typed shared memory for an agent. Supports observer callbacks that fire on value changes — this is the backbone of the abort system.

### Abort Modes

Observers watch blackboard keys and trigger aborts when conditions change:

| Mode | Behavior |
|---|---|
| `Abort.None` | No reactive behavior |
| `Abort.Self` | Halts self when condition becomes false |
| `Abort.LowerPriority` | Aborts lower-priority running branches when condition becomes true |
| `Abort.LowerPriorityImmediateRestart` | Same as LowerPriority, immediately re-enters the branch |

### Reactive vs Memory Composites

| Type | Behavior |
|---|---|
| `sequence` / `selector` | **Memory**: resumes from the child that was RUNNING |
| `reactiveSequence` / `reactiveSelector` | **Reactive**: re-evaluates from child 0 every tick |

### Services

Periodic updaters attached to composite nodes. They fire on a timer while their parent subtree is active, updating blackboard values without consuming a tick slot.

## API Reference

### Leaf Nodes

| Function | Description |
|---|---|
| `condition(name, predicate)` | Pure boolean check. Returns SUCCESS or FAILURE. |
| `action(name, handler)` | Performs work. Accepts a simple function or `{ onStart, onRunning, onHalted }`. |

### Composites

| Function | Description |
|---|---|
| `sequence(children)` | Runs children left-to-right. Fails on first failure. Memory mode. |
| `reactiveSequence(children)` | Same as sequence but re-evaluates from child 0 every tick. |
| `selector(children)` | Runs children left-to-right. Succeeds on first success. Memory mode. |
| `reactiveSelector(children)` | Same as selector but re-evaluates from child 0 every tick. |
| `parallel(config, children)` | Ticks all children. Configurable success/failure policies. |

### Decorators

| Function | Description |
|---|---|
| `invert(child)` | Flips SUCCESS ↔ FAILURE. |
| `rep(child, { times })` | Repeats child N times before propagating SUCCESS. |
| `repeatUntilFail(child)` | Loops until child returns FAILURE, then returns SUCCESS. |
| `cooldown(child, { seconds })` | Gates child — can only succeed once per N seconds. |
| `timeout(child, { seconds })` | Fails if child is still RUNNING after N seconds. |
| `retry(child, { times })` | Retries on FAILURE up to N times. |
| `guard(condition, child)` | Only ticks child when condition returns SUCCESS. |

### Observer

| Function | Description |
|---|---|
| `observe(name, predicate, abortMode, keys, child)` | Watches blackboard keys and triggers aborts based on the mode. |

### Service

| Function | Description |
|---|---|
| `service(config, updater)` | Creates a periodic updater. |
| `attach(node, serviceDef)` | Attaches a service to a composite node. |

### Core

| Function | Description |
|---|---|
| `tree(root)` | Wraps a root node into a tickable tree. |
| `createBoard(defaults)` | Creates a typed blackboard with default values. |
| `createContext(board, agent)` | Creates a per-agent execution context. |
| `createRunner(tree, ctx, config?)` | Creates a tick-rate managed runner. |
