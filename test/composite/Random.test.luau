--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Random", function(): ()
    it("picks a child and returns its result", function(): ()
        local node = bt.random({ bt.check(function() return true end) })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("sticks with the same child while running", function(): ()
        local aCount = 0
        local bCount = 0
        local node = bt.random({
            bt.action(function()
                aCount += 1
                return "running"
            end),
            bt.action(function()
                bCount += 1
                return "running"
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(aCount + bCount):toBe(3)
        expect(aCount == 3 or bCount == 3):toBe(true)
    end)

    it("re-picks after resolution, not sticky across completions", function(): ()
        --[[
            With 200 trials and 2 children, the probability of always
            picking the same child is astronomically low.
        ]]
        local pickedA = 0
        local pickedB = 0
        for _ = 1, 200 do
            local node = bt.random({
                bt.action(function()
                    pickedA += 1
                    return "success"
                end),
                bt.action(function()
                    pickedB += 1
                    return "success"
                end),
            })
            local ctx = bt.bind(node, {}, nil)
            ctx:tick(0)
        end
        expect(pickedA):toBeGreaterThan(10)
        expect(pickedB):toBeGreaterThan(10)
    end)

    it("halts running child on external halt", function(): ()
        local halted = false
        local node = bt.random({
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

    it("respects weights (statistical sanity check)", function(): ()
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
            }, { 1 })
        end):toThrow("weight count")
    end)

    it("errors on empty children", function(): ()
        expect(function()
            bt.random({})
        end):toThrow("at least 1 child")
    end)

    it("clears selection on child completion", function(): ()
        local count = 0
        local node = bt.random({
            bt.action(function()
                count += 1
                return "success"
            end),
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(count):toBe(3)
    end)
end)

return nil
