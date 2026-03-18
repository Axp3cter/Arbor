// Type declarations for Arbor.

// -- Utility types -----------------------------------------------------

type Prettify<T> = { [K in keyof T]: T[K] } & {};

// -- Enums -------------------------------------------------------------

/** Status returned by every node tick. */
export const enum Status {
	SUCCESS = 1,
	FAILURE = 2,
	RUNNING = 3,
}

/** Abort mode for observer decorators. */
export const enum AbortMode {
	None = 0,
	Self = 1,
	LowerPriority = 2,
	LowerPriorityImmediateRestart = 3,
}

/** Success/failure policy for parallel composites. */
export const enum Policy {
	RequireOne = 1,
	RequireAll = 2,
}

// -- Core interfaces ---------------------------------------------------

/** Disconnectable subscription handle. */
export interface Connection {
	disconnect(this: Connection): void;
	connected: boolean;
}

/** Typed shared memory for an agent. Observers fire on value changes. */
export interface Blackboard<T extends Record<string, defined> = Record<string, defined>> {
	/** @hidden @deprecated */
	readonly _nominal_Blackboard: T;

	/** Read a value by key. Return type is inferred from the board schema. */
	get<K extends keyof T>(this: Blackboard<T>, key: K): T[K];

	/** Write a value by key. Fires observers if the value changed. */
	set<K extends keyof T>(this: Blackboard<T>, key: K, value: T[K]): void;

	/** Subscribe to changes on a specific key. Returns a disconnectable handle. */
	observe<K extends keyof T>(
		this: Blackboard<T>,
		key: K,
		callback: (this: void, newValue: T[K], oldValue: T[K]) => void,
	): Connection;

	/** Reset all fields to their initial defaults. Fires observers for changed fields. */
	reset(this: Blackboard<T>): void;
}

/** Opaque behavior tree node. Created by factory functions, composed into trees. */
export interface Node {
	/** @hidden @deprecated */
	readonly _nominal_Node: unique symbol;
}

/** Per-agent execution context. Stores running state across ticks. */
export interface Context<T extends Record<string, defined> = Record<string, defined>> {
	/** @hidden @deprecated */
	readonly _nominal_Context: T;

	readonly board: Blackboard<T>;
	readonly agent: defined;

	getState(this: Context<T>, node: Node): defined | undefined;
	setState(this: Context<T>, node: Node, data: defined): void;
	clearState(this: Context<T>, node: Node): void;
	halt(this: Context<T>, node: Node): void;
}

/** Tickable tree wrapping a root node. */
export interface Tree {
	/** @hidden @deprecated */
	readonly _nominal_Tree: unique symbol;

	/** Tick the tree once against a context. Returns the root node's status. */
	tick(this: Tree, ctx: Context): Status;
}

/** Tick-rate managed runner driven by RunService.Heartbeat. */
export interface Runner {
	/** @hidden @deprecated */
	readonly _nominal_Runner: unique symbol;

	start(this: Runner): void;
	stop(this: Runner): void;
	pause(this: Runner): void;
	resume(this: Runner): void;
}

// -- Config interfaces -------------------------------------------------

/** Three-phase async action callbacks. */
export interface ActionCallbacks<T extends Record<string, defined> = Record<string, defined>> {
	/** Called on the first tick. Return RUNNING to continue, or SUCCESS/FAILURE to complete. */
	onStart: (this: void, board: Blackboard<T>, agent: defined) => Status;

	/** Called on subsequent ticks while the action is RUNNING. */
	onRunning: (this: void, board: Blackboard<T>, agent: defined) => Status;

	/** Called when the action is aborted mid-execution. Use for cleanup. */
	onHalted?: (this: void, board: Blackboard<T>, agent: defined) => void;
}

/** Configuration for parallel composite nodes. */
export interface ParallelConfig {
	/** How many children must succeed for the parallel to succeed. */
	successPolicy: Policy;

	/** How many children must fail for the parallel to fail. */
	failurePolicy: Policy;
}

/** Configuration for the tick-rate runner. */
export interface RunnerConfig {
	/** Ticks per second. Defaults to 20. */
	tickRate?: number;

	/** Called when the tree completes with SUCCESS or FAILURE. */
	onComplete?: (this: void, status: Status) => void;
}

/** Configuration for a periodic service. */
export interface ServiceConfig {
	/** Interval in seconds between service updates. */
	interval: number;
}

/** Opaque service definition. Attach to composites at creation time. */
export interface ServiceDef {
	/** @hidden @deprecated */
	readonly _nominal_ServiceDef: unique symbol;
}

export interface RepeatConfig {
	/** Number of successful iterations before propagating SUCCESS. */
	times: number;
}

export interface CooldownConfig {
	/** Seconds after a SUCCESS before the child can be ticked again. */
	seconds: number;
}

export interface TimeoutConfig {
	/** Seconds before a RUNNING child is forcibly halted with FAILURE. */
	seconds: number;
}

export interface RetryConfig {
	/** Maximum retry attempts on FAILURE before propagating FAILURE. */
	times: number;
}

// -- Main namespace ----------------------------------------------------

declare namespace Arbor {
	export const VERSION: string;

