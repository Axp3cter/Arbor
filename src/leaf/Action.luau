--!strict
--!optimize 2
-- Leaf node that performs work.

local Types = require(script.Parent.Parent.Types)
local Node  = require(script.Parent.Parent.core.Node)

type ActionDef = Types.ActionDef
type Context   = Types.Context
type Node      = Types.Node
type Status    = Types.Status

-- Simple form: function runs every tick, no state tracked ----------------

local function tickSimple(node: Node, ctx: Context): Status
    local fn = (node :: any)._fn :: (unknown, unknown, number) -> Status
    return fn(ctx.board, ctx.agent, ctx.dt)
end

-- Phased form: enter once, tick while running, halt on interrupt ---------

local function tickPhased(node: Node, ctx: Context): Status
    local def   = (node :: any)._def :: ActionDef
    local state = ctx._state

    if state[node] then
        local result = (def.tick :: any)(ctx.board, ctx.agent, ctx.dt)
        if result ~= "running" then
            state[node] = nil
        end
        return result
    end

    local result = (def.enter :: any)(ctx.board, ctx.agent, ctx.dt)
    if result == "running" then
        state[node] = true
    end
    return result
end

local function haltPhased(node: Node, ctx: Context): ()
    local state = ctx._state
    if not state[node] then return end
    state[node] = nil

    local haltFn = ((node :: any)._def :: ActionDef).halt
    if haltFn then
        haltFn(ctx.board, ctx.agent)
    end
end

-- Public -----------------------------------------------------------------

local Action = {}

function Action.create(
    handler: ((board: unknown, agent: unknown, dt: number) -> Status) | ActionDef
): Node
    if type(handler) == "function" then
        return Node.make({
            _tick = tickSimple,
            _halt = Node.haltNoop,
            _fn   = handler,
        })
    end

    return Node.make({
        _tick = tickPhased,
        _halt = haltPhased,
        _def  = handler :: ActionDef,
    })
end

return table.freeze(Action)
