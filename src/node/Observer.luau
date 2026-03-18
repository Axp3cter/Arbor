--!strict
--!native
-- Observer decorator that watches blackboard keys and triggers abort modes.

local Types = require(script.Parent.Parent.Types)

type AbortMode = Types.AbortMode
type Blackboard = Types.Blackboard
type Connection = Types.Connection
type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants -----------------------------------------------------------

local SUCCESS: Status = 1
local FAILURE: Status = 2
local RUNNING: Status = 3

local ABORT_SELF: AbortMode = 1
local ABORT_LOWER: AbortMode = 2
local ABORT_LOWER_RESTART: AbortMode = 3

-- Private -------------------------------------------------------------

type ObserverState = {
    result: boolean,
    conns: { Connection },
    running: boolean,
}

local function teardown(state: ObserverState): ()
    local conns = state.conns
    for i = 1, #conns do
        conns[i]:disconnect()
    end
    table.clear(conns)
end

local function subscribe(
    node: Node,
    ctx: Context,
    state: ObserverState,
    keys: { string },
    abortMode: AbortMode,
    predicate: (board: Blackboard, agent: any) -> boolean
): ()
    local board = ctx.board
    for i = 1, #keys do
        local conn = board:observe(keys[i], function(_new: any, _old: any): ()
            local prev = state.result
            local now = predicate(board, ctx.agent)
            if now == prev then
                return
            end
            state.result = now
            if abortMode == ABORT_SELF then
                if not now and state.running then
                    -- Condition flipped false while child is running.
                    -- Next tick will see the updated result and halt.
                end
            elseif abortMode == ABORT_LOWER or abortMode == ABORT_LOWER_RESTART then
                if now then
                    -- Condition flipped true — next tick re-evaluates.
                end
            end
        end)
        state.conns[#state.conns + 1] = conn
    end
end

local function tick(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local predicate = (node :: any)._fn :: (board: Blackboard, agent: any) -> boolean
    local abortMode = (node :: any)._abortMode :: AbortMode
    local keys = (node :: any)._observeKeys :: { string }
    local state = ctx:getState(node) :: ObserverState?

    if not state then
        local result = predicate(ctx.board, ctx.agent)
        state = { result = result, conns = {}, running = false }
        ctx:setState(node, state)
        subscribe(node, ctx, state, keys, abortMode, predicate)
        if not result then
            teardown(state)
            ctx:clearState(node)
            return FAILURE
        end
    else
        local result = predicate(ctx.board, ctx.agent)
        state.result = result
        if not result then
            if state.running then
                ctx:halt(child)
                state.running = false
            end
            teardown(state)
            ctx:clearState(node)
            return FAILURE
        end
    end

    local status = child._tick(child, ctx)
    state.running = status == RUNNING
    if status ~= RUNNING then
        teardown(state)
        ctx:clearState(node)
    end
    return status
end

local function halt(node: Node, ctx: Context): ()
    local state = ctx:getState(node) :: ObserverState?
    if state then
        teardown(state)
        if state.running then
            local child = (node._children :: { Node })[1]
            ctx:halt(child)
        end
    end
    ctx:clearState(node)
end

-- Public --------------------------------------------------------------

local Observer = {}

function Observer.create(
    name: string,
    predicate: (board: Blackboard, agent: any) -> boolean,
    abortMode: AbortMode,
    keys: { string },
    child: Node
): Node
    return table.freeze({
        _kind = "observer",
        _name = name,
        _tick = tick,
        _halt = halt,
        _children = { child },
        _fn = predicate,
        _abortMode = abortMode,
        _observeKeys = keys,
    }) :: any
end

return table.freeze(Observer)
