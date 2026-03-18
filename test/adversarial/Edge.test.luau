--!strict
--!optimize 2
-- Adversarial and edge-case tests.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Edge cases", function(): ()
    it("should handle sequence with single child", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.sequence({
            Arbor.condition("Only", function()
                return true
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should handle selector with single child", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.selector({
            Arbor.condition("Only", function()
                return false
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.FAILURE)
    end)

    it("should handle deeply nested trees", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local leaf = Arbor.condition("Deep", function()
            return true
        end)
        local node: Arbor.Node = leaf
        for _ = 1, 10 do
            node = Arbor.sequence({ node })
        end
        local tree = Arbor.tree(node)
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should handle nil agent", function(): ()
        local board = Arbor.createBoard({ val = 1 })
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.action("NoAgent", function(b, _agent)
            return if b:get("val") == 1 then Arbor.SUCCESS else Arbor.FAILURE
        end))
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should share one tree across multiple contexts", function(): ()
        local board1 = Arbor.createBoard({ count = 0 })
        local board2 = Arbor.createBoard({ count = 0 })
        local ctx1 = Arbor.createContext(board1, nil)
        local ctx2 = Arbor.createContext(board2, nil)
        local tree = Arbor.tree(Arbor.action("Inc", function(b)
            b:set("count", b:get("count") + 1)
            return Arbor.SUCCESS
        end))
        tree:tick(ctx1)
        tree:tick(ctx1)
        tree:tick(ctx2)
        expect(board1:get("count")):toBe(2)
        expect(board2:get("count")):toBe(1)
    end)

    it("should handle rapid blackboard toggles", function(): ()
        local board = Arbor.createBoard({ flag = false })
        local changes = 0
        board:observe("flag", function()
            changes += 1
        end)
        for _ = 1, 100 do
            board:set("flag", true)
            board:set("flag", false)
        end
        expect(changes):toBe(200)
    end)

    it("should handle invert of invert", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.invert(Arbor.invert(Arbor.condition("Yes", function()
            return true
        end))))
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should handle parallel with all RUNNING children", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.parallel({
            successPolicy = Arbor.Policy.RequireAll,
            failurePolicy = Arbor.Policy.RequireAll,
        }, {
            Arbor.action("A", function()
                return Arbor.RUNNING
            end),
            Arbor.action("B", function()
                return Arbor.RUNNING
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.RUNNING)
    end)
end)

return nil
