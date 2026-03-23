--!strict
--!optimize 2

local Runner = require(script.Parent.Parent.Runner)
local bt = require(game:GetService("ReplicatedStorage").Arbor)
local describe, it, expect = Runner.describe, Runner.it, Runner.expect

describe("Snapshot", function(): ()
    it("returns an entry for every node in the tree", function(): ()
        local root = bt.sequence({
            bt.check(function()
                return true
            end),
            bt.action(function()
                return "success"
            end),
        })
        local ctx = bt.bind(root, {}, nil)
        local snap = bt.snapshot(ctx)
        expect(#snap):toBe(3)
    end)

    it("identifies node kinds correctly", function(): ()
        local root = bt.select({
            bt.check(function()
                return true
            end),
            bt.action(function()
                return "running"
            end):timeout(5),
        })
        local ctx = bt.bind(root, {}, nil)
        local snap = bt.snapshot(ctx)
        local kinds: { string } = {}
        for _, entry in snap do
            table.insert(kinds, entry.kind)
        end
        expect(table.find(kinds, "select") ~= nil):toBe(true)
        expect(table.find(kinds, "check") ~= nil):toBe(true)
        expect(table.find(kinds, "timeout") ~= nil):toBe(true)
        expect(table.find(kinds, "action") ~= nil):toBe(true)
    end)

    it("shows phased action in tick phase", function(): ()
        local root = bt.action({
            enter = function()
                return "running"
            end,
            tick = function()
                return "running"
            end,
        })
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        expect(snap[1].active):toBe(true)
        expect((snap[1] :: any).form):toBe("phased")
        expect((snap[1] :: any).phase):toBe("tick")
    end)

    it("shows simple action form", function(): ()
        local root = bt.action(function()
            return "success"
        end)
        local ctx = bt.bind(root, {}, nil)
        local snap = bt.snapshot(ctx)
        expect((snap[1] :: any).form):toBe("simple")
    end)

    it("shows phased action handler availability", function(): ()
        local root = bt.action({
            enter = function()
                return "running"
            end,
            halt = function() end,
        })
        local ctx = bt.bind(root, {}, nil)
        local snap = bt.snapshot(ctx)
        local entry = snap[1] :: any
        expect(entry.hasEnter):toBe(true)
        expect(entry.hasTick):toBe(false)
        expect(entry.hasHalt):toBe(true)
    end)

    it("shows wait progress", function(): ()
        local root = bt.wait(2.0)
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0.5)
        local snap = bt.snapshot(ctx)
        local entry = snap[1] :: any
        expect(entry.kind):toBe("wait")
        expect(entry.active):toBe(true)
        expect(entry.elapsed):toBeCloseTo(0.5)
        expect(entry.remaining):toBeCloseTo(1.5)
        expect(entry.progress):toBeCloseTo(0.25)
        expect(entry.seconds):toBe(2.0)
    end)

    it("shows cooldown blocked state", function(): ()
        local root = bt.check(function()
            return true
        end):cooldown(5)
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        local cd: any = nil
        for _, e in snap do
            if e.kind == "cooldown" then
                cd = e
            end
        end
        expect(cd ~= nil):toBe(true)
        expect(cd.active):toBe(true)
        expect(cd.blocked):toBe(true)
        expect(cd.seconds):toBe(5)
    end)

    it("shows cooldown not blocked when idle", function(): ()
        local root = bt.check(function()
            return false
        end):cooldown(5)
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        local cd: any = nil
        for _, e in snap do
            if e.kind == "cooldown" then
                cd = e
            end
        end
        expect(cd.blocked):toBe(false)
    end)

    it("shows timeout elapsed and remaining", function(): ()
        local root = bt.action(function()
            return "running"
        end):timeout(10)
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        local to: any = nil
        for _, e in snap do
            if e.kind == "timeout" then
                to = e
            end
        end
        expect(to ~= nil):toBe(true)
        expect(to.active):toBe(true)
        expect(to.seconds):toBe(10)
        expect((to.remaining :: number) > 0):toBe(true)
    end)

    it("shows retry attempt count", function(): ()
        local root = bt.check(function()
            return false
        end):retry(5)
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        local r: any = nil
        for _, e in snap do
            if e.kind == "retry" then
                r = e
            end
        end
        expect(r ~= nil):toBe(true)
        expect(r.attempt):toBe(2)
        expect(r.times):toBe(5)
    end)

    it("shows parallel progress", function(): ()
        local root = bt.parallel(2)({
            bt.check(function()
                return true
            end),
            bt.action(function()
                return "running"
            end),
            bt.action(function()
                return "running"
            end),
        })
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        local p: any = nil
        for _, e in snap do
            if e.kind == "parallel" then
                p = e
            end
        end
        expect(p ~= nil):toBe(true)
        expect(p.successes):toBe(1)
        expect(p.failures):toBe(0)
        expect(p.running):toBe(2)
        expect(p.succeed):toBe(2)
    end)

    it("shows sequence running child index", function(): ()
        local root = bt.sequence({
            bt.check(function()
                return true
            end),
            bt.action(function()
                return "running"
            end),
        })
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        expect(snap[1].kind):toBe("sequence")
        expect((snap[1] :: any).runningChild):toBe(2)
    end)

    it("shows select running child index", function(): ()
        local root = bt.select({
            bt.check(function()
                return false
            end),
            bt.action(function()
                return "running"
            end),
        })
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        expect(snap[1].kind):toBe("select")
        expect((snap[1] :: any).runningChild):toBe(2)
    end)

    it("shows random running child index", function(): ()
        local root = bt.random({
            bt.action(function()
                return "running"
            end),
        })
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        expect(snap[1].kind):toBe("random")
        expect((snap[1] :: any).runningChild):toBe(1)
    end)

    it("shows random weights", function(): ()
        local root = bt.random({
            bt.check(function()
                return true
            end),
            bt.check(function()
                return true
            end),
        }, { 3, 1 })
        local ctx = bt.bind(root, {}, nil)
        local snap = bt.snapshot(ctx)
        expect((snap[1] :: any).weights):toEqual({ 3, 1 })
    end)

    it("shows counted loop iteration", function(): ()
        local calls = 0
        local root = bt.action(function()
            calls += 1
            return if calls == 2 then "running" else "success"
        end):loop(5)
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        local loop: any = nil
        for _, e in snap do
            if e.kind == "loop" then
                loop = e
            end
        end
        expect(loop ~= nil):toBe(true)
        expect(loop.times):toBe(5)
        expect(loop.iteration):toBe(1)
    end)

    it("shows always forced status", function(): ()
        local root = bt.check(function()
            return true
        end):always("failure")
        local ctx = bt.bind(root, {}, nil)
        local snap = bt.snapshot(ctx)
        local a: any = nil
        for _, e in snap do
            if e.kind == "always" then
                a = e
            end
        end
        expect(a ~= nil):toBe(true)
        expect(a.forced):toBe("failure")
    end)

    it("shows guard passing state", function(): ()
        local root = bt.action(function()
            return "running"
        end):guard(function()
            return true
        end)
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        local g: any = nil
        for _, e in snap do
            if e.kind == "guard" then
                g = e
            end
        end
        expect(g ~= nil):toBe(true)
        expect(g.passing):toBe(true)
    end)

    it("shows tags on tagged nodes", function(): ()
        local root = bt.check(function()
            return true
        end):tag("myTag")
        local ctx = bt.bind(root, {}, nil)
        local snap = bt.snapshot(ctx)
        local tagged: any = nil
        for _, e in snap do
            if e.tag == "myTag" then
                tagged = e
            end
        end
        expect(tagged ~= nil):toBe(true)
    end)

    it("assigns correct depth values", function(): ()
        local root = bt.sequence({
            bt.check(function()
                return true
            end),
        })
        local ctx = bt.bind(root, {}, nil)
        local snap = bt.snapshot(ctx)
        expect(snap[1].depth):toBe(0)
        expect(snap[2].depth):toBe(1)
    end)

    it("includes serve polls", function(): ()
        local root = bt.action(function()
            return "running"
        end):serve(bt.poll(0.5, function() end))
        local ctx = bt.bind(root, {}, nil)
        local snap = bt.snapshot(ctx)
        local hasPoll = false
        for _, e in snap do
            if e.kind == "poll" then
                hasPoll = true
            end
        end
        expect(hasPoll):toBe(true)
    end)

    it("shows poll timing after fire", function(): ()
        local root = bt.poll(1.0, function() end)
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        local snap = bt.snapshot(ctx)
        local entry = snap[1] :: any
        expect(entry.interval):toBe(1.0)
        expect(entry.lastFired):toBeType("number")
    end)

    it("shows idle state after stop clears everything", function(): ()
        local root = bt.sequence({
            bt.check(function()
                return true
            end),
            bt.action(function()
                return "running"
            end),
        })
        local ctx = bt.bind(root, {}, nil)
        ctx:tick(0)
        ctx:stop()
        local snap = bt.snapshot(ctx)
        for _, e in snap do
            expect(e.active):toBe(false)
        end
    end)
end)

return nil
