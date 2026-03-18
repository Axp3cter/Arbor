--!strict
--!native
-- Composite node that ticks all children concurrently with configurable policies.

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type ParallelConfig = Types.ParallelConfig
type Status = Types.Status

-- Constants -----------------------------------------------------------

local SUCCESS: Status = 1
local FAILURE: Status = 2
local RUNNING: Status = 3

local REQUIRE_ONE = 1

-- Private -------------------------------------------------------------

local function haltRunning(children: { Node }, ctx: Context): ()
    for i = 1, #children do
        local child = children[i]
        if ctx:getState(child) ~= nil then
            ctx:halt(child)
        end
    end
end

local function tick(node: Node, ctx: Context): Status
    local children = node._children :: { Node }
    local config = (node :: any)._config :: ParallelConfig
    local successCount = 0
    local failureCount = 0
    local n = #children
    local failOne = config.failurePolicy == REQUIRE_ONE
    local succOne = config.successPolicy == REQUIRE_ONE
    for i = 1, n do
        local child = children[i]
        local status = child._tick(child, ctx)
        if status == SUCCESS then
            successCount += 1
            if succOne then
                haltRunning(children, ctx)
                ctx:clearState(node)
                return SUCCESS
            end
        elseif status == FAILURE then
            failureCount += 1
            if failOne then
                haltRunning(children, ctx)
                ctx:clearState(node)
                return FAILURE
            end
        end
    end
    if successCount == n then
        ctx:clearState(node)
        return SUCCESS
    end
    if failureCount == n then
        ctx:clearState(node)
        return FAILURE
    end
    ctx:setState(node, true)
    return RUNNING
end

local function halt(node: Node, ctx: Context): ()
    haltRunning(node._children :: { Node }, ctx)
    ctx:clearState(node)
end

-- Public --------------------------------------------------------------

local Parallel = {}

function Parallel.create(config: ParallelConfig, children: { Node }): Node
    return table.freeze({
        _kind = "parallel",
        _name = "Parallel",
        _tick = tick,
        _halt = halt,
        _children = children,
        _config = config,
    }) :: any
end

return table.freeze(Parallel)
