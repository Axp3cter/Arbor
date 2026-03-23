--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
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

    it("shared tree, running state does not bleed between contexts", function(): ()
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
        ctx1:tick(0)
        expect(ctx2:tick(0)):toBe("running")
    end)

    it("stop then tick restarts the tree from scratch", function(): ()
        local aTicks = 0
        local tree = bt.sequence({
            bt.action(function()
                aTicks += 1
                return "success"
            end),
            bt.action(function()
                return "running"
            end),
        })
        local ctx = bt.bind(tree, {}, nil)
        ctx:tick(0) -- A succeeds (aTicks=1), B runs, sequence sticks at B
        ctx:tick(0) -- Resumes at B, A not re-ticked (aTicks still 1)
        ctx:stop() -- Clears all state
        ctx:tick(0) -- Fresh start: A re-ticked (aTicks=2), B runs
        expect(aTicks):toBe(2)
    end)

    it("isRunning returns false before start", function(): ()
        local root = bt.check(function()
            return true
        end)
        local ctx = bt.bind(root, {}, nil)
        expect(ctx:isRunning()):toBe(false)
    end)

    it("isRunning returns false after stop", function(): ()
        local root = bt.check(function()
            return true
        end)
        local ctx = bt.bind(root, {}, nil)
        ctx:start()
        ctx:stop()
        expect(ctx:isRunning()):toBe(false)
    end)

    it("isRunning returns false after destroy", function(): ()
        local root = bt.check(function()
            return true
        end)
        local ctx = bt.bind(root, {}, nil)
        ctx:start()
        ctx:destroy()
        expect(ctx:isRunning()):toBe(false)
    end)

    it("start is ignored after destroy", function(): ()
        local root = bt.check(function()
            return true
        end)
        local ctx = bt.bind(root, {}, nil)
        ctx:destroy()
        ctx:start()
        expect(ctx:isRunning()):toBe(false)
    end)

    it("second start is ignored when already running", function(): ()
        local tickCount = 0
        local root = bt.action(function()
            tickCount += 1
            return "success"
        end)
        local ctx = bt.bind(root, {}, nil)
        ctx:start()
        ctx:start() -- should be a no-op, not double-connect
        task.wait(0.1)
        ctx:stop()
        --[[
            If double-connected, tickCount would be roughly double.
            With single connection at ~60Hz, 0.1s gives ~6 ticks.
        ]]
        expect(tickCount):toBeLessThan(20)
    end)
end)

return nil
