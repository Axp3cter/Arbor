--!strict
--!optimize 2
-- Shared node metatable, constructor, and decorator implementations.

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants --------------------------------------------------------------

local clock = os.clock

-- Metatable --------------------------------------------------------------

local NodeMT = {}
NodeMT.__index = NodeMT

-- Constructor ------------------------------------------------------------

local function make(fields: { [string]: any }): Node
    return table.freeze(setmetatable(fields, NodeMT)) :: any
end

-- Shared halt ------------------------------------------------------------

local function haltSingleChild(node: Node, ctx: Context): ()
    local child = (node :: any)._child :: Node
    child._halt(child, ctx)
    ctx._state[node] = nil
end

local function haltNoop(_node: Node, _ctx: Context): () end

-- Invert -----------------------------------------------------------------

local function tickInvert(node: Node, ctx: Context): Status
    local child = (node :: any)._child :: Node
    local result = child._tick(child, ctx)
    if result == "success" then
        return "failure"
    end
    if result == "failure" then
        return "success"
    end
    return "running"
end

-- Always -----------------------------------------------------------------

local function tickAlways(node: Node, ctx: Context): Status
    local child = (node :: any)._child :: Node
    local forced = (node :: any)._forced :: Status
    local result = child._tick(child, ctx)
    if result == "running" then
        return "running"
    end
    return forced
end

-- Loop -------------------------------------------------------------------

local function tickLoop(node: Node, ctx: Context): Status
    local child = (node :: any)._child :: Node
    local times = (node :: any)._times :: number?
    local state = ctx._state

    if times then
        local count = (state[node] :: number?) or 0
        for _ = count + 1, times do
            local result = child._tick(child, ctx)
            if result == "running" then
                state[node] = count
                return "running"
            end
            if result == "failure" then
                state[node] = nil
                return "failure"
            end
            count += 1
        end
        state[node] = nil
        return "success"
    end

    -- Infinite: tick once per frame, yield on success to prevent spin.
    local result = child._tick(child, ctx)
    if result == "failure" then
        return "failure"
    end
    return "running"
end

-- Cooldown ---------------------------------------------------------------

local function tickCooldown(node: Node, ctx: Context): Status
    local child = (node :: any)._child :: Node
    local seconds = (node :: any)._seconds :: number
    local state = ctx._state
    local now = clock()

    local lastSuccess = state[node] :: number?
    if lastSuccess then
        if now - lastSuccess < seconds then
            return "failure"
        end
        state[node] = nil
    end

    local result = child._tick(child, ctx)
    if result == "success" then
        state[node] = now
    end
    return result
end

-- Timestamp must survive halts — cooldown is a rate limiter.
local function haltCooldown(node: Node, ctx: Context): ()
    local child = (node :: any)._child :: Node
    child._halt(child, ctx)
end

-- Timeout ----------------------------------------------------------------

local function tickTimeout(node: Node, ctx: Context): Status
    local child = (node :: any)._child :: Node
    local seconds = (node :: any)._seconds :: number
    local state = ctx._state
    local now = clock()

    local startTime = state[node] :: number?
    if not startTime then
        state[node] = now
    elseif now - startTime >= seconds then
        child._halt(child, ctx)
        state[node] = nil
        return "failure"
    end

    local result = child._tick(child, ctx)
    if result ~= "running" then
        state[node] = nil
    end
    return result
end

-- Retry ------------------------------------------------------------------

-- Halts child between attempts so composites and phased actions reset.
local function tickRetry(node: Node, ctx: Context): Status
    local child = (node :: any)._child :: Node
    local times = (node :: any)._times :: number
    local state = ctx._state

    local attempts = (state[node] :: number?) or 0
    local result = child._tick(child, ctx)

    if result == "success" then
        state[node] = nil
        return "success"
    end
    if result == "running" then
        return "running"
    end

    child._halt(child, ctx)
    attempts += 1
    if attempts >= times then
        state[node] = nil
        return "failure"
    end

    state[node] = attempts
    return "running"
end

-- Guard ------------------------------------------------------------------

local function tickGuard(node: Node, ctx: Context): Status
    local child = (node :: any)._child :: Node
    local check = (node :: any)._check :: (unknown) -> boolean
    local state = ctx._state

    if not check(ctx.board) then
        -- Only halt if child was actually running.
        if state[node] then
            child._halt(child, ctx)
            state[node] = nil
        end
        return "failure"
    end

    local result = child._tick(child, ctx)
    state[node] = if result == "running" then true else nil
    return result
end

local function haltGuard(node: Node, ctx: Context): ()
    local state = ctx._state
    if state[node] then
        local child = (node :: any)._child :: Node
        child._halt(child, ctx)
        state[node] = nil
    end
end

-- Tag --------------------------------------------------------------------

local function tickTag(node: Node, ctx: Context): Status
    local child = (node :: any)._child :: Node
    return child._tick(child, ctx)
end

-- Serve ------------------------------------------------------------------

local function tickServed(node: Node, ctx: Context): Status
    local polls = (node :: any)._polls :: { Node }
    for i = 1, #polls do
        local poll = polls[i]
        poll._tick(poll, ctx)
    end
    local child = (node :: any)._child :: Node
    return child._tick(child, ctx)
end

local function haltServed(node: Node, ctx: Context): ()
    local child = (node :: any)._child :: Node
    child._halt(child, ctx)
    local polls = (node :: any)._polls :: { Node }
    for i = 1, #polls do
        local poll = polls[i]
        poll._halt(poll, ctx)
    end
end

-- Decorator methods ------------------------------------------------------

function NodeMT.invert(self: Node): Node
    return make({ _tick = tickInvert, _halt = haltSingleChild, _child = self })
end

function NodeMT.always(self: Node, status: "success" | "failure"): Node
    return make({ _tick = tickAlways, _halt = haltSingleChild, _child = self, _forced = status })
end

function NodeMT.loop(self: Node, count: number?): Node
    return make({ _tick = tickLoop, _halt = haltSingleChild, _child = self, _times = count })
end

function NodeMT.cooldown(self: Node, seconds: number): Node
    return make({ _tick = tickCooldown, _halt = haltCooldown, _child = self, _seconds = seconds })
end

function NodeMT.timeout(self: Node, seconds: number): Node
    return make({ _tick = tickTimeout, _halt = haltSingleChild, _child = self, _seconds = seconds })
end

function NodeMT.retry(self: Node, times: number): Node
    return make({ _tick = tickRetry, _halt = haltSingleChild, _child = self, _times = times })
end

function NodeMT.guard(self: Node, check: (board: unknown) -> boolean): Node
    return make({ _tick = tickGuard, _halt = haltGuard, _child = self, _check = check })
end

function NodeMT.tag(self: Node, name: string): Node
    return make({ _tick = tickTag, _halt = haltSingleChild, _child = self, _tag = name })
end

function NodeMT.serve(self: Node, ...: any): Node
    return make({ _tick = tickServed, _halt = haltServed, _child = self, _polls = { ... } })
end

-- Public -----------------------------------------------------------------

local NodeModule = {}

NodeModule.make = make
NodeModule.haltNoop = haltNoop

return table.freeze(NodeModule)
