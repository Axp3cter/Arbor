// Type declarations for roblox-ts.

// -- Status ----------------------------------------------------------------

export type Status = "success" | "failure" | "running";

// -- Core interfaces -------------------------------------------------------

/** Opaque behavior tree node. Supports chained decorator methods. */
export interface Node {
    /** @hidden @deprecated */
    readonly _nominal_Node: unique symbol;

    /** Flip Success ↔ Failure. Running passes through. */
    invert(this: Node): Node;

    /** Force a specific terminal status. Running passes through. */
    always(this: Node, status: "success" | "failure"): Node;

    /** Repeat child. Counted: up to N times, yields on running. Infinite: once per tick, yields on success. Stops on failure. */
    loop(this: Node, count?: number): Node;

    /** Rate limiter. Child can only succeed once per N seconds. Timestamp survives branch-level halts but is cleared by stop/destroy. */
    cooldown(this: Node, seconds: number): Node;

    /** Fail if child is still running after N seconds (wall clock). */
    timeout(this: Node, seconds: number): Node;

    /** Retry child on failure up to N additional attempts. Halts child between attempts. */
    retry(this: Node, times: number): Node;

    /** Re-check condition every tick before ticking child. Halts child if check fails. */
    guard(this: Node, check: (this: void, board: defined) => boolean): Node;

    /** Limits how often the child is evaluated. Returns the cached result while fresh. Running children pass through every tick. Cache survives branch-level halts. */
    throttle(this: Node, seconds: number): Node;

    /** Attach a debug name to this node. */
    tag(this: Node, name: string): Node;

    /** Attach periodic poll services scoped to this node's lifecycle. */
    serve(this: Node, ...polls: Node[]): Node;
}

/**
 * Three-phase action lifecycle. At least one of enter or tick must be provided.
 * enter and tick receive (board, agent, dt). halt receives (board, agent).
 */
export interface ActionDef<B = defined, A = defined> {
    /** First tick after entering this action. */
    enter?: (this: void, board: B, agent: A, dt: number) => Status;

    /** Every tick while running (after enter). */
    tick?: (this: void, board: B, agent: A, dt: number) => Status;

    /** Cleanup hook when interrupted while running. Does not receive dt. */
    halt?: (this: void, board: B, agent: A) => void;
}

/** Per-agent execution context. */
export interface Context {
    /** @hidden @deprecated */
    readonly _nominal_Context: unique symbol;

    readonly board: defined;
    readonly agent: defined;

    /** Current frame delta time. Set before each tick. */
    readonly dt: number;

    /** Tick the tree once. Returns the root status. dt defaults to 0. Always pass it for time-based nodes. */
    tick(this: Context, dt?: number): Status;

    /** Start ticking via RunService.Heartbeat. Rate > 0 uses fixed timestep. Rate 0 or omitted uses frame dt. */
    start(this: Context, tickRate?: number): void;

    /** Stop the runner. Halts all running nodes, clears all state including cooldown timers. */
    stop(this: Context): void;

    /** Full teardown. Idempotent. After this, tick() returns "failure". */
    destroy(this: Context): void;

    /** Whether the managed runner is active. */
    isRunning(this: Context): boolean;
}

/** Single node's state from bt.snapshot(). Fields beyond the base set are kind-specific. */
export interface SnapshotEntry {
    kind: string;
    tag?: string;
    depth: number;
    active: boolean;
    [key: string]: unknown;
}

// -- Main namespace --------------------------------------------------------

declare namespace bt {
    // Type re-exports
    export type { Node, Context, ActionDef, Status, SnapshotEntry };

    // -- Leaves ----------------------------------------------------------------

    /** Boolean condition. Returns "success" or "failure", never "running". Predicate receives (board). */
    export function check<B = defined>(
        predicate: (this: void, board: B) => boolean,
    ): Node;

    /** Action with a simple handler that fires every tick. Handler receives (board, agent, dt). */
    export function action<B = defined, A = defined>(
        handler: (this: void, board: B, agent: A, dt: number) => Status,
    ): Node;

    /** Action with phased lifecycle. At least one of enter or tick required. */
    export function action<B = defined, A = defined>(
        phases: ActionDef<B, A>,
    ): Node;

    /** Returns "running" for N seconds (accumulated via dt, tracks simulation time), then "success". */
    export function wait(seconds: number): Node;

    /** Periodic updater. Fires on a wall-clock interval (os.clock), independent of tick rate. Always "success". */
    export function poll<B = defined, A = defined>(
        interval: number,
        updater: (this: void, board: B, agent: A) => void,
    ): Node;

    /** Waits for a signal to fire once, then returns "success". Manages the connection lifecycle automatically. Disconnects on halt or completion. */
    export function event(signal: RBXScriptSignal): Node;

    // -- Composites ------------------------------------------------------------

    /** Selector. Re-evaluates from child 1 every tick for priority checking. */
    export function select(children: ReadonlyArray<Node>): Node;

    /** Sequence. Resumes from the last running child (sticky). */
    export function sequence(children: ReadonlyArray<Node>): Node;

    /**
     * Parallel. Curried: `bt.parallel(succeed)(children)`.
     * Ticks all children. Resolves when succeed or fail threshold is met.
     * Both thresholds must be > 0 and ≤ child count.
     * @param succeed How many children must succeed.
     * @param fail How many must fail. Defaults to child count.
     */
    export function parallel(
        succeed: number,
        fail?: number,
    ): (children: ReadonlyArray<Node>) => Node;

    /** Random. Picks one child at random, sticks with it until resolved. */
    export function random(
        children: ReadonlyArray<Node>,
        weights?: ReadonlyArray<number>,
    ): Node;

    // -- Context ---------------------------------------------------------------

    /** Create a context without starting a runner. Use ctx.tick(dt) manually. */
    export function bind(
        root: Node,
        board: defined,
        agent: defined,
    ): Context;

    /** Create a context and start ticking. Rate > 0 uses fixed timestep. Rate 0 or omitted uses frame dt. */
    export function run(
        root: Node,
        board: defined,
        agent: defined,
        tickRate?: number,
    ): Context;

    /** Returns a flat list of every node with its kind, config, and current interpreted state. Plain data. */
    export function snapshot(ctx: Context): Array<SnapshotEntry>;
}

export default bt;
