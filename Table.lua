Table = {}

local function aux(tbl, indent)
    local acc = ""
    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. (type(k) == "table" and aux(k, indent) or tostring(k)) .. ": "
        if type(v) == "table" then
            acc = acc .. formatting .. "\n" .. aux(v, indent+1)
        else
            acc = acc .. formatting .. tostring(v) .. "\n"
        end
    end
    return acc
end
function Table.toString(tbl) return aux(tbl, 0) end
function Table.print(tbl) print(Table.toString(tbl)) end
function Table.count(tbl)
    local res = 0
    for k,v in pairs(tbl) do
        res = res + 1
    end
    return res
end
function Table.first(tbl) for k,v in pairs(tbl) do return v end end
function Table.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Table.deepcopy(orig_key)] = Table.deepcopy(orig_value)
        end
        setmetatable(copy, Table.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function Table.contains(tbl, e)
    for _,v in pairs(tbl) do
        if v == e then return true end
    end
    return false
end

function Table.containsKey(tbl, key)
    for k,_ in pairs(tbl) do
        if k == key then return true end
    end
    return false
end
