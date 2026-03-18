--!strict
--!native
-- Tree wrapper that ticks a root node against a context.

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type Node = Types.Node
type Status = Types.Status
type Tree = Types.Tree

-- Public --------------------------------------------------------------

local Tree = {}

function Tree.create(root: Node): Tree
    local rootTick = root._tick

    local tree = {} :: any

    function tree.tick(_self: Tree, ctx: Context): Status
        return rootTick(root, ctx)
    end

    return table.freeze(tree)
end

return table.freeze(Tree)
