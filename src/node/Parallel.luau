--!strict
--!optimize 2
-- Parallel. Ticks all children, resolves by threshold.

local Node = require(script.Parent.Node)
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
    local children = node._children :: { Node }
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

    pstate.successes = successes
    pstate.failures = failures
    return "running"
end

local function halt(node: Node, ctx: Context): ()
    local state = ctx._state
    local pstate = state[node] :: ParallelState?
    if pstate then
        haltActive(node._children :: { Node }, pstate.active, #(node._children :: { Node }), ctx)
    end
    state[node] = nil
end

-- Curried: bt.parallel(succeed) { children }
local Parallel = {}

function Parallel.create(succeed: number, fail: number?): ({ Node }) -> Node
    return function(children: { Node }): Node
        local count = #children
        local failThreshold = fail or count

        if count == 0 then
            error("parallel requires at least 1 child", 2)
        end

        return Node.make({
            _tick = tick,
            _halt = halt,
            _children = children,
            _succeed = succeed,
            _fail = failThreshold,
        })
    end
end

return table.freeze(Parallel)
