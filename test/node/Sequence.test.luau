--!strict
--!optimize 2
-- Tests for Sequence composite node.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Sequence", function(): ()
    it("should return SUCCESS when all children succeed", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.sequence({
            Arbor.condition("A", function()
                return true
            end),
            Arbor.condition("B", function()
                return true
            end),
            Arbor.condition("C", function()
                return true
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should return FAILURE on first child failure", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local cCalled = false
        local tree = Arbor.tree(Arbor.sequence({
            Arbor.condition("A", function()
                return true
            end),
            Arbor.condition("B", function()
                return false
            end),
            Arbor.condition("C", function()
                cCalled = true
                return true
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.FAILURE)
        expect(cCalled):toBe(false) -- C should not be reached
    end)

    it("should return RUNNING when a child is running", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.sequence({
            Arbor.condition("A", function()
                return true
            end),
            Arbor.action("B", function()
                return Arbor.RUNNING
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.RUNNING)
    end)

    it("should resume from running child in memory mode", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local aTicks = 0
        local runCount = 0
        local tree = Arbor.tree(Arbor.sequence({
            Arbor.action("A", function()
                aTicks += 1
                return Arbor.SUCCESS
            end),
            Arbor.action("B", function()
                runCount += 1
                if runCount >= 2 then
                    return Arbor.SUCCESS
                end
                return Arbor.RUNNING
            end),
        }))
        tree:tick(ctx) -- A succeeds, B returns RUNNING
        expect(aTicks):toBe(1)
        tree:tick(ctx) -- Memory: resumes at B, skips A
        expect(aTicks):toBe(1) -- A should not be re-ticked
        expect(runCount):toBe(2)
    end)

    it("should re-evaluate from start in reactive mode", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local aTicks = 0
        local tree = Arbor.tree(Arbor.reactiveSequence({
            Arbor.action("A", function()
                aTicks += 1
                return Arbor.SUCCESS
            end),
            Arbor.action("B", function()
                return Arbor.RUNNING
            end),
        }))
        tree:tick(ctx)
        tree:tick(ctx) -- Reactive: re-evaluates from child 0
        expect(aTicks):toBe(2) -- A ticked both times
    end)
end)

return nil
