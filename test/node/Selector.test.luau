--!strict
--!optimize 2
-- Tests for Selector composite node.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Selector", function(): ()
    it("should return SUCCESS on first child success", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local bCalled = false
        local tree = Arbor.tree(Arbor.selector({
            Arbor.condition("A", function()
                return true
            end),
            Arbor.condition("B", function()
                bCalled = true
                return true
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
        expect(bCalled):toBe(false) -- B not reached
    end)

    it("should return FAILURE when all children fail", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.selector({
            Arbor.condition("A", function()
                return false
            end),
            Arbor.condition("B", function()
                return false
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.FAILURE)
    end)

    it("should try next child on failure", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.selector({
            Arbor.condition("A", function()
                return false
            end),
            Arbor.condition("B", function()
                return true
            end),
        }))
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should resume from running child in memory mode", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local aTicks = 0
        local runCount = 0
        local tree = Arbor.tree(Arbor.selector({
            Arbor.action("A", function()
                aTicks += 1
                return Arbor.FAILURE
            end),
            Arbor.action("B", function()
                runCount += 1
                if runCount >= 2 then
                    return Arbor.SUCCESS
                end
                return Arbor.RUNNING
            end),
        }))
        tree:tick(ctx) -- A fails, B returns RUNNING
        expect(aTicks):toBe(1)
        tree:tick(ctx) -- Memory: resumes at B
        expect(aTicks):toBe(1) -- A not re-ticked
        expect(runCount):toBe(2)
    end)

    it("should re-evaluate from start in reactive mode", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local aTicks = 0
        local tree = Arbor.tree(Arbor.reactiveSelector({
            Arbor.action("A", function()
                aTicks += 1
                return Arbor.FAILURE
            end),
            Arbor.action("B", function()
                return Arbor.RUNNING
            end),
        }))
        tree:tick(ctx)
        tree:tick(ctx)
        expect(aTicks):toBe(2) -- A re-evaluated both times
    end)
end)

return nil
