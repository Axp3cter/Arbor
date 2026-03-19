--!strict
--!optimize 2
-- Action.luau — Leaf node that performs work. Simple and phased forms.

local Types = require(script.Parent.Parent.Types)

type ActionPhases = Types.ActionPhases
type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants --------------------------------------------------------------

local RUNNING: Status = 3
local SENTINEL = true

-- Simple form ------------------------------------------------------------

local function tickSimple(node: Node, ctx: Context): Status
    local handler = (node :: any)._handler :: (board: any, agent: any) -> Status
    return handler(ctx.board, ctx.agent)
end

local function haltSimple(_node: Node, _ctx: Context): () end

-- Phased form ------------------------------------------------------------

local function tickPhased(node: Node, ctx: Context): Status
    local phases = (node :: any)._phases :: ActionPhases
    local state = ctx._state

    if not state[node] then
        local status = phases.start(ctx.board, ctx.agent)
        if status == RUNNING then
            state[node] = SENTINEL
        end
        return status
    end

    local status = phases.tick(ctx.board, ctx.agent)
    if status ~= RUNNING then
        state[node] = nil
    end
    return status
end

local function haltPhased(node: Node, ctx: Context): ()
    local phases = (node :: any)._phases :: ActionPhases
    local state = ctx._state
    if state[node] and phases.halt then
        (phases.halt :: any)(ctx.board, ctx.agent)
    end
    state[node] = nil
end

-- Public -----------------------------------------------------------------

local Action = {}

function Action.create(
    name: string,
    handler: ((board: any, agent: any) -> Status) | ActionPhases
): Node
    if type(handler) == "function" then
        return table.freeze({
            _kind = "action",
            _name = name,
            _tick = tickSimple,
            _halt = haltSimple,
            _handler = handler,
        }) :: any
    end

    return table.freeze({
        _kind = "action",
        _name = name,
        _tick = tickPhased,
        _halt = haltPhased,
        _phases = handler :: ActionPhases,
    }) :: any
end

return table.freeze(Action)
