--!strict
--!optimize 2
-- Reads the node graph and context state. Returns structured plain data.

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node

local clock = os.clock

export type Entry = {
    kind: string,
    tag: string?,
    depth: number,
    active: boolean,
    [string]: unknown,
}

-- Private -------------------------------------------------------------

local function walk(
    node: any,
    state: { [unknown]: unknown },
    depth: number,
    now: number,
    results: { Entry }
): ()
    local kind = node._kind :: string
    local raw = state[node]

    local entry: Entry = {
        kind = kind,
        tag = node._tag,
        depth = depth,
        active = raw ~= nil,
    }

    if kind == "action" then
        if node._fn then
            entry.form = "simple"
        else
            entry.form = "phased"
            entry.phase = if raw then "tick" else nil

            local def = node._def
            entry.hasEnter = def.enter ~= nil
            entry.hasTick = def.tick ~= nil
            entry.hasHalt = def.halt ~= nil
        end
    elseif kind == "wait" then
        local seconds = node._seconds :: number
        local elapsed = (raw :: number?) or 0
        entry.seconds = seconds
        entry.elapsed = elapsed
        entry.remaining = seconds - elapsed
        entry.progress = if seconds > 0 then elapsed / seconds else 1
    elseif kind == "poll" then
        local interval = node._interval :: number
        entry.interval = interval
        if raw then
            local elapsed = now - (raw :: number)
            entry.lastFired = elapsed
            entry.nextIn = math.max(0, interval - elapsed)
        end
    elseif kind == "select" or kind == "sequence" then
        entry.runningChild = raw :: number?
    elseif kind == "parallel" then
        entry.succeed = node._succeed
        entry.fail = node._fail
        if raw then
            local pstate = raw :: any
            entry.successes = pstate.successes
            entry.failures = pstate.failures
            local running = 0
            for _, v in pstate.active do
                if v then
                    running += 1
                end
            end
            entry.running = running
        end
    elseif kind == "random" then
        entry.runningChild = raw :: number?
        if node._weights then
            entry.weights = node._weights
        end
    elseif kind == "loop" then
        local times = node._times :: number?
        if times then
            entry.times = times
            entry.iteration = (raw :: number?) or 0
        end
    elseif kind == "cooldown" then
        local seconds = node._seconds :: number
        entry.seconds = seconds
        if raw then
            local remaining = seconds - (now - (raw :: number))
            entry.blocked = remaining > 0
            entry.remaining = math.max(0, remaining)
        else
            entry.blocked = false
        end
    elseif kind == "timeout" then
        local seconds = node._seconds :: number
        entry.seconds = seconds
        if raw then
            local elapsed = now - (raw :: number)
            entry.elapsed = elapsed
            entry.remaining = math.max(0, seconds - elapsed)
        end
    elseif kind == "retry" then
        entry.times = node._times
        entry.attempt = (raw :: number?) or 0
    elseif kind == "always" then
        entry.forced = node._forced
    elseif kind == "guard" then
        entry.passing = raw ~= nil
    elseif kind == "throttle" then
        local seconds = node._seconds :: number
        entry.seconds = seconds
        if type(raw) == "table" then
            local t = raw :: any
            local remaining = seconds - (now - t.time)
            entry.cached = t.last
            entry.remaining = math.max(0, remaining)
            entry.fresh = remaining > 0
        elseif raw == true then
            entry.childRunning = true
        end
    elseif kind == "event" then
        if raw then
            entry.fired = (raw :: any).fired == true
        end
    end

    table.insert(results, entry)

    -- Recurse into child graph.
    if node._children then
        for _, child in node._children do
            walk(child, state, depth + 1, now, results)
        end
    end
    if node._child then
        walk(node._child, state, depth + 1, now, results)
    end
    if node._polls then
        for _, poll in node._polls do
            walk(poll, state, depth + 1, now, results)
        end
    end
end

-- Public --------------------------------------------------------------

local Snapshot = {}

function Snapshot.take(ctx: Context): { Entry }
    local results: { Entry } = {}
    walk((ctx :: any)._root, (ctx :: any)._state, 0, clock(), results)
    return results
end

return table.freeze(Snapshot)
