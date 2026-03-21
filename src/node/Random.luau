--!strict
--!optimize 2
-- Random. Picks one child, sticks with it until resolved.

local Node = require(script.Parent.Node)
local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

local random = math.random

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
    local totalWeight = (node :: any)._totalWeight :: number?
    local state = ctx._state

    local idx = state[node] :: number?
    if not idx then
        idx = if weights and totalWeight
            then pickWeighted(weights, totalWeight)
            else random(1, #children)
    end

    local result = children[idx]._tick(children[idx], ctx)

    if result == "running" then
        state[node] = idx
        return "running"
    end

    state[node] = nil
    return result
end

local function halt(node: Node, ctx: Context): ()
    local state = ctx._state
    local idx = state[node] :: number?
    if idx then
        local child = (node._children :: { Node })[idx]
        child._halt(child, ctx)
    end
    state[node] = nil
end

local Random = {}

function Random.create(children: { Node }, weights: { number }?): Node
    local count = #children
    if count == 0 then
        error("random requires at least 1 child", 2)
    end

    local totalWeight: number? = nil
    if weights then
        if #weights ~= count then
            error(`random weight count ({#weights}) must match child count ({count})`, 2)
        end
        local sum = 0
        for i = 1, count do
            sum += weights[i]
        end
        totalWeight = sum
    end

    return Node.make({
        _tick = tick,
        _halt = halt,
        _children = children,
        _weights = weights,
        _totalWeight = totalWeight,
    })
end

return table.freeze(Random)
