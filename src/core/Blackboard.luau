--!strict
--!optimize 2
-- Blackboard.luau — Reactive proxy blackboard with direct field access.

local Types = require(script.Parent.Parent.Types)

type BoardData = Types.BoardData
type BoardObserver = Types.BoardObserver

-- Constants --------------------------------------------------------------

local clone = table.clone
local find = table.find

-- Private ----------------------------------------------------------------

local _boardData: { [any]: BoardData } = setmetatable({}, { __mode = "k" }) :: any

local function fireObservers(data: BoardData, key: string, new: any, old: any): ()
    local list = data._observers[key]
    if not list then
        return
    end

    local snapshot = clone(list)
    for i = 1, #snapshot do
        snapshot[i](new, old)
    end
end

-- Public -----------------------------------------------------------------

local Blackboard = {}

function Blackboard.create(defaults: { [string]: any }): any
    local fields: { [string]: any } = {}
    local defaultsCopy: { [string]: any } = {}

    for key, value in defaults do
        fields[key] = value
        defaultsCopy[key] = value
    end
    table.freeze(defaultsCopy)

    local data: BoardData = {
        _fields = fields,
        _defaults = defaultsCopy,
        _observers = {},
    }

    local proxy = setmetatable({}, {
        __index = function(_self: any, key: string): any
            return fields[key]
        end,

        __newindex = function(_self: any, key: string, value: any): ()
            local old = fields[key]
            if old == value then
                return
            end
            fields[key] = value
            fireObservers(data, key, value, old)
        end,

        __iter = function(_self: any): () -> (string?, any)
            return next :: any, fields
        end,

        __len = function(): number
            local count = 0
            for _ in fields do
                count += 1
            end
            return count
        end,

        __metatable = "Arbor.Board",
    })

    _boardData[proxy] = data
    return proxy
end

function Blackboard.getData(board: any): BoardData
    return _boardData[board]
end

function Blackboard.subscribe(board: any, key: string, callback: BoardObserver): () -> ()
    local data = Blackboard.getData(board)
    local list = data._observers[key]
    if not list then
        list = {}
        data._observers[key] = list
    end
    list[#list + 1] = callback

    local disconnected = false
    return function(): ()
        if disconnected then
            return
        end
        disconnected = true
        local idx = find(list, callback)
        if idx then
            local last = #list
            list[idx] = list[last]
            list[last] = nil :: any
        end
    end
end

function Blackboard.snapshot(board: any): { [string]: any }
    local data = Blackboard.getData(board)
    local copy: { [string]: any } = {}
    for key, value in data._fields do
        copy[key] = value
    end
    return table.freeze(copy)
end

function Blackboard.reset(board: any): ()
    local data = Blackboard.getData(board)
    for key, value in data._defaults do
        local old = data._fields[key]
        if old ~= value then
            data._fields[key] = value
            fireObservers(data, key, value, old)
        end
    end
end

return table.freeze(Blackboard)
