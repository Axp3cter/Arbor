--!strict
--!optimize 2
-- Tests for Service nodes.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

local Status = Arbor.Status

describe("Service", function(): ()
    it("should create a service definition", function(): ()
        local svc = Arbor.service("Test", 0.5, function() end)
        expect(svc._interval):toBe(0.5)
        expect(svc._name):toBe("Test")
    end)

    it("should pass services at composite creation time", function(): ()
        local svc = Arbor.service("Test", 0.2, function() end)
        local seq = Arbor.sequence({
            Arbor.condition("Always", function()
                return true
            end),
        }, { services = { svc } })
        expect((seq :: any)._services).never:toBeNil()
    end)

    it("should fire service updater during composite tick", function(): ()
        local board = Arbor.board({ val = 0 })
        local svc = Arbor.service("Inc", 0, function(b)
            b.val += 1
        end)
        local root = Arbor.sequence({
            Arbor.condition("Yes", function()
                return true
            end),
        }, { services = { svc } })
        local ctx = Arbor.context(root, board, nil)
        ctx:tick()
        expect(board.val):toBeGreaterThan(0)
    end)
end)

return nil
