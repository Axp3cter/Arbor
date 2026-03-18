--!strict
--!optimize 2
-- Tests for Observer (abort mode) decorator.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Observer", function(): ()
    it("should tick child when condition is true", function(): ()
        local board = Arbor.createBoard({ hasTarget = true })
        local ctx = Arbor.createContext(board, nil)
        local childTicked = false
        local tree = Arbor.tree(Arbor.observe(
            "HasTarget",
            function(b)
                return b:get("hasTarget") == true
            end,
            Arbor.Abort.Self,
            { "hasTarget" },
            Arbor.action("Chase", function()
                childTicked = true
                return Arbor.SUCCESS
            end)
        ))
        tree:tick(ctx)
        expect(childTicked):toBe(true)
    end)

    it("should return FAILURE when condition is false", function(): ()
        local board = Arbor.createBoard({ hasTarget = false })
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.observe(
            "HasTarget",
            function(b)
                return b:get("hasTarget") == true
            end,
            Arbor.Abort.Self,
            { "hasTarget" },
            Arbor.action("Chase", function()
                return Arbor.SUCCESS
            end)
        ))
        expect(tree:tick(ctx)):toBe(Arbor.FAILURE)
    end)

    it("should halt child when Self abort triggers", function(): ()
        local board = Arbor.createBoard({ hasTarget = true })
        local ctx = Arbor.createContext(board, nil)
        local halted = false
        local observerNode = Arbor.observe(
            "HasTarget",
            function(b)
                return b:get("hasTarget") == true
            end,
            Arbor.Abort.Self,
            { "hasTarget" },
            Arbor.action("Chase", {
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
        )
        local tree = Arbor.tree(observerNode)
        tree:tick(ctx) -- starts, condition true
        -- Condition flips → Self abort should signal.
        board:set("hasTarget", false)
        -- Next tick re-evaluates and halts.
        tree:tick(ctx)
        expect(halted):toBe(true)
    end)

    it("should clean up observers on completion", function(): ()
        local board = Arbor.createBoard({ key = "a" })
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.observe(
            "Check",
            function(b)
                return b:get("key") == "a"
            end,
            Arbor.Abort.Self,
            { "key" },
            Arbor.action("Quick", function()
                return Arbor.SUCCESS
            end)
        ))
        tree:tick(ctx) -- completes, observers cleaned up
        -- Changing key should not error or trigger anything.
        board:set("key", "b")
        board:set("key", "c")
    end)
end)

return nil
