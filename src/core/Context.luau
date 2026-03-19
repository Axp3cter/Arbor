--!strict
--!optimize 2
-- Context.luau — Per-agent execution context with integrated runner lifecycle.

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)

type Abort = Types.Abort
type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants --------------------------------------------------------------

local FAILURE: Status = 2
local ABORT_RESTART: Abort = 3

-- Shared metatable -------------------------------------------------------

local ContextMethods = {}
ContextMethods.__index = ContextMethods

function ContextMethods.getState(self: Context, node: any): any?
    return self._state[node]
end

function ContextMethods.setState(self: Context, node: any, data: any): ()
    self._state[node] = data
end

function ContextMethods.clearState(self: Context, node: any): ()
    self._state[node] = nil
end

function ContextMethods.haltNode(self: Context, node: Node): ()
    node._halt(node, self)
end

function ContextMethods.tick(self: Context): Status
    if self._destroyed then return FAILURE end

    local root = self._root
    local abortMode = self._pendingAbort

    if abortMode then
        self._pendingAbort = nil
        root._halt(root, self)

        if abortMode == ABORT_RESTART then
            return root._tick(root, self)
        end

        return FAILURE
    end

    return root._tick(root, self)
end

function ContextMethods.start(self: Context, tickRate: number?): ()
    if self._destroyed then return end
    if self._connection then return end

    -- Hoist tick to local. Captured as LCT_VAL (never reassigned).
    -- Avoids NAMECALL metatable resolution on every Heartbeat frame.
    local tick = self.tick

    local rate = tickRate or 0
    if rate > 0 then
        local interval = 1 / rate
        local accumulator = 0
        self._connection = RunService.Heartbeat:Connect(function(dt: number): ()
            if self._destroyed then return end
            accumulator += dt
            self._elapsed = dt
            while accumulator >= interval do
                accumulator -= interval
                tick(self)
            end
        end)
    else
        self._connection = RunService.Heartbeat:Connect(function(dt: number): ()
            if self._destroyed then return end
            self._elapsed = dt
            tick(self)
        end)
    end
end

function ContextMethods.stop(self: Context): ()
    local conn = self._connection
    if conn then
        conn:Disconnect()
        self._connection = nil
    end
end

function ContextMethods.destroy(self: Context): ()
    if self._destroyed then return end
    self._destroyed = true

    self:stop()

    local root = self._root
    root._halt(root, self)

    local cleanups = self._observerCleanups
    for i = 1, #cleanups do
        cleanups[i]()
    end
    table.clear(cleanups)

    table.clear(self._state)
end

function ContextMethods.isRunning(self: Context): boolean
    return self._connection ~= nil and not self._destroyed
end

-- Public -----------------------------------------------------------------

local Context = {}

function Context.create(root: Node, board: any, agent: any): Context
    return setmetatable({
        board = board,
        agent = agent,
        _root = root,
        _state = {},
        _elapsed = 0,
        _destroyed = false,
        _pendingAbort = nil :: Abort?,
        _observerCleanups = {},
        _connection = nil :: RBXScriptConnection?,
    }, ContextMethods) :: any
end

return table.freeze(Context)
