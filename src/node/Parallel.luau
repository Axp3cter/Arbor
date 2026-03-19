--!strict
--!optimize 2
-- Parallel.luau — Ticks all children. Numeric success/failure policies.

local Types = require(script.Parent.Parent.Types)

local ServiceRunner = require(script.Parent.Parent.core.ServiceRunner)

type Context = Types.Context
type Node = Types.Node
type ParallelConfig = Types.ParallelConfig
type ServiceDef = Types.ServiceDef
type Status = Types.Status

-- Constants --------------------------------------------------------------

local SUCCESS: Status = 1
local FAILURE: Status = 2
local RUNNING: Status = 3

local tableCreate = table.create

-- Private ----------------------------------------------------------------

type ParallelState = {
    results: { Status },
}

local function haltSurvivors(children: { Node }, results: { Status }, n: number, ctx: Context): ()
    for i = 1, n do
        if results[i] == RUNNING then
            children[i]._halt(children[i], ctx)
        end
    end
end

local function tick(node: Node, ctx: Context): Status
    local services = node._services
    if services then
        ServiceRunner.tick(services, ctx)
    end

    local children = node._children :: { Node }
    local config = (node :: any)._config :: ParallelConfig
    local n = #children
    local succeedThreshold = config.succeed or n
    local failThreshold = config.fail or 1
    local state = ctx._state

    local pstate = state[node] :: ParallelState?
    local results: { Status }

    if pstate then
        results = pstate.results
    else
        results = tableCreate(n, RUNNING)
        pstate = { results = results }
        state[node] = pstate
    end

    local successCount = 0
    local failureCount = 0

    for i = 1, n do
        local result = results[i]

        if result == RUNNING then
            result = children[i]._tick(children[i], ctx)
            results[i] = result
        end

        if result == SUCCESS then
            successCount += 1
            if successCount >= succeedThreshold then
                haltSurvivors(children, results, n, ctx)
                state[node] = nil
                return SUCCESS
            end
        elseif result == FAILURE then
            failureCount += 1
            if failureCount >= failThreshold then
                haltSurvivors(children, results, n, ctx)
                state[node] = nil
                return FAILURE
            end
        end
    end

    return RUNNING
end

local function halt(node: Node, ctx: Context): ()
    local state = ctx._state
    local pstate = state[node] :: ParallelState?
    if pstate then
        local children = node._children :: { Node }
        haltSurvivors(children, pstate.results, #children, ctx)
    end
    state[node] = nil

    local services = node._services
    if services then
        ServiceRunner.halt(services, ctx)
    end
end

-- Public -----------------------------------------------------------------

local Parallel = {}

function Parallel.create(children: { Node }, config: ParallelConfig): Node
    return table.freeze({
        _kind = "parallel",
        _name = "Parallel",
        _tick = tick,
        _halt = halt,
        _children = children,
        _services = config.services,
        _config = config,
    }) :: any
end

return table.freeze(Parallel)
