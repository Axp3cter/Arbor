--!strict
--!optimize 2
-- Leaf that waits for a RBXScriptSignal to fire, then succeeds.

local Node = require(script.Parent.Parent.core.Node)
local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

type EventState = {
    connection: RBXScriptConnection,
    fired: boolean,
}

local function tick(node: Node, ctx: Context): Status
    local signal = (node :: any)._signal :: RBXScriptSignal
    local state = ctx._state

    local es = state[node] :: EventState?

    -- Already connected. Check if the signal has fired.
    if es then
        if es.fired then
            state[node] = nil
            return "success"
        end
        return "running"
    end

    -- First tick. Connect and wait.
    local newState: EventState = {
        connection = nil :: any,
        fired = false,
    }
    newState.connection = signal:Connect(function(...)
        newState.fired = true
        newState.connection:Disconnect()
    end)
    state[node] = newState
    return "running"
end

local function halt(node: Node, ctx: Context): ()
    local state = ctx._state
    local es = state[node] :: EventState?
    if not es then
        return
    end

    -- Disconnect if the signal hasn't fired yet (connection still alive).
    if not es.fired then
        es.connection:Disconnect()
    end
    state[node] = nil
end

-- Public --------------------------------------------------------------

local Event = {}

function Event.create(signal: RBXScriptSignal): Node
    return Node.make({ _kind = "event", _tick = tick, _halt = halt, _signal = signal })
end

return table.freeze(Event)
