# Arbor

Composable, typed behavior trees for Roblox AI.

[Releases](https://github.com/Axp3cter/Arbor/releases) · [API Reference](#api-reference)

## Install

**Wally (Luau)**

```toml
[dependencies]
arbor = "axp3cter/arbor@2.0.0"
```

**npm (roblox-ts)**

```
npm install @axpecter/arbor
```

**Direct download**

Grab the latest `.rbxm` from [Releases](https://github.com/Axp3cter/Arbor/releases).

## Quick Start

```luau
local bt = require(path.to.bt)

local board = { target = nil :: Player?, health = 100 }
local npc = script.Parent

local root = bt.select {
    bt.sequence {
        bt.check(function(b) return b.health < 30 end),
        bt.action(function(_b, agent)
            agent:runAway()
            return "running"
        end),
    },
    bt.sequence {
        bt.check(function(b) return b.target ~= nil end),
        bt.action(function(_b, agent)
            agent:attack()
            return "success"
        end),
    },
    bt.action(function(_b, agent)
        agent:patrol()
        return "running"
    end),
}

local ctx = bt.run(root, board, npc, 10)

npc.Destroying:Once(function()
    ctx:destroy()
end)
```

## Concepts

### Status

Every node returns one of three statuses each tick:

| Status | Meaning |
|---|---|
| `"success"` | Done, it worked. |
| `"failure"` | Done, it did not work. |
| `"running"` | Still in progress. Tick again next frame. |

These are the only three values in the system. Composites and decorators make decisions based on which status their children return.

### Board

The board is a shared data table that every node callback receives as its first argument. Put anything the AI needs to reason about on here — targets, health, flags, positions. You define the shape.

```luau
local board = {
    target    = nil :: Player?,
    health    = 100,
    canSee    = false,
    allies    = 0,
    lastHeard = nil :: Vector3?,
}
```

Conditions only receive `(board)`. Actions receive `(board, agent, dt)`. If you need agent state in a condition, write it to the board first (a poll is the natural place for that).

### Conditions

Conditions read the board and return `"success"` or `"failure"`. They never return `"running"`. Use them as gates in sequences and selectors.

```luau
local hasTarget = bt.check(function(b) return b.target ~= nil end)
local isHurt    = bt.check(function(b) return b.health < 30 end)
```

### Actions

Actions are where the NPC does work. Two forms exist depending on whether the work is instant or spans multiple frames.

**Function form** — runs every tick the action is active. No state is tracked internally. The handler receives `(board, agent, dt)` and must return a status.

```luau
local attack = bt.action(function(_b, agent)
    agent:swingWeapon()
    return "success"
end)
```

**Table form** — for work that spans multiple frames. Three optional hooks:

- `enter(board, agent, dt)` — runs once on the first tick after activation. If it returns `"running"`, the action enters the tick phase. If it returns `"success"` or `"failure"`, the action completes immediately without ever calling `tick`.
- `tick(board, agent, dt)` — runs every subsequent tick while the action is `"running"`. Return `"success"` or `"failure"` to complete.
- `halt(board, agent)` — runs if the action is interrupted while `"running"` (a parent halts it). Not called on normal completion. Does not receive `dt`.

At least one of `enter` or `tick` must be provided. If `enter` is omitted, the action skips straight to `tick` on its first frame. If `tick` is omitted and `enter` returns `"running"`, the action stays `"running"` indefinitely until halted externally — this is a valid fire-and-forget pattern (start an animation, keep running until the branch switches).

```luau
local chase = bt.action({
    enter = function(b, agent)
        agent:pathTo(b.target)
        return "running"
    end,
    tick = function(_b, agent)
        return if agent:reachedTarget() then "success" else "running"
    end,
    halt = function(_b, agent)
        agent:stopMoving()
    end,
})
```

### Composites

Composites combine multiple nodes into control flow.

**`bt.select`** runs children left to right and succeeds on the first child that succeeds. Re-evaluates from child 1 every tick. This means higher-priority branches automatically take over when their conditions become true — if a lower-priority child was `"running"`, it gets halted. Returns `"failure"` only if every child fails.

```luau
bt.select {
    bt.sequence { isHurt, flee },       -- priority 1
    bt.sequence { hasTarget, attack },  -- priority 2
    patrol,                             -- priority 3
}
```

**`bt.sequence`** runs children left to right and fails on the first child that fails. Unlike select, sequence uses sticky resume — it remembers which child was `"running"` and picks up there next tick. Earlier children that already succeeded are not re-evaluated. Returns `"success"` only if every child succeeds.

```luau
bt.sequence {
    hasTarget,
    canSee,
    chase,
}
```

**`bt.parallel(succeed, fail?)`** ticks all children every frame. Resolves when enough children have reached a terminal status. `succeed` is the number of children that must succeed for the parallel to return `"success"`. `fail` is the number that must fail for `"failure"` — defaults to the total child count. Both thresholds must be > 0 and ≤ the child count.

When a threshold is met mid-tick, all remaining active children are halted. If all children resolve without either threshold being met (possible when `succeed + fail > count`), the parallel returns `"failure"`.

```luau
bt.parallel(1) {        -- succeed when 1 child succeeds
    chase,
    attackLoop,
}

bt.parallel(2, 1) {     -- succeed when 2 succeed, fail when 1 fails
    taskA,
    taskB,
    taskC,
}
```

Note the curried API — `bt.parallel(succeed)` returns a function that takes the children table. This reads naturally in Luau thanks to call sugar: `bt.parallel(1) { ... }`.

**`bt.random`** picks one child at random and sticks with it until it resolves (`"success"` or `"failure"`). While the chosen child returns `"running"`, it stays selected. On resolution, the selection is cleared — next activation picks fresh. Optional weights make some children more likely.

```luau
bt.random({
    patrol,
    idleAnimation,
}, { 3, 1 })  -- patrol is 3x more likely
```

### Decorators

Decorators are chained methods on any node. Each returns a new node wrapping the original. Read left to right:

```luau
chase:timeout(6):retry(3)
-- "chase, with a 6-second timeout, retried up to 3 times"
```

| Decorator | Behavior |
|---|---|
| `node:invert()` | Flips `"success"` ↔ `"failure"`. `"running"` passes through unchanged. |
| `node:always(status)` | Forces `"success"` or `"failure"` when the child completes. `"running"` passes through — the child still runs until it finishes, then the forced status is returned. |
| `node:loop(count?)` | **Counted** (with count): repeats the child up to N times. If the child returns `"running"`, the loop yields and resumes the count next tick. Stops immediately on `"failure"`. Returns `"success"` after N completions. **Infinite** (no count): ticks the child once per frame. On `"success"`, yields `"running"` to prevent spin — the child runs again next frame. Stops on `"failure"`. |
| `node:cooldown(seconds)` | After the child succeeds, blocks re-entry for N seconds (wall-clock via `os.clock`). Returns `"failure"` during the cooldown window. The cooldown timestamp survives branch-level halts — if a selector switches away and comes back, the cooldown still applies. `ctx:stop()` and `ctx:destroy()` clear all state including cooldown timestamps. |
| `node:timeout(seconds)` | Starts a wall-clock timer on entry. If the child is still `"running"` after N seconds, halts it and returns `"failure"`. Timer resets on normal completion. |
| `node:retry(times)` | If the child fails, halts it (resetting internal state) and tries again, up to N total attempts. Returns `"failure"` after exhausting all attempts. Returns the child's `"running"` and `"success"` directly. |
| `node:guard(check)` | Re-evaluates `check(board)` every tick before ticking the child. If the check returns false and the child was `"running"`, halts it. Returns `"failure"`. If the check returns false and the child was not running, returns `"failure"` without halting. |
| `node:tag(name)` | Attaches a debug name string to the node. Currently inert — intended for future debug tooling. |
| `node:serve(polls...)` | Attaches poll nodes that tick before the child every frame. When the child is halted, the polls are halted too (timers reset). On re-entry, polls fire immediately. |

### Poll Services

Polls run a function on a wall-clock interval (`os.clock`) and always return `"success"`. The interval is independent of the context's tick rate — a 0.3s poll fires based on real elapsed time, not simulation ticks.

Attach polls to nodes via `:serve()`. The polls are scoped to the served node's lifecycle: they tick every frame while the served branch is active, and their timers reset when the branch is halted.

```luau
local scan = bt.poll(0.3, function(b, agent)
    b.target = agent:findNearestEnemy()
    b.canSee = b.target ~= nil and agent:hasLineOfSight(b.target)
end)

local root = bt.select {
    -- decision tree...
} :serve(scan)
```

### Wait

`bt.wait(seconds)` returns `"running"` until the specified duration has elapsed, then returns `"success"`. Duration is tracked by accumulating `ctx.dt` — it measures simulation time, not wall-clock time. With a fixed-timestep runner at 10Hz, each tick advances by 0.1s of simulation time.

```luau
bt.sequence {
    attack:cooldown(0.8),
    bt.wait(0.2),        -- brief pause after attack
} :loop()
```

### Context

A tree is just a structure — a frozen graph of nodes. To run it, bind it to a board and an agent by creating a context. The context holds all runtime state (which child is running, timers, cooldown timestamps). One tree can be shared across many contexts with independent state.

```luau
-- Manual ticking:
local ctx = bt.bind(root, board, npc)
RunService.Heartbeat:Connect(function(dt)
    ctx:tick(dt)
end)

-- Automatic runner at N Hz (fixed timestep):
local ctx = bt.run(root, board, npc, 10)

-- Automatic runner at frame rate (variable dt):
local ctx = bt.run(root, board, npc)
```

When ticking manually, always pass `dt`. Omitting it defaults to `0`, which means time-based nodes like `bt.wait` and `node:timeout` will never make progress.

`ctx:stop()` disconnects the runner, halts all running nodes (triggering their cleanup), and clears all internal state. After stop, calling `tick()` or `start()` begins a completely fresh run — no prior state survives.

`ctx:destroy()` calls `stop()` and marks the context as dead. All subsequent `tick()` calls return `"failure"`. Idempotent.

Always call `ctx:destroy()` when the NPC is removed. Without it, the Heartbeat connection leaks.

```luau
npc.Destroying:Once(function()
    ctx:destroy()
end)
```

## Full Example

```luau
local bt = require(path.to.bt)

type Board = {
    target: Player?,
    health: number,
    canSee: boolean,
    allies: number,
    lastHeard: Vector3?,
}

local board: Board = {
    target    = nil,
    health    = 100,
    canSee    = false,
    allies    = 0,
    lastHeard = nil,
}

local npc = script.Parent

-- Conditions

local hasTarget  = bt.check(function(b: Board) return b.target ~= nil end)
local isHurt     = bt.check(function(b: Board) return b.health < 30 end)
local canSee     = bt.check(function(b: Board) return b.canSee end)
local hasAllies  = bt.check(function(b: Board) return b.allies > 0 end)
local heardNoise = bt.check(function(b: Board) return b.lastHeard ~= nil end)

-- Actions

local attack = bt.action(function(_b: Board, agent)
    agent:swingWeapon()
    return "success"
end)

local callForHelp = bt.action(function(_b: Board, agent)
    agent:shout()
    return "success"
end)

local heal = bt.action(function(b: Board, agent)
    agent:playAnimation("Heal")
    b.health = math.min(100, b.health + 30)
    return "success"
end)

local patrol = bt.action(function(_b: Board, agent)
    agent:walkToNextWaypoint()
    return "running"
end)

local chase = bt.action({
    enter = function(b: Board, agent)
        agent:pathTo(b.target)
        return "running"
    end,
    tick = function(_b: Board, agent)
        return if agent:reachedTarget() then "success" else "running"
    end,
    halt = function(_b: Board, agent)
        agent:stopMoving()
    end,
})

local flee = bt.action({
    enter = function(_b: Board, agent)
        agent:runAway()
        return "running"
    end,
    tick = function(_b: Board, agent)
        return if agent:isSafe() then "success" else "running"
    end,
    halt = function(_b: Board, agent)
        agent:stopMoving()
    end,
})

local investigate = bt.action({
    enter = function(b: Board, agent)
        agent:pathTo(b.lastHeard)
        return "running"
    end,
    tick = function(b: Board, agent)
        if agent:reachedTarget() then
            b.lastHeard = nil
            return "success"
        end
        return "running"
    end,
    halt = function(_b: Board, agent)
        agent:stopMoving()
    end,
})

-- Tree

local root = bt.select {
    bt.sequence {
        isHurt,
        bt.select {
            bt.sequence { hasAllies:invert(), flee },
            bt.sequence { callForHelp, heal:cooldown(8) },
        },
    },

    bt.sequence {
        hasTarget,
        canSee,
        bt.parallel(1) {
            chase:timeout(6):retry(3),
            bt.sequence { attack:cooldown(0.8), bt.wait(0.2) } :loop(),
        },
    },

    bt.sequence { heardNoise, investigate:timeout(10) },

    bt.random({
        bt.sequence { patrol, bt.wait(3) } :loop(),
        bt.wait(5),
    }, { 3, 1 }),

} :serve(
    bt.poll(0.3, function(b: Board, agent)
        b.target = agent:findNearestEnemy()
        b.canSee = b.target ~= nil and agent:hasLineOfSight(b.target)
        b.allies = agent:countNearbyAllies()
    end),
    bt.poll(1.0, function(b: Board, agent)
        b.lastHeard = agent:getLastHeardPosition()
    end)
)

-- Run

local ctx = bt.run(root, board, npc, 10)

npc.Destroying:Once(function()
    ctx:destroy()
end)
```

## API Reference

### Leaves

| Function | Description |
|---|---|
| `bt.check(predicate)` | Boolean gate. Returns `"success"` or `"failure"`. Predicate receives `(board)`. |
| `bt.action(handler)` | Function form. Handler receives `(board, agent, dt)`, runs every tick. |
| `bt.action({ enter, tick, halt })` | Table form. `enter` on first tick, `tick` on subsequent, `halt` on interrupt. At least one of `enter` or `tick` required. `enter` and `tick` receive `(board, agent, dt)`. `halt` receives `(board, agent)`. |
| `bt.wait(seconds)` | Returns `"running"` for N seconds via dt accumulation (simulation time), then `"success"`. |
| `bt.poll(interval, updater)` | Fires `updater(board, agent)` on a wall-clock interval (`os.clock`). Always `"success"`. |

### Composites

| Function | Description |
|---|---|
| `bt.select(children)` | Left to right. Succeeds on first `"success"`. Re-evaluates from child 1 every tick. |
| `bt.sequence(children)` | Left to right. Fails on first `"failure"`. Resumes from running child. |
| `bt.parallel(succeed, fail?)(children)` | Curried. Ticks all children. Resolves by threshold. `fail` defaults to child count. Both thresholds must be > 0 and ≤ child count. |
| `bt.random(children, weights?)` | Picks one at random. Sticks while `"running"`. Optional weights. |

### Decorators

Chained methods on `Node`. Each returns a new `Node`.

| Method | Description |
|---|---|
| `node:invert()` | Flips `"success"` ↔ `"failure"`. |
| `node:always(status)` | Forces `"success"` or `"failure"` on completion. |
| `node:loop(count?)` | Counted: repeats up to N times, yields on `"running"`. Infinite: once per tick, yields on `"success"`. Stops on `"failure"`. |
| `node:cooldown(seconds)` | Blocks for N seconds after success. Survives branch-level halts. Cleared by `stop()`/`destroy()`. |
| `node:timeout(seconds)` | Fails if child runs longer than N seconds (wall-clock). |
| `node:retry(times)` | Retries on failure up to N times. Halts child between attempts. |
| `node:guard(check)` | Re-checks `check(board)` every tick. Halts child if false. |
| `node:tag(name)` | Attaches a debug name. |
| `node:serve(polls...)` | Attaches polls scoped to this node's lifecycle. |

### Context

| Function | Description |
|---|---|
| `bt.bind(root, board, agent)` | Creates a context for manual ticking. |
| `bt.run(root, board, agent, tickRate?)` | Creates a context and starts the runner. Rate > 0 uses fixed timestep. Rate 0 or omitted uses frame dt. |
| `ctx:tick(dt?)` | Ticks the tree once. `dt` defaults to `0` — always pass it when ticking manually. |
| `ctx:start(tickRate?)` | Starts via `RunService.Heartbeat`. Ignored if already running. |
| `ctx:stop()` | Stops runner, halts all nodes, clears all state. Fresh start on next tick/start. |
| `ctx:destroy()` | Full teardown. Idempotent. `tick()` returns `"failure"` after this. |
| `ctx:isRunning()` | Whether the runner is active. |

## License

MIT
