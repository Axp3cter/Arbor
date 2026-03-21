--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Poll", function(): ()
    it("always returns success", function(): ()
        local node = bt.poll(1.0, function() end)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("fires immediately on first tick", function(): ()
        local fired = false
        local node = bt.poll(999, function()
            fired = true
        end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        expect(fired):toBe(true)
    end)

    it("passes board and agent to updater", function(): ()
        local gotBoard, gotAgent: any, any
        local board = { x = 1 }
        local agent = { y = 2 }
        local node = bt.poll(0, function(b, a)
            gotBoard, gotAgent = b, a
        end)
        local ctx = bt.bind(node, board, agent)
        ctx:tick(0)
        expect(gotBoard):toBe(board)
        expect(gotAgent):toBe(agent)
    end)

    it("respects interval between fires", function(): ()
        local fireCount = 0
        local node = bt.poll(0.5, function()
            fireCount += 1
        end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- fires (first tick, no last fire)
        ctx:tick(0) -- does not fire (0s since last)
        ctx:tick(0) -- does not fire
        expect(fireCount):toBe(1)
        task.wait(0.6)
        ctx:tick(0) -- fires (interval elapsed)
        expect(fireCount):toBe(2)
    end)

    it("resets timer on halt", function(): ()
        local fireCount = 0
        local node = bt.poll(999, function()
            fireCount += 1
        end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- fires (first tick)
        ctx:stop() -- halt clears timer state
        ctx:tick(0) -- fires again (first tick after reset)
        expect(fireCount):toBe(2)
    end)
end)

return nil
