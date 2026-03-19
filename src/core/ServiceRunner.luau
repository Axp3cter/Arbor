--!strict
--!optimize 2
-- ServiceRunner.luau — Shared service tick/halt logic for composite nodes.

local Types = require(script.Parent.Parent.Types)

type Context = Types.Context
type ServiceDef = Types.ServiceDef

-- Constants --------------------------------------------------------------

local clock = os.clock

-- Public -----------------------------------------------------------------

local ServiceRunner = {}

function ServiceRunner.tick(services: { ServiceDef }, ctx: Context): ()
    local state = ctx._state
    local now = clock()
    for i = 1, #services do
        local svc = services[i]
        local last = state[svc] :: number?
        if not last or (now - last) >= svc._interval then
            state[svc] = now
            svc._updater(ctx.board, ctx.agent)
        end
    end
end

function ServiceRunner.halt(services: { ServiceDef }, ctx: Context): ()
    local state = ctx._state
    for i = 1, #services do
        state[services[i]] = nil
    end
end

return table.freeze(ServiceRunner)
