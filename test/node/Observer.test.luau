--!strict
--!optimize 2
-- Tests for Observer decorator.

local Arbor = require(game:GetService("ReplicatedStorage").Arbor)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

local Status = Arbor.Status
local Abort = Arbor.Abort

describe("Observer", function(): ()
    it("should tick child when condition is true", function(): ()
        local board = Arbor.board({ hasTarget = true })
        local childTicked = false
        local cond = Arbor.condition("HasTarget", function(b)
            return b.hasTarget == true
        end, { "hasTarget" })
        local root = Arbor.observe(
            cond,
            Abort.Self,
            Arbor.action("Chase", function()
                childTicked = true
                return Status.Success
            end)
        )
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        expect(childTicked):toBe(true)
    end)

    it("should return Failure when condition is false", function(): ()
        local board = Arbor.board({ hasTarget = false })
        local cond = Arbor.condition("HasTarget", function(b)
            return b.hasTarget == true
        end, { "hasTarget" })
        local root = Arbor.observe(
            cond,
            Abort.Self,
            Arbor.action("Chase", function()
                return Status.Success
            end)
        )
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Failure)
    end)

    it("should halt child when Self abort triggers", function(): ()
        local board = Arbor.board({ hasTarget = true })
        local halted = false
        local cond = Arbor.condition("HasTarget", function(b)
            return b.hasTarget == true
        end, { "hasTarget" })
        local root = Arbor.observe(
            cond,
            Abort.Self,
            Arbor.action("Chase", {
                start = function()
                    return Status.Running
                end,
                tick = function()
                    return Status.Running
                end,
                halt = function()
                    halted = true
                end,
            })
        )
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        board.hasTarget = false
        ctx:tick()
        expect(halted):toBe(true)
    end)

    it("should error when condition has no watch keys", function(): ()
        local cond = Arbor.condition("NoKeys", function()
            return true
        end)
        expect(function()
            Arbor.observe(
                cond,
                Abort.Self,
                Arbor.action("X", function()
                    return Status.Success
                end)
            )
        end):toThrow("no watch keys")
    end)

    it("should clean up on destroy", function(): ()
        local board = Arbor.board({ key = "a" })
        local cond = Arbor.condition("Check", function(b)
            return b.key == "a"
        end, { "key" })
        local root = Arbor.observe(
            cond,
            Abort.Self,
            Arbor.action("Quick", function()
                return Status.Success
            end)
        )
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        ctx:destroy()
        board.key = "b"
        board.key = "c"
    end)
end)

return nil
