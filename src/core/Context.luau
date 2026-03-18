--!strict
--!native
-- Per-agent execution context for behavior tree traversal.

local Types = require(script.Parent.Parent.Types)

type Blackboard = Types.Blackboard
type Context = Types.Context
type Node = Types.Node

-- Public --------------------------------------------------------------

local Context = {}

function Context.create(board: Blackboard, agent: any): Context
    local state: { [any]: any } = {}

    local ctx: any = {
        board = board,
        agent = agent,
        _state = state,
        _elapsed = 0,
    }

    function ctx.getState(_self: Context, node: any): any?
        return state[node]
    end

    function ctx.setState(_self: Context, node: any, data: any): ()
        state[node] = data
    end

    function ctx.clearState(_self: Context, node: any): ()
        state[node] = nil
    end

    function ctx.halt(_self: Context, node: Node): ()
        -- Only call the node's own halt. The node's halt is responsible
        -- for halting its own children. No recursive walk here — that
        -- caused double-halt of onHalted callbacks.
        node._halt(node, ctx)
    end

    return ctx
end

return table.freeze(Context)
