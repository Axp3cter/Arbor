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
arbor = "axp3cter/arbor@1.0.0"
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

local action    = Arbor.action
local condition = Arbor.condition
local selector  = Arbor.selector
local sequence  = Arbor.sequence
local observe   = Arbor.observe
local guard     = Arbor.guard
local cooldown  = Arbor.cooldown
local timeout   = Arbor.timeout
local loop      = Arbor.loop
local wait      = Arbor.wait
local succeed   = Arbor.succeed
local random    = Arbor.random
local service   = Arbor.service
local Status    = Arbor.Status
local Abort     = Arbor.Abort

-- Typed blackboard with direct field access.
local board = Arbor.board({
    target  = nil :: Player?,
    health  = 100,
    ammo    = 30,
    isAlert = false,
})

-- Conditions — pure reads, never RUNNING.
local hasTarget   = condition("HasTarget", function(b) return b.target ~= nil end, { "target" })
local isHealthLow = condition("IsHealthLow", function(b) return b.health < 30 end, { "health" })
local hasAmmo     = condition("HasAmmo", function(b) return b.ammo > 0 end, { "ammo" })
local isAlert     = condition("IsAlert", function(b) return b.isAlert end, { "isAlert" })

-- Actions — simple or three-phase.
local chase = action("Chase", {
    start = function(b, agent)
        agent:requestPath(b.target)
        return Status.Running
    end,
    tick = function(_b, agent)
        return if agent:hasReachedDestination() then Status.Success else Status.Running
    end,
    halt = function(_b, agent)
        agent:cancelPath()
    end,
})

local attack = action("Attack", function(_b, agent)
    agent:playAnimation("Attack")
    return Status.Success
end)

local patrol = action("Patrol", function(_b, agent)
    agent:moveToNextWaypoint()
    return Status.Running
end)

-- Services — periodic updaters attached to composites.
local scanForTargets = service("ScanForTargets", 0.5, function(b, agent)
    b.target = agent:findNearestEnemy()
end)

-- Compose the tree.
local root = selector({
    observe(isHealthLow, Abort.Lower, action("Flee", function(_b, agent)
        agent:flee()
        return Status.Running
    end)),

    sequence({
        hasTarget,
        guard(hasAmmo, sequence({
            timeout(chase, 10),
            cooldown(attack, 0.5),
        })),
    }),

    loop(sequence({ patrol, wait(2) })),
}, {
    services = { scanForTargets },
})

-- One tree, many agents.
local ctx = Arbor.context(root, board, myNpcAgent)
ctx:start(10) -- tick 10 times per second

-- Cleanup when NPC is removed:
npcModel.Destroying:Connect(function()
    ctx:destroy()
end)
```

## Concepts

### Status

Every node returns one of three statuses:

| Status | Value | Meaning |
|---|---|---|
| `Status.Success` | `1` | Node completed successfully |
| `Status.Failure` | `2` | Node failed |
| `Status.Running` | `3` | Node is still working, tick again next frame |

### Blackboard

Typed shared memory for an agent. Read and write fields directly — `board.health`, `board.health = 50`. Writes fire observer callbacks automatically. Supports generalized iteration (`for k, v in board`).

### Abort Modes

Observers watch blackboard keys and trigger aborts when conditions change:

| Mode | Behavior |
|---|---|
| `Abort.Self` | Halts self when condition becomes false |
| `Abort.Lower` | Aborts lower-priority running branches when condition becomes true (one frame delay) |
| `Abort.Restart` | Same as Lower, immediately re-enters the branch (zero frame delay) |

### Memory vs Reactive Composites

Pass `{ reactive = true }` as the second argument to `sequence` or `selector`:

| Mode | Behavior |
|---|---|
| Memory (default) | Resumes from the child that was RUNNING |
| Reactive | Re-evaluates from child 0 every tick |

### Context Lifecycle

| Method | Purpose |
|---|---|
| `ctx:tick()` | Manual single tick |
| `ctx:start(hz?)` | Start managed runner at N Hz (omit for every frame) |
| `ctx:stop()` | Stop the managed runner |
| `ctx:destroy()` | Full cleanup: stop runner, halt nodes, unregister observers |
| `ctx:isRunning()` | Whether the managed runner is active |

## API Reference

### Leaf Nodes

| Function | Description |
|---|---|
| `condition(name, predicate, watchKeys?)` | Pure boolean check. Returns Success or Failure. Watch keys enable `observe`. |
| `action(name, handler)` | Performs work. Simple function fires every tick while active. |
| `action(name, { start, tick, halt })` | Three-phase form for async work. |
| `wait(seconds)` | Returns Running for N seconds, then Success. |

### Composites

| Function | Description |
|---|---|
| `sequence(children, config?)` | Runs children left-to-right. Fails on first failure. |
| `selector(children, config?)` | Runs children left-to-right. Succeeds on first success. |
| `parallel(children, config)` | Ticks all children. Numeric `succeed`/`fail` policies. |
| `random(children, weights?)` | Picks one child at random. Sticky while Running. |

### Decorators

| Function | Description |
|---|---|
| `invert(child)` | Flips Success ↔ Failure. |
| `succeed(child)` | Forces Success. Swallows Failure. |
| `fail(child)` | Forces Failure. Swallows Success. |
| `loop(child, count?)` | Repeats child. Omit count for infinite. |
| `cooldown(child, seconds)` | Gates child — can only succeed once per N seconds. |
| `timeout(child, seconds)` | Fails if child is still Running after N seconds. |
| `retry(child, times)` | Retries on Failure up to N times. |
| `guard(condition, child)` | Re-checks condition every tick before ticking child. |

### Observer

| Function | Description |
|---|---|
| `observe(condition, abort, child)` | Watches blackboard keys via condition and triggers aborts. |

### Service

| Function | Description |
|---|---|
| `service(name, interval, updater)` | Periodic updater. Attach via composite `config.services`. |

### Core

| Function | Description |
|---|---|
| `board(defaults)` | Creates a typed reactive blackboard. |
| `context(root, board, agent)` | Creates a per-agent execution context. |
| `watch(board, key, callback)` | Subscribes to blackboard changes. Returns unsubscribe function. |
| `snapshot(board)` | Returns a frozen, non-reactive shallow copy. |
