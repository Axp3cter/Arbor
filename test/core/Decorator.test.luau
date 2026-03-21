--!strict
--!optimize 2

local bt = require(game:GetService("ReplicatedStorage").bt)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Invert", function(): ()
    it("flips success to failure", function(): ()
        local node = bt.check(function() return true end):invert()
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("flips failure to success", function(): ()
        local node = bt.check(function() return false end):invert()
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("passes running through", function(): ()
        local node = bt.action(function() return "running" end):invert()
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
    end)

    it("double invert is identity", function(): ()
        local node = bt.check(function() return true end):invert():invert()
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)
end)

describe("Always", function(): ()
    it("forces success regardless of child", function(): ()
        local node = bt.check(function() return false end):always("success")
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("passes running through", function(): ()
        local node = bt.action(function() return "running" end):always("success")
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
        expect(ctx:tick(0)):toBe("running") -- iteration 1 → running
        expect(ctx:tick(0)):toBe("success") -- continues from where it left off
    end)
end)

describe("Loop (infinite)", function(): ()
    it("does not spin — yields running after child success", function(): ()
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
        ctx:tick(0) -- success → running
        ctx:tick(0) -- success → running
        expect(ctx:tick(0)):toBe("failure")
    end)
end)

describe("Cooldown", function(): ()
    it("blocks child during cooldown period", function(): ()
        local node = bt.check(function() return true end):cooldown(10)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("passes through child failure without starting cooldown", function(): ()
        local shouldPass = false
        local node = bt.check(function() return shouldPass end):cooldown(10)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure") -- child failed, no cooldown set
        shouldPass = true
        expect(ctx:tick(0)):toBe("success") -- child succeeds, not blocked
    end)

    it("persists across branch switches (halt does not clear timestamp)", function(): ()
        local count = 0
        local shouldFight = true
        local attack = bt.action(function()
            count += 1
            return "success"
        end):cooldown(999)

        local root = bt.select {
            bt.sequence {
                bt.check(function() return shouldFight end),
                attack,
            },
            bt.check(function() return true end),
        }
        local ctx = bt.bind(root, {}, nil)

        ctx:tick(0) -- attack fires (count=1), cooldown starts
        expect(count):toBe(1)

        shouldFight = false
        ctx:tick(0) -- fight branch fails, selector falls through

        shouldFight = true
        ctx:tick(0) -- fight re-entered, attack on cooldown → failure → selector falls through
        expect(count):toBe(1) -- attack did NOT fire again
    end)
end)

describe("Timeout", function(): ()
    it("passes through child result when within time", function(): ()
        local node = bt.check(function() return true end):timeout(5)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("returns failure and halts child when deadline exceeded", function(): ()
        local halted = false
        local node = bt.action({
            enter = function() return "running" end,
            tick = function() return "running" end,
            halt = function() halted = true end,
        }):timeout(1.0)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        -- Force clock to advance past deadline
        task.wait(1.1)
        expect(ctx:tick(0)):toBe("failure")
        expect(halted):toBe(true)
    end)

    it("clears state on child success", function(): ()
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
        ctx:tick(0) -- attempt 1 → fail → running
        ctx:tick(0) -- attempt 2 → fail → running
        expect(ctx:tick(0)):toBe("success")
        expect(attempts):toBe(3)
    end)

    it("returns failure after exhausting retries", function(): ()
        local node = bt.check(function() return false end):retry(2)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- attempt 1 → fail → running
        expect(ctx:tick(0)):toBe("failure") -- attempt 2 → fail → exhausted
    end)

    it("resets child state between attempts (enter is re-called)", function(): ()
        local enterCount = 0
        local node = bt.action({
            enter = function()
                enterCount += 1
                return "running"
            end,
            tick = function() return "failure" end,
        }):retry(3)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- enter 1 → running
        ctx:tick(0) -- tick → failure, attempt 1
        ctx:tick(0) -- enter 2 → running (state was reset)
        ctx:tick(0) -- tick → failure, attempt 2
        ctx:tick(0) -- enter 3 → running
        expect(ctx:tick(0)):toBe("failure") -- tick → failure, exhausted
        expect(enterCount):toBe(3)
    end)
end)

describe("Guard", function(): ()
    it("ticks child when check passes", function(): ()
        local ticked = false
        local node = bt.action(function()
            ticked = true
            return "success"
        end):guard(function() return true end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(ticked):toBe(true)
    end)

    it("returns failure when check fails", function(): ()
        local node = bt.action(function() return "success" end)
            :guard(function() return false end)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("halts running child when check flips to false", function(): ()
        local halted = false
        local shouldPass = true
        local node = bt.action({
            enter = function() return "running" end,
            tick = function() return "running" end,
            halt = function() halted = true end,
        }):guard(function() return shouldPass end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- guard passes, child enters running
        shouldPass = false
        ctx:tick(0) -- guard fails, child should be halted
        expect(halted):toBe(true)
    end)

    it("does not halt child that was never running", function(): ()
        local haltCount = 0
        local node = bt.action({
            enter = function() return "running" end,
            tick = function() return "running" end,
            halt = function() haltCount += 1 end,
        }):guard(function() return false end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- guard fails immediately, child never entered
        ctx:tick(0)
        ctx:tick(0)
        expect(haltCount):toBe(0)
    end)
end)

describe("Tag", function(): ()
    it("passes through child result transparently", function(): ()
        local node = bt.check(function() return true end):tag("MyCheck")
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
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
        local poll = bt.poll(999, function() fireCount += 1 end)
        local child = bt.action({
            enter = function() return "running" end,
            tick = function() return "running" end,
        })
        local node = child:serve(poll)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- poll fires (first tick), child enters
        expect(fireCount):toBe(1)

        ctx:stop() -- halts child and poll (poll timer cleared)

        ctx:tick(0) -- poll fires again (timer was cleared, so it's a fresh first tick)
        expect(fireCount):toBe(2)
    end)
end)

describe("Decorator chaining", function(): ()
    it("composes correctly: timeout → retry → loop", function(): ()
        local count = 0
        local node = bt.action(function()
            count += 1
            return "success"
        end):timeout(5):retry(3):loop(2)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        -- loop(2): runs inner twice. Inner is retry(3) wrapping timeout(5) wrapping action.
        -- action succeeds instantly → timeout passes through → retry passes through → loop counts.
        expect(count):toBe(2)
    end)
end)

return nil
