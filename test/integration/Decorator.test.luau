--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Invert", function(): ()
    it("flips success to failure", function(): ()
        local node = bt.check(function()
            return true
        end):invert()
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("flips failure to success", function(): ()
        local node = bt.check(function()
            return false
        end):invert()
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("passes running through", function(): ()
        local node = bt.action(function()
            return "running"
        end):invert()
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
    end)

    it("double invert is identity", function(): ()
        local node = bt.check(function()
            return true
        end)
            :invert()
            :invert()
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)
end)

describe("Always", function(): ()
    it("forces success regardless of child result", function(): ()
        local node = bt.check(function()
            return false
        end):always("success")
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("forces failure regardless of child result", function(): ()
        local node = bt.check(function()
            return true
        end):always("failure")
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("passes running through", function(): ()
        local node = bt.action(function()
            return "running"
        end):always("success")
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
    end)
end)

describe("Loop (counted)", function(): ()
    it("runs child N times in one tick for instant actions", function(): ()
        local count = 0
        local node = bt.action(function()
            count += 1
            return "success"
        end):loop(5)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
        expect(count):toBe(5)
    end)

    it("stops on failure", function(): ()
        local count = 0
        local node = bt.action(function()
            count += 1
            return if count == 3 then "failure" else "success"
        end):loop(10)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
        expect(count):toBe(3)
    end)

    it("yields on running, resumes count next tick", function(): ()
        local ticks = 0
        local runOnce = true
        local node = bt.action(function()
            ticks += 1
            if runOnce then
                runOnce = false
                return "running"
            end
            return "success"
        end):loop(3)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
        expect(ctx:tick(0)):toBe("success")
    end)

    it("loop(1) runs child exactly once", function(): ()
        local count = 0
        local node = bt.action(function()
            count += 1
            return "success"
        end):loop(1)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
        expect(count):toBe(1)
    end)
end)

describe("Loop (infinite)", function(): ()
    it("does not spin, yields running after child success", function(): ()
        local count = 0
        local node = bt.action(function()
            count += 1
            return "success"
        end):loop()
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(count):toBe(1)
    end)

    it("stops on child failure", function(): ()
        local count = 0
        local node = bt.action(function()
            count += 1
            return if count >= 3 then "failure" else "success"
        end):loop()
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- success, yields running
        ctx:tick(0) -- success, yields running
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("keeps running when child returns running", function(): ()
        local node = bt.action(function()
            return "running"
        end):loop()
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
        expect(ctx:tick(0)):toBe("running")
    end)
end)

describe("Cooldown", function(): ()
    it("blocks child during cooldown period", function(): ()
        local node = bt.check(function()
            return true
        end):cooldown(10)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("passes through child failure without starting cooldown", function(): ()
        local shouldPass = false
        local node = bt.check(function()
            return shouldPass
        end):cooldown(10)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
        shouldPass = true
        expect(ctx:tick(0)):toBe("success")
    end)

    it("persists across branch switches (halt does not clear timestamp)", function(): ()
        local count = 0
        local shouldFight = true
        local attack = bt.action(function()
            count += 1
            return "success"
        end):cooldown(999)

        local root = bt.select({
            bt.sequence({
                bt.check(function()
                    return shouldFight
                end),
                attack,
            }),
            bt.check(function()
                return true
            end),
        })
        local ctx = bt.bind(root, {}, nil)

        ctx:tick(0)
        expect(count):toBe(1)

        shouldFight = false
        ctx:tick(0)

        shouldFight = true
        ctx:tick(0)
        expect(count):toBe(1)
    end)

    it("is cleared by ctx:stop()", function(): ()
        local count = 0
        local node = bt.action(function()
            count += 1
            return "success"
        end):cooldown(999)
        local ctx = bt.bind(node, {}, nil)

        ctx:tick(0)
        expect(count):toBe(1)
        expect(ctx:tick(0)):toBe("failure")

        ctx:stop()
        expect(ctx:tick(0)):toBe("success")
        expect(count):toBe(2)
    end)

    it("is cleared by ctx:destroy() (fresh context needed)", function(): ()
        local count = 0
        local tree = bt.action(function()
            count += 1
            return "success"
        end):cooldown(999)

        local ctx1 = bt.bind(tree, {}, nil)
        ctx1:tick(0)
        expect(count):toBe(1)
        expect(ctx1:tick(0)):toBe("failure")
        ctx1:destroy()

        -- New context, shared tree. Cooldown was per-context state.
        local ctx2 = bt.bind(tree, {}, nil)
        expect(ctx2:tick(0)):toBe("success")
        expect(count):toBe(2)
    end)
end)

describe("Timeout", function(): ()
    it("passes through child result when within time", function(): ()
        local node = bt.check(function()
            return true
        end):timeout(5)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("returns failure and halts child when deadline exceeded", function(): ()
        local halted = false
        local node = bt.action({
            enter = function()
                return "running"
            end,
            tick = function()
                return "running"
            end,
            halt = function()
                halted = true
            end,
        }):timeout(1.0)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        task.wait(1.1)
        expect(ctx:tick(0)):toBe("failure")
        expect(halted):toBe(true)
    end)

    it("clears timer on child success, does not carry over", function(): ()
        local callCount = 0
        local node = bt.action(function()
            callCount += 1
            return if callCount == 1 then "running" else "success"
        end):timeout(5)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- running, starts timer
        ctx:tick(0) -- success, clears timer
        ctx:tick(0) -- fresh entry, no stale timer
        expect(callCount):toBe(3)
    end)
end)

describe("Retry", function(): ()
    it("retries on failure up to N times", function(): ()
        local attempts = 0
        local node = bt.action(function()
            attempts += 1
            return if attempts >= 3 then "success" else "failure"
        end):retry(5)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        expect(ctx:tick(0)):toBe("success")
        expect(attempts):toBe(3)
    end)

    it("returns failure after exhausting retries", function(): ()
        local node = bt.check(function()
            return false
        end):retry(2)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("resets child state between attempts (enter is re-called)", function(): ()
        local enterCount = 0
        local node = bt.action({
            enter = function()
                enterCount += 1
                return "running"
            end,
            tick = function()
                return "failure"
            end,
        }):retry(3)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(ctx:tick(0)):toBe("failure")
        expect(enterCount):toBe(3)
    end)

    it("passes through success immediately", function(): ()
        local node = bt.check(function()
            return true
        end):retry(5)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("passes through running without counting an attempt", function(): ()
        local node = bt.action(function()
            return "running"
        end):retry(1)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
        expect(ctx:tick(0)):toBe("running")
        expect(ctx:tick(0)):toBe("running")
    end)
end)

describe("Guard", function(): ()
    it("ticks child when check passes", function(): ()
        local ticked = false
        local node = bt.action(function()
            ticked = true
            return "success"
        end):guard(function()
            return true
        end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(ticked):toBe(true)
    end)

    it("returns failure when check fails", function(): ()
        local node = bt.action(function()
            return "success"
        end):guard(function()
            return false
        end)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("halts running child when check flips to false", function(): ()
        local halted = false
        local shouldPass = true
        local node = bt.action({
            enter = function()
                return "running"
            end,
            tick = function()
                return "running"
            end,
            halt = function()
                halted = true
            end,
        }):guard(function()
            return shouldPass
        end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        shouldPass = false
        ctx:tick(0)
        expect(halted):toBe(true)
    end)

    it("does not halt child that was never running", function(): ()
        local haltCount = 0
        local node = bt.action({
            enter = function()
                return "running"
            end,
            tick = function()
                return "running"
            end,
            halt = function()
                haltCount += 1
            end,
        }):guard(function()
            return false
        end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(haltCount):toBe(0)
    end)

    it("guard check receives board", function(): ()
        local gotBoard: any = nil
        local board = { hp = 42 }
        local node = bt.action(function()
            return "success"
        end):guard(function(b)
            gotBoard = b
            return true
        end)
        local ctx = bt.bind(node, board, nil)
        ctx:tick(0)
        expect(gotBoard):toBe(board)
    end)
end)

describe("Tag", function(): ()
    it("passes through child result transparently", function(): ()
        local node = bt.check(function()
            return true
        end):tag("MyCheck")
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("does not affect running behavior", function(): ()
        local node = bt.action(function()
            return "running"
        end):tag("RunForever")
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
    end)
end)

describe("Serve", function(): ()
    it("ticks polls before child", function(): ()
        local log: { string } = {}
        local poll = bt.poll(0, function()
            table.insert(log, "poll")
        end)
        local child = bt.action(function()
            table.insert(log, "child")
            return "success"
        end)
        local node = child:serve(poll)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(log[1]):toBe("poll")
        expect(log[2]):toBe("child")
    end)

    it("halts polls when child is halted, poll fires fresh on re-entry", function(): ()
        local fireCount = 0
        local poll = bt.poll(999, function()
            fireCount += 1
        end)
        local child = bt.action({
            enter = function()
                return "running"
            end,
            tick = function()
                return "running"
            end,
        })
        local node = child:serve(poll)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(fireCount):toBe(1)
        ctx:stop()
        ctx:tick(0)
        expect(fireCount):toBe(2)
    end)

    it("supports multiple polls", function(): ()
        local aFired = false
        local bFired = false
        local pollA = bt.poll(0, function()
            aFired = true
        end)
        local pollB = bt.poll(0, function()
            bFired = true
        end)
        local child = bt.action(function()
            return "success"
        end)
        local node = child:serve(pollA, pollB)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(aFired):toBe(true)
        expect(bFired):toBe(true)
    end)
end)

describe("Decorator chaining", function(): ()
    it("composes correctly: timeout then retry then loop", function(): ()
        local count = 0
        local node = bt.action(function()
            count += 1
            return "success"
        end)
            :timeout(5)
            :retry(3)
            :loop(2)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(count):toBe(2)
    end)

    it("composes correctly: invert then always", function(): ()
        local node = bt.check(function()
            return true
        end)
            :invert()
            :always("success")
        local ctx = bt.bind(node, {}, nil)
        -- check returns success, invert flips to failure, always forces success
        expect(ctx:tick(0)):toBe("success")
    end)
end)

describe("Throttle", function(): ()
    it("ticks child on first call and returns its result", function(): ()
        local count = 0
        local node = bt.check(function()
            count += 1
            return true
        end):throttle(10)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
        expect(count):toBe(1)
    end)

    it("returns cached result without ticking child while fresh", function(): ()
        local count = 0
        local node = bt.check(function()
            count += 1
            return true
        end):throttle(10)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(count):toBe(1)
    end)

    it("re-ticks child after interval expires", function(): ()
        local count = 0
        local node = bt.check(function()
            count += 1
            return true
        end):throttle(0.2)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(count):toBe(1)
        task.wait(0.3)
        ctx:tick(0)
        expect(count):toBe(2)
    end)

    it("caches failure results the same as success", function(): ()
        local count = 0
        local node = bt.check(function()
            count += 1
            return false
        end):throttle(10)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
        expect(ctx:tick(0)):toBe("failure")
        expect(count):toBe(1)
    end)

    it("passes through running children every tick", function(): ()
        local count = 0
        local node = bt.action(function()
            count += 1
            return "running"
        end):throttle(10)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(count):toBe(3)
    end)

    it("caches result once running child completes", function(): ()
        local ticks = 0
        local node = bt.action(function()
            ticks += 1
            return if ticks >= 3 then "success" else "running"
        end):throttle(10)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- running
        ctx:tick(0) -- running
        ctx:tick(0) -- success, cached
        expect(ctx:tick(0)):toBe("success") -- cached, child not ticked
        expect(ticks):toBe(3)
    end)

    it("halts running child on external halt", function(): ()
        local halted = false
        local node = bt.action({
            enter = function()
                return "running"
            end,
            tick = function()
                return "running"
            end,
            halt = function()
                halted = true
            end,
        }):throttle(10)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop()
        expect(halted):toBe(true)
    end)

    it("preserves cache across branch-level halts", function(): ()
        local count = 0
        local shouldFight = true
        local throttled = bt.action(function()
            count += 1
            return "success"
        end):throttle(999)

        local root = bt.select({
            bt.sequence({
                bt.check(function()
                    return shouldFight
                end),
                throttled,
            }),
            bt.check(function()
                return true
            end),
        })
        local ctx = bt.bind(root, {}, nil)

        ctx:tick(0)
        expect(count):toBe(1)

        shouldFight = false
        ctx:tick(0) -- branch switches, throttle halted

        shouldFight = true
        ctx:tick(0) -- branch returns, cache still fresh
        expect(count):toBe(1)
    end)

    it("cache is cleared by ctx:stop()", function(): ()
        local count = 0
        local node = bt.action(function()
            count += 1
            return "success"
        end):throttle(999)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(count):toBe(1)
        ctx:stop()
        ctx:tick(0)
        expect(count):toBe(2)
    end)
end)

return nil
