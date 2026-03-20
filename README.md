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
arbor = "axp3cter/arbor@1.0.2"
```

**npm (roblox-ts)**

```sh
npm install @axpecter/arbor
```

**Direct download**

Grab the latest `.rbxm` from [Releases](https://github.com/Axp3cter/Arbor/releases).

## What is a behavior tree?

A behavior tree is a way to organize NPC decisions. You build a tree of small nodes, each doing one thing: checking a condition, running an action, or picking between options. Every frame you "tick" the tree, and it walks through the nodes to decide what the NPC should do right now.

The three building blocks:

- **Conditions** check something and instantly return yes or no. "Do I have a target?" "Is my health low?"
- **Actions** do work. "Chase the target." "Play an attack animation." They can finish instantly or take multiple frames.
- **Composites** combine nodes. A **sequence** runs nodes left to right and stops if any fails (like an AND). A **selector** tries nodes left to right and stops when one succeeds (like an OR).

Every node returns one of three statuses each tick:

| Status | Meaning |
|---|---|
| `Status.Success` | Done, it worked |
| `Status.Failure` | Done, it didn't work |
| `Status.Running` | Still working, tick me again next frame |

## Example

```luau
local Arbor = require(path.to.Arbor)

local action    = Arbor.action
local condition = Arbor.condition
local when      = Arbor.when
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

-- Conditions (shorthand)

local hasTarget  = when("target",    function(v) return v ~= nil end)
local isHurt     = when("health",    function(v) return v < 30 end)
local canSee     = when("canSee",    function(v) return v == true end)
local hasAllies  = when("allies",    function(v) return v > 0 end)
local heardNoise = when("lastHeard", function(v) return v ~= nil end)

-- Conditions (full form, for multi-field checks or custom names)

local isLowAndVisible = condition("IsLowAndVisible", function(b)
    return b.health < 30 and b.canSee
end, { "health", "canSee" })

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

## How it works

### Blackboard

The blackboard is where your NPC stores what it knows. You define the fields and their defaults up front:

```luau
local board = Arbor.board({
    target = nil :: Player?,
    health = 100,
})
```

Then read and write them like a normal table:

```luau
board.health = 50
print(board.health) -- 50
```

The difference from a normal table is that writes are tracked. When `board.health` changes, any observer watching `"health"` gets notified automatically. This is what powers the abort system.

You can also loop over it with `for k, v in board do` and take a snapshot with `Arbor.snapshot(board)` when you need a plain copy for saving or logging.

### Conditions

Conditions are simple true/false checks that read from the blackboard. They never return `Running`.

**Shorthand form** for single-key checks. Name and watch keys are auto-derived from the key:

```luau
local hasTarget = when("target", function(v) return v ~= nil end)
local isHurt    = when("health", function(v) return v < 30 end)
```

**Full form** for multi-field checks or when you want a custom name:

```luau
local hasTarget = condition("HasTarget", function(b)
    return b.target ~= nil
end, { "target" })
```

The third argument (`{ "target" }`) is optional. It tells Arbor which blackboard fields this condition depends on. You only need it if you plan to use this condition inside `observe()` for reactive aborts. For plain use in sequences and selectors, you can leave it out.

### Actions

Actions are where your NPC actually does things.

**Simple form** for instant or stateless work. The function runs every tick the action is active:

```luau
local attack = action("Attack", function(_b, agent)
    agent:swingWeapon()
    return Status.Success
end)
```

**Phased form** for work that spans multiple frames, like pathfinding. `start` runs once on entry, `tick` runs every frame after that while you return `Running`, and `halt` runs if the action gets interrupted:

```luau
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
```

### Composites

Composites combine multiple nodes into a group.

**sequence** runs its children left to right. If any child fails, the sequence fails immediately and the rest are skipped. If all children succeed, the sequence succeeds. Use it when you need multiple things to happen in order: "have a target AND chase it AND attack it."

**selector** runs its children left to right. If any child succeeds, the selector succeeds immediately and the rest are skipped. If all children fail, the selector fails. Use it to try options in priority order: "try fleeing OR try fighting OR patrol."

**parallel** ticks all its children every frame at the same time. You tell it how many need to succeed or fail for the parallel to resolve. Good for things like "chase the target while also attacking."

