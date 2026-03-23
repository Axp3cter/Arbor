--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Select", function(): ()
    it("returns success on first child success", function(): ()
        local node = bt.select({
            bt.check(function()
                return false
            end),
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

    it("returns failure when all children fail", function(): ()
        local node = bt.select({
            bt.check(function()
                return false
            end),
            bt.check(function()
                return false
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("does not tick children after a success", function(): ()
        local cTicked = false
        local node = bt.select({
            bt.check(function()
                return false
            end),
            bt.check(function()
                return true
            end),
            bt.action(function()
                cTicked = true
                return "success"
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(cTicked):toBe(false)
    end)

    it("re-evaluates from child 1 every tick", function(): ()
        local aTicks = 0
        local node = bt.select({
            bt.action(function()
                aTicks += 1
                return "failure"
            end),
            bt.action(function()
                return "running"
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        expect(aTicks):toBe(2)
    end)

    it("halts previously running child when higher-priority takes over", function(): ()
        local halted = false
        local shouldSucceed = false
        local node = bt.select({
            bt.check(function()
                return shouldSucceed
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
        shouldSucceed = true
        ctx:tick(0)
        expect(halted):toBe(true)
    end)

    it("halts previously running child when a different running child takes over", function(): ()
        local haltA = false
        local haltB = false
        local aReturns: bt.Status = "running"
        local node = bt.select({
            bt.action({
                enter = function()
                    return aReturns
                end,
                tick = function()
                    return aReturns
                end,
                halt = function()
                    haltA = true
                end,
            }),
            bt.action({
                enter = function()
                    return "running"
                end,
                tick = function()
                    return "running"
                end,
                halt = function()
                    haltB = true
                end,
            }),
        })
        local ctx = bt.bind(node, {}, nil)
        aReturns = "failure"
        ctx:tick(0) -- A fails, B starts running
        aReturns = "running"
        ctx:tick(0) -- A running, B should be halted
        expect(haltB):toBe(true)
        expect(haltA):toBe(false)
    end)

    it("works with a single child", function(): ()
        local node = bt.select({ bt.check(function()
            return true
        end) })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("returns failure for empty children", function(): ()
        local node = bt.select({})
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)
end)

return nil
