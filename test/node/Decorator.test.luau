--!strict
--!optimize 2
-- Tests for Decorator nodes.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Decorator.invert", function(): ()
    it("should flip SUCCESS to FAILURE", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.invert(Arbor.condition("True", function()
            return true
        end)))
        expect(tree:tick(ctx)):toBe(Arbor.FAILURE)
    end)

    it("should flip FAILURE to SUCCESS", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.invert(Arbor.condition("False", function()
            return false
        end)))
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should pass RUNNING through", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.invert(Arbor.action("Run", function()
            return Arbor.RUNNING
        end)))
        expect(tree:tick(ctx)):toBe(Arbor.RUNNING)
    end)
end)

describe("Decorator.rep", function(): ()
    it("should repeat child N times", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local count = 0
        local tree = Arbor.tree(Arbor.rep(
            Arbor.action("Inc", function()
                count += 1
                return Arbor.SUCCESS
            end),
            { times = 3 }
        ))
        tree:tick(ctx)
        tree:tick(ctx)
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
        expect(count):toBe(3)
    end)

    it("should return FAILURE immediately if child fails", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.rep(
            Arbor.condition("Fail", function()
                return false
            end),
            { times = 5 }
        ))
        expect(tree:tick(ctx)):toBe(Arbor.FAILURE)
    end)
end)

describe("Decorator.repeatUntilFail", function(): ()
    it("should loop until child fails then return SUCCESS", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local count = 0
        local tree = Arbor.tree(Arbor.repeatUntilFail(Arbor.action("Dec", function()
            count += 1
            if count >= 3 then
                return Arbor.FAILURE
            end
            return Arbor.SUCCESS
        end)))
        -- Re-ticks in same frame on SUCCESS, so one tick runs all iterations.
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
        expect(count):toBe(3)
    end)
end)

describe("Decorator.retry", function(): ()
    it("should retry on failure up to N times", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local attempts = 0
        local tree = Arbor.tree(Arbor.retry(
            Arbor.action("Flaky", function()
                attempts += 1
                if attempts >= 3 then
                    return Arbor.SUCCESS
                end
                return Arbor.FAILURE
            end),
            { times = 5 }
        ))
        tree:tick(ctx)
        tree:tick(ctx)
        expect(tree:tick(ctx)):toBe(Arbor.SUCCESS)
    end)

    it("should return FAILURE after exhausting retries", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.retry(
            Arbor.condition("Fail", function()
                return false
            end),
            { times = 2 }
        ))
        tree:tick(ctx)
        expect(tree:tick(ctx)):toBe(Arbor.FAILURE)
    end)
end)

describe("Decorator.guard", function(): ()
    it("should tick child when condition succeeds", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local childTicked = false
        local tree = Arbor.tree(Arbor.guard(
            Arbor.condition("Gate", function()
                return true
            end),
            Arbor.action("Work", function()
                childTicked = true
                return Arbor.SUCCESS
            end)
        ))
        tree:tick(ctx)
        expect(childTicked):toBe(true)
    end)

    it("should return FAILURE when condition fails", function(): ()
        local board = Arbor.createBoard({})
        local ctx = Arbor.createContext(board, nil)
        local tree = Arbor.tree(Arbor.guard(
            Arbor.condition("Gate", function()
                return false
            end),
            Arbor.action("Work", function()
                return Arbor.SUCCESS
            end)
        ))
        expect(tree:tick(ctx)):toBe(Arbor.FAILURE)
    end)

    it("should halt child when condition flips to false", function(): ()
        local board = Arbor.createBoard({ open = true })
        local ctx = Arbor.createContext(board, nil)
        local halted = false
        local tree = Arbor.tree(Arbor.guard(
            Arbor.condition("Gate", function(b)
                return b:get("open") == true
            end),
            Arbor.action("Work", {
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
        ))
        tree:tick(ctx)
        board:set("open", false)
        tree:tick(ctx)
        expect(halted):toBe(true)
    end)
end)

return nil
