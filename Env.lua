local function findenv(f)
    local level = 1
    repeat
        local name, value = debug.getupvalue(f, level)
        if name == '_ENV' then
            return level, value
        end
        level = level + 1
    until name == nil
    return nil
end
function getfenv(f)
    return(select(2, findenv(f)) or _G)
end
function setfenv(f, t)
    local level = findenv(f)
    if level then
        debug.setupvalue(f, level, t)
    end
    return f
end