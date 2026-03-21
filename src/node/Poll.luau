--!strict
--!optimize 2
-- Periodic updater node. Fires on a timer, always succeeds.

local Node = require(script.Parent.Node)
local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

local clock = os.clock

local function tick(node: Node, ctx: Context): Status
    local interval = (node :: any)._interval :: number
    local updater = (node :: any)._updater :: (unknown, unknown) -> ()
    local state = ctx._state
    local now = clock()

    local lastFire = state[node] :: number?
    if not lastFire or (now - lastFire) >= interval then
        state[node] = now
        updater(ctx.board, ctx.agent)
    end

    return "success"
end

local function halt(node: Node, ctx: Context): ()
    ctx._state[node] = nil
end

local Poll = {}

function Poll.create(interval: number, updater: (board: unknown, agent: unknown) -> ()): Node
    return Node.make({ _tick = tick, _halt = halt, _interval = interval, _updater = updater })
end

return table.freeze(Poll)
