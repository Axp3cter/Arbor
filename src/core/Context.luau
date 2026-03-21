--!strict
--!optimize 2
-- Per-agent execution context with integrated runner.

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants --------------------------------------------------------------

-- Cap catch-up ticks to prevent spiral-of-death after lag spikes.
local MAX_CATCHUP = 4

-- Metatable --------------------------------------------------------------

local ContextMT = {}
ContextMT.__index = ContextMT

function ContextMT.tick(self: Context, dt: number?): Status
    if self._destroyed then
        return "failure"
    end
    self.dt = dt or 0
    local root = self._root
    return root._tick(root, self)
end

function ContextMT.start(self: Context, tickRate: number?): ()
    if self._destroyed then
        return
    end
    if self._connection then
        return
    end

    local rate = tickRate or 0

    if rate > 0 then
        local interval = 1 / rate
        local maxAccum = interval * MAX_CATCHUP
        local accumulator = 0

        self._connection = RunService.Heartbeat:Connect(function(dt: number): ()
            if self._destroyed then
                return
            end

            accumulator += dt
            if accumulator > maxAccum then
                accumulator = maxAccum
            end

            while accumulator >= interval do
                accumulator -= interval
                self.dt = interval
                local root = self._root
                root._tick(root, self)
            end
        end)
    else
        self._connection = RunService.Heartbeat:Connect(function(dt: number): ()
            if self._destroyed then
                return
            end
            self.dt = dt
            local root = self._root
            root._tick(root, self)
        end)
    end
end

function ContextMT.stop(self: Context): ()
    local conn = self._connection
    if conn then
        conn:Disconnect()
        self._connection = nil
    end

    local root = self._root
    root._halt(root, self)
    table.clear(self._state)
end

function ContextMT.destroy(self: Context): ()
    if self._destroyed then
        return
    end
    self._destroyed = true
    self:stop()
end

function ContextMT.isRunning(self: Context): boolean
    return self._connection ~= nil and not self._destroyed
end

-- Public -----------------------------------------------------------------

local Context = {}

function Context.create(root: Node, board: unknown, agent: unknown): Context
    return setmetatable({
        board = board,
        agent = agent,
        dt = 0,
        _root = root,
        _state = {},
        _destroyed = false,
        _connection = nil :: RBXScriptConnection?,
    }, ContextMT) :: any
end

return table.freeze(Context)
