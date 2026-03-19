--!strict
--!optimize 2
-- Tests for Blackboard.

local Arbor = require(script.Parent.Parent.Parent)
local Runner = require(script.Parent.Parent.Runner)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Blackboard", function(): ()
    it("should create with default values via direct access", function(): ()
        local board = Arbor.board({ health = 100, target = nil :: string? })
        expect(board.health):toBe(100)
        expect(board.target):toBeNil()
    end)

    it("should write and read via direct field access", function(): ()
        local board = Arbor.board({ x = 0, y = 0 })
        board.x = 42
        expect(board.x):toBe(42)
        expect(board.y):toBe(0)
    end)

    it("should not fire observer when value unchanged", function(): ()
        local board = Arbor.board({ count = 5 })
        local fired = 0
        Arbor.watch(board, "count", function()
            fired += 1
        end)
        board.count = 5
        expect(fired):toBe(0)
    end)

    it("should fire observer on change", function(): ()
        local board = Arbor.board({ name = "a" })
        local captured: { new: any, old: any } = { new = nil, old = nil }
        Arbor.watch(board, "name", function(new, old)
            captured.new = new
            captured.old = old
        end)
        board.name = "b"
        expect(captured.new):toBe("b")
        expect(captured.old):toBe("a")
    end)

    it("should support multiple observers on same key", function(): ()
        local board = Arbor.board({ val = 0 })
        local c1, c2 = 0, 0
        Arbor.watch(board, "val", function() c1 += 1 end)
        Arbor.watch(board, "val", function() c2 += 1 end)
        board.val = 1
        expect(c1):toBe(1)
        expect(c2):toBe(1)
    end)

    it("should disconnect observer via returned unsubscribe", function(): ()
        local board = Arbor.board({ val = 0 })
        local fired = 0
        local unsub = Arbor.watch(board, "val", function() fired += 1 end)
        board.val = 1
        expect(fired):toBe(1)
        unsub()
        board.val = 2
        expect(fired):toBe(1)
    end)

    it("should handle double unsubscribe", function(): ()
        local board = Arbor.board({ val = 0 })
        local unsub = Arbor.watch(board, "val", function() end)
        unsub()
        unsub()
    end)

    it("should snapshot to a frozen plain table", function(): ()
        local board = Arbor.board({ hp = 100, name = "test" })
        board.hp = 50
        local snap = Arbor.snapshot(board)
        expect(snap.hp):toBe(50)
        expect(snap.name):toBe("test")
        expect(table.isfrozen(snap)):toBe(true)
    end)

    it("should iterate via generalized for", function(): ()
        local board = Arbor.board({ a = 1, b = 2, c = 3 })
        local keys: { string } = {}
        for key in board do
            table.insert(keys, key)
        end
        table.sort(keys)
        expect(#keys):toBe(3)
        expect(keys[1]):toBe("a")
        expect(keys[2]):toBe("b")
        expect(keys[3]):toBe("c")
    end)

    it("should handle observer unsubscribe during iteration (snapshot safety)", function(): ()
        local board = Arbor.board({ val = 0 })
        local unsub2: (() -> ())?
        Arbor.watch(board, "val", function()
            if unsub2 then (unsub2 :: () -> ())() end
        end)
        unsub2 = Arbor.watch(board, "val", function() end)
        board.val = 1
    end)
end)

return nil
