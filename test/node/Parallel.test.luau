--!strict
--!optimize 2
-- Tests for Parallel composite node.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

local Status = Arbor.Status

describe("Parallel", function(): ()
    it("should succeed when succeed threshold met", function(): ()
        local board = Arbor.board({})
        local root = Arbor.parallel({
            Arbor.condition("A", function()
                return true
            end),
            Arbor.condition("B", function()
                return true
            end),
        }, { succeed = 2, fail = 1 })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should succeed with succeed=1 when any succeeds", function(): ()
        local board = Arbor.board({})
        local root = Arbor.parallel({
            Arbor.condition("A", function()
                return false
            end),
            Arbor.condition("B", function()
                return true
            end),
        }, { succeed = 1 })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should fail when fail threshold met", function(): ()
        local board = Arbor.board({})
        local root = Arbor.parallel({
            Arbor.condition("A", function()
                return true
            end),
            Arbor.condition("B", function()
                return false
            end),
        }, { fail = 1 })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Failure)
    end)

    it("should return Running when no policy met", function(): ()
        local board = Arbor.board({})
        local root = Arbor.parallel({
            Arbor.condition("A", function()
                return true
            end),
            Arbor.action("B", function()
                return Status.Running
            end),
        }, { succeed = 2 })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Running)
    end)

    it("should not re-tick resolved children", function(): ()
        local board = Arbor.board({})
        local aTicks = 0
        local root = Arbor.parallel({
            Arbor.action("A", function()
                aTicks += 1
                return Status.Success
            end),
            Arbor.action("B", function()
                return Status.Running
            end),
        }, { succeed = 2 })
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        ctx:tick()
        expect(aTicks):toBe(1)
    end)

    it("should early-exit and not tick remaining children after policy met", function(): ()
        local board = Arbor.board({})
        local bTicked = false
        local root = Arbor.parallel({
            Arbor.condition("A", function()
                return false
            end),
            Arbor.action("B", function()
                bTicked = true
                return Status.Running
            end),
        }, { fail = 1 })
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        expect(bTicked):toBe(false)
    end)
end)

return nil
