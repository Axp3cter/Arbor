--!strict
--!optimize 2
-- Public API.

-- Node
local Action = require(script.node.Action)
local Condition = require(script.node.Condition)
local Decorator = require(script.node.Decorator)
local Observer = require(script.node.Observer)
local Parallel = require(script.node.Parallel)
local Selector = require(script.node.Selector)
local Sequence = require(script.node.Sequence)
local Service = require(script.node.Service)

-- Core
local Blackboard = require(script.core.Blackboard)
local Context = require(script.core.Context)
local Runner = require(script.core.Runner)
local Tree = require(script.core.Tree)

-- Type re-exports -----------------------------------------------------

local Types = require(script.Types)

export type Blackboard = Types.Blackboard
export type Connection = Types.Connection
export type Context = Types.Context
export type Node = Types.Node
export type Runner = Types.Runner
export type Status = Types.Status
export type Tree = Types.Tree
export type ActionCallbacks = Types.ActionCallbacks
export type ParallelConfig = Types.ParallelConfig
export type RunnerConfig = Types.RunnerConfig
export type ServiceConfig = Types.ServiceConfig
export type ServiceDef = Types.ServiceDef

-- Constants -----------------------------------------------------------

local SUCCESS: Types.Status = 1
local FAILURE: Types.Status = 2
local RUNNING: Types.Status = 3

-- Public --------------------------------------------------------------

local Arbor = {
    VERSION = "0.0.0",

    -- Status
    SUCCESS = SUCCESS,
    FAILURE = FAILURE,
    RUNNING = RUNNING,

    -- Abort modes
    Abort = table.freeze({
        None = 0,
        Self = 1,
        LowerPriority = 2,
        LowerPriorityImmediateRestart = 3,
    }),

    -- Parallel policies
    Policy = table.freeze({
        RequireOne = 1,
        RequireAll = 2,
    }),

    -- Leaf nodes
    condition = Condition.create,
    action = Action.create,

    -- Composites
    sequence = Sequence.create,
    reactiveSequence = Sequence.createReactive,
    selector = Selector.create,
    reactiveSelector = Selector.createReactive,
    parallel = Parallel.create,

    -- Decorators
    invert = Decorator.invert,
    rep = Decorator.rep,
    repeatUntilFail = Decorator.repeatUntilFail,
    cooldown = Decorator.cooldown,
    timeout = Decorator.timeout,
    retry = Decorator.retry,
    guard = Decorator.guard,

    -- Observer (abort modes)
    observe = Observer.create,

    -- Service
    service = Service.create,

    -- Tree
    tree = Tree.create,

    -- Blackboard
    createBoard = Blackboard.create,

    -- Context
    createContext = Context.create,

    -- Runner
    createRunner = Runner.create,
}

Arbor.default = Arbor
return table.freeze(Arbor)
