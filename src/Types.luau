--!strict
--!optimize 2
-- Shared type definitions for Arbor.

export type Status = number
export type AbortMode = number
export type Policy = number

export type Connection = {
    disconnect: (self: Connection) -> (),
    connected: boolean,
}

export type BlackboardObserver = (newValue: any, oldValue: any) -> ()

export type Blackboard = {
    get: (self: Blackboard, key: string) -> any,
    set: (self: Blackboard, key: string, value: any) -> (),
    observe: (self: Blackboard, key: string, callback: BlackboardObserver) -> Connection,
    reset: (self: Blackboard) -> (),
}

export type ServiceDef = {
    _interval: number,
    _updater: (board: Blackboard, agent: any) -> (),
}

export type Node = {
    _kind: string,
    _name: string,
    _tick: (node: Node, ctx: Context) -> Status,
    _halt: (node: Node, ctx: Context) -> (),
    _children: { Node }?,
    _services: { ServiceDef }?,
}

export type Context = {
    board: Blackboard,
    agent: any,
    _state: { [any]: any },
    _elapsed: number,
    getState: (self: Context, node: any) -> any?,
    setState: (self: Context, node: any, data: any) -> (),
    clearState: (self: Context, node: any) -> (),
    halt: (self: Context, node: Node) -> (),
}

export type ActionCallbacks = {
    onStart: (board: Blackboard, agent: any) -> Status,
    onRunning: (board: Blackboard, agent: any) -> Status,
    onHalted: ((board: Blackboard, agent: any) -> ())?,
}

export type ParallelConfig = {
    successPolicy: Policy,
    failurePolicy: Policy,
}

export type RepeatConfig = { times: number }
export type CooldownConfig = { seconds: number }
export type TimeoutConfig = { seconds: number }
export type RetryConfig = { times: number }
export type ServiceConfig = { interval: number }

export type Tree = {
    tick: (self: Tree, ctx: Context) -> Status,
}

export type RunnerConfig = {
    tickRate: number?,
    onComplete: ((status: Status) -> ())?,
}

export type Runner = {
    start: (self: Runner) -> (),
    stop: (self: Runner) -> (),
    pause: (self: Runner) -> (),
    resume: (self: Runner) -> (),
}

return nil
