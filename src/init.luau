--!strict
--!optimize 2
-- Composable, typed behavior trees for Roblox.

local Action = require(script.leaf.Action)
local Check = require(script.leaf.Check)
local Poll = require(script.leaf.Poll)
local Wait = require(script.leaf.Wait)

local Parallel = require(script.composite.Parallel)
local Random = require(script.composite.Random)
local Select = require(script.composite.Select)
local Sequence = require(script.composite.Sequence)

local Context = require(script.core.Context)

local Types = require(script.Types)

export type ActionDef = Types.ActionDef
export type Context = Types.Context
export type Node = Types.Node
export type Status = Types.Status

-- Public -----------------------------------------------------------------

local bt = {
    check = Check.create,
    action = Action.create,
    wait = Wait.create,
    poll = Poll.create,
    select = Select.create,
    sequence = Sequence.create,
    parallel = Parallel.create,
    random = Random.create,
    bind = Context.create,
}

function bt.run(root: Types.Node, board: unknown, agent: unknown, tickRate: number?): Types.Context
    local ctx = Context.create(root, board, agent)
    ctx:start(tickRate)
    return ctx
end
(bt :: any).default = bt

return table.freeze(bt)
