--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Wait", function(): ()
    it("returns running until duration elapses", function(): ()
        local node = bt.wait(1.0)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0.3)):toBe("running")
        expect(ctx:tick(0.3)):toBe("running")
        expect(ctx:tick(0.3)):toBe("running")
        expect(ctx:tick(0.2)):toBe("success")
    end)

    it("succeeds immediately if dt exceeds duration", function(): ()
        local node = bt.wait(0.5)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(1.0)):toBe("success")
    end)

    it("resets on halt and restarts from zero", function(): ()
        local node = bt.wait(1.0)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0.8) -- 0.8 accumulated
        ctx:stop() -- reset
        expect(ctx:tick(0.3)):toBe("running") -- should be 0.3 not 1.1
        expect(ctx:tick(0.8)):toBe("success") -- 1.1 total
    end)

    it("handles zero duration", function(): ()
        local node = bt.wait(0)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)
end)

return nil
