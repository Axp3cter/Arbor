--!strict
--!optimize 2
-- Yields for a duration (measured by dt accumulation) then succeeds.

local Node = require(script.Parent.Parent.core.Node)
local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

local function tick(node: Node, ctx: Context): Status
    local seconds = (node :: any)._seconds :: number
    local state = ctx._state
    local elapsed = ((state[node] :: number?) or 0) + ctx.dt

    if elapsed >= seconds then
        state[node] = nil
        return "success"
    end

    state[node] = elapsed
    return "running"
end

local function halt(node: Node, ctx: Context): ()
    ctx._state[node] = nil
end

-- Public --------------------------------------------------------------

local Wait = {}

function Wait.create(seconds: number): Node
    return Node.make({ _kind = "wait", _tick = tick, _halt = halt, _seconds = seconds })
end

return table.freeze(Wait)
