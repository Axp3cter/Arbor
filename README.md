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
local observe   = Arbor.observe
local selector  = Arbor.selector
local sequence  = Arbor.sequence
local parallel  = Arbor.parallel
local random    = Arbor.random
local guard     = Arbor.guard
local cooldown  = Arbor.cooldown
local timeout   = Arbor.timeout
local retry     = Arbor.retry
local loop      = Arbor.loop
local succeed   = Arbor.succeed
local invert    = Arbor.invert
local wait      = Arbor.wait
local service   = Arbor.service
local Status    = Arbor.Status
local Abort     = Arbor.Abort

local board = Arbor.board({
    target    = nil :: Player?,
    health    = 100,
    allies    = 0,
    canSee    = false,
    lastHeard = nil :: Vector3?,
})

-- Conditions

local hasTarget  = condition("HasTarget",  function(b) return b.target ~= nil end, { "target" })
local isHurt     = condition("IsHurt",     function(b) return b.health < 30 end,   { "health" })
local canSee     = condition("CanSee",     function(b) return b.canSee end,        { "canSee" })
local hasAllies  = condition("HasAllies",  function(b) return b.allies > 0 end,    { "allies" })
local heardNoise = condition("HeardNoise", function(b) return b.lastHeard ~= nil end, { "lastHeard" })

-- Actions

local chase = action("Chase", {
    start = function(b, agent)
        agent:pathTo(b.target)
        return Status.Running
    end,
    tick = function(_b, agent)
        return if agent:reachedTarget() then Status.Success else Status.Running
    end,
    halt = function(_b, agent)
        agent:stopMoving()
    end,
})

local attack = action("Attack", function(_b, agent)
    agent:swingWeapon()
    return Status.Success
end)

local flee = action("Flee", {
    start = function(_b, agent)
        agent:runAway()
        return Status.Running
    end,
    tick = function(_b, agent)
        return if agent:isSafe() then Status.Success else Status.Running
    end,
    halt = function(_b, agent)
        agent:stopMoving()
    end,
})

local callForHelp = action("CallForHelp", function(_b, agent)
    agent:shout()
    return Status.Success
end)

local heal = action("Heal", function(b, agent)
    agent:playAnimation("Heal")
    b.health = math.min(100, b.health + 30)
    return Status.Success
end)

local investigate = action("Investigate", {
    start = function(b, agent)
        agent:pathTo(b.lastHeard)
        return Status.Running
    end,
    tick = function(b, agent)
        if agent:reachedTarget() then
            b.lastHeard = nil
            return Status.Success
        end
        return Status.Running
    end,
    halt = function(_b, agent)
        agent:stopMoving()
    end,
})

local patrol = action("Patrol", function(_b, agent)
    agent:walkToNextWaypoint()
    return Status.Running
end)

-- Tree

local root = selector({
    -- Hurt and alone: flee. Hurt with allies: heal behind cover.
    observe(isHurt, Abort.Lower, selector({
        sequence({ invert(hasAllies), flee }),
        sequence({ callForHelp, cooldown(heal, 8) }),
    })),

    -- Combat: chase and attack. Retry the approach if pathfinding fails.
    sequence({
        hasTarget,
        canSee,
        parallel({
            retry(timeout(chase, 6), 3),
            loop(sequence({ cooldown(attack, 0.8), wait(0.2) })),
        }, { succeed = 1 }),
    }),

    -- Heard something: go check it out.
    guard(heardNoise, timeout(investigate, 10)),

    -- Nothing going on: random idle behavior.
    random({
        loop(sequence({ patrol, wait(3) })),
        succeed(wait(5)),
    }, { 3, 1 }),
}, {
    services = {
        service("Scan", 0.3, function(b, agent)
            b.target  = agent:findNearestEnemy()
            b.canSee  = b.target ~= nil and agent:hasLineOfSight(b.target)
            b.allies  = agent:countNearbyAllies()
        end),
        service("Listen", 1.0, function(b, agent)
            b.lastHeard = agent:getLastHeardPosition()
        end),
    },
})

local ctx = Arbor.context(root, board, myNpc)
ctx:start(10)

myNpc.Destroying:Once(function()
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
