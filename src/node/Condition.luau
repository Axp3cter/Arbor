--!strict
--!optimize 2
-- Condition.luau — Pure boolean gate. Never returns RUNNING.

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status

-- Constants --------------------------------------------------------------

local SUCCESS: Status = 1
local FAILURE: Status = 2

-- Private ----------------------------------------------------------------

local function tick(node: Node, ctx: Context): Status
    local predicate = (node :: any)._predicate :: (board: any) -> boolean
    return if predicate(ctx.board) then SUCCESS else FAILURE
end

local function halt(_node: Node, _ctx: Context): () end

-- Public -----------------------------------------------------------------

local Condition = {}

function Condition.create(
    name: string,
    predicate: (board: any) -> boolean,
    watchKeys: { string }?
): Node
    return table.freeze({
        _kind = "condition",
        _name = name,
        _tick = tick,
        _halt = halt,
        _predicate = predicate,
        _watchKeys = watchKeys,
    }) :: any
end

return table.freeze(Condition)
