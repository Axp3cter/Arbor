--!strict
--!optimize 2
-- Arbor — Composable, typed behavior trees for Roblox AI.

-- Node
local Action    = require(script.node.Action)
local Condition = require(script.node.Condition)
local Decorator = require(script.node.Decorator)
local Observer  = require(script.node.Observer)
local Parallel  = require(script.node.Parallel)
local Random    = require(script.node.Random)
local Selector  = require(script.node.Selector)
local Sequence  = require(script.node.Sequence)
local Service   = require(script.node.Service)
local Wait      = require(script.node.Wait)

-- Core
local Blackboard = require(script.core.Blackboard)
local Context    = require(script.core.Context)

-- Types
local Types = require(script.Types)

export type Abort = Types.Abort
export type ActionPhases = Types.ActionPhases
export type CompositeConfig = Types.CompositeConfig
export type ConditionNode = Types.ConditionNode
export type Context = Types.Context
export type Node = Types.Node
export type ParallelConfig = Types.ParallelConfig
export type ServiceDef = Types.ServiceDef
export type Status = Types.Status

-- Enums ------------------------------------------------------------------

local Status = table.freeze({
    Success = 1,
    Failure = 2,
    Running = 3,
})

local Abort = table.freeze({
    Self    = 1,
    Lower   = 2,
    Restart = 3,
})

-- Public -----------------------------------------------------------------

local Arbor = {

    -- Enums
    Status = Status,
    Abort  = Abort,

    -- Blackboard
    board    = Blackboard.create,
    watch    = Blackboard.subscribe,
    snapshot = Blackboard.snapshot,

    -- Context
    context = Context.create,

    -- Leaf nodes
    condition = Condition.create,
    action    = Action.create,
    wait      = Wait.create,

    -- Composites
    sequence = Sequence.create,
    selector = Selector.create,
    parallel = Parallel.create,
    random   = Random.create,

    -- Observer
    observe = Observer.create,

    -- Decorators
    invert   = Decorator.invert,
    succeed  = Decorator.succeed,
    fail     = Decorator.fail,
    loop     = Decorator.loop,
    cooldown = Decorator.cooldown,
    timeout  = Decorator.timeout,
    retry    = Decorator.retry,
    guard    = Decorator.guard,

    -- Service
    service = Service.create,
}

Arbor.default = Arbor
return table.freeze(Arbor)
