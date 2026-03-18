--!strict
--!native
-- Leaf node that evaluates a boolean predicate. Never returns RUNNING.

local Types = require(script.Parent.Parent.Types)

type Blackboard = Types.Blackboard
type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants -----------------------------------------------------------

local SUCCESS: Status = 1
local FAILURE: Status = 2

-- Private -------------------------------------------------------------

local function tick(node: Node, ctx: Context): Status
    local predicate = (node :: any)._fn :: (board: Blackboard, agent: any) -> boolean
    if predicate(ctx.board, ctx.agent) then
        return SUCCESS
    end
    return FAILURE
end

local function halt(_node: Node, _ctx: Context): () end

-- Public --------------------------------------------------------------

local Condition = {}

function Condition.create(name: string, predicate: (board: Blackboard, agent: any) -> boolean): Node
    return table.freeze({
        _kind = "condition",
        _name = name,
        _tick = tick,
        _halt = halt,
        _fn = predicate,
    }) :: any
end

return table.freeze(Condition)
