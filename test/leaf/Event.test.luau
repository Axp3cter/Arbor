--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Event", function(): ()
    it("returns running until the signal fires", function(): ()
        local bindable = Instance.new("BindableEvent")
        local node = bt.event(bindable.Event)
        local ctx = bt.bind(node, {}, nil)

        expect(ctx:tick(0)):toBe("running")
        expect(ctx:tick(0)):toBe("running")

        bindable:Fire()
        task.wait() -- let deferred signal process

        expect(ctx:tick(0)):toBe("success")
        bindable:Destroy()
    end)

    it("returns success on the tick after fire, not the same tick", function(): ()
        local bindable = Instance.new("BindableEvent")
        local node = bt.event(bindable.Event)
        local ctx = bt.bind(node, {}, nil)

        ctx:tick(0) -- connect
        bindable:Fire()
        task.wait()

        expect(ctx:tick(0)):toBe("success")
        bindable:Destroy()
    end)

    it("disconnects on halt without leaking", function(): ()
        local bindable = Instance.new("BindableEvent")
        local node = bt.event(bindable.Event)
        local ctx = bt.bind(node, {}, nil)

        ctx:tick(0) -- connect
        ctx:stop() -- halt should disconnect

        -- Fire after halt. Should not affect anything.
        bindable:Fire()
        task.wait()

        -- Fresh tick after stop. Re-enters from scratch.
        expect(ctx:tick(0)):toBe("running")
        bindable:Destroy()
    end)

    it("disconnects itself on fire (one-shot)", function(): ()
        local bindable = Instance.new("BindableEvent")
        local node = bt.event(bindable.Event)
        local ctx = bt.bind(node, {}, nil)

        ctx:tick(0)
        bindable:Fire()
        task.wait()

        expect(ctx:tick(0)):toBe("success")

        -- Re-entering should reconnect fresh.
        expect(ctx:tick(0)):toBe("running")
        bindable:Fire()
        task.wait()
        expect(ctx:tick(0)):toBe("success")

        bindable:Destroy()
    end)

    it("works inside a sequence", function(): ()
        local bindable = Instance.new("BindableEvent")
        local actionRan = false
        local root = bt.sequence({
            bt.event(bindable.Event),
            bt.action(function()
                actionRan = true
                return "success"
            end),
        })
        local ctx = bt.bind(root, {}, nil)

        ctx:tick(0)
        expect(actionRan):toBe(false)

        bindable:Fire()
        task.wait()

        ctx:tick(0)
        expect(actionRan):toBe(true)

        bindable:Destroy()
    end)

    it("halt is safe when signal already fired but not yet ticked", function(): ()
        local bindable = Instance.new("BindableEvent")
        local node = bt.event(bindable.Event)
        local ctx = bt.bind(node, {}, nil)

        ctx:tick(0)
        bindable:Fire()
        task.wait()

        -- Signal fired but we halt before reading the result.
        ctx:stop()

        -- Re-enter fresh. Should reconnect, not see stale fired state.
        expect(ctx:tick(0)):toBe("running")
        bindable:Destroy()
    end)
end)

return nil
