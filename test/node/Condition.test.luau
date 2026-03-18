--!strict
--!optimize 2
-- Tests for Condition node.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Condition", function(): ()
    it("should return SUCCESS when predicate is true", function(): ()
        local board = Arbor.createBoard({ alive = true })
        local ctx = Arbor.createContext(board, nil)
        local node = Arbor.condition("IsAlive", function(b)
            return b:get("alive") == true
        end)
        local tree = Arbor.tree(node)
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should return FAILURE when predicate is false", function(): ()
        local board = Arbor.createBoard({ alive = false })
        local ctx = Arbor.createContext(board, nil)
        local node = Arbor.condition("IsAlive", function(b)
            return b:get("alive") == true
        end)
        local tree = Arbor.tree(node)
        expect(tree:tick(ctx)):toBe(Arbor.FAILURE)
    end)

    it("should never return RUNNING", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local node = Arbor.condition("Always", function()
            return true
        end)
        local tree = Arbor.tree(node)
        local status = tree:tick(ctx)
        expect(status).never:toBe(Arbor.RUNNING)
    end)

    it("should re-evaluate on each tick", function(): ()
        local board = Arbor.createBoard({ val = 0 })
        local ctx = Arbor.createContext(board, nil)
        local node = Arbor.condition("Check", function(b)
            return b:get("val") > 5
        end)
        local tree = Arbor.tree(node)
        expect(tree:tick(ctx)):toBe(Arbor.FAILURE)
        board:set("val", 10)
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)
end)

return nil
