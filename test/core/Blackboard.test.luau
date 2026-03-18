--!strict
--!optimize 2
-- Tests for Blackboard.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Blackboard", function(): ()
    it("should create with default values", function(): ()
        local board = Arbor.createBoard({ health = 100, target = nil :: string? })
        expect(board:get("health")):toBe(100)
        expect(board:get("target")):toBeNil()
    end)

    it("should set and get values", function(): ()
        local board = Arbor.createBoard({ x = 0, y = 0 })
        board:set("x", 42)
        expect(board:get("x")):toBe(42)
        expect(board:get("y")):toBe(0)
    end)

    it("should not fire observer when value unchanged", function(): ()
        local board = Arbor.createBoard({ count = 5 })
        local fired = 0
        board:observe("count", function()
            fired += 1
        end)
        board:set("count", 5)
        expect(fired):toBe(0)
    end)

    it("should fire observer on change", function(): ()
        local board = Arbor.createBoard({ name = "a" })
        local captured: { new: any, old: any } = { new = nil, old = nil }
        board:observe("name", function(new, old)
            captured.new = new
            captured.old = old
        end)
        board:set("name", "b")
        expect(captured.new):toBe("b")
        expect(captured.old):toBe("a")
    end)

    it("should support multiple observers on same key", function(): ()
        local board = Arbor.createBoard({ val = 0 })
        local c1, c2 = 0, 0
        board:observe("val", function()
            c1 += 1
        end)
        board:observe("val", function()
            c2 += 1
        end)
        board:set("val", 1)
        expect(c1):toBe(1)
        expect(c2):toBe(1)
    end)

    it("should disconnect observer", function(): ()
        local board = Arbor.createBoard({ val = 0 })
        local fired = 0
        local conn = board:observe("val", function()
            fired += 1
        end)
        board:set("val", 1)
        expect(fired):toBe(1)
        conn:disconnect()
        board:set("val", 2)
        expect(fired):toBe(1)
        expect(conn.connected):toBe(false)
    end)

    it("should handle double disconnect", function(): ()
        local board = Arbor.createBoard({ val = 0 })
        local conn = board:observe("val", function() end)
        conn:disconnect()
        conn:disconnect()
        expect(conn.connected):toBe(false)
    end)

    it("should reset to defaults and fire observers", function(): ()
        local board = Arbor.createBoard({ val = 10 })
        board:set("val", 50)
        local fired = false
        board:observe("val", function(new, old)
            fired = true
            expect(new):toBe(10)
            expect(old):toBe(50)
        end)
        board:reset()
        expect(fired):toBe(true)
        expect(board:get("val")):toBe(10)
    end)
end)

return nil
