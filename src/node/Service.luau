--!strict
--!optimize 2
-- Service.luau — Periodic blackboard updater attached to composite nodes.

local Types = require(script.Parent.Parent.Types)

type ServiceDef = Types.ServiceDef

-- Public -----------------------------------------------------------------

local Service = {}

function Service.create(
    name: string,
    interval: number,
    updater: (board: any, agent: any) -> ()
): ServiceDef
    return table.freeze({
        _name = name,
        _interval = interval,
        _updater = updater,
    })
end

return table.freeze(Service)
