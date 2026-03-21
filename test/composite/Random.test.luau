--!strict
--!optimize 2

local bt = require(game:GetService("ReplicatedStorage").bt)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Random", function(): ()
    it("picks a child and returns its result", function(): ()
        local node = bt.random { bt.check(function() return true end) }
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("sticks with the same child while running", function(): ()
        local aCount = 0
        local bCount = 0
        local node = bt.random {
            bt.action(function()
                aCount += 1
                return "running"
            end),
            bt.action(function()
                bCount += 1
                return "running"
            end),
        }
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        -- One child was picked and ticked 3 times, the other 0
        expect(aCount + bCount):toBe(3)
        expect(aCount == 3 or bCount == 3):toBe(true)
    end)

    it("halts running child on external halt", function(): ()
        local halted = false
        local node = bt.random {
            bt.action({
                enter = function() return "running" end,
                tick = function() return "running" end,
                halt = function() halted = true end,
            }),
        }
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop()
        expect(halted):toBe(true)
    end)

    it("respects weights (statistical sanity check)", function(): ()
        -- Weight 100 vs weight 0 is not valid (min weight must be positive)
        -- Use extreme disparity: 1000 vs 1
        local aCount = 0
        local bCount = 0
        for _ = 1, 200 do
            local node = bt.random({
                bt.action(function()
                    aCount += 1
                    return "success"
                end),
                bt.action(function()
                    bCount += 1
                    return "success"
                end),
            }, { 1000, 1 })
            local ctx = bt.bind(node, {}, nil)
            ctx:tick(0)
        end
        expect(aCount):toBeGreaterThan(150)
    end)

    it("errors on weight count mismatch", function(): ()
        expect(function()
            bt.random({
                bt.check(function() return true end),
                bt.check(function() return true end),
            }, { 1 }) -- 1 weight for 2 children
        end):toThrow("weight count")
    end)
end)

return nil
