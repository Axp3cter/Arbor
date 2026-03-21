--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").bt)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Action (simple)", function(): ()
    it("calls the function every tick", function(): ()
        local count = 0
        local node = bt.action(function()
            count += 1
            return "success"
        end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        expect(count):toBe(2)
    end)

    it("passes board, agent, and dt", function(): ()
        local gotBoard, gotAgent, gotDt: any, any, any
        local board = { x = 1 }
        local agent = { y = 2 }
        local node = bt.action(function(b, a, d)
            gotBoard, gotAgent, gotDt = b, a, d
            return "success"
        end)
        local ctx = bt.bind(node, board, agent)
        ctx:tick(0.016)
        expect(gotBoard):toBe(board)
        expect(gotAgent):toBe(agent)
        expect(gotDt):toBeCloseTo(0.016)
    end)

    it("halt is a no-op for simple actions", function(): ()
        local node = bt.action(function()
            return "running"
        end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop() -- should not error
    end)
end)

describe("Action (phased)", function(): ()
    it("calls enter on first tick, tick on subsequent", function(): ()
        local log: { string } = {}
        local node = bt.action({
            enter = function()
                table.insert(log, "enter")
                return "running"
            end,
            tick = function()
                table.insert(log, "tick")
                return "running"
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(log[1]):toBe("enter")
        expect(log[2]):toBe("tick")
        expect(log[3]):toBe("tick")
    end)

    it("does not call tick if enter returns success", function(): ()
        local tickCalled = false
        local node = bt.action({
            enter = function()
                return "success"
            end,
            tick = function()
                tickCalled = true
                return "success"
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
        expect(tickCalled):toBe(false)
    end)

    it("calls halt only when running and interrupted", function(): ()
        local haltCount = 0
        local node = bt.action({
            enter = function()
                return "running"
            end,
            tick = function()
                return "running"
            end,
            halt = function()
                haltCount += 1
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop()
        expect(haltCount):toBe(1)
    end)

    it("does not call halt if never entered", function(): ()
        local haltCount = 0
        local node = bt.action({
            enter = function()
                return "running"
            end,
            tick = function()
                return "running"
            end,
            halt = function()
                haltCount += 1
            end,
        })
        local _ctx = bt.bind(node, {}, nil)
        -- never ticked
        _ctx:stop()
        expect(haltCount):toBe(0)
    end)

    it("does not call halt if completed normally", function(): ()
        local haltCount = 0
        local tickCount = 0
        local node = bt.action({
            enter = function()
                return "running"
            end,
            tick = function()
                tickCount += 1
                return if tickCount >= 2 then "success" else "running"
            end,
            halt = function()
                haltCount += 1
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0) -- enter → running
        ctx:tick(0) -- tick → running
        ctx:tick(0) -- tick → success
        expect(haltCount):toBe(0)
    end)

    it("resets state after completion, re-calls enter on next activation", function(): ()
        local enterCount = 0
        local node = bt.action({
            enter = function()
                enterCount += 1
                return "success"
            end,
            tick = function()
                return "success"
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        expect(enterCount):toBe(2)
    end)
end)

return nil
