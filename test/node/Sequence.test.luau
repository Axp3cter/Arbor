--!strict
--!optimize 2

local Arbor = require(game:GetService("ReplicatedStorage").Arbor)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

local Status = Arbor.Status

describe("Sequence", function(): ()
    it("should return Success when all children succeed", function(): ()
        local board = Arbor.board({})
        local root = Arbor.sequence({
            Arbor.condition("A", function()
                return true
            end),
            Arbor.condition("B", function()
                return true
            end),
            Arbor.condition("C", function()
                return true
            end),
        })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should return Failure on first child failure", function(): ()
        local board = Arbor.board({})
        local cCalled = false
        local root = Arbor.sequence({
            Arbor.condition("A", function()
                return true
            end),
            Arbor.condition("B", function()
                return false
            end),
            Arbor.condition("C", function()
                cCalled = true
                return true
            end),
        })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Failure)
        expect(cCalled):toBe(false)
    end)

    it("should resume from running child in memory mode", function(): ()
        local board = Arbor.board({})
        local aTicks = 0
        local runCount = 0
        local root = Arbor.sequence({
            Arbor.action("A", function()
                aTicks += 1
                return Status.Success
            end),
            Arbor.action("B", function()
                runCount += 1
                return if runCount >= 2 then Status.Success else Status.Running
            end),
        })
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        expect(aTicks):toBe(1)
        ctx:tick()
        expect(aTicks):toBe(1)
        expect(runCount):toBe(2)
    end)

    it("should re-evaluate from start in reactive mode", function(): ()
        local board = Arbor.board({})
        local aTicks = 0
        local root = Arbor.sequence({
            Arbor.action("A", function()
                aTicks += 1
                return Status.Success
            end),
            Arbor.action("B", function()
                return Status.Running
            end),
        }, { reactive = true })
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        ctx:tick()
        expect(aTicks):toBe(2)
    end)
end)

return nil