	// Status
	export const SUCCESS: Status.SUCCESS;
	export const FAILURE: Status.FAILURE;
	export const RUNNING: Status.RUNNING;

	// Abort modes
	export const Abort: {
		readonly None: AbortMode.None;
		readonly Self: AbortMode.Self;
		readonly LowerPriority: AbortMode.LowerPriority;
		readonly LowerPriorityImmediateRestart: AbortMode.LowerPriorityImmediateRestart;
	};

	// Parallel policies
	const _Policy: {
		readonly RequireOne: Policy.RequireOne;
		readonly RequireAll: Policy.RequireAll;
	};
	export { _Policy as Policy };

	// Type re-exports
	export type {
		Connection,
		Blackboard,
		Node,
		Context,
		Tree,
		Runner,
		ActionCallbacks,
		ParallelConfig,
		RunnerConfig,
		ServiceConfig,
		ServiceDef,
		RepeatConfig,
		CooldownConfig,
		TimeoutConfig,
		RetryConfig,
	};

	// -- Leaf nodes --------------------------------------------------------

	/** Create a condition node. Pure boolean check — never returns RUNNING. */
	export function condition<T extends Record<string, defined> = Record<string, defined>>(
		name: string,
		predicate: (this: void, board: Blackboard<T>, agent: defined) => boolean,
	): Node;

	/** Create an action node with a simple tick function. */
	export function action<T extends Record<string, defined> = Record<string, defined>>(
		name: string,
		handler: (this: void, board: Blackboard<T>, agent: defined) => Status,
	): Node;

	/** Create an action node with three-phase async callbacks. */
	export function action<T extends Record<string, defined> = Record<string, defined>>(
		name: string,
		callbacks: ActionCallbacks<T>,
	): Node;

	// -- Composites --------------------------------------------------------

	/** Run children left-to-right. Fails on first failure. Resumes from running child. */
	export function sequence(children: ReadonlyArray<Node>, services?: ReadonlyArray<ServiceDef>): Node;

	/** Like sequence, but re-evaluates from child 0 every tick. */
	export function reactiveSequence(
		children: ReadonlyArray<Node>,
		services?: ReadonlyArray<ServiceDef>,
	): Node;

	/** Run children left-to-right. Succeeds on first success. Resumes from running child. */
	export function selector(children: ReadonlyArray<Node>, services?: ReadonlyArray<ServiceDef>): Node;

	/** Like selector, but re-evaluates from child 0 every tick. */
	export function reactiveSelector(
		children: ReadonlyArray<Node>,
		services?: ReadonlyArray<ServiceDef>,
	): Node;

	/** Tick all children concurrently. Outcome determined by success/failure policies. */
	export function parallel(config: ParallelConfig, children: ReadonlyArray<Node>): Node;

	// -- Decorators --------------------------------------------------------

	/** Flip SUCCESS ↔ FAILURE. RUNNING passes through. */
	export function invert(child: Node): Node;

	/** Repeat child N times before propagating SUCCESS. Fails immediately on child FAILURE. */
	export function rep(child: Node, config: RepeatConfig): Node;

	/** Loop child until it returns FAILURE, then return SUCCESS. */
	export function repeatUntilFail(child: Node): Node;

	/** Gate: child can only succeed once per N seconds. Returns FAILURE during cooldown. */
	export function cooldown(child: Node, config: CooldownConfig): Node;

	/** Fail if child is still RUNNING after N seconds. */
	export function timeout(child: Node, config: TimeoutConfig): Node;

	/** Retry child on FAILURE up to N times. Returns FAILURE after exhausting retries. */
	export function retry(child: Node, config: RetryConfig): Node;

	/** Only tick child when condition returns SUCCESS. Halts child if condition flips. */
	export function guard(cond: Node, child: Node): Node;

	// -- Observer ----------------------------------------------------------

	/** Watch blackboard keys and react to changes with abort modes. */
	export function observe<T extends Record<string, defined> = Record<string, defined>>(
		name: string,
		predicate: (this: void, board: Blackboard<T>, agent: defined) => boolean,
		abortMode: AbortMode,
		keys: ReadonlyArray<keyof T & string>,
		child: Node,
	): Node;

	// -- Service -----------------------------------------------------------

	/** Create a periodic blackboard updater. Attach to composites at creation time. */
	export function service<T extends Record<string, defined> = Record<string, defined>>(
		config: ServiceConfig,
		updater: (this: void, board: Blackboard<T>, agent: defined) => void,
	): ServiceDef;

	// -- Core --------------------------------------------------------------

	/** Wrap a root node into a tickable tree. */
	export function tree(root: Node): Tree;

	/** Create a typed blackboard with default values. */
	export function createBoard<T extends Record<string, defined>>(defaults: T): Blackboard<Prettify<T>>;

	/** Create a per-agent execution context. One tree, many contexts. */
	export function createContext<T extends Record<string, defined>>(
		board: Blackboard<T>,
		agent: defined,
	): Context<T>;

	/** Create a tick-rate managed runner. Connects to RunService.Heartbeat. */
	export function createRunner(tree: Tree, ctx: Context, config?: RunnerConfig): Runner;
}

export default Arbor;
