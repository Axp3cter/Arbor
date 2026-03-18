--!strict
--!native
-- Periodic blackboard updater attached to composite nodes at creation time.

local Types = require(script.Parent.Parent.Types)

type Blackboard = Types.Blackboard
type ServiceConfig = Types.ServiceConfig
type ServiceDef = Types.ServiceDef

-- Public --------------------------------------------------------------

local Service = {}

function Service.create(
    config: ServiceConfig,
    updater: (board: Blackboard, agent: any) -> ()
): ServiceDef
    return table.freeze({
        _interval = config.interval,
        _updater = updater,
    })
end

return table.freeze(Service)
