--!strict
--!optimize 2
-- Leaf node that performs work.

local Node = require(script.Parent.Parent.core.Node)
local Types = require(script.Parent.Parent.Types)

type ActionDef = Types.ActionDef
type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Simple form: function runs every tick, no state tracked -------------

local function tickSimple(node: Node, ctx: Context): Status
    local fn = (node :: any)._fn :: (unknown, unknown, number) -> Status
    return fn(ctx.board, ctx.agent, ctx.dt)
end

-- Phased form: enter once, tick while running, halt on interrupt ------

local function tickPhased(node: Node, ctx: Context): Status
    local def = (node :: any)._def :: ActionDef
    local state = ctx._state

    -- Already entered. Run the tick handler each frame.
    if state[node] then
        local tickFn = def.tick
        if not tickFn then
            return "running"
        end

        local result = tickFn(ctx.board, ctx.agent, ctx.dt)
        if result ~= "running" then
            state[node] = nil
        end
        return result
    end

    -- First activation. Run enter if it exists.
    local enterFn = def.enter
    if enterFn then
        local result = enterFn(ctx.board, ctx.agent, ctx.dt)
        if result == "running" then
            state[node] = true
        end
        return result
    end

    -- No enter handler. Activate tick phase immediately.
    state[node] = true
    local tickFn = def.tick :: (unknown, unknown, number) -> Status
    local result = tickFn(ctx.board, ctx.agent, ctx.dt)
    if result ~= "running" then
        state[node] = nil
    end
    return result
end

local function haltPhased(node: Node, ctx: Context): ()
    local state = ctx._state
    if not state[node] then
        return
    end
    state[node] = nil

    local haltFn = ((node :: any)._def :: ActionDef).halt
    if haltFn then
        haltFn(ctx.board, ctx.agent)
    end
end

-- Public --------------------------------------------------------------

local Action = {}

function Action.create(
    handler: ((board: unknown, agent: unknown, dt: number) -> Status) | ActionDef
): Node
    if type(handler) == "function" then
        return Node.make({
            _kind = "action",
            _tick = tickSimple,
            _halt = Node.haltNoop,
            _fn = handler,
        })
    end

    local def = handler :: ActionDef
    if not def.enter and not def.tick then
        error("action requires at least an enter or tick handler", 2)
    end

    return Node.make({
        _kind = "action",
        _tick = tickPhased,
        _halt = haltPhased,
        _def = def,
    })
end

return table.freeze(Action)
