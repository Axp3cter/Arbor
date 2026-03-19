--!strict
--!optimize 2
-- Tests for Condition node.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

local Status = Arbor.Status

describe("Condition", function(): ()
    it("should return Success when predicate is true", function(): ()
        local board = Arbor.board({ alive = true })
        local root = Arbor.condition("IsAlive", function(b) return b.alive == true end)
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should return Failure when predicate is false", function(): ()
        local board = Arbor.board({ alive = false })
        local root = Arbor.condition("IsAlive", function(b) return b.alive == true end)
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Failure)
    end)

    it("should never return Running", function(): ()
        local board = Arbor.board({})
        local root = Arbor.condition("Always", function() return true end)
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()).never:toBe(Status.Running)
    end)

    it("should re-evaluate on each tick", function(): ()
        local board = Arbor.board({ val = 0 })
        local root = Arbor.condition("Check", function(b) return b.val > 5 end)
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Failure)
        board.val = 10
        expect(ctx:tick()):toBe(Status.Success)
    end)
end)

return nil
