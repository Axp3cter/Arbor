--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
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

    it("returns the handler's status directly", function(): ()
        local status: bt.Status = "running"
        local node = bt.action(function()
            return status
        end)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
        status = "failure"
        expect(ctx:tick(0)):toBe("failure")
        status = "success"
        expect(ctx:tick(0)):toBe("success")
    end)

    it("halt is a no-op for simple actions", function(): ()
        local node = bt.action(function()
            return "running"
        end)
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop()
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

    it("does not call tick if enter returns failure", function(): ()
        local tickCalled = false
        local node = bt.action({
            enter = function()
                return "failure"
            end,
            tick = function()
                tickCalled = true
                return "success"
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
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
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
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

    it("halt receives board and agent but not dt", function(): ()
        local argCount = 0
        local gotBoard, gotAgent: any, any
        local board = { x = 1 }
        local agent = { y = 2 }
        local node = bt.action({
            enter = function()
                return "running"
            end,
            tick = function()
                return "running"
            end,
            halt = function(b, a)
                gotBoard = b
                gotAgent = a
                argCount = select("#", b, a)
            end,
        })
        local ctx = bt.bind(node, board, agent)
        ctx:tick(0.016)
        ctx:stop()
        expect(gotBoard):toBe(board)
        expect(gotAgent):toBe(agent)
        expect(argCount):toBe(2)
    end)
end)

describe("Action (enter only, no tick)", function(): ()
    it("stays running indefinitely when enter returns running", function(): ()
        local node = bt.action({
            enter = function()
                return "running"
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
        expect(ctx:tick(0)):toBe("running")
        expect(ctx:tick(0)):toBe("running")
    end)

    it("completes immediately when enter returns success", function(): ()
        local node = bt.action({
            enter = function()
                return "success"
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("completes immediately when enter returns failure", function(): ()
        local node = bt.action({
            enter = function()
                return "failure"
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("calls halt when interrupted while running", function(): ()
        local halted = false
        local node = bt.action({
            enter = function()
                return "running"
            end,
            halt = function()
                halted = true
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop()
        expect(halted):toBe(true)
    end)
end)

describe("Action (tick only, no enter)", function(): ()
    it("skips enter and runs tick on the first frame", function(): ()
        local tickCount = 0
        local node = bt.action({
            tick = function()
                tickCount += 1
                return if tickCount >= 3 then "success" else "running"
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
        expect(ctx:tick(0)):toBe("running")
        expect(ctx:tick(0)):toBe("success")
        expect(tickCount):toBe(3)
    end)

    it("returns tick's result on the first frame", function(): ()
        local node = bt.action({
            tick = function()
                return "failure"
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("calls halt when interrupted while running", function(): ()
        local halted = false
        local node = bt.action({
            tick = function()
                return "running"
            end,
            halt = function()
                halted = true
            end,
        })
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop()
        expect(halted):toBe(true)
    end)
end)

describe("Action (validation)", function(): ()
    it("errors when given an empty table", function(): ()
        expect(function()
            bt.action({})
        end):toThrow("at least")
    end)

    it("errors when only halt is provided", function(): ()
        expect(function()
            bt.action({ halt = function() end })
        end):toThrow("at least")
    end)
end)

return nil
