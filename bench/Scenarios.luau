--!strict
--!optimize 2
-- Benchmark scenarios. Each exposes a specific cost, not a best-case.

local bt = require(script.Parent.Parent)

-- Scenarios --------------------------------------------------------------

local Scenarios = {}

-- 1. Leaf cost isolation -------------------------------------------------

Scenarios.CheckLeaf = bt.check(function(b)
    return (b :: any).hp > 0
end)

Scenarios.SimpleAction = bt.action(function(b)
    (b :: any).x = ((b :: any).x :: number) + 1
    return "success"
end)

Scenarios.RunningAction = bt.action(function()
    return "running"
end)

Scenarios.WaitLeaf = bt.wait(999)

Scenarios.PollLeaf = bt.poll(0.1, function(b)
    (b :: any).scanned = true
end)

-- 2. Composite overhead --------------------------------------------------

-- Selector: always re-evaluates from top, 5 failing checks then 1 running
Scenarios.SelectorFallthrough = bt.select({
    bt.check(function(b)
        return (b :: any).a
    end),
    bt.check(function(b)
        return (b :: any).b
    end),
    bt.check(function(b)
        return (b :: any).c
    end),
    bt.check(function(b)
        return (b :: any).d
    end),
    bt.check(function(b)
        return (b :: any).e
    end),
    bt.action(function()
        return "running"
    end),
})

-- Sequence: sticky resume from running child, 2 passed + 1 running
Scenarios.SequenceResume = bt.sequence({
    bt.check(function()
        return true
    end),
    bt.check(function()
        return true
    end),
    bt.action(function()
        return "running"
    end),
})

-- Parallel: 3 children, mixed resolved and running
Scenarios.ParallelMixed = bt.parallel(2)({
    bt.check(function()
        return true
    end),
    bt.action(function()
        return "running"
    end),
    bt.action(function()
        return "running"
    end),
})

-- Deep: 20 levels of wrapping around a single check
Scenarios.DeepNesting = (function()
    local node: bt.Node = bt.check(function()
        return true
    end)
    for _ = 1, 20 do
        node = bt.sequence({ node })
    end
    return node
end)()

-- Wide: 50 failing children, last one succeeds
Scenarios.WideFallthrough = (function()
    local children: { bt.Node } = {}
    for i = 1, 50 do
        if i == 50 then
            children[i] = bt.check(function()
                return true
            end)
        else
            children[i] = bt.check(function()
                return false
            end)
        end
    end
    return bt.select(children)
end)()

-- 3. Decorator cost ------------------------------------------------------

Scenarios.SingleDecorator = bt.check(function()
    return true
end):invert()

Scenarios.ChainedDecorators = bt.action(function()
    return "running"
end)
    :timeout(999)
    :retry(3)
    :guard(function()
        return true
    end)

-- 4. Halt cost (selector priority switch) --------------------------------

-- Tree where child 2 is a deep running subtree, and child 1 can win
Scenarios.HaltCascade = (function()
    local deep: bt.Node = bt.action(function()
        return "running"
    end)
    for _ = 1, 10 do
        deep = bt.sequence({ bt.check(function()
            return true
        end), deep })
    end
    return bt.select({ bt.check(function(b)
        return (b :: any).win
    end), deep })
end)()

-- 5. Real-world combat tree with polls, cooldowns, running actions -------

Scenarios.CombatTree = (function()
    local board = {
        target = true,
        health = 80,
        canSee = true,
        allies = 2,
    }

    local tree = bt.select({
        bt.sequence({
            bt.check(function(b)
                return (b :: any).health < 30
            end),
            bt.action(function()
                return "running"
            end), -- flee
        }),
        bt.sequence({
            bt.check(function(b)
                return (b :: any).target ~= nil
            end),
            bt.check(function(b)
                return (b :: any).canSee
            end),
            bt.parallel(1)({
                bt.action(function()
                    return "running"
                end):timeout(6), -- chase
                bt.sequence({
                    bt.action(function()
                        return "success"
                    end):cooldown(0.8),
                    bt.wait(0.2),
                }):loop(),
            }),
        }),
        bt.action(function()
            return "running"
        end), -- patrol
    }):serve(bt.poll(0.3, function(b)
        (b :: any).scanned = true
    end))

    return { tree = tree, board = board }
end)()

-- Defaults ---------------------------------------------------------------

Scenarios.BOARD_BASIC = table.freeze({ hp = 100, x = 0 })
Scenarios.BOARD_SELECTOR = table.freeze({ a = false, b = false, c = false, d = false, e = false })
Scenarios.BOARD_HALT = table.freeze({ win = false })
Scenarios.BOARD_HALT_WIN = table.freeze({ win = true })

return table.freeze(Scenarios)
