--!strict
--!optimize 2
-- Tests for Parallel composite node.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Parallel", function(): ()
    it("should succeed with RequireAll when all succeed", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.parallel({
            successPolicy = Arbor.Policy.RequireAll,
            failurePolicy = Arbor.Policy.RequireOne,
        }, {
            Arbor.condition("A", function()
                return true
            end),
            Arbor.condition("B", function()
                return true
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should succeed with RequireOne when any succeeds", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.parallel({
            successPolicy = Arbor.Policy.RequireOne,
            failurePolicy = Arbor.Policy.RequireAll,
        }, {
            Arbor.condition("A", function()
                return false
            end),
            Arbor.condition("B", function()
                return true
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should fail with RequireOne failure when any fails", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.parallel({
            successPolicy = Arbor.Policy.RequireAll,
            failurePolicy = Arbor.Policy.RequireOne,
        }, {
            Arbor.condition("A", function()
                return true
            end),
            Arbor.condition("B", function()
                return false
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.FAILURE)
    end)

    it("should return RUNNING when no policy is met", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.parallel({
            successPolicy = Arbor.Policy.RequireAll,
            failurePolicy = Arbor.Policy.RequireAll,
        }, {
            Arbor.condition("A", function()
                return true
            end),
            Arbor.action("B", function()
                return Arbor.RUNNING
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.RUNNING)
    end)

    it("should tick all children every tick", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local aTicks, bTicks = 0, 0
        local tree = Arbor.tree(Arbor.parallel({
            successPolicy = Arbor.Policy.RequireAll,
            failurePolicy = Arbor.Policy.RequireAll,
        }, {
            Arbor.action("A", function()
                aTicks += 1
                return Arbor.RUNNING
            end),
            Arbor.action("B", function()
                bTicks += 1
                return Arbor.RUNNING
            end),
        }))
        tree:tick(ctx)
        tree:tick(ctx)
        expect(aTicks):toBe(2)
        expect(bTicks):toBe(2)
    end)
end)

return nil
