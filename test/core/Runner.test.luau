--!strict
--!optimize 2
-- Tests for tick-rate Runner.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Runner", function(): ()
    it("should create a runner with default tick rate", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.condition("Yes", function()
            return true
        end))
        local runner = Arbor.createRunner(tree, ctx)
        expect(runner).never:toBeNil()
    end)

    it("should create a runner with custom config", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.condition("Yes", function()
            return true
        end))
        local completed = false
        local runner = Arbor.createRunner(tree, ctx, {
            tickRate = 10,
            onComplete = function()
                completed = true
            end,
        })
        expect(runner).never:toBeNil()
    end)
end)

return nil
