--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Sequence", function(): ()
    it("returns success when all children succeed", function(): ()
        local node = bt.sequence({
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

    it("returns failure on first child failure", function(): ()
        local cTicked = false
        local node = bt.sequence({
            bt.check(function()
                return true
            end),
            bt.check(function()
                return false
            end),
            bt.action(function()
                cTicked = true
                return "success"
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
        expect(cTicked):toBe(false)
    end)

    it("resumes from running child, does not re-tick passed children", function(): ()
        local aTicks = 0
        local bTicks = 0
        local node = bt.sequence({
            bt.action(function()
                aTicks += 1
                return "success"
            end),
            bt.action(function()
                bTicks += 1
                return if bTicks >= 3 then "success" else "running"
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(aTicks):toBe(1)
        expect(bTicks):toBe(3)
    end)

    it("halts running child when externally halted", function(): ()
        local halted = false
        local node = bt.sequence({
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
        ctx:tick(0)
        ctx:stop()
        expect(halted):toBe(true)
    end)

    it("re-enters cleanly after completing", function(): ()
        local enterCount = 0
        local node = bt.sequence({
            bt.action(function()
                enterCount += 1
                return "success"
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        expect(enterCount):toBe(2)
    end)

    it("returns success for empty children (vacuous truth)", function(): ()
        local node = bt.sequence({})
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("only halts the running child on failure, not completed children", function(): ()
        local aHalted = false
        local bHalted = false
        local node = bt.sequence({
            bt.action({
                enter = function()
                    return "success"
                end,
                halt = function()
                    aHalted = true
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
                    bHalted = true
                end,
            }),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop()
        expect(aHalted):toBe(false)
        expect(bHalted):toBe(true)
    end)
end)

return nil