**random** picks one child at random and sticks with it until it finishes. You can pass weights to make some options more likely than others.

By default, `sequence` and `selector` use **memory mode**: if a child returns `Running`, the composite resumes from that child next tick instead of starting over. Pass `{ reactive = true }` to re-evaluate from the first child every tick instead.

### Decorators

Decorators wrap a single child and change its behavior:

| Decorator | What it does |
|---|---|
| `invert(child)` | Flips the result. Success becomes Failure, Failure becomes Success. |
| `succeed(child)` | Always returns Success, even if the child fails. Good for optional behavior. |
| `fail(child)` | Always returns Failure, even if the child succeeds. |
| `loop(child, count?)` | Repeats the child. Pass a number to repeat N times, or leave it out to repeat forever. Stops on Failure. |
| `cooldown(child, seconds)` | After the child succeeds, blocks it for N seconds. Returns Failure during the cooldown. |
| `timeout(child, seconds)` | If the child is still Running after N seconds, forces Failure and halts it. |
| `retry(child, times)` | If the child fails, tries again up to N times before giving up. |
| `guard(condition, child)` | Checks a condition before every tick. If the condition fails, the child is halted and the guard returns Failure. |

### Observers and Aborts

Observers let the tree react to blackboard changes between ticks instead of waiting for the next evaluation.

```luau
observe(isHurt, Abort.Lower, flee)
```

This says: "watch the `isHurt` condition. When it flips to true, abort whatever lower-priority branch is currently running and let this branch take over." The condition's watch keys tell the observer which blackboard fields to listen to.

There are three abort modes:

| Mode | When to use it |
|---|---|
| `Abort.Self` | Halt your own branch if the condition becomes false while you're running. Example: stop chasing if you lose sight of the target. |
| `Abort.Lower` | Interrupt a lower-priority sibling when your condition becomes true. There's a one-tick delay. Example: flee interrupts combat when health drops. |
| `Abort.Restart` | Same as Lower but with no delay. The interrupted branch is halted and the observer's branch starts in the same tick. |

The difference between `guard` and `observe`: `guard` checks the condition once per tick, right before ticking the child. `observe` listens to blackboard writes and can react between ticks. Guard is simpler and cheaper. Use `observe` when you need instant reactions to state changes.

### Services

Services are background updaters that run on a timer while their parent composite is active. They update the blackboard without taking up a slot in the tree.

```luau
selector({
    -- tree children here
}, {
    services = {
        service("Scan", 0.5, function(b, agent)
            b.target = agent:findNearestEnemy()
        end),
    },
})
```

This `Scan` service runs every 0.5 seconds while the selector is active, keeping `board.target` up to date. When the selector is halted or the tree moves elsewhere, the service stops too.

### Context and running the tree

The tree itself is just a structure. To actually run it, you create a **context** that binds the tree to a specific blackboard and agent:

```luau
local ctx = Arbor.context(root, board, myNpc)
```

Then either tick it manually:

```luau
RunService.Heartbeat:Connect(function()
    ctx:tick()
end)
```

Or use the built-in runner:

```luau
ctx:start(10) -- ticks 10 times per second
```

One tree can be shared across many contexts. Each context tracks its own state independently, so 100 NPCs can share the same tree structure without interfering with each other.

When you're done (NPC dies, gets removed, etc.), call `ctx:destroy()`. This stops the runner, halts any running actions so their cleanup code runs, and unregisters all blackboard observers. Without this, you'll leak connections.

## API Reference

### Leaf Nodes

| Function | Description |
|---|---|
| `condition(name, predicate, watchKeys?)` | Pure boolean check. Returns Success or Failure. Watch keys enable `observe`. |
| `when(key, predicate)` | Shorthand condition. Name and watch keys auto-derived from key. Predicate receives `board[key]`. |
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
| `invert(child)` | Flips Success and Failure. |
| `succeed(child)` | Forces Success. Swallows Failure. |
| `fail(child)` | Forces Failure. Swallows Success. |
| `loop(child, count?)` | Repeats child. Omit count for infinite. |
| `cooldown(child, seconds)` | Child can only succeed once per N seconds. |
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