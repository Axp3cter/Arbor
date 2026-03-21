--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").bt)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Parallel", function(): ()
    it("succeeds when succeed threshold is met", function(): ()
        local node = bt.parallel(2)({
            bt.check(function()
                return true
            end),
            bt.check(function()
                return true
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("fails when fail threshold is met", function(): ()
        local node = bt.parallel(2, 1)({
            bt.check(function()
                return false
            end),
            bt.check(function()
                return true
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("returns running when neither threshold is met", function(): ()
        local node = bt.parallel(2)({
            bt.check(function()
                return true
            end),
            bt.action(function()
                return "running"
            end),
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
            bt.action(function()
                return "running"
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(aTicks):toBe(1)
    end)

    it("halts running children when threshold met mid-tick", function(): ()
        local halted = false
        local node = bt.parallel(1)({
            bt.check(function()
                return true
            end),
            bt.action({
                enter = function()
                    return "running"
                end,
                tick = function()
                    return "running"
                end,
                halt = function()
                    halted = true
                end,
            }),
        })
        local ctx = bt.bind(node, {}, nil)
        -- Child 1 succeeds immediately → threshold met → child 2 never ticked
        -- But child 2 was never entered, so halt should not call user halt
        -- Actually: parallel ticks children in order, child 1 succeeds, threshold met,
        -- haltActive runs on child 2 which was never entered → idempotent halt
        ctx:tick(0)
        expect(halted):toBe(false) -- child 2 was never entered
    end)

    it("halts running children on external halt", function(): ()
        local halted = false
        local node = bt.parallel(2)({
            bt.action(function()
                return "running"
            end),
            bt.action({
                enter = function()
                    return "running"
                end,
                tick = function()
                    return "running"
                end,
                halt = function()
                    halted = true
                end,
            }),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop()
        expect(halted):toBe(true)
    end)

    it("defaults fail threshold to child count (all must fail)", function(): ()
        -- 2 children, default fail = 2. One failure should not resolve.
        local node = bt.parallel(2)({
            bt.check(function()
                return false
            end),
            bt.action(function()
                return "running"
            end),
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

return nil
