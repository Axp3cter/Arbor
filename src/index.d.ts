// Arbor v2 — Type declarations for roblox-ts.

// -- Enums -----------------------------------------------------------------

/** Status returned by every node tick. */
export const enum Status {
	Success = 1,
	Failure = 2,
	Running = 3,
}

/** Abort mode for observer decorators. */
export const enum Abort {
	Self = 1,
	Lower = 2,
	Restart = 3,
}

// -- Utility ---------------------------------------------------------------

type Prettify<T> = { [K in keyof T]: T[K] } & {};

// -- Core interfaces -------------------------------------------------------

/**
 * Reactive proxy blackboard. Read and write fields directly.
 * Writes fire observer callbacks when the value changes.
 */
export type Board<T extends Record<string, defined> = Record<string, defined>> = {
	-readonly [K in keyof T]: T[K];
} & {
	/** @hidden @deprecated */
	readonly _nominal_Board: unique symbol;
};

/** Opaque behavior tree node. Created by factory functions, composed into trees. */
export interface Node {
	/** @hidden @deprecated */
	readonly _nominal_Node: unique symbol;
}

/** Condition node with optional watch keys. Required by observe(). */
export interface ConditionNode extends Node {
	/** @hidden @deprecated */
	readonly _nominal_ConditionNode: unique symbol;
}

/** Opaque service definition. Attach to composites via config. */
export interface ServiceDef {
	/** @hidden @deprecated */
	readonly _nominal_ServiceDef: unique symbol;
}

/** Per-agent execution context. Stores running state, owns the runner lifecycle. */
export interface Context<T extends Record<string, defined> = Record<string, defined>> {
	/** @hidden @deprecated */
	readonly _nominal_Context: unique symbol;

	readonly board: Board<T>;
	readonly agent: defined;

	/** Tick the tree once. Returns the root node's status. */
	tick(this: Context<T>): Status;

	/** Start ticking at N Hz via RunService.Heartbeat. Omit tickRate for every frame. */
	start(this: Context<T>, tickRate?: number): void;

	/** Stop the managed runner. Does not clean up observers or halt nodes. */
	stop(this: Context<T>): void;

	/**
	 * Full cleanup. Stops runner, halts all running nodes, unregisters all
	 * observer callbacks. After destroy(), tick() and start() are no-ops.
	 */
	destroy(this: Context<T>): void;

	/** Whether the managed runner is currently active. */
	isRunning(this: Context<T>): boolean;
}

// -- Config interfaces -----------------------------------------------------

/** Three-phase action lifecycle. */
export interface ActionPhases<T extends Record<string, defined> = Record<string, defined>> {
	/** First tick after entering this action. */
	start: (this: void, board: Board<T>, agent: defined) => Status;

	/** Every subsequent tick while Status.Running. */
	tick: (this: void, board: Board<T>, agent: defined) => Status;

	/** Cleanup hook when the action is interrupted. No return value. */
	halt?: (this: void, board: Board<T>, agent: defined) => void;
}

/** Optional config for sequence and selector composites. */
export interface CompositeConfig {
	/** Re-evaluate from child 0 every tick instead of resuming from running child. */
	reactive?: boolean;

	/** Periodic updaters that run while this composite is active. */
	services?: ReadonlyArray<ServiceDef>;
}

/** Required config for parallel composites. */
export interface ParallelConfig {
	/** Succeed after N children succeed. Default: all children. */
	succeed?: number;

	/** Fail after N children fail. Default: 1. */
	fail?: number;

	/** Periodic updaters that run while this parallel is active. */
	services?: ReadonlyArray<ServiceDef>;
}

// -- Main namespace --------------------------------------------------------

declare namespace Arbor {
	export const VERSION: string;

	// Enums
	export const Status: {
		readonly Success: Status.Success;
		readonly Failure: Status.Failure;
		readonly Running: Status.Running;
	};

	export const Abort: {
		readonly Self: Abort.Self;
		readonly Lower: Abort.Lower;
		readonly Restart: Abort.Restart;
	};

	// Type re-exports
	export type {
		Board,
		Node,
		ConditionNode,
		Context,
		ServiceDef,
		ActionPhases,
		CompositeConfig,
		ParallelConfig,
	};

	// -- Blackboard ------------------------------------------------------------

