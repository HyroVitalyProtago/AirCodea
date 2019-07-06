express = class() -- expressjs.com

local socket = require "socket"

-- define methods functions shortcuts sugar on express
local methods = { "checkout", "copy", "delete", "get", "head", "lock", "merge", "mkactivity", "mkcol", "move", "m-search", "notify", "options", "patch", "post", "purge", "put", "report", "search", "subscribe", "trace", "unlock", "unsubscribe"}
for _,method in pairs(methods) do
    local methodUpper = method:upper()
    express[method] = function(self, path, callback)
        self.callbacks[methodUpper][path] = callback
    end
end

function express.getIp() -- because getsockname doesn't work directly, this function bypass it
    local sock = socket.udp()
    sock:setpeername("192.168.0.1", "9999")
    local ip = sock:getsockname()
    sock:close()
    return ip
end

function express:init()--middleware)
    self.connections = {} -- [port] = {sock=socket, co=coroutine}
    self.callbacks = {} -- [method][pattern] = callback(request, response, next)
    for _,method in pairs(methods) do
        self.callbacks[method:upper()] = {}
    end
    self.allCallbacks = {} -- contains callbacks defined by app:all() (works with all requested methods)
    self.backlog = 5 -- number of client waiting queued
    self.timeout = 0 -- non-blocking accept
end
function express:update()
    for port,connection in pairs(self.connections) do
        coroutine.resume(connection.co)
    end
end
function express:dispose() -- close all open ports
    for port,_ in pairs(self.connections) do
        self:close(port)
    end
end
function express:close(port)
    if not self.connections[port] then
        error("can't close the not binded port "..port)
    end
    
    self.connections[port].sock:close()
    self.connections[port] = nil
end
--function express:all(url, callback) end
--function express:disable(property) end
--function express:disabled(property) end
--function express:enable(property) end
--function express:enabled(property) end
--function express:engine() end

function express:listen(port, callback)
    if self.connections[port] then
        error("the port "..port.." is already binded...")
    end
    
    local sock = assert(socket.tcp())
    assert(sock:bind("*", port))
    sock:listen(self.backlog)
    sock:settimeout(self.timeout)
    
    local this = self
    local pendingRequests = {} -- list of coroutines that run handle client function
    
    -- coroutine to handle a client request
    local handleClient = function(client)
        return coroutine.create(function()
            client:settimeout(0)
            
            -- sometimes, the message is not received when the client is accepted
            -- so we read the socket until safeguard times is reached, in case of the message will be received
            -- if even after that the message can't be received, the server send a 503 error (Service Unavailable)
            -- and the client must retry to send the command

            local safeguard = 2 -- seconds max to handle the request
            local t0 = os.clock()
            repeat
                local msg, err = client:receive('*l')
                if not err then this:receive(msg, client) end
                coroutine.yield()
            until not err or err == 'closed' or os.clock()-t0 >= safeguard
                    
            if os.clock()-t0 >= safeguard then
                print("Error happened while getting the connection: ",err,select(3, client:receive('*a')))
                Response(client):status(503):send('Please retry...')
            end
        end)
    end
    
    -- coroutine to handle clients
    local co = coroutine.create(function()
        while true do
            local client, err = sock:accept()
            if client then
                table.insert(pendingRequests, 1, handleClient(client))
            end

            -- handle other pending clients requests
            -- when coroutine is ended, remove it from handlers (so loop through handlers in back order)
            for i=#pendingRequests,1,-1 do
                coroutine.resume(pendingRequests[i])
                if coroutine.status(pendingRequests[i]) == 'dead' then
                    table.remove(pendingRequests, i)
                end
            end
            
            coroutine.yield()
        end
    end)
    
    self.connections[port] = {sock=sock,co=co}
    
    if callback then callback() end
end

--function express:path() end
--function express:render() end
--function express:route(url) end
--function express:set(property, enabled) end
--function express:use(middleware) end
--function express:on(event, callback) end

local function match(path, pattern)
    local ptrn = pattern:gsub(':[A-Za-z0-9_]+', '[A-Za-z0-9_]+')
    return string.match(path, ptrn) == path
end

-- internal
function express:receive(msg, client)
    local request = Request(msg, client)
    local response = Response(client)
    local t = self.callbacks[request.method]
    local tAll = self.allCallbacks
    local function nextCallback(k)
        return function()
            -- send callback for method request that match pattern
            for pattern, callback in next, t, k do
                if match(request.path, pattern) then
                    return callback(request:setPattern(pattern), response, nextCallback(pattern))
                end
            end
            
            -- send callback for ALL request that match pattern
            --[[for pattern, callback in next, tAll, k do
                if match(request.path, pattern) then
                    return callback(request:setPattern(pattern), response, nextCallback(pattern))
                end
            end]]--
        
            -- if nothing match, send 404
            response:status(404):send('404 Not Found') -- @todo 404 template
        end
    end
    nextCallback(nil)() -- first callback
end
