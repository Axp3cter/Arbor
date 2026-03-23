--!strict
--!optimize 2
-- Parallel. Ticks all children every frame, resolves by threshold.

local Node = require(script.Parent.Parent.core.Node)
local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

local tableCreate = table.create

type ParallelState = {
    active: { boolean },
    successes: number,
    failures: number,
}

local function haltActive(children: { Node }, active: { boolean }, count: number, ctx: Context): ()
    for i = 1, count do
        if active[i] then
            children[i]._halt(children[i], ctx)
        end
    end
end

local function tick(node: Node, ctx: Context): Status
    local children = (node :: any)._children :: { Node }
    local succeed = (node :: any)._succeed :: number
    local fail = (node :: any)._fail :: number
    local count = #children
    local state = ctx._state

    local pstate = state[node] :: ParallelState?
    if not pstate then
        pstate = {
            active = tableCreate(count, true),
            successes = 0,
            failures = 0,
        }
        state[node] = pstate
    end

    local active = pstate.active
    local successes = pstate.successes
    local failures = pstate.failures

    for i = 1, count do
        if not active[i] then
            continue
        end

        local result = children[i]._tick(children[i], ctx)

        if result == "success" then
            active[i] = false
            successes += 1
            if successes >= succeed then
                haltActive(children, active, count, ctx)
                state[node] = nil
                return "success"
            end
        elseif result == "failure" then
            active[i] = false
            failures += 1
            if failures >= fail then
                haltActive(children, active, count, ctx)
                state[node] = nil
                return "failure"
            end
        end
    end

    --[[
        All children resolved but neither threshold met. This can happen
        when succeed + fail > count. Treat as failure to prevent deadlock.
    ]]
    if successes + failures >= count then
        state[node] = nil
        return "failure"
    end

    pstate.successes = successes
    pstate.failures = failures
    return "running"
end

local function halt(node: Node, ctx: Context): ()
    local state = ctx._state
    local pstate = state[node] :: ParallelState?
    if pstate then
        local children = (node :: any)._children :: { Node }
        haltActive(children, pstate.active, #children, ctx)
    end
    state[node] = nil
end

-- Curried so tree construction reads as `bt.parallel(1) { child1, child2 }`.
local Parallel = {}

function Parallel.create(succeed: number, fail: number?): ({ Node }) -> Node
    return function(children: { Node }): Node
        local count = #children
        local failThreshold = fail or count

        if count == 0 then
            error("parallel requires at least 1 child", 2)
        end
        if succeed <= 0 then
            error("parallel succeed threshold must be > 0", 2)
        end
        if succeed > count then
            error(`parallel succeed threshold ({succeed}) exceeds child count ({count})`, 2)
        end
        if failThreshold > count then
            error(`parallel fail threshold ({failThreshold}) exceeds child count ({count})`, 2)
        end

        return Node.make({
            _kind = "parallel",
            _tick = tick,
            _halt = halt,
            _children = children,
            _succeed = succeed,
            _fail = failThreshold,
        })
    end
end

return table.freeze(Parallel)
