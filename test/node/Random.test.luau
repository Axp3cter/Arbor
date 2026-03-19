--!strict
--!optimize 2
-- Tests for Random composite node.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

local Status = Arbor.Status

describe("Random", function(): ()
    it("should pick one child and return its status", function(): ()
        local board = Arbor.board({})
        local root = Arbor.random({
            Arbor.condition("A", function()
                return true
            end),
            Arbor.condition("B", function()
                return true
            end),
        })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should be sticky while Running", function(): ()
        local board = Arbor.board({})
        local aCalls, bCalls = 0, 0
        local root = Arbor.random({
            Arbor.action("A", function()
                aCalls += 1
                return Status.Running
            end),
            Arbor.action("B", function()
                bCalls += 1
                return Status.Running
            end),
        })
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        ctx:tick()
        ctx:tick()
        -- One child was picked and ticked 3 times, the other 0 times.
        expect(aCalls + bCalls):toBe(3)
        expect(aCalls == 3 or bCalls == 3):toBe(true)
    end)

    it("should work with weights", function(): ()
        local board = Arbor.board({})
        -- Weight 0 for A means B should always be picked.
        local bCalled = false
        local root = Arbor.random({
            Arbor.action("A", function()
                return Status.Success
            end),
            Arbor.action("B", function()
                bCalled = true
                return Status.Success
            end),
        }, { 0, 1 })
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        expect(bCalled):toBe(true)
    end)
end)

return nil
