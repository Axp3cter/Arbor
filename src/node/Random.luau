--!strict
--!optimize 2
-- Random.luau — Picks one child at random. Sticky while RUNNING.

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants --------------------------------------------------------------

local RUNNING: Status = 3

local random = math.random

-- Private ----------------------------------------------------------------

@native
local function pickWeighted(weights: { number }, totalWeight: number): number
    local roll = random() * totalWeight
    local cumulative = 0
    for i = 1, #weights do
        cumulative += weights[i]
        if roll <= cumulative then
            return i
        end
    end
    return #weights
end

local function tick(node: Node, ctx: Context): Status
    local children = node._children :: { Node }
    local weights = (node :: any)._weights :: { number }?
    local state = ctx._state

    local idx = state[node] :: number?

    if not idx then
        if weights then
            idx = pickWeighted(weights, (node :: any)._totalWeight :: number)
        else
            idx = random(1, #children)
        end
    end

    local child = children[idx]
    local status = child._tick(child, ctx)

    if status == RUNNING then
        state[node] = idx
        return RUNNING
    end

    state[node] = nil
    return status
end

local function halt(node: Node, ctx: Context): ()
    local state = ctx._state
    local idx = state[node] :: number?
    if idx then
        local children = node._children :: { Node }
        children[idx]._halt(children[idx], ctx)
    end
    state[node] = nil
end

-- Public -----------------------------------------------------------------

local Random = {}

function Random.create(children: { Node }, weights: { number }?): Node
    local n = #children
    if n == 0 then
        error("Random requires at least 1 child", 2)
    end

    local totalWeight: number? = nil
    if weights then
        if #weights ~= n then
            error(`Random weights count ({#weights}) must match child count ({n})`, 2)
        end
        local sum = 0
        for i = 1, n do
            sum += weights[i]
        end
        totalWeight = sum
    end

    return table.freeze({
        _kind = "random",
        _name = "Random",
        _tick = tick,
        _halt = halt,
        _children = children,
        _weights = weights,
        _totalWeight = totalWeight,
    }) :: any
end

return table.freeze(Random)
