--!strict
--!optimize 2
-- Tests for Action node.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Action", function(): ()
    it("should work with simple function form", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local called = false
        local node = Arbor.action("Simple", function()
            called = true
            return Arbor.SUCCESS
        end)
        local tree = Arbor.tree(node)
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
        expect(called):toBe(true)
    end)

    it("should call onStart on first tick", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local startCalled = false
        local node = Arbor.action("Async", {
            onStart = function()
                startCalled = true
                return Arbor.RUNNING
            end,
            onRunning = function()
                return Arbor.SUCCESS
            end,
        })
        local tree = Arbor.tree(node)
        tree:tick(ctx)
        expect(startCalled):toBe(true)
    end)

    it("should call onRunning on subsequent ticks", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local runningCalls = 0
        local node = Arbor.action("Async", {
            onStart = function()
                return Arbor.RUNNING
            end,
            onRunning = function()
                runningCalls += 1
                if runningCalls >= 3 then
                    return Arbor.SUCCESS
                end
                return Arbor.RUNNING
            end,
        })
        local tree = Arbor.tree(node)
        expect(tree:tick(ctx)):toBe(Arbor.RUNNING) -- onStart
        expect(tree:tick(ctx)):toBe(Arbor.RUNNING) -- onRunning 1
        expect(tree:tick(ctx)):toBe(Arbor.RUNNING) -- onRunning 2
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS) -- onRunning 3
    end)

    it("should call onHalted when halted", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local halted = false
        local node = Arbor.action("Async", {
            onStart = function()
                return Arbor.RUNNING
            end,
            onRunning = function()
                return Arbor.RUNNING
            end,
            onHalted = function()
                halted = true
            end,
        })
        local tree = Arbor.tree(node)
        tree:tick(ctx) -- start
        ctx:halt(node)
        expect(halted):toBe(true)
    end)

    it("should clear state after completion", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local startCalls = 0
        local node = Arbor.action("Async", {
            onStart = function()
                startCalls += 1
                return Arbor.SUCCESS
            end,
            onRunning = function()
                return Arbor.SUCCESS
            end,
        })
        local tree = Arbor.tree(node)
        tree:tick(ctx) -- completes immediately
        tree:tick(ctx) -- should call onStart again
        expect(startCalls):toBe(2)
    end)
end)

return nil
