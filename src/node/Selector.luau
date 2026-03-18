--!strict
--!native
-- Composite node that runs children left-to-right until one succeeds.

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type ServiceDef = Types.ServiceDef
type Status = Types.Status

-- Constants -----------------------------------------------------------

local SUCCESS: Status = 1
local FAILURE: Status = 2
local RUNNING: Status = 3

local clock = os.clock

-- Private -------------------------------------------------------------

local function tickServices(services: { ServiceDef }, ctx: Context): ()
    local now = clock()
    for i = 1, #services do
        local svc = services[i]
        local last = ctx:getState(svc) :: number?
        if not last or (now - last) >= svc._interval then
            ctx:setState(svc, now)
            svc._updater(ctx.board, ctx.agent)
        end
    end
end

local function haltServices(services: { ServiceDef }, ctx: Context): ()
    for i = 1, #services do
        ctx:clearState(services[i])
    end
end

local function tickMemory(node: Node, ctx: Context): Status
    local services = node._services
    if services then
        tickServices(services, ctx)
    end
    local children = node._children :: { Node }
    local startIdx = (ctx:getState(node) :: number?) or 1
    for i = startIdx, #children do
        local child = children[i]
        local status = child._tick(child, ctx)
        if status == SUCCESS then
            ctx:clearState(node)
            return SUCCESS
        end
        if status == RUNNING then
            ctx:setState(node, i)
            return RUNNING
        end
    end
    ctx:clearState(node)
    return FAILURE
end

local function tickReactive(node: Node, ctx: Context): Status
    local services = node._services
    if services then
        tickServices(services, ctx)
    end
    local children = node._children :: { Node }
    local prevIdx = ctx:getState(node) :: number?
    for i = 1, #children do
        local child = children[i]
        local status = child._tick(child, ctx)
        if status == SUCCESS then
            if prevIdx and prevIdx > i then
                ctx:halt(children[prevIdx])
            end
            ctx:clearState(node)
            return SUCCESS
        end
        if status == RUNNING then
            if prevIdx and prevIdx ~= i then
                ctx:halt(children[prevIdx])
            end
            ctx:setState(node, i)
            return RUNNING
        end
    end
    ctx:clearState(node)
    return FAILURE
end

local function halt(node: Node, ctx: Context): ()
    local runIdx = ctx:getState(node) :: number?
    if runIdx then
        local children = node._children :: { Node }
        ctx:halt(children[runIdx])
    end
    ctx:clearState(node)
    local services = node._services
    if services then
        haltServices(services, ctx)
    end
end

-- Public --------------------------------------------------------------

local Selector = {}

function Selector.create(children: { Node }, services: { ServiceDef }?): Node
    return table.freeze({
        _kind = "selector",
        _name = "Selector",
        _tick = tickMemory,
        _halt = halt,
        _children = children,
        _services = services,
    }) :: any
end

function Selector.createReactive(children: { Node }, services: { ServiceDef }?): Node
    return table.freeze({
        _kind = "selector",
        _name = "ReactiveSelector",
        _tick = tickReactive,
        _halt = halt,
        _children = children,
        _services = services,
    }) :: any
end

return table.freeze(Selector)
