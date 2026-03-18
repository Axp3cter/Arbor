--!strict
--!native
-- Leaf node that performs work. Supports simple and three-phase async forms.

local Types = require(script.Parent.Parent.Types)

type ActionCallbacks = Types.ActionCallbacks
type Blackboard = Types.Blackboard
type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants -----------------------------------------------------------

local RUNNING: Status = 3
local SENTINEL = true

-- Private -------------------------------------------------------------

local function tickSimple(node: Node, ctx: Context): Status
    local fn = (node :: any)._fn :: (board: Blackboard, agent: any) -> Status
    return fn(ctx.board, ctx.agent)
end

local function haltSimple(_node: Node, _ctx: Context): () end

local function tickAsync(node: Node, ctx: Context): Status
    local cbs = (node :: any)._callbacks :: ActionCallbacks
    local running = ctx:getState(node)
    if not running then
        local status = cbs.onStart(ctx.board, ctx.agent)
        if status == RUNNING then
            ctx:setState(node, SENTINEL)
        end
        return status
    end
    local status = cbs.onRunning(ctx.board, ctx.agent)
    if status ~= RUNNING then
        ctx:clearState(node)
    end
    return status
end

local function haltAsync(node: Node, ctx: Context): ()
    local cbs = (node :: any)._callbacks :: ActionCallbacks
    if ctx:getState(node) and cbs.onHalted then
        (cbs.onHalted :: any)(ctx.board, ctx.agent)
    end
    ctx:clearState(node)
end

-- Public --------------------------------------------------------------

local Action = {}

function Action.create(
    name: string,
    handler: ((board: Blackboard, agent: any) -> Status) | ActionCallbacks
): Node
    if type(handler) == "function" then
        return table.freeze({
            _kind = "action",
            _name = name,
            _tick = tickSimple,
            _halt = haltSimple,
            _fn = handler,
        }) :: any
    end
    return table.freeze({
        _kind = "action",
        _name = name,
        _tick = tickAsync,
        _halt = haltAsync,
        _callbacks = handler :: ActionCallbacks,
    }) :: any
end

return table.freeze(Action)
