--!strict
--!optimize 2
-- Tests for Context.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Context", function(): ()
    it("should create with board and agent", function(): ()
        local board = Arbor.createBoard({ hp = 100 })
        local agent = { name = "npc" }
        local ctx = Arbor.createContext(board, agent)
        expect(ctx.board):toBe(board)
        expect(ctx.agent):toBe(agent)
    end)

    it("should get/set/clear per-node state", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local node = Arbor.condition("test", function()
            return true
        end)
        expect(ctx:getState(node)):toBeNil()
        ctx:setState(node, { index = 3 })
        local state = ctx:getState(node) :: { index: number }
        expect(state.index):toBe(3)
        ctx:clearState(node)
        expect(ctx:getState(node)):toBeNil()
    end)

    it("should halt and call onHalted exactly once", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local haltCount = 0
        local node = Arbor.action("test", {
            onStart = function()
                return Arbor.RUNNING
            end,
            onRunning = function()
                return Arbor.RUNNING
            end,
            onHalted = function()
                haltCount += 1
            end,
        })
        local tree = Arbor.tree(node)
        tree:tick(ctx)
        expect(ctx:getState(node)).never:toBeNil()
        ctx:halt(node)
        expect(haltCount):toBe(1)
    end)
end)

return nil
