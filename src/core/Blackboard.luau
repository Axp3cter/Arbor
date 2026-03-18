--!strict
--!native
-- Typed blackboard with observer-driven change notifications.

local Types = require(script.Parent.Parent.Types)

type Blackboard = Types.Blackboard
type BlackboardObserver = Types.BlackboardObserver
type Connection = Types.Connection

-- Public --------------------------------------------------------------

local Blackboard = {}

function Blackboard.create(defaults: { [string]: any }): Blackboard
    local fields: { [string]: any } = {}
    local defaultsCopy: { [string]: any } = {}
    local observers: { [string]: { BlackboardObserver } } = {}

    for k, v in defaults do
        fields[k] = v
        defaultsCopy[k] = v
    end
    table.freeze(defaultsCopy)

    local board = {} :: any

    function board.get(_self: Blackboard, key: string): any
        return fields[key]
    end

    function board.set(_self: Blackboard, key: string, value: any): ()
        local old = fields[key]
        if old == value then
            return
        end
        fields[key] = value
        local list = observers[key]
        if list then
            for i = 1, #list do
                list[i](value, old)
            end
        end
    end

    function board.observe(_self: Blackboard, key: string, callback: BlackboardObserver): Connection
        local list = observers[key]
        if not list then
            list = {}
            observers[key] = list
        end
        list[#list + 1] = callback
        local connected = true
        local conn: Connection
        conn = {
            connected = true,
            disconnect = function(_c: Connection): ()
                if not connected then
                    return
                end
                connected = false
                conn.connected = false
                local idx = table.find(list, callback)
                if idx then
                    table.remove(list, idx)
                end
            end,
        }
        return conn
    end

    function board.reset(_self: Blackboard): ()
        for k, v in defaultsCopy do
            board:set(k, v)
        end
    end

    return table.freeze(board)
end

return table.freeze(Blackboard)
