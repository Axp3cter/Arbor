--!strict
--!optimize 2
-- Tests for Action node.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

local Status = Arbor.Status

describe("Action", function(): ()
    it("should work with simple function form", function(): ()
        local board = Arbor.board({})
        local called = false
        local root = Arbor.action("Simple", function()
            called = true
            return Status.Success
        end)
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
        expect(called):toBe(true)
    end)

    it("should call start on first tick", function(): ()
        local board = Arbor.board({})
        local startCalled = false
        local root = Arbor.action("Async", {
            start = function()
                startCalled = true
                return Status.Running
            end,
            tick = function()
                return Status.Success
            end,
            halt = function() end,
        })
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        expect(startCalled):toBe(true)
    end)

    it("should call tick on subsequent ticks", function(): ()
        local board = Arbor.board({})
        local tickCalls = 0
        local root = Arbor.action("Async", {
            start = function()
                return Status.Running
            end,
            tick = function()
                tickCalls += 1
                return if tickCalls >= 3 then Status.Success else Status.Running
            end,
            halt = function() end,
        })
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Running)
        expect(ctx:tick()):toBe(Status.Running)
        expect(ctx:tick()):toBe(Status.Running)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should call halt when halted", function(): ()
        local board = Arbor.board({})
        local halted = false
        local root = Arbor.action("Async", {
            start = function()
                return Status.Running
            end,
            tick = function()
                return Status.Running
            end,
            halt = function()
                halted = true
            end,
        })
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        ctx:destroy()
        expect(halted):toBe(true)
    end)

    it("should clear state after completion", function(): ()
        local board = Arbor.board({})
        local startCalls = 0
        local root = Arbor.action("Async", {
            start = function()
                startCalls += 1
                return Status.Success
            end,
            tick = function()
                return Status.Success
            end,
            halt = function() end,
        })
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        ctx:tick()
        expect(startCalls):toBe(2)
    end)

    it("should call simple handler every tick while Running", function(): ()
        local board = Arbor.board({})
        local calls = 0
        local root = Arbor.action("Repeat", function()
            calls += 1
            return if calls >= 3 then Status.Success else Status.Running
        end)
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        ctx:tick()
        ctx:tick()
        expect(calls):toBe(3)
    end)
end)

return nil
