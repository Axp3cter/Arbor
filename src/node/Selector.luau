--!strict
--!optimize 2
-- Selector.luau — Runs children left-to-right. Succeeds on first success.

local Types = require(script.Parent.Parent.Types)

local ServiceRunner = require(script.Parent.Parent.core.ServiceRunner)

type CompositeConfig = Types.CompositeConfig
type Context = Types.Context
type Node = Types.Node
type ServiceDef = Types.ServiceDef
type Status = Types.Status

-- Constants --------------------------------------------------------------

local SUCCESS: Status = 1
local FAILURE: Status = 2
local RUNNING: Status = 3

-- Private ----------------------------------------------------------------

local function tickMemory(node: Node, ctx: Context): Status
    local services = node._services
    if services then
        ServiceRunner.tick(services, ctx)
    end

    local children = node._children :: { Node }
    local state = ctx._state
    local startIdx = (state[node] :: number?) or 1

    for i = startIdx, #children do
        local child = children[i]
        local status = child._tick(child, ctx)
        if status == SUCCESS then
            state[node] = nil
            return SUCCESS
        end
        if status == RUNNING then
            state[node] = i
            return RUNNING
        end
    end

    state[node] = nil
    return FAILURE
end

local function tickReactive(node: Node, ctx: Context): Status
    local services = node._services
    if services then
        ServiceRunner.tick(services, ctx)
    end

    local children = node._children :: { Node }
    local state = ctx._state
    local prevIdx = state[node] :: number?

    for i = 1, #children do
        local child = children[i]
        local status = child._tick(child, ctx)
        if status == SUCCESS then
            if prevIdx and prevIdx > i then
                local prev = children[prevIdx]
                prev._halt(prev, ctx)
            end
            state[node] = nil
            return SUCCESS
        end
        if status == RUNNING then
            if prevIdx and prevIdx ~= i then
                local prev = children[prevIdx]
                prev._halt(prev, ctx)
            end
            state[node] = i
            return RUNNING
        end
    end

    state[node] = nil
    return FAILURE
end

local function halt(node: Node, ctx: Context): ()
    local state = ctx._state
    local runIdx = state[node] :: number?
    if runIdx then
        local child = (node._children :: { Node })[runIdx]
        child._halt(child, ctx)
    end
    state[node] = nil

    local services = node._services
    if services then
        ServiceRunner.halt(services, ctx)
    end
end

-- Public -----------------------------------------------------------------

local Selector = {}

function Selector.create(children: { Node }, config: CompositeConfig?): Node
    local isReactive = false
    local services: { ServiceDef }? = nil

    if config then
        isReactive = config.reactive == true
        services = config.services
    end

    return table.freeze({
        _kind = "selector",
        _name = if isReactive then "ReactiveSelector" else "Selector",
        _tick = if isReactive then tickReactive else tickMemory,
        _halt = halt,
        _children = children,
        _services = services,
    }) :: any
end

return table.freeze(Selector)
