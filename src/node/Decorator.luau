--!strict
--!native
-- Decorator nodes that wrap and modify a single child's behavior.

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type CooldownConfig = Types.CooldownConfig
type Node = Types.Node
type RepeatConfig = Types.RepeatConfig
type RetryConfig = Types.RetryConfig
type Status = Types.Status
type TimeoutConfig = Types.TimeoutConfig

-- Constants -----------------------------------------------------------

local SUCCESS: Status = 1
local FAILURE: Status = 2
local RUNNING: Status = 3

-- Private -------------------------------------------------------------

local function haltChild(node: Node, ctx: Context): ()
    local child = (node._children :: { Node })[1]
    if ctx:getState(child) ~= nil then
        ctx:halt(child)
    end
    ctx:clearState(node)
end

-- Invert --------------------------------------------------------------

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

-- Repeat --------------------------------------------------------------

local function tickRepeat(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local times = ((node :: any)._decConfig :: RepeatConfig).times
    local count = (ctx:getState(node) :: number?) or 0
    local status = child._tick(child, ctx)
    if status == RUNNING then
        return RUNNING
    end
    if status == FAILURE then
        ctx:clearState(node)
        return FAILURE
    end
    count += 1
    if count >= times then
        ctx:clearState(node)
        return SUCCESS
    end
    ctx:setState(node, count)
    return RUNNING
end

-- RepeatUntilFail -----------------------------------------------------

local function tickRepeatUntilFail(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    while true do
        local status = child._tick(child, ctx)
        if status == FAILURE then
            ctx:clearState(node)
            return SUCCESS
        end
        if status == RUNNING then
            ctx:setState(node, true)
            return RUNNING
        end
        -- SUCCESS — re-tick immediately in the same frame.
    end
    -- Unreachable but satisfies the type checker.
    return SUCCESS :: any
end

-- Cooldown ------------------------------------------------------------

local function tickCooldown(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local seconds = ((node :: any)._decConfig :: CooldownConfig).seconds
    local remaining = (ctx:getState(node) :: number?) or 0
    if remaining > 0 then
        remaining -= ctx._elapsed
        if remaining > 0 then
            ctx:setState(node, remaining)
            return FAILURE
        end
        ctx:clearState(node)
    end
    local status = child._tick(child, ctx)
    if status == SUCCESS then
        ctx:setState(node, seconds)
    end
    return status
end

-- Timeout -------------------------------------------------------------

local function tickTimeout(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local seconds = ((node :: any)._decConfig :: TimeoutConfig).seconds
    local elapsed = (ctx:getState(node) :: number?) or 0
    elapsed += ctx._elapsed
    if elapsed >= seconds then
        if ctx:getState(child) ~= nil then
            ctx:halt(child)
        end
        ctx:clearState(node)
        return FAILURE
    end
    local status = child._tick(child, ctx)
    if status == RUNNING then
        ctx:setState(node, elapsed)
        return RUNNING
    end
    ctx:clearState(node)
    return status
end

-- Retry ---------------------------------------------------------------

local function tickRetry(node: Node, ctx: Context): Status
    local child = (node._children :: { Node })[1]
    local times = ((node :: any)._decConfig :: RetryConfig).times
    local attempts = (ctx:getState(node) :: number?) or 0
    local status = child._tick(child, ctx)
    if status == SUCCESS then
        ctx:clearState(node)
        return SUCCESS
    end
    if status == RUNNING then
        return RUNNING
    end
    attempts += 1
    if attempts >= times then
        ctx:clearState(node)
        return FAILURE
    end
    ctx:setState(node, attempts)
    return RUNNING
end

-- Guard ---------------------------------------------------------------

local function tickGuard(node: Node, ctx: Context): Status
    local children = node._children :: { Node }
    local condition = children[1]
    local child = children[2]
    if condition._tick(condition, ctx) ~= SUCCESS then
        if ctx:getState(child) ~= nil then
            ctx:halt(child)
        end
        return FAILURE
    end
    return child._tick(child, ctx)
end

local function haltGuard(node: Node, ctx: Context): ()
    local child = (node._children :: { Node })[2]
    if ctx:getState(child) ~= nil then
        ctx:halt(child)
    end
end

-- Public --------------------------------------------------------------

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

function Decorator.rep(child: Node, config: RepeatConfig): Node
    return table.freeze({
        _kind = "decorator",
        _name = "Repeat",
        _tick = tickRepeat,
        _halt = haltChild,
        _children = { child },
        _decConfig = config,
    }) :: any
end

function Decorator.repeatUntilFail(child: Node): Node
    return table.freeze({
        _kind = "decorator",
        _name = "RepeatUntilFail",
        _tick = tickRepeatUntilFail,
        _halt = haltChild,
        _children = { child },
    }) :: any
end

function Decorator.cooldown(child: Node, config: CooldownConfig): Node
    return table.freeze({
        _kind = "decorator",
        _name = "Cooldown",
        _tick = tickCooldown,
        _halt = haltChild,
        _children = { child },
        _decConfig = config,
    }) :: any
end

function Decorator.timeout(child: Node, config: TimeoutConfig): Node
    return table.freeze({
        _kind = "decorator",
        _name = "Timeout",
        _tick = tickTimeout,
        _halt = haltChild,
        _children = { child },
        _decConfig = config,
    }) :: any
end

function Decorator.retry(child: Node, config: RetryConfig): Node
    return table.freeze({
        _kind = "decorator",
        _name = "Retry",
        _tick = tickRetry,
        _halt = haltChild,
        _children = { child },
        _decConfig = config,
    }) :: any
end

function Decorator.guard(condition: Node, child: Node): Node
    return table.freeze({
        _kind = "decorator",
        _name = "Guard",
        _tick = tickGuard,
        _halt = haltGuard,
        _children = { condition, child },
    }) :: any
end

return table.freeze(Decorator)
