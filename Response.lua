Response = class() -- https://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6

local STATUS = {
    -- 1xx Informational
    [100] = "Continue",
    [101] = "Switching Protocols",
    -- 2xx Success
    [200] = "OK",
    [201] = "Created",
    [202] = "Accepted",
    [203] = "Non-Authoritative Information",
    [204] = "No Content",
    [205] = "Reset Content",
    [206] = "Partial Content",
    -- 3xx Redirection
    [300] = "Multiple Choices",
    [301] = "Moved Permanently",
    [302] = "Found",
    [303] = "See Other",
    [304] = "Not Modified",
    [305] = "Use Proxy",
    [307] = "Temporary Redirect",
    -- 4xx Client Error
    [400] = "Bad Request",
    [401] = "Unauthorized",
    [402] = "Payment Required",
    [403] = "Forbidden",
    [404] = "Not Found",
    [405] = "Method Not Allowed",
    [406] = "Not Acceptable",
    [407] = "Proxy Authentication Required",
    [408] = "Request Time-out",
    [409] = "Conflict",
    [410] = "Gone",
    [411] = "Length Required",
    [412] = "Precondition Failed",
    [413] = "Request Entity Too Large",
    [414] = "Request-URI Too Large",
    [415] = "Unsupported Media Type",
    [416] = "Requested range not satisfiable",
    [417] = "Expectation Failed",
    -- 5xx Server Error
    [500] = "Internal Server Error",
    [501] = "Not Implemented",
    [502] = "Bad Gateway",
    [503] = "Service Unavailable",
    [504] = "Gateway Time-out",
    [505] = "HTTP Version not supported"
}

function Response.headerFormat(response)
    local ret = 'HTTP/1.1 ' .. response.statusCode .. ' ' .. STATUS[response.statusCode] .. '\n' -- status-line
    for header, value in pairs(response.headers) do -- headers
        ret = ret .. header .. ': ' .. value .. '\n'
    end
    ret = ret .. '\n'
    return ret
end

function Response:init(client)
    self.statusCode = 200
    self.headers = {
        ['Content-Type'] = 'text/html'
        -- Content-Length
        -- Accept-Ranges
        -- Age
        -- ETag
        -- Location
        -- Proxy-Authenticate
        -- Retry-After
        -- Server
        -- Vary
        -- WWW-Authenticate
    }
    self.client = client
end

-- function Response:append() end
-- function Response:attachment() end
-- function Response:cookie() end
-- function Response:clearCookie() end
-- function Response:download() end
-- function Response:end() end
-- function Response:format() end
-- function Response:get() end
function Response:json(value)
    self.headers['Content-Type'] = 'application/json'
    self:send(json.encode(value))
end
-- function Response:jsonp() end
-- function Response:links() end
-- function Response:location() end
-- function Response:redirect() end
-- function Response:render() end
function Response:send(value)
    self.client:send(Response.headerFormat(self) .. (value or ''))
    self.client:close()
    self.client = nil
end
-- function Response:sendFile() end
-- function Response:sendStatus() end
function Response:set(field, value)
    self.headers[field] = value
    return self
end
function Response:status(code)
    self.statusCode = code -- assert code exist
    return self
end
-- function Response:type() end
-- function Response:vary() end