--!strict
--!optimize 2
-- Tests for Wait leaf node.

local Arbor = require(game:GetService("ReplicatedStorage").Arbor)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

local Status = Arbor.Status

describe("Wait", function(): ()
    it("should return Running on first tick", function(): ()
        local board = Arbor.board({})
        local root = Arbor.wait(10)
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Running)
    end)

    it("should return Success after duration elapses", function(): ()
        local board = Arbor.board({})
        local root = Arbor.wait(0)
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        -- 0 seconds means next tick should succeed.
        expect(ctx:tick()):toBe(Status.Success)
    end)
end)

return nil
