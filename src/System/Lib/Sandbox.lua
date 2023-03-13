local api = {}

local function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy

    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]

        else
            copy = {}
            copies[orig] = copy

            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
            end
            setmetatable(copy, deepcopy(getmetatable(orig), copies))
        end

    else -- number, string, boolean, etc
        copy = orig
    end

    return copy
end

local blacklist = {
    component = true, computer = true, devices=true, service=true,
  }

api.create_env = function(base)
    checkArg(1, base, "table", "nil")

    local new = deepcopy(base or _G)
    for key in pairs(blacklist) do new[key] = nil end

    new.load = function(a, b, c, d)
        return k.load(a, b, c, d or k.current_process().env)
    end

    local yield = new.coroutine.yield
    new.coroutine.yield = function(request, ...)
        local proc = k.current_process()
        local last_yield = proc.last_yield or computer.uptime()

        if request == "syscall" then
            if computer.uptime() - last_yield > 3 then
                coroutine.yield(k.sysyield_string)
                proc.last_yield = computer.uptime()
            end

            return k.perform_system_call(...)
        end

        proc.last_yield = computer.uptime()
        return yield(request, ...)
    end

    if new.coroutine.resume == coroutine.resume then
        local resume = new.coroutine.resume

        function new.coroutine.resume(co, ...)
            local result
            repeat
                result = table.pack(resume(co, ...))
                if result[2] == k.sysyield_string then
                    yield(k.sysyield_string)
                end
            until result[2] ~= k.sysyield_string or not result[1]

            return table.unpack(result, 1, result.n)
        end
    end

    return new
end