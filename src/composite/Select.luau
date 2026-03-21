--!strict
--!optimize 2
-- Selector. Re-evaluates from child 1 every tick for priority checking.

local Node = require(script.Parent.Parent.core.Node)
local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

local function tick(node: Node, ctx: Context): Status
    local children = node._children :: { Node }
    local state = ctx._state
    local prevIdx = state[node] :: number?

    for i = 1, #children do
        local child = children[i]
        local result = child._tick(child, ctx)

        if result == "success" then
            if prevIdx and prevIdx ~= i then
                local prev = children[prevIdx]
                prev._halt(prev, ctx)
            end
            state[node] = nil
            return "success"
        end

        if result == "running" then
            if prevIdx and prevIdx ~= i then
                local prev = children[prevIdx]
                prev._halt(prev, ctx)
            end
            state[node] = i
            return "running"
        end
    end

    state[node] = nil
    return "failure"
end

local function halt(node: Node, ctx: Context): ()
    local state = ctx._state
    local runIdx = state[node] :: number?
    if runIdx then
        local child = (node._children :: { Node })[runIdx]
        child._halt(child, ctx)
    end
    state[node] = nil
end

local Select = {}

function Select.create(children: { Node }): Node
    return Node.make({ _tick = tick, _halt = halt, _children = children })
end

return table.freeze(Select)
