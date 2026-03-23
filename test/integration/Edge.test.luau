--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Edge: deep nesting", function(): ()
    it("handles 20 levels of nested sequences", function(): ()
        local leaf = bt.check(function() return true end)
        local node: bt.Node = leaf
        for _ = 1, 20 do
            node = bt.sequence({ node })
        end
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
    end)

    it("handles 20 levels of nested selectors", function(): ()
        local leaf = bt.check(function() return false end)
        local node: bt.Node = leaf
        for _ = 1, 20 do
            node = bt.select({ node })
        end
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("halt cascades through deep nesting", function(): ()
        local halted = false
        local leaf = bt.action({
            enter = function() return "running" end,
            tick = function() return "running" end,
            halt = function() halted = true end,
        })
        local node: bt.Node = leaf
        for _ = 1, 10 do
            node = bt.sequence({ node })
        end
        local ctx = bt.bind(node, {}, nil)
        ctx:tick(0)
        ctx:stop()
        expect(halted):toBe(true)
    end)
end)

describe("Edge: priority switch with deep subtree", function(): ()
    it("halts entire deep subtree when higher-priority branch wins", function(): ()
        local halted = false
        local shouldWin = false

        local deepChild = bt.sequence({
            bt.check(function() return true end),
            bt.sequence({
                bt.check(function() return true end),
                bt.action({
                    enter = function() return "running" end,
                    tick = function() return "running" end,
                    halt = function() halted = true end,
                }),
            }),
        })

        local root = bt.select({
            bt.check(function() return shouldWin end),
            deepChild,
        })

        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        expect(halted):toBe(false)

        shouldWin = true
        ctx:tick(0)
        expect(halted):toBe(true)
    end)
end)

describe("Edge: sequence failure mid-way halts running child", function(): ()
    it("does not halt child that completed normally before sequence fails", function(): ()
        local halted = false
        local step = 0
        local root = bt.select({
            bt.sequence({
                bt.check(function() return true end),
                bt.action({
                    enter = function()
                        step += 1
                        return "running"
                    end,
                    tick = function()
                        step += 1
                        return if step >= 3 then "success" else "running"
                    end,
                    halt = function()
                        halted = true
                    end,
                }),
                bt.check(function() return false end),
            }),
            bt.check(function() return true end),
        })
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        ctx:tick(0)
        expect(halted):toBe(false)
    end)
end)

describe("Edge: parallel with all running", function(): ()
    it("stays running when no thresholds met", function(): ()
        local node = bt.parallel(2)({
            bt.action(function() return "running" end),
            bt.action(function() return "running" end),
        })
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("running")
        expect(ctx:tick(0)):toBe("running")
    end)
end)

describe("Edge: serve scoping with selector", function(): ()
    it("polls stop when served branch loses priority", function(): ()
        local pollCount = 0
        local shouldWin = false

        local served = bt.action(function() return "running" end)
            :serve(bt.poll(0, function()
                pollCount += 1
            end))

        local root = bt.select({
            bt.check(function() return shouldWin end),
            served,
        })

        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        expect(pollCount):toBe(1)

        shouldWin = true
        ctx:tick(0)
        local countAfterHalt = pollCount

        shouldWin = false
        ctx:tick(0)
        expect(pollCount):toBe(countAfterHalt + 1)
    end)
end)

describe("Edge: nil agent", function(): ()
    it("works when agent is nil", function(): ()
        local root = bt.action(function(b)
            return if (b :: any).x == 1 then "success" else "failure"
        end)
        local ctx = bt.bind(root, { x = 1 }, nil)
        expect(ctx:tick(0)):toBe("success")
    end)
end)

describe("Edge: board mutation visible within same tick", function(): ()
    it("poll updates board before child reads it", function(): ()
        local board = { ready = false }
        local poll = bt.poll(0, function(b)
            (b :: any).ready = true
        end)
        local child = bt.check(function(b)
            return (b :: any).ready
        end)
        local node = child:serve(poll)
        local ctx = bt.bind(node, board, nil)
        expect(ctx:tick(0)):toBe("success")
    end)
end)

describe("Edge: decorator on composite", function(): ()
    it("invert on sequence flips the final result", function(): ()
        local node = bt.sequence({
            bt.check(function() return true end),
            bt.check(function() return true end),
        }):invert()
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("failure")
    end)

    it("cooldown on parallel works correctly", function(): ()
        local count = 0
        local node = bt.parallel(1)({
            bt.action(function()
                count += 1
                return "success"
            end),
        }):cooldown(999)
        local ctx = bt.bind(node, {}, nil)
        expect(ctx:tick(0)):toBe("success")
        expect(ctx:tick(0)):toBe("failure")
        expect(count):toBe(1)
    end)
end)

return nil
