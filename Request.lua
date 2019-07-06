Request = class() -- https://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html

function Request:init(msg, client) -- msg == "METHOD PATH HTTP/1.1" (first client receive)
    --print(msg)
    local fields = {}
    for field in string.gmatch(msg, "%S+") do table.insert(fields, field) end
    self.method = fields[1] -- assert method exist
    self.path = fields[2] -- assert path is valid
    
    -- @todo compute headers and body
    self.headers = {}
    while true do
        local msg, err = client:receive('*l')
        --print(msg, err)
        if string.len(msg) == 0 or err then -- end of headers
            break
        end
        
        local header, value = string.match(msg, "([^:]+):%s*([^\r\n]+)")
        self.headers[header] = value
    end
    
    -- @todo check content-type
    local contentLength = self.headers['Content-Length']
    if contentLength then
        self.body = client:receive(contentLength)
    end
    
    self.params = {} -- get all values from msg that begin with : defined by [A-Za-z0-9_]
end

-- function Request:accepts() end
-- function Request:acceptsCharsets() end
-- function Request:acceptsEncoding() end
-- function Request:acceptsLanguages() end
function Request:get(header)
    return self.headers[header]
end
-- function Request:is() end
-- function Request:range() end

local function split(str, sep)
    local sep, fields = sep or ",", {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) table.insert(fields, c) end)
    return fields
end

local function computeParams(req)
    if not req.pattern then return end
    local fields = split(req.path, "/")
    for i,v in ipairs(split(req.pattern, "/")) do
        if v:sub(1,1) == ":" then
            req.params[v:sub(2)] = fields[i]
        else -- @test
            req.params[i] = fields[i]
        end
    end
end

function Request:setPattern(pattern)
    self.pattern = pattern
    computeParams(self)
    return self
end