	/** Create a reactive proxy blackboard from default values. */
	export function board<T extends Record<string, defined>>(
		defaults: T,
	): Board<Prettify<T>>;

	/** Subscribe to changes on a specific blackboard key. Returns an unsubscribe function. */
	export function watch<T extends Record<string, defined>, K extends keyof T & string>(
		board: Board<T>,
		key: K,
		callback: (this: void, newValue: T[K], oldValue: T[K]) => void,
	): () => void;

	/** Returns a frozen, non-reactive shallow copy of the blackboard. */
	export function snapshot<T extends Record<string, defined>>(
		board: Board<T>,
	): Readonly<T>;

	// -- Context ---------------------------------------------------------------

	/** Create a per-agent execution context. One tree structure, many contexts. */
	export function context<T extends Record<string, defined>>(
		root: Node,
		board: Board<T>,
		agent: defined,
	): Context<T>;

	// -- Leaf nodes ------------------------------------------------------------

	/** Pure boolean gate. Returns Success or Failure. Never Running. */
	export function condition<T extends Record<string, defined> = Record<string, defined>>(
		name: string,
		predicate: (this: void, board: Board<T>) => boolean,
		watchKeys?: ReadonlyArray<keyof T & string>,
	): ConditionNode;

	/** Action with a simple handler that fires every tick while active. */
	export function action<T extends Record<string, defined> = Record<string, defined>>(
		name: string,
		handler: (this: void, board: Board<T>, agent: defined) => Status,
	): Node;

	/** Action with three-phase lifecycle: start, tick, halt. */
	export function action<T extends Record<string, defined> = Record<string, defined>>(
		name: string,
		phases: ActionPhases<T>,
	): Node;

	/** Pure delay. Returns Running for N seconds, then Success. */
	export function wait(seconds: number): Node;

	// -- Composites ------------------------------------------------------------

	/** Run children left-to-right. Fails on first failure. Memory mode by default. */
	export function sequence(
		children: ReadonlyArray<Node>,
		config?: CompositeConfig,
	): Node;

	/** Run children left-to-right. Succeeds on first success. Memory mode by default. */
	export function selector(
		children: ReadonlyArray<Node>,
		config?: CompositeConfig,
	): Node;

	/** Tick all children. Resolves based on numeric success/failure policies. */
	export function parallel(
		children: ReadonlyArray<Node>,
		config: ParallelConfig,
	): Node;

	/** Pick one child at random. Sticky while Running. Optional relative weights. */
	export function random(
		children: ReadonlyArray<Node>,
		weights?: ReadonlyArray<number>,
	): Node;

	// -- Observer --------------------------------------------------------------

	/** Watch blackboard keys via a condition and trigger aborts on change. */
	export function observe(
		gate: ConditionNode,
		abort: Abort,
		child: Node,
	): Node;

	// -- Decorators ------------------------------------------------------------

	/** Flip Success ↔ Failure. Running passes through. */
	export function invert(child: Node): Node;

	/** Force Success. Swallows Failure. Running passes through. */
	export function succeed(child: Node): Node;

	/** Force Failure. Swallows Success. Running passes through. */
	export function fail(child: Node): Node;

	/**
	 * Repeat child N times. Failure always propagates as Failure.
	 * Omit count for infinite loop (terminates only on Failure).
	 */
	export function loop(child: Node, count?: number): Node;

	/** Gate: child can only succeed once per N seconds. Returns Failure during cooldown. */
	export function cooldown(child: Node, seconds: number): Node;

	/** Fail if child is still Running after N seconds. */
	export function timeout(child: Node, seconds: number): Node;

	/** Retry child on Failure up to N additional attempts. */
	export function retry(child: Node, times: number): Node;

	/**
	 * Synchronous gate: re-checks condition every tick before ticking child.
	 * Does not register blackboard observers. Use observe() for reactive gating.
	 */
	export function guard(gate: ConditionNode, child: Node): Node;

	// -- Service ---------------------------------------------------------------

	/** Create a periodic blackboard updater. Attach to composites via config.services. */
	export function service<T extends Record<string, defined> = Record<string, defined>>(
		name: string,
		interval: number,
		updater: (this: void, board: Board<T>, agent: defined) => void,
	): ServiceDef;
}

export default Arbor;
