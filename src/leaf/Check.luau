--!strict
--!optimize 2
-- Boolean condition leaf. Returns "success" or "failure", never "running".

local Types = require(script.Parent.Parent.Types)
local Node  = require(script.Parent.Parent.core.Node)

type Context = Types.Context
type Node    = Types.Node
type Status  = Types.Status

local function tick(node: Node, ctx: Context): Status
    local predicate = (node :: any)._predicate :: (unknown) -> boolean
    return if predicate(ctx.board) then "success" else "failure"
end

local Check = {}

function Check.create(predicate: (board: unknown) -> boolean): Node
    return Node.make({ _tick = tick, _halt = Node.haltNoop, _predicate = predicate })
end

return table.freeze(Check)
