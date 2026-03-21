--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").bt)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Check", function(): ()
    it("returns success when predicate is true", function(): ()
        local node = bt.check(function()
            return true
        end)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("returns failure when predicate is false", function(): ()
        local node = bt.check(function()
            return false
        end)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("receives the board as its argument", function(): ()
        local captured: any = nil
        local board = { hp = 42 }
        local node = bt.check(function(b)
            captured = b
            return true
        end)
        local ctx = bt.bind(node, board, nil)
        ctx:tick(0)
        expect(captured):toBe(board)
    end)

    it("never returns running", function(): ()
        local node = bt.check(function()
            return true
        end)
        local ctx = bt.bind(node, {}, nil)
        local result = ctx:tick(0)
        expect(result == "running"):toBe(false)
    end)

    it("halt is a no-op and does not error", function(): ()
        local node = bt.check(function()
            return true
        end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop()
    end)
end)

return nil
