# Arbor

Composable, typed behavior trees for Roblox AI.

[Releases](https://github.com/Axp3cter/Arbor/releases) · [API Reference](#api-reference)

## Install

**Wally (Luau)**

```toml
[dependencies]
arbor = "axp3cter/arbor@2.1.0"
```

**npm (roblox-ts)**

```
npm install @axpecter/arbor
```

**Direct download**

Grab the latest `.rbxm` from [Releases](https://github.com/Axp3cter/Arbor/releases).

## Quick Start

An NPC that patrols, chases players, and attacks when close. Tags every node so `bt.snapshot()` can identify what's running.

```luau
local bt = require(path.to.bt)

type Board = { target: Model?, dist: number, hp: number }

local board: Board = { target = nil, dist = math.huge, hp = 100 }
local npc = script.Parent

-- Poll writes perception data to the board every 0.2s.
local scan = bt.poll(0.2, function(b: Board, agent: Model)
    local closest, closestDist = nil :: Model?, math.huge
    for _, player in game.Players:GetPlayers() do
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            local d = (root.Position - agent:GetPivot().Position).Magnitude
            if d < 40 and d < closestDist then
                closest, closestDist = player.Character, d
            end
        end
    end
    b.target, b.dist = closest, closestDist
end)

-- Conditions read the board. Never "running".
local hasTarget = bt.check(function(b: Board) return b.target ~= nil end):tag("hasTarget")
local isHurt    = bt.check(function(b: Board) return b.hp < 30 end):tag("isHurt")

-- Combat: follows the target, attacks on cooldown when in range.
-- One action that handles both, so the select never flickers between branches.
local combat = bt.action({
    enter = function(b: Board)
        return if b.target then "running" else "failure"
    end,
    tick = function(b: Board, agent: Model, dt: number)
        if not b.target then return "failure" end
        local root = b.target:FindFirstChild("HumanoidRootPart") :: BasePart
        if not root then return "failure" end
        -- Move toward target
        local pos = agent:GetPivot().Position
        local dir = (root.Position - pos).Unit
        agent:PivotTo(CFrame.new(pos + dir * 16 * dt))
        return "running"
    end,
    halt = function() end,
}):tag("combat")

-- Flee: backs away until safe.
local flee = bt.action({
    enter = function() return "running" end,
    tick = function(b: Board, agent: Model, dt: number)
        if not b.target then return "success" end
        local pos = agent:GetPivot().Position
        local root = b.target:FindFirstChild("HumanoidRootPart") :: BasePart
        if not root then return "success" end
        local away = (pos - root.Position).Unit
        agent:PivotTo(CFrame.new(pos + away * 20 * dt))
        return if b.dist > 25 then "success" else "running"
    end,
    halt = function() end,
}):tag("flee")

-- Patrol: walks waypoints. Simple function form.
local wpIndex = 1
local waypoints = { Vector3.new(20, 3, 20), Vector3.new(-20, 3, -20) }
local patrol = bt.action(function(_b, agent: Model, dt: number)
    local target = waypoints[wpIndex]
    local pos = agent:GetPivot().Position
    if (target - pos).Magnitude < 2 then
        wpIndex = wpIndex % #waypoints + 1
    end
    local dir = (target - pos).Unit
    agent:PivotTo(CFrame.new(pos + dir * 8 * dt))
    return "running"
end):tag("patrol")

-- Tree: select picks the highest-priority branch that succeeds.
local tree = bt.select {
    bt.sequence { isHurt, flee:timeout(5) },
    bt.sequence { hasTarget, combat:timeout(10):retry(2) },
    patrol,
} :serve(scan):tag("root")

-- Run at 20Hz fixed timestep.
local ctx = bt.run(tree, board, npc, 20)

npc.Destroying:Once(function()
    ctx:destroy()
end)
```

## How It Works

### Status

Every node returns `"success"`, `"failure"`, or `"running"` each tick. Composites and decorators read these to make decisions.

### Board

A shared table every callback receives. You define its shape. Polls write to it, checks read from it.

```luau
local board = { target = nil :: Player?, hp = 100, canSee = false }
```

Checks receive `(board)`. Actions receive `(board, agent, dt)`. Halt callbacks receive `(board, agent)`.

### Leaves

**`bt.check(fn)`** returns `"success"` or `"failure"`. Never `"running"`.

```luau
local isHurt = bt.check(function(b) return b.hp < 30 end)
```

**`bt.action(fn)`** runs every tick. No internal state.

```luau
local patrol = bt.action(function(b, agent, dt)
    -- move agent
    return "running"
end)
```

**`bt.action({ enter, tick, halt })`** is for multi-frame work. `enter` runs once on activation, `tick` runs every frame while `"running"`, `halt` runs on interruption. At least one of `enter` or `tick` required. `halt` does not receive `dt`.

```luau
local chase = bt.action({
    enter = function(b, agent, dt)
        return if b.target then "running" else "failure"
    end,
    tick = function(b, agent, dt)
        -- move toward target
        return if closeEnough then "success" else "running"
    end,
    halt = function(b, agent)
        -- cleanup
    end,
})
```

**`bt.wait(seconds)`** returns `"running"` for N seconds of accumulated `dt` (simulation time), then `"success"`.

**`bt.event(signal)`** connects to a `RBXScriptSignal` on entry, returns `"running"` until it fires, then `"success"`. Disconnects on fire or halt. No leaked connections. Reconnects on each fresh activation.

```luau
bt.sequence {
    startAnimation,
    bt.event(humanoid.AnimationPlayed),
    dealDamage,
}
```

**`bt.poll(interval, fn)`** fires `fn(board, agent)` on a wall-clock interval (`os.clock`). Always returns `"success"`. Attach to nodes with `:serve()`.

### Composites

**`bt.select { ... }`** tries children left to right. Returns the first `"success"`. Re-evaluates from child 1 every tick, so higher-priority branches preempt lower ones. If a lower child was `"running"`, it gets halted.

**`bt.sequence { ... }`** tries children left to right. Fails on the first `"failure"`. Uses sticky resume: remembers which child was `"running"` and picks up there next tick.

**`bt.parallel(succeed, fail?) { ... }`** ticks all children every frame. Resolves when `succeed` children have succeeded or `fail` children have failed. `fail` defaults to child count. Halts remaining children on resolution.

```luau
bt.parallel(1) {
    chaseTask,
    supportTask,
}
```

**`bt.random(children, weights?)`** picks one child at random, sticks with it until resolved. Optional weights table.

### Decorators

Chained on any node. Each returns a new wrapped node. Read left to right.

```luau
chase:timeout(6):retry(3)  -- chase, 6s timeout, retry up to 3 times
```

| Decorator | What it does |
|---|---|
| `node:invert()` | Flips `"success"` and `"failure"`. `"running"` passes through. |
| `node:always(status)` | Forces `"success"` or `"failure"` on completion. `"running"` passes through. |
| `node:loop(count?)` | Counted: repeats N times, stops on `"failure"`. Infinite (no arg): repeats every tick, yields `"running"` after `"success"` to prevent spin. |
| `node:cooldown(seconds)` | Blocks for N seconds after a `"success"`. Returns `"failure"` while blocked. Survives branch-level halts (rate limiter). Cleared by `stop()`/`destroy()`. |
| `node:timeout(seconds)` | Halts child and returns `"failure"` after N seconds wall-clock. Resets on normal completion. |
| `node:retry(times)` | Retries on `"failure"` up to N times. Halts child between attempts to reset state. |
| `node:guard(check)` | Re-evaluates `check(board)` every tick. If false, halts running child and returns `"failure"`. |
| `node:throttle(seconds)` | Caches terminal results for N seconds. Returns the cache without ticking the child while fresh. `"running"` children pass through every tick. Cache survives branch halts, cleared by `stop()`/`destroy()`. Use on expensive checks. |
| `node:tag(name)` | Attaches a name. Shows up in `bt.snapshot()` output. |
| `node:serve(polls...)` | Attaches polls that tick before the child. Halted when the child is halted (timers reset). |

### Context

A tree is a frozen graph. To run it, bind it to a board and agent.

```luau
-- Manual ticking:
local ctx = bt.bind(tree, board, agent)
ctx:tick(dt)

-- Automatic at 10Hz fixed timestep:
local ctx = bt.run(tree, board, agent, 10)

-- Automatic at frame rate:
local ctx = bt.run(tree, board, agent)
```

One tree, many contexts. Each context has independent state.

`ctx:stop()` halts all nodes, clears all state. Next tick starts fresh. `ctx:destroy()` calls stop and marks it dead. Always destroy when the NPC is removed.

```luau
npc.Destroying:Once(function()
    ctx:destroy()
end)
```

### Snapshot

`bt.snapshot(ctx)` returns a flat list of every node with its current state. Plain tables. No setup, no overhead when not called.

```luau
local snap = bt.snapshot(ctx)
for _, entry in snap do
    if entry.active and entry.tag then
        print(entry.tag, entry.kind, entry.depth)
    end
end
```

Each entry has `kind`, `tag`, `depth`, and `active`. Active nodes also have kind-specific fields:

| Kind | Extra fields |
|---|---|
| wait | `seconds`, `elapsed`, `remaining`, `progress` |
| poll | `interval`, `lastFired`, `nextIn` |
| cooldown | `seconds`, `remaining`, `blocked` |
| timeout | `seconds`, `elapsed`, `remaining` |
| retry | `times`, `attempt` |
| loop (counted) | `times`, `iteration` |
| parallel | `succeed`, `fail`, `successes`, `failures`, `running` |
| select, sequence | `runningChild` |
| random | `runningChild`, `weights` |
| throttle | `seconds`, `cached`, `remaining`, `fresh` |
| action (phased) | `form`, `phase`, `hasEnter`, `hasTick`, `hasHalt` |
| always | `forced` |
| guard | `passing` |
| event | `fired` |

## Full Example

A combat NPC with perception, flee, heal, chase, attack, investigate, and idle behaviors. Demonstrates every feature.

```luau
local bt = require(path.to.bt)

type Board = {
    target: Model?,
    targetDist: number,
    hp: number,
    canSee: boolean,
    allies: number,
    lastHeard: Vector3?,
}

local board: Board = {
    target     = nil,
    targetDist = math.huge,
    hp         = 100,
    canSee     = false,
    allies     = 0,
    lastHeard  = nil,
}

local npc = script.Parent
local hum = npc:FindFirstChildWhichIsA("Humanoid") :: Humanoid

-- Perception: fast scan and slow listen on separate intervals.
-- Both write to the board. Conditions read from the board.

local scan = bt.poll(0.2, function(b: Board, agent: Model)
    local pos = agent:GetPivot().Position
    local closest, closestDist = nil :: Model?, math.huge
    for _, player in game.Players:GetPlayers() do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            local d = (root.Position - pos).Magnitude
            if d < 50 and d < closestDist then
                closest, closestDist = char, d
            end
        end
    end
    b.target, b.targetDist = closest, closestDist
    b.canSee = closest ~= nil and closestDist < 30
end)

local listen = bt.poll(1.0, function(b: Board, agent: Model)
    -- Simulate hearing: pick up nearby sounds, write position.
    -- Replace with your own audio/raycast system.
    b.lastHeard = nil
end)

-- Conditions

local hasTarget  = bt.check(function(b: Board) return b.target ~= nil end):tag("hasTarget")
local isHurt     = bt.check(function(b: Board) return b.hp < 30 end):tag("isHurt")
local canSee     = bt.check(function(b: Board) return b.canSee end):tag("canSee")
local noAllies   = bt.check(function(b: Board) return b.allies > 0 end):invert()
local heardNoise = bt.check(function(b: Board) return b.lastHeard ~= nil end)

-- Actions

local attack = bt.action(function(b: Board, agent: Model)
    -- Instant hit. Gated by cooldown in the tree.
    return "success"
end):tag("attack")

local heal = bt.action(function(b: Board)
    b.hp = math.min(100, b.hp + 30)
    return "success"
end):tag("heal")

local callForHelp = bt.action(function()
    return "success"
end)

local combat = bt.action({
    enter = function(b: Board, agent: Model)
        return if b.target then "running" else "failure"
    end,
    tick = function(b: Board, agent: Model, dt: number)
        local root = b.target and b.target:FindFirstChild("HumanoidRootPart")
        if not root or not root:IsA("BasePart") then return "failure" end
        hum:MoveTo(root.Position)
        return "running"
    end,
    halt = function(_b, agent: Model)
        hum:MoveTo(agent:GetPivot().Position)
    end,
}):tag("combat")

local flee = bt.action({
    enter = function() return "running" end,
    tick = function(b: Board, agent: Model, dt: number)
        local root = b.target and b.target:FindFirstChild("HumanoidRootPart")
        if not root or not root:IsA("BasePart") then return "success" end
        local pos = agent:GetPivot().Position
        local away = (pos - root.Position).Unit
        hum:MoveTo(pos + away * 15)
        return if b.targetDist > 25 then "success" else "running"
    end,
    halt = function(_b, agent: Model)
        hum:MoveTo(agent:GetPivot().Position)
    end,
}):tag("flee")

local investigate = bt.action({
    enter = function(b: Board)
        return if b.lastHeard then "running" else "failure"
    end,
    tick = function(b: Board, agent: Model)
        if not b.lastHeard then return "success" end
        hum:MoveTo(b.lastHeard)
        local dist = (agent:GetPivot().Position - b.lastHeard).Magnitude
        if dist < 3 then
            b.lastHeard = nil
            return "success"
        end
        return "running"
    end,
    halt = function(_b, agent: Model)
        hum:MoveTo(agent:GetPivot().Position)
    end,
}):tag("investigate")

local patrol = bt.action(function(_b, agent: Model)
    -- Replace with your waypoint system.
    return "running"
end):tag("patrol")

-- Tree
-- Select picks the highest-priority branch. Comments show what each uses.

local tree = bt.select {
    -- Hurt and alone: flee until safe.                  [check, invert, sequence, timeout]
    bt.sequence {
        isHurt,
        noAllies,
        flee:timeout(5),
    },

    -- Hurt with allies: call for help and heal.         [cooldown, always, loop]
    bt.sequence {
        isHurt,
        bt.sequence({
            callForHelp,
            heal:cooldown(4),
            bt.wait(0.5),
        }):loop():always("success"),
    },

    -- Can see target: chase and attack.                 [parallel, throttle, cooldown, guard, timeout, retry, wait, loop]
    bt.sequence {
        hasTarget,
        canSee,
        bt.parallel(2) {
            combat:timeout(8):retry(2),
            bt.sequence({
                bt.check(function(b: Board) return b.targetDist < 6 end):throttle(0.2),
                attack:cooldown(0.8),
                bt.wait(0.15),
            }):loop(),
        } :guard(function(b: Board) return b.target ~= nil end),
    },

    -- Heard something: investigate.                     [timeout]
    bt.sequence { heardNoise, investigate:timeout(10) },

    -- Nothing happening: patrol or idle.                [random, wait, loop]
    bt.random({
        bt.sequence({ patrol, bt.wait(3) }):loop(),
        bt.wait(5),
    }, { 3, 1 }),

} :serve(scan, listen):tag("root")

-- Run at 10Hz. One tree, many NPCs: call bt.bind/bt.run per NPC.
local ctx = bt.run(tree, board, npc, 10)

npc.Destroying:Once(function()
    ctx:destroy()
end)

-- Development: log active nodes every 3s.
task.spawn(function()
    while ctx:isRunning() do
        task.wait(3)
        local snap = bt.snapshot(ctx)
        local path: { string } = {}
        for _, e in snap do
            if e.active and e.tag then
                table.insert(path, e.tag :: string)
            end
        end
        if #path > 0 then
            print("[BT]", table.concat(path, " > "))
            -- Example output: [BT] root > hasTarget > canSee > combat
        end
    end
end)
```

## API Reference

### Leaves

| Function | Description |
|---|---|
| `bt.check(fn)` | `fn(board) -> boolean`. Returns `"success"` or `"failure"`. |
| `bt.action(fn)` | `fn(board, agent, dt) -> Status`. Runs every tick. |
| `bt.action({ enter, tick, halt })` | Phased. `enter`/`tick` get `(board, agent, dt)`. `halt` gets `(board, agent)`. At least one of `enter`/`tick` required. |
| `bt.wait(seconds)` | `"running"` for N seconds (dt accumulation), then `"success"`. |
| `bt.event(signal)` | `"running"` until signal fires, then `"success"`. Connects on entry, disconnects on fire/halt. |
| `bt.poll(interval, fn)` | `fn(board, agent)` on a wall-clock interval. Always `"success"`. |

### Composites

| Function | Description |
|---|---|
| `bt.select { ... }` | First `"success"` wins. Re-evaluates from child 1 every tick. Halts preempted children. |
| `bt.sequence { ... }` | First `"failure"` fails. Sticky resume from running child. |
| `bt.parallel(succeed, fail?) { ... }` | Ticks all. Resolves by threshold. Curried. `fail` defaults to child count. |
| `bt.random(children, weights?)` | Picks one, sticks while `"running"`. |

### Decorators

| Method | Description |
|---|---|
| `:invert()` | Flips `"success"` / `"failure"`. |
| `:always(status)` | Forces terminal status. `"running"` passes through. |
| `:loop(count?)` | Repeats. Counted stops on `"failure"`. Infinite yields `"running"` after `"success"`. |
| `:cooldown(seconds)` | Blocks N seconds after `"success"`. Survives halts. Cleared by `stop()`/`destroy()`. |
| `:timeout(seconds)` | Fails after N seconds wall-clock. |
| `:retry(times)` | Retries on `"failure"`. Halts child between attempts. |
| `:guard(fn)` | `fn(board)` every tick. Halts child if false. |
| `:throttle(seconds)` | Caches terminal results N seconds. `"running"` passes through. |
| `:tag(name)` | Debug name. Shows in `bt.snapshot()`. |
| `:serve(polls...)` | Scoped polls. Halt with the child. |

### Context

| Function | Description |
|---|---|
| `bt.bind(root, board, agent)` | Manual ticking via `ctx:tick(dt)`. |
| `bt.run(root, board, agent, rate?)` | Auto-tick on Heartbeat. `rate > 0` = fixed timestep. `0`/nil = frame dt. |
| `ctx:tick(dt?)` | One tick. `dt` defaults to `0`. |
| `ctx:start(rate?)` | Start runner. No-op if already running. |
| `ctx:stop()` | Halt all, clear all state. |
| `ctx:destroy()` | Stop + mark dead. `tick()` returns `"failure"` after. |
| `ctx:isRunning()` | Whether the runner is active. |
| `bt.snapshot(ctx)` | Flat list of every node: `kind`, `tag`, `depth`, `active`, plus kind-specific state. |

### Snapshot Fields

| Kind | Fields |
|---|---|
| wait | `seconds`, `elapsed`, `remaining`, `progress` |
| poll | `interval`, `lastFired`, `nextIn` |
| cooldown | `seconds`, `remaining`, `blocked` |
| timeout | `seconds`, `elapsed`, `remaining` |
| retry | `times`, `attempt` |
| loop | `times`, `iteration` |
| parallel | `succeed`, `fail`, `successes`, `failures`, `running` |
| select, sequence | `runningChild` |
| random | `runningChild`, `weights` |
| throttle | `seconds`, `cached`, `remaining`, `fresh` |
| action | `form`, `phase`, `hasEnter`, `hasTick`, `hasHalt` |
| always | `forced` |
| guard | `passing` |
| event | `fired` |

## License

MIT
