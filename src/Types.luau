--!strict
-- Types.luau — Shared type definitions for Arbor. No runtime code.

export type Status = number
export type Abort = number

export type BoardObserver = (newValue: any, oldValue: any) -> ()

export type BoardData = {
    _fields: { [string]: any },
    _defaults: { [string]: any },
    _observers: { [string]: { BoardObserver } },
}

export type ServiceDef = {
    _name: string,
    _interval: number,
    _updater: (board: any, agent: any) -> (),
}

export type Node = {
    _kind: string,
    _name: string,
    _tick: (node: Node, ctx: Context) -> Status,
    _halt: (node: Node, ctx: Context) -> (),
    _children: { Node }?,
    _services: { ServiceDef }?,
}

export type ConditionNode = Node & {
    _predicate: (board: any) -> boolean,
    _watchKeys: { string }?,
}

export type ActionPhases = {
    start: (board: any, agent: any) -> Status,
    tick: (board: any, agent: any) -> Status,
    halt: ((board: any, agent: any) -> ())?,
}

export type CompositeConfig = {
    reactive: boolean?,
    services: { ServiceDef }?,
}

export type ParallelConfig = {
    succeed: number?,
    fail: number?,
    services: { ServiceDef }?,
}

export type Context = {
    board: any,
    agent: any,
    _root: Node,
    _state: { [any]: any },
    _elapsed: number,
    _destroyed: boolean,
    _pendingAbort: Abort?,
    _observerCleanups: { () -> () },
    _connection: RBXScriptConnection?,
    getState: (self: Context, node: any) -> any?,
    setState: (self: Context, node: any, data: any) -> (),
    clearState: (self: Context, node: any) -> (),
    haltNode: (self: Context, node: Node) -> (),
    tick: (self: Context) -> Status,
    start: (self: Context, tickRate: number?) -> (),
    stop: (self: Context) -> (),
    destroy: (self: Context) -> (),
    isRunning: (self: Context) -> boolean,
}

return nil
