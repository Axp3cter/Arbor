--!strict
--!optimize 2

local Arbor = require(game:GetService("ReplicatedStorage").Arbor)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

local Status = Arbor.Status

describe("Context", function(): ()
    it("should create with board and agent", function(): ()
        local board = Arbor.board({ hp = 100 })
        local agent = { name = "npc" }
        local root = Arbor.condition("Yes", function()
            return true
        end)
        local ctx = Arbor.context(root, board, agent)
        expect(ctx.board):toBe(board)
        expect(ctx.agent):toBe(agent)
    end)

    it("should tick root and return status", function(): ()
        local board = Arbor.board({})
        local root = Arbor.condition("Yes", function()
            return true
        end)
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should propagate RUNNING", function(): ()
        local board = Arbor.board({})
        local root = Arbor.action("Wait", function()
            return Status.Running
        end)
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Running)
    end)

    it("should halt and call halt handler exactly once", function(): ()
        local board = Arbor.board({})
        local haltCount = 0
        local node = Arbor.action("Test", {
            start = function()
                return Status.Running
            end,
            tick = function()
                return Status.Running
            end,
            halt = function()
                haltCount += 1
            end,
        })
        local ctx = Arbor.context(node, board, nil)
        ctx:tick()
        ctx:destroy()
        expect(haltCount):toBe(1)
    end)

    it("should be no-op after destroy", function(): ()
        local board = Arbor.board({})
        local root = Arbor.condition("Yes", function()
            return true
        end)
        local ctx = Arbor.context(root, board, nil)
        ctx:destroy()
        expect(ctx:tick()):toBe(Status.Failure)
        expect(ctx:isRunning()):toBe(false)
    end)

    it("should support nested trees", function(): ()
        local board = Arbor.board({ health = 50, hasTarget = true })
        local root = Arbor.selector({
            Arbor.sequence({
                Arbor.condition("LowHealth", function(b)
                    return b.health < 30
                end),
                Arbor.action("Flee", function()
                    return Status.Running
                end),
            }),
            Arbor.sequence({
                Arbor.condition("HasTarget", function(b)
                    return b.hasTarget == true
                end),
                Arbor.action("Attack", function()
                    return Status.Success
                end),
            }),
        })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)
end)

return nil
