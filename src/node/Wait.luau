--!strict
--!optimize 2
-- Wait.luau — Leaf node that returns RUNNING for N seconds, then SUCCESS.

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants --------------------------------------------------------------

local SUCCESS: Status = 1
local RUNNING: Status = 3

local clock = os.clock

-- Private ----------------------------------------------------------------

local function tick(node: Node, ctx: Context): Status
    local seconds = (node :: any)._seconds :: number
    local state = ctx._state
    local startTime = state[node] :: number?

    if not startTime then
        state[node] = clock()
        return RUNNING
    end

    if clock() - startTime >= seconds then
        state[node] = nil
        return SUCCESS
    end

    return RUNNING
end

local function halt(node: Node, ctx: Context): ()
    ctx._state[node] = nil
end

-- Public -----------------------------------------------------------------

local Wait = {}

function Wait.create(seconds: number): Node
    return table.freeze({
        _kind = "wait",
        _name = `Wait({seconds}s)`,
        _tick = tick,
        _halt = halt,
        _seconds = seconds,
    }) :: any
end

return table.freeze(Wait)
