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
        ctx:tick(0.8)
        ctx:stop()
        expect(ctx:tick(0.3)):toBe("running")
        expect(ctx:tick(0.8)):toBe("success")
    end)

    it("handles zero duration", function(): ()
        local node = bt.wait(0)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("uses dt accumulation, not wall-clock time", function(): ()
        local node = bt.wait(1.0)
        local ctx = bt.bind(node, {}, nil)
        -- Even if real time passes, only accumulated dt matters.
        ctx:tick(0)
        task.wait(1.5)
        -- Still running because we only passed dt=0.
        expect(ctx:tick(0)):toBe("running")
        -- Now pass enough dt to complete.
        expect(ctx:tick(2.0)):toBe("success")
    end)

    it("never completes if dt is always zero", function(): ()
        local node = bt.wait(0.1)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(ctx:tick(0)):toBe("running")
    end)
end)

return nil
