--!strict
--!optimize 2
-- Tests for Service nodes.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Service", function(): ()
    it("should create a service definition", function(): ()
        local svc = Arbor.service({ interval = 0.5 }, function() end)
        expect(svc._interval):toBe(0.5)
    end)

    it("should pass services at composite creation time", function(): ()
        local svc = Arbor.service({ interval = 0.2 }, function() end)
        local seq = Arbor.sequence({
            Arbor.condition("Always", function()
                return true
            end),
        }, { svc })
        expect((seq :: any)._services).never:toBeNil()
    end)
end)

return nil
