--!strict
--!optimize 2
-- Adversarial and edge-case tests.

local Arbor = require(game:GetService("ReplicatedStorage").Arbor)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

local Status = Arbor.Status

describe("Edge cases", function(): ()
    it("should handle sequence with single child", function(): ()
        local board = Arbor.board({})
        local root = Arbor.sequence({ Arbor.condition("Only", function()
            return true
        end) })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should handle selector with single child", function(): ()
        local board = Arbor.board({})
        local root = Arbor.selector({ Arbor.condition("Only", function()
            return false
        end) })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Failure)
    end)

    it("should handle deeply nested trees", function(): ()
        local board = Arbor.board({})
        local leaf = Arbor.condition("Deep", function()
            return true
        end)
        local node: Arbor.Node = leaf
        for _ = 1, 10 do
            node = Arbor.sequence({ node })
        end
        local ctx = Arbor.context(node, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should handle nil agent", function(): ()
        local board = Arbor.board({ val = 1 })
        local root = Arbor.action("NoAgent", function(b)
            return if b.val == 1 then Status.Success else Status.Failure
        end)
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should share one tree across multiple contexts", function(): ()
        local board1 = Arbor.board({ count = 0 })
        local board2 = Arbor.board({ count = 0 })
        local root = Arbor.action("Inc", function(b)
            b.count += 1
            return Status.Success
        end)
        local ctx1 = Arbor.context(root, board1, nil)
        local ctx2 = Arbor.context(root, board2, nil)
        ctx1:tick()
        ctx1:tick()
        ctx2:tick()
        expect(board1.count):toBe(2)
        expect(board2.count):toBe(1)
    end)

    it("should handle rapid blackboard toggles", function(): ()
        local board = Arbor.board({ flag = false })
        local changes = 0
        Arbor.watch(board, "flag", function()
            changes += 1
        end)
        for _ = 1, 100 do
            board.flag = true
            board.flag = false
        end
        expect(changes):toBe(200)
    end)

    it("should handle invert of invert", function(): ()
        local board = Arbor.board({})
        local root = Arbor.invert(Arbor.invert(Arbor.condition("Yes", function()
            return true
        end)))
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should handle parallel with all Running children", function(): ()
        local board = Arbor.board({})
        local root = Arbor.parallel({
            Arbor.action("A", function()
                return Status.Running
            end),
            Arbor.action("B", function()
                return Status.Running
            end),
        }, { succeed = 2 })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Running)
    end)

    it("should handle succeed(loop(child)) pattern", function(): ()
        local board = Arbor.board({})
        local count = 0
        local root = Arbor.succeed(Arbor.loop(Arbor.action("Dec", function()
            count += 1
            return if count >= 3 then Status.Failure else Status.Success
        end)))
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
        expect(count):toBe(3)
    end)

    it("should destroy idempotently", function(): ()
        local board = Arbor.board({})
        local root = Arbor.condition("Y", function()
            return true
        end)
        local ctx = Arbor.context(root, board, nil)
        ctx:destroy()
        ctx:destroy()
        expect(ctx:isRunning()):toBe(false)
    end)
end)

return nil
