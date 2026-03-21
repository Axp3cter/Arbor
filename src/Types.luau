--!strict
--!optimize 2
-- Shared type definitions.

export type Status = "success" | "failure" | "running"

export type Node = {
    _tick: (self: Node, ctx: Context) -> Status,
    _halt: (self: Node, ctx: Context) -> (),
    _tag: string?,
    _child: Node?,
    _children: { Node }?,

    invert: (self: Node) -> Node,
    always: (self: Node, status: "success" | "failure") -> Node,
    loop: (self: Node, count: number?) -> Node,
    cooldown: (self: Node, seconds: number) -> Node,
    timeout: (self: Node, seconds: number) -> Node,
    retry: (self: Node, times: number) -> Node,
    guard: (self: Node, check: (board: unknown) -> boolean) -> Node,
    tag: (self: Node, name: string) -> Node,
    serve: (self: Node, ...Node) -> Node,
}

export type Context = {
    board: unknown,
    agent: unknown,
    dt: number,
    _root: Node,
    _state: { [unknown]: unknown },
    _destroyed: boolean,
    _connection: RBXScriptConnection?,

    tick: (self: Context, dt: number?) -> Status,
    start: (self: Context, tickRate: number?) -> (),
    stop: (self: Context) -> (),
    destroy: (self: Context) -> (),
    isRunning: (self: Context) -> boolean,
}

export type ActionDef = {
    enter: ((board: unknown, agent: unknown, dt: number) -> Status)?,
    tick: ((board: unknown, agent: unknown, dt: number) -> Status)?,
    halt: ((board: unknown, agent: unknown) -> ())?,
}

return nil
