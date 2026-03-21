--!strict
--!optimize 2
-- Sequence. Resumes from the last running child.

local Node = require(script.Parent.Parent.core.Node)
local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

local function tick(node: Node, ctx: Context): Status
    local children = node._children :: { Node }
    local state = ctx._state
    local startIdx = (state[node] :: number?) or 1

    for i = startIdx, #children do
        local child = children[i]
        local result = child._tick(child, ctx)

        if result == "running" then
            state[node] = i
            return "running"
        end
        if result == "failure" then
            state[node] = nil
            return "failure"
        end
    end

    state[node] = nil
    return "success"
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

local Sequence = {}

function Sequence.create(children: { Node }): Node
    return Node.make({ _tick = tick, _halt = halt, _children = children })
end

return table.freeze(Sequence)
