--!strict
--!optimize 2
-- Decorator.luau — Nodes that wrap and modify a single child's behavior.

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants --------------------------------------------------------------

local SUCCESS: Status = 1
local FAILURE: Status = 2
local RUNNING: Status = 3

local clock = os.clock

-- Shared -----------------------------------------------------------------

local function haltChild(node: Node, ctx: Context): ()
    local child = (node._children :: { Node })[1]
    local state = ctx._state
    if state[child] ~= nil then
        child._halt(child, ctx)
    end
    state[node] = nil
end

-- Invert -----------------------------------------------------------------

local function tickInvert(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local status = child._tick(child, ctx)
    if status == SUCCESS then
        return FAILURE
    end
    if status == FAILURE then
        return SUCCESS
    end
    return RUNNING
end

-- Succeed ----------------------------------------------------------------

local function tickSucceed(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local status = child._tick(child, ctx)
    if status == RUNNING then
        return RUNNING
    end
    return SUCCESS
end

-- Fail -------------------------------------------------------------------

local function tickFail(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local status = child._tick(child, ctx)
    if status == RUNNING then
        return RUNNING
    end
    return FAILURE
end

-- Loop -------------------------------------------------------------------

local function tickLoop(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local times = (node :: any)._times :: number?
    local state = ctx._state
    local count = (state[node] :: number?) or 0

    while true do
        local status = child._tick(child, ctx)

        if status == RUNNING then
            state[node] = count
            return RUNNING
        end

        if status == FAILURE then
            state[node] = nil
            return FAILURE
        end

        count += 1

        if times and count >= times then
            state[node] = nil
            return SUCCESS
        end
    end

    return SUCCESS :: any
end

-- Cooldown ---------------------------------------------------------------

local function tickCooldown(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local seconds = (node :: any)._seconds :: number
    local state = ctx._state
    local lastSuccess = state[node] :: number?

    if lastSuccess then
        if clock() - lastSuccess < seconds then
            return FAILURE
        end
        state[node] = nil
    end

    local status = child._tick(child, ctx)
    if status == SUCCESS then
        state[node] = clock()
    end
    return status
end

-- Timeout ----------------------------------------------------------------

local function tickTimeout(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local seconds = (node :: any)._seconds :: number
    local state = ctx._state
    local startTime = state[node] :: number?

    if startTime then
        if clock() - startTime >= seconds then
            child._halt(child, ctx)
            state[node] = nil
            return FAILURE
        end
    end

    local status = child._tick(child, ctx)

    if status == RUNNING then
        if not startTime then
            state[node] = clock()
        end
        return RUNNING
    end

    state[node] = nil
    return status
end

-- Retry ------------------------------------------------------------------

local function tickRetry(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local times = (node :: any)._times :: number
    local state = ctx._state
    local attempts = (state[node] :: number?) or 0

    local status = child._tick(child, ctx)

    if status == SUCCESS then
        state[node] = nil
        return SUCCESS
    end

    if status == RUNNING then
        return RUNNING
    end

    attempts += 1
    if attempts >= times then
        state[node] = nil
        return FAILURE
    end

    state[node] = attempts
    return RUNNING
end

-- Guard ------------------------------------------------------------------

local function tickGuard(node: Node, ctx: Context): Status
    local children = node._children :: { Node }
    local gate = children[1]
    local child = children[2]

    if gate._tick(gate, ctx) ~= SUCCESS then
        if ctx._state[child] ~= nil then
            child._halt(child, ctx)
        end
        return FAILURE
    end

    return child._tick(child, ctx)
end

local function haltGuard(node: Node, ctx: Context): ()
    local child = (node._children :: { Node })[2]
    local state = ctx._state
    if state[child] ~= nil then
        child._halt(child, ctx)
    end
    state[node] = nil
end

-- Public -----------------------------------------------------------------

local Decorator = {}

function Decorator.invert(child: Node): Node
    return table.freeze({
        _kind = "decorator",
        _name = "Invert",
        _tick = tickInvert,
        _halt = haltChild,
        _children = { child },
    }) :: any
end

function Decorator.succeed(child: Node): Node
    return table.freeze({
        _kind = "decorator",
        _name = "Succeed",
        _tick = tickSucceed,
        _halt = haltChild,
        _children = { child },
    }) :: any
end

function Decorator.fail(child: Node): Node
    return table.freeze({
        _kind = "decorator",
        _name = "Fail",
        _tick = tickFail,
        _halt = haltChild,
        _children = { child },
    }) :: any
end

function Decorator.loop(child: Node, times: number?): Node
    return table.freeze({
        _kind = "decorator",
        _name = if times then `Loop({times})` else "Loop",
        _tick = tickLoop,
        _halt = haltChild,
        _children = { child },
        _times = times,
    }) :: any
end

function Decorator.cooldown(child: Node, seconds: number): Node
    return table.freeze({
        _kind = "decorator",
        _name = `Cooldown({seconds}s)`,
        _tick = tickCooldown,
        _halt = haltChild,
        _children = { child },
        _seconds = seconds,
    }) :: any
end

function Decorator.timeout(child: Node, seconds: number): Node
    return table.freeze({
        _kind = "decorator",
        _name = `Timeout({seconds}s)`,
        _tick = tickTimeout,
        _halt = haltChild,
        _children = { child },
        _seconds = seconds,
    }) :: any
end

function Decorator.retry(child: Node, times: number): Node
    return table.freeze({
        _kind = "decorator",
        _name = `Retry({times})`,
        _tick = tickRetry,
        _halt = haltChild,
        _children = { child },
        _times = times,
    }) :: any
end

function Decorator.guard(gate: Node, child: Node): Node
    return table.freeze({
        _kind = "decorator",
        _name = "Guard",
        _tick = tickGuard,
        _halt = haltGuard,
        _children = { gate, child },
    }) :: any
end

return table.freeze(Decorator)
