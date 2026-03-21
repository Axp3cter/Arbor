--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").bt)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Context", function(): ()
    it("exposes board and agent", function(): ()
        local board = { hp = 100 }
        local agent = { name = "npc" }
        local root = bt.check(function()
            return true
        end)
        local ctx = bt.bind(root, board, agent)
        expect(ctx.board):toBe(board)
        expect(ctx.agent):toBe(agent)
    end)

    it("passes dt through to nodes", function(): ()
        local gotDt: number = 0
        local root = bt.action(function(_b, _a, d)
            gotDt = d
            return "success"
        end)
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0.033)
        expect(gotDt):toBeCloseTo(0.033)
    end)

    it("defaults dt to 0 when not provided", function(): ()
        local gotDt: number = -1
        local root = bt.action(function(_b, _a, d)
            gotDt = d
            return "success"
        end)
        local ctx = bt.bind(root, {}, nil)
        ctx:tick()
        expect(gotDt):toBe(0)
    end)

    it("returns failure after destroy", function(): ()
        local root = bt.check(function()
            return true
        end)
        local ctx = bt.bind(root, {}, nil)
        ctx:destroy()
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("destroy is idempotent", function(): ()
        local root = bt.check(function()
            return true
        end)
        local ctx = bt.bind(root, {}, nil)
        ctx:destroy()
        ctx:destroy()
        ctx:destroy()
        expect(ctx:isRunning()):toBe(false)
    end)

    it("stop halts running nodes and clears state", function(): ()
        local halted = false
        local root = bt.action({
            enter = function()
                return "running"
            end,
            tick = function()
                return "running"
            end,
            halt = function()
                halted = true
            end,
        })
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        ctx:stop()
        expect(halted):toBe(true)
    end)

    it("halt is called exactly once on destroy", function(): ()
        local haltCount = 0
        local root = bt.action({
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
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        ctx:destroy()
        expect(haltCount):toBe(1)
    end)

    it("shared tree, independent state across contexts", function(): ()
        local tree = bt.action(function(b)
            (b :: any).count += 1
            return "success"
        end)
        local board1 = { count = 0 }
        local board2 = { count = 0 }
        local ctx1 = bt.bind(tree, board1, nil)
        local ctx2 = bt.bind(tree, board2, nil)
        ctx1:tick(0)
        ctx1:tick(0)
        ctx2:tick(0)
        expect(board1.count):toBe(2)
        expect(board2.count):toBe(1)
    end)

    it("shared tree, running state does not bleed", function(): ()
        local tree = bt.sequence({
            bt.action(function()
                return "success"
            end),
            bt.action(function()
                return "running"
            end),
        })
        local ctx1 = bt.bind(tree, {}, nil)
        local ctx2 = bt.bind(tree, {}, nil)
        ctx1:tick(0) -- sequence: child 1 success, child 2 running
        -- ctx2 should start fresh, not resume from ctx1's running child
        expect(ctx2:tick(0)):toBe("running")
        -- Both should be running independently
    end)
end)

return nil
