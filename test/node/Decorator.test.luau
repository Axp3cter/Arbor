--!strict
--!optimize 2
-- Tests for Decorator nodes.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

local Status = Arbor.Status

describe("Decorator.invert", function(): ()
    it("should flip Success to Failure", function(): ()
        local board = Arbor.board({})
        local root = Arbor.invert(Arbor.condition("T", function()
            return true
        end))
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Failure)
    end)

    it("should flip Failure to Success", function(): ()
        local board = Arbor.board({})
        local root = Arbor.invert(Arbor.condition("F", function()
            return false
        end))
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should pass Running through", function(): ()
        local board = Arbor.board({})
        local root = Arbor.invert(Arbor.action("R", function()
            return Status.Running
        end))
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Running)
    end)
end)

describe("Decorator.succeed", function(): ()
    it("should force Success on Failure", function(): ()
        local board = Arbor.board({})
        local root = Arbor.succeed(Arbor.condition("F", function()
            return false
        end))
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should pass Running through", function(): ()
        local board = Arbor.board({})
        local root = Arbor.succeed(Arbor.action("R", function()
            return Status.Running
        end))
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Running)
    end)
end)

describe("Decorator.fail", function(): ()
    it("should force Failure on Success", function(): ()
        local board = Arbor.board({})
        local root = Arbor.fail(Arbor.condition("T", function()
            return true
        end))
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Failure)
    end)
end)

describe("Decorator.loop", function(): ()
    it("should repeat child N times in same tick for instant actions", function(): ()
        local board = Arbor.board({})
        local count = 0
        local root = Arbor.loop(
            Arbor.action("Inc", function()
                count += 1
                return Status.Success
            end),
            3
        )
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Success)
        expect(count):toBe(3)
    end)

    it("should return Failure immediately if child fails", function(): ()
        local board = Arbor.board({})
        local root = Arbor.loop(
            Arbor.condition("Fail", function()
                return false
            end),
            5
        )
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Failure)
    end)

    it("should loop indefinitely without count", function(): ()
        local board = Arbor.board({})
        local count = 0
        local root = Arbor.loop(Arbor.action("Dec", function()
            count += 1
            return if count >= 5 then Status.Failure else Status.Success
        end))
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Failure)
        expect(count):toBe(5)
    end)
end)

describe("Decorator.retry", function(): ()
    it("should retry on failure up to N times", function(): ()
        local board = Arbor.board({})
        local attempts = 0
        local root = Arbor.retry(
            Arbor.action("Flaky", function()
                attempts += 1
                return if attempts >= 3 then Status.Success else Status.Failure
            end),
            5
        )
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        ctx:tick()
        expect(ctx:tick()):toBe(Status.Success)
    end)

    it("should return Failure after exhausting retries", function(): ()
        local board = Arbor.board({})
        local root = Arbor.retry(
            Arbor.condition("Fail", function()
                return false
            end),
            2
        )
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        expect(ctx:tick()):toBe(Status.Failure)
    end)
end)

describe("Decorator.guard", function(): ()
    it("should tick child when condition succeeds", function(): ()
        local board = Arbor.board({})
        local childTicked = false
        local root = Arbor.guard(
            Arbor.condition("Gate", function()
                return true
            end),
            Arbor.action("Work", function()
                childTicked = true
                return Status.Success
            end)
        )
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        expect(childTicked):toBe(true)
    end)

    it("should return Failure when condition fails", function(): ()
        local board = Arbor.board({})
        local root = Arbor.guard(
            Arbor.condition("Gate", function()
                return false
            end),
            Arbor.action("Work", function()
                return Status.Success
            end)
        )
        local ctx = Arbor.context(root, board, nil)
        expect(ctx:tick()):toBe(Status.Failure)
    end)

    it("should halt child when condition flips to false", function(): ()
        local board = Arbor.board({ open = true })
        local halted = false
        local root = Arbor.guard(
            Arbor.condition("Gate", function(b)
                return b.open == true
            end),
            Arbor.action("Work", {
                start = function()
                    return Status.Running
                end,
                tick = function()
                    return Status.Running
                end,
                halt = function()
                    halted = true
                end,
            })
        )
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        board.open = false
        ctx:tick()
        expect(halted):toBe(true)
    end)
end)

return nil
