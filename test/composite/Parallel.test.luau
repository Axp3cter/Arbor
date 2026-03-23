--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Parallel", function(): ()
    it("succeeds when succeed threshold is met", function(): ()
        local node = bt.parallel(2)({
            bt.check(function() return true end),
            bt.check(function() return true end),
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("fails when fail threshold is met", function(): ()
        local node = bt.parallel(2, 1)({
            bt.check(function() return false end),
            bt.check(function() return true end),
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("returns running when neither threshold is met", function(): ()
        local node = bt.parallel(2)({
            bt.check(function() return true end),
            bt.action(function() return "running" end),
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
    end)

    it("does not re-tick resolved children", function(): ()
        local aTicks = 0
        local node = bt.parallel(2)({
            bt.action(function()
                aTicks += 1
                return "success"
            end),
            bt.action(function() return "running" end),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(aTicks):toBe(1)
    end)

    it("halts remaining active children when succeed threshold met mid-tick", function(): ()
        local halted = false
        local node = bt.parallel(1)({
            bt.check(function() return true end),
            bt.action({
                enter = function() return "running" end,
                tick = function() return "running" end,
                halt = function() halted = true end,
            }),
        })
        local ctx = bt.bind(node, {}, nil)
        --[[
            Child 1 succeeds, threshold met before child 2 is ticked.
            Child 2 was never entered so halt is idempotent.
        ]]
        ctx:tick(0)
        expect(halted):toBe(false)
    end)

    it("halts active running children when succeed threshold met", function(): ()
        local halted = false
        local ticks = 0
        local node = bt.parallel(1)({
            bt.action(function()
                ticks += 1
                return if ticks >= 2 then "success" else "running"
            end),
            bt.action({
                enter = function() return "running" end,
                tick = function() return "running" end,
                halt = function() halted = true end,
            }),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- Both start running.
        ctx:tick(0) -- Child 1 succeeds, child 2 should be halted.
        expect(halted):toBe(true)
    end)

    it("halts running children on external halt", function(): ()
        local halted = false
        local node = bt.parallel(2)({
            bt.action(function() return "running" end),
            bt.action({
                enter = function() return "running" end,
                tick = function() return "running" end,
                halt = function() halted = true end,
            }),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop()
        expect(halted):toBe(true)
    end)

    it("defaults fail threshold to child count (all must fail)", function(): ()
        local node = bt.parallel(2)({
            bt.check(function() return false end),
            bt.action(function() return "running" end),
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
    end)

    it("re-enters cleanly after completing", function(): ()
        local count = 0
        local node = bt.parallel(1)({
            bt.action(function()
                count += 1
                return "success"
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        expect(count):toBe(2)
    end)
end)

describe("Parallel (deadlock prevention)", function(): ()
    it("returns failure when all children resolve without meeting either threshold", function(): ()
        --[[
            3 children: succeed=3, fail=3. If 1 succeeds and 2 fail,
            neither threshold (3) is met. All children resolved with
            no winner. The deadlock guard should return failure.
        ]]
        local node = bt.parallel(3, 3)({
            bt.check(function() return true end),
            bt.check(function() return false end),
            bt.check(function() return false end),
        })
        local ctx = bt.bind(node, {}, nil)
        -- successes=1, failures=2, neither >= 3. Deadlock guard returns failure.
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("does not false-positive when children are still running", function(): ()
        local node = bt.parallel(2, 2)({
            bt.check(function() return true end),
            bt.action(function() return "running" end),
        })
        local ctx = bt.bind(node, {}, nil)
        -- 1 success, 0 failures, 1 still running. Should stay running.
        expect(ctx:tick(0)):toBe("running")
    end)
end)

describe("Parallel (validation)", function(): ()
    it("errors on empty children", function(): ()
        expect(function()
            bt.parallel(1)({})
        end):toThrow("at least 1 child")
    end)

    it("errors when succeed threshold is zero", function(): ()
        expect(function()
            bt.parallel(0)({ bt.check(function() return true end) })
        end):toThrow("must be > 0")
    end)

    it("errors when succeed threshold exceeds child count", function(): ()
        expect(function()
            bt.parallel(5)({
                bt.check(function() return true end),
                bt.check(function() return true end),
            })
        end):toThrow("exceeds child count")
    end)

    it("errors when fail threshold exceeds child count", function(): ()
        expect(function()
            bt.parallel(1, 5)({
                bt.check(function() return true end),
                bt.check(function() return true end),
            })
        end):toThrow("exceeds child count")
    end)
end)

return nil
