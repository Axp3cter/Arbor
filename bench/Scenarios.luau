--!strict
--!optimize 2
-- Scenarios.luau — Data and setup definitions for benchmarks.

local Arbor = require(script.Parent.Parent)

local Status = Arbor.Status

-- Definitions ------------------------------------------------------------

local Scenarios = {}

Scenarios.SimpleCondition = Arbor.condition("AlwaysTrue", function()
    return true
end)

Scenarios.ShallowSequence = Arbor.sequence({
    Arbor.condition("A", function()
        return true
    end),
    Arbor.condition("B", function()
        return true
    end),
    Arbor.condition("C", function()
        return true
    end),
})

Scenarios.DeepSequence = (function()
    local leaf = Arbor.condition("Leaf", function()
        return true
    end)
    local node: Arbor.Node = leaf
    for _ = 1, 20 do
        node = Arbor.sequence({ node })
    end
    return node
end)()

Scenarios.WideSelectorFallthrough = (function()
    local children: { Arbor.Node } = {}
    for i = 1, 50 do
        if i == 50 then
            children[i] = Arbor.condition("Last", function()
                return true
            end)
        else
            children[i] = Arbor.condition(`Fail{i}`, function()
                return false
            end)
        end
    end
    return Arbor.selector(children)
end)()

Scenarios.CombatTree = Arbor.selector({
    Arbor.sequence({
        Arbor.condition("LowHealth", function(b)
            return b.health < 30
        end),
        Arbor.action("Flee", function()
            return Status.Success
        end),
    }),
    Arbor.sequence({
        Arbor.condition("HasTarget", function(b)
            return b.hasTarget == true
        end),
        Arbor.action("Attack", function()
            return Status.Success
        end),
    }),
    Arbor.action("Patrol", function()
        return Status.Success
    end),
})

Scenarios.COMBAT_DEFAULTS = table.freeze({
    health = 80,
    hasTarget = true,
})

return table.freeze(Scenarios)
