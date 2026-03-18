--!strict
--!optimize 2
-- Tests for Tree wrapper.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Tree", function(): ()
    it("should tick root and return status", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.condition("Yes", function()
            return true
        end))
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should propagate RUNNING", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.action("Wait", function()
            return Arbor.RUNNING
        end))
        expect(tree:tick(ctx)):toBe(Arbor.RUNNING)
    end)

    it("should support nested trees", function(): ()
        local board = Arbor.createBoard({ health = 50, hasTarget = true })
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.selector({
            Arbor.sequence({
                Arbor.condition("LowHealth", function(b)
                    return b:get("health") < 30
                end),
                Arbor.action("Flee", function()
                    return Arbor.RUNNING
                end),
            }),
            Arbor.sequence({
                Arbor.condition("HasTarget", function(b)
                    return b:get("hasTarget") == true
                end),
                Arbor.action("Attack", function()
                    return Arbor.SUCCESS
                end),
            }),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)
end)

return nil
