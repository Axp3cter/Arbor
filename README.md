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
| `"success"` | Done, it worked |
| `"failure"` | Done, it did not work |
| `"running"` | Still working, tick again next frame |

### Board

The board is a table you define. Every node callback receives it as the first argument.

```luau
local board = {
    target    = nil :: Player?,
    health    = 100,
    canSee    = false,
    allies    = 0,
    lastHeard = nil :: Vector3?,
}
```

### Conditions

Conditions check the board and return `"success"` or `"failure"`, never `"running"`.

```luau
local hasTarget = bt.check(function(b) return b.target ~= nil end)
local isHurt    = bt.check(function(b) return b.health < 30 end)
```

### Actions

Actions are where the NPC does work.

**Function form** for instant or stateless work. Runs every tick the action is active:

```luau
local attack = bt.action(function(_b, agent)
    agent:swingWeapon()
    return "success"
end)
```

**Table form** for work that spans multiple frames. `enter` runs once on activation, `tick` runs every frame after that while `"running"`, and `halt` runs if the action is interrupted. `halt` is not called if the action completed normally. All fields are optional. Callbacks receive `(board, agent, dt)`.

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

Composites combine multiple nodes.

**`bt.select`** runs children left to right. Succeeds on the first child that succeeds. Re-evaluates from child 1 every tick, so higher-priority branches take over when their conditions become true. If a lower-priority child was running, it is halted.

```luau
bt.select {
    bt.sequence { isHurt, flee },       -- priority 1
    bt.sequence { hasTarget, attack },  -- priority 2
    patrol,                             -- priority 3
}
```

**`bt.sequence`** runs children left to right. Fails on the first child that fails. Resumes from the last running child — earlier children that already succeeded are not re-evaluated.

```luau
bt.sequence {
    hasTarget,
    canSee,
    chase,
}
```

**`bt.parallel(succeed)`** ticks all children every frame. Resolves when enough children have succeeded or failed. The second argument is the fail threshold, defaulting to the child count.

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

**`bt.random`** picks one child at random and sticks with it until it resolves. Optional weights make some children more likely:

```luau
bt.random({
    patrol,
    idleAnimation,
}, { 3, 1 })  -- patrol is 3x more likely
```

### Decorators

Decorators are chained methods on any node. They return a new node. Read left to right:

```luau
chase:timeout(6):retry(3)
-- "chase, with a 6-second timeout, retried up to 3 times"
```

| Decorator | What it does |
|---|---|
| `node:invert()` | Flips `"success"` ↔ `"failure"`. `"running"` passes through. |
| `node:always(status)` | Forces `"success"` or `"failure"` on completion. `"running"` passes through. |
| `node:loop(count?)` | Counted: repeats child N times within one tick. Infinite (no count): runs child once per tick, yields `"running"` after each success. Stops on `"failure"`. |
| `node:cooldown(seconds)` | After the child succeeds, blocks it for N seconds. Returns `"failure"` during cooldown. The timer persists across halts — if a selector switches branches and comes back, the cooldown still applies. |
| `node:timeout(seconds)` | If the child is still `"running"` after N seconds, halts it and returns `"failure"`. |
| `node:retry(times)` | If the child fails, halts it and retries up to N times. Returns `"failure"` after exhausting attempts. |
| `node:guard(check)` | Re-checks `check(board)` every tick. If the check fails and the child was running, halts it. Returns `"failure"`. |
| `node:tag(name)` | Attaches a debug name. |
| `node:serve(polls...)` | Attaches poll services scoped to this node's lifecycle. |

### Poll Services

Polls run a function on a wall-clock interval and always return `"success"`. Attach them to nodes via `:serve()`. When the served node is halted, the polls halt too. When the branch is re-entered, they fire immediately.

```luau
local scan = bt.poll(0.3, function(b, agent)
    b.target = agent:findNearestEnemy()
    b.canSee = b.target ~= nil and agent:hasLineOfSight(b.target)
end)

local root = bt.select {
    -- decision tree...
} :serve(scan)
```

### Context

The tree is a structure. To run it, bind it to a board and agent:

```luau
-- Manual ticking:
local ctx = bt.bind(root, board, npc)
RunService.Heartbeat:Connect(function(dt)
    ctx:tick(dt)
end)

-- Automatic runner at N Hz:
local ctx = bt.run(root, board, npc, 10)
```

One tree can be shared across many contexts. Each context tracks its own state.

Call `ctx:destroy()` when done. This stops the runner, halts running actions so their cleanup runs, and clears all state. Without this, you leak the Heartbeat connection.

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
| `bt.action({ enter, tick, halt })` | Table form. `enter` on first tick, `tick` on subsequent, `halt` on interrupt. All optional. |
| `bt.wait(seconds)` | Returns `"running"` for N seconds (via `dt` accumulation), then `"success"`. |
| `bt.poll(interval, updater)` | Fires `updater(board, agent)` on a wall-clock interval. Always `"success"`. |

### Composites

| Function | Description |
|---|---|
| `bt.select(children)` | Left to right. Succeeds on first `"success"`. Re-evaluates from child 1 every tick. |
| `bt.sequence(children)` | Left to right. Fails on first `"failure"`. Resumes from running child. |
| `bt.parallel(succeed, fail?)(children)` | Curried. Ticks all children. Resolves by threshold. `fail` defaults to child count. |
| `bt.random(children, weights?)` | Picks one at random. Sticks while `"running"`. Optional weights. |

### Decorators

Chained methods on `Node`. Each returns a new `Node`.

| Method | Description |
|---|---|
| `node:invert()` | Flips `"success"` ↔ `"failure"`. |
| `node:always(status)` | Forces `"success"` or `"failure"`. |
| `node:loop(count?)` | Repeats child. Counted or infinite. |
| `node:cooldown(seconds)` | Blocks for N seconds after success. Persists across halts. |
| `node:timeout(seconds)` | Fails if child runs longer than N seconds. |
| `node:retry(times)` | Retries on failure up to N times. |
| `node:guard(check)` | Re-checks `check(board)` every tick. Halts child if false. |
| `node:tag(name)` | Attaches a debug name. |
| `node:serve(polls...)` | Attaches polls scoped to this node's lifecycle. |

### Context

| Function | Description |
|---|---|
| `bt.bind(root, board, agent)` | Creates a context for manual ticking. |
| `bt.run(root, board, agent, tickRate?)` | Creates a context and starts the automatic runner. |
| `ctx:tick(dt?)` | Ticks the tree once. `dt` defaults to `0`. |
| `ctx:start(tickRate?)` | Starts via `RunService.Heartbeat`. Rate > 0 uses fixed timestep. |
| `ctx:stop()` | Stops runner, halts all nodes, clears state. |
| `ctx:destroy()` | Full teardown. Idempotent. `tick()` returns `"failure"` after this. |
| `ctx:isRunning()` | Whether the runner is active. |

## License

MIT
