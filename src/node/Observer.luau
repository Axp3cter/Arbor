--!strict
--!optimize 2
-- Observer.luau — Reactive decorator that watches blackboard keys and triggers aborts.

local Types = require(script.Parent.Parent.Types)

local Blackboard = require(script.Parent.Parent.core.Blackboard)

type Abort = Types.Abort
type ConditionNode = Types.ConditionNode
type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants --------------------------------------------------------------

local FAILURE: Status = 2
local RUNNING: Status = 3

local ABORT_SELF: Abort    = 1
local ABORT_LOWER: Abort   = 2
local ABORT_RESTART: Abort = 3

-- State types ------------------------------------------------------------

type SubscriptionState = {
    result: boolean,
    cleanups: { () -> () },
}

-- Private ----------------------------------------------------------------

local function ensureSubscribed(node: Node, ctx: Context): SubscriptionState
    local subsKey = (node :: any)._subsKey
    local state = ctx._state
    local subs = state[subsKey] :: SubscriptionState?
    if subs then return subs end

    local gate = (node :: any)._gate :: ConditionNode
    local abortMode = (node :: any)._abortMode :: Abort
    local predicate = gate._predicate
    local watchKeys = gate._watchKeys :: { string }
    local board = ctx.board

    local result = predicate(board)
    local cleanups: { () -> () } = {}

    -- Non-reassigned local for closures to capture as LCT_VAL.
    -- `subs` above was declared as SubscriptionState? and would be
    -- reassigned (nil → table), making it LCT_REF with UpVal heap cost.
    local subsState: SubscriptionState = {
        result = result,
        cleanups = cleanups,
    }
    state[subsKey] = subsState

    for i = 1, #watchKeys do
        local cleanup = Blackboard.subscribe(board, watchKeys[i], function(_new: any, _old: any): ()
            local prevResult = subsState.result
            local newResult = predicate(board)
            subsState.result = newResult

            if newResult == prevResult then return end

            if abortMode == ABORT_SELF then
                -- Flag is updated; next tick() call handles the halt.
            elseif abortMode == ABORT_LOWER or abortMode == ABORT_RESTART then
                if newResult and not state[node] then
                    ctx._pendingAbort = abortMode
                end
            end
        end)

        cleanups[#cleanups + 1] = cleanup

        local ctxCleanups = ctx._observerCleanups
        ctxCleanups[#ctxCleanups + 1] = cleanup
    end

    return subsState
end

local function tick(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local state = ctx._state

    -- Ensure blackboard subscriptions are active.
    local subs = ensureSubscribed(node, ctx)

    -- Read cached result. The subscription callback keeps subs.result
    -- updated synchronously on every board write — re-evaluating the
    -- predicate here would be redundant.
    if not subs.result then
        if state[node] then
            child._halt(child, ctx)
            state[node] = nil
        end
        return FAILURE
    end

    local status = child._tick(child, ctx)

    if status == RUNNING then
        state[node] = true
    else
        state[node] = nil
    end

    return status
end

local function halt(node: Node, ctx: Context): ()
    local child = (node._children :: { Node })[1]
    local abortMode = (node :: any)._abortMode :: Abort
    local state = ctx._state

    if state[node] then
        child._halt(child, ctx)
    end
    state[node] = nil

    if abortMode == ABORT_SELF then
        local subsKey = (node :: any)._subsKey
        local subs = state[subsKey] :: SubscriptionState?
        if subs then
            for i = 1, #subs.cleanups do
                subs.cleanups[i]()
            end
            state[subsKey] = nil
        end
    end
end

-- Public -----------------------------------------------------------------

local Observer = {}

function Observer.create(gate: Node, abortMode: Abort, child: Node): Node
    local condNode = gate :: any :: ConditionNode

    if not condNode._watchKeys or #condNode._watchKeys == 0 then
        error(
            `condition '{condNode._name}' passed to observe() has no watch keys`
                .. ` — add them as the third argument to condition()`,
            2
        )
    end

    local subsKey = table.freeze({})

    return table.freeze({
        _kind = "observer",
        _name = `Observe({condNode._name})`,
        _tick = tick,
        _halt = halt,
        _children = { child },
        _gate = condNode,
        _abortMode = abortMode,
        _subsKey = subsKey,
    }) :: any
end

return table.freeze(Observer)
