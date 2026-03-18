--!strict
--!optimize 2
-- Tick-rate managed runner that drives a tree via RunService.Heartbeat.

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Runner = Types.Runner
type RunnerConfig = Types.RunnerConfig
type Status = Types.Status
type Tree = Types.Tree

-- Constants -----------------------------------------------------------

local DEFAULT_TICK_RATE = 20
local RUNNING: Status = 3

-- Public --------------------------------------------------------------

local Runner = {}

function Runner.create(tree: Tree, ctx: Context, config: RunnerConfig?): Runner
    local tickRate = DEFAULT_TICK_RATE
    local onComplete: ((Status) -> ())? = nil
    if config then
        if config.tickRate then
            tickRate = config.tickRate :: number
        end
        onComplete = config.onComplete
    end

    local interval = 1 / tickRate
    local accumulator = 0
    local paused = false
    local connection: RBXScriptConnection? = nil
    local treeTick = tree.tick

    local runner = {} :: any

    function runner.start(_self: Runner): ()
        if connection then
            return
        end
        accumulator = 0
        connection = RunService.Heartbeat:Connect(function(dt: number): ()
            if paused then
                return
            end
            accumulator += dt
            ctx._elapsed = dt
            while accumulator >= interval do
                accumulator -= interval
                local status = treeTick(tree, ctx)
                if status ~= RUNNING then
                    if onComplete then
                        (onComplete :: any)(status)
                    end
                    runner:stop()
                    return
                end
            end
        end)
    end

    function runner.stop(_self: Runner): ()
        if connection then
            (connection :: RBXScriptConnection):Disconnect()
            connection = nil
        end
        accumulator = 0
    end

    function runner.pause(_self: Runner): ()
        paused = true
    end

    function runner.resume(_self: Runner): ()
        paused = false
    end

    return table.freeze(runner)
end

return table.freeze(Runner)
