-- AirCodea

-- @todo good tabs order on client
-- @todo change tab order
-- @todo tab scroll when there is a lot of tabs
-- @todo works on project name that contains ' ', '-', '&/, ...
-- @todo client projects view (with images!)
-- @todo new/delete project on client

-- @todo show/hide play/pause buttons in function of codea update callback
-- @todo replace monaco editor with codemirror editor

-- @todo+ codea features : error location in file, hints for methods parameters, intelligent autocompletion, sprite panel, color picker, lua+codea docs
-- @todo+ client "go to definition" & "find all references" if not available in lua (github.com/Microsoft/monaco-editor/issues/291)
-- @todo+ version control system (git, github, gist, ...)

-- @todo go to file shortcut
-- @todo console send command from client
-- @todo client todo panel (search all @todo and go on click)

-- @todo highlight draw if code line is inspected
-- @todo highlight code if draw is inspected

-- @todo pause = recursive immutability on objects to allow it on projects without update and only draw functions ???
-- (@todo+ authentication ?)
-- @todo plugins for AirCodea client

-- @todo move the view in edit mode ?
-- @todo translate/rotate/scale objects in edit mode

-- setup package for require
-- package.path = package.path .. ";" .. os.getenv('HOME') .. '/Documents/' .. 'AirCodea' .. '.codea/?.lua'

local clientState = readLocalData('clientState', {
    play = true,
    pause = false,
    autoplay = true,
    autosave = false
})

-- return if a tab exist for a specified project
local function hasTab(project, tab) return hasProject(project) and Table.contains(listProjectTabs(project), tab) end

--local websocketCoroutine
local events = {} -- {type="ping", data="something"} -- need type or data
local function sendEvent(evt) table.insert(events, evt) end
local eventStreamCoroutine

local currentIp -- the current ip address of the server
local currentProject -- name of current project
local projectEnv -- env for current project to continue update server in background
local projectCache = {} -- ordered array of { name, content }, used when autosave is disabled
-- return status (bool: project successfully started), err (string: error if project can't start)
local function startProject(project, noSetup)
    local env
    if project == currentProject then -- restart the same project with the same environnement
        env = projectEnv
    else
        collectgarbage() -- free all unused memory allocated by AirCodea or old project started
        currentProject = project
        env = setmetatable({}, { -- probably induce latency, cache _G call ? fill env with _G before AirCodea project load ?
            __index = function(t,k)
                -- @todo protect all globals from AirCodea
                if k == "setup" or k == "draw" or k == "touched" or k == "update" then
                    return nil
                end
                if k == "restart" then -- @todo better override restart function
                    return function()
                        collectgarbage()
                        t.setup()
                    end
                end
                if k == "print" then
                    return function(...)
                        sendEvent({ type='print', data=json.encode({...}) })
                    end
                end
                -- @todo override listProjectTabs, ...
                return _G[k]
            end
        })    
    end
    
    -- @todo only reload modified code
    -- @todo if not clientState.autosave, load from cached project
    -- @todo set filename of call inside something....
    return pcall(function()
        local loadedTabs = {}
        if not clientState.autosave then
            for _,tab in ipairs(projectCache) do
                loadedTabs[tab.name] = true
                local f = assert(loadstring(tab.content))
                f = setfenv(f, env) -- set another environnement on function
                f()
            end
        end
        
        local tabs = listProjectTabs(project)
        for _,tab in pairs(tabs) do
            if not loadedTabs[tab] then
                local f = assert(loadstring(readProjectTab(project .. ':' .. tab)))
                f = setfenv(f, env) -- set another environnement on function
                f()
            end
        end
        -- collectgarbage() -- free all unused memory allocated by AirCodea or old project started
        if env.setup and not noSetup then env.setup() end
        projectEnv = env
    end)
end
local function stopCurrentProject()
    if currentProject == nil then return end
    currentProject = nil
    projectEnv = nil
    projectCache = {}
    collectgarbage()
end

local app -- (PS: server run at the project framerate, try to keep it up, it can also induce lags on request)
function setup()
    -- WARNING sometimes, there is some problems with readProjectTab
    
    displayMode(FULLSCREEN)
    
    -- @todo load files locally to enable AirCodea without internet
    -- projectData
    -- fontawesome.css : https://use.fontawesome.com/releases/v5.7.0/css/all.css
    -- https://unpkg.com/monaco-editor@0.16.1/min/vs/loader.js
    -- https://unpkg.com/monaco-editor@0.16.1/min/vs
    
    --[[
    http.request("http://use.fontawesome.com/releases/v5.7.0/webfonts/fa-solid-900.woff2", function(data, status, head)
        saveText("Project:fa-solid-900.woff2",data)
        print('saved')
    end, print)
    ]]--
    
    app = express()
    parameter.action("Close", function() app:dispose();close() end)
    
    --[[
    app:get('/static', function(req, res) return res:json(listProjectData()) end)
    app:get('/static/.*', function(req, res)
        local content = readText('Project:'..req.params[2])
        if content then
            -- @todo type depending on extension...
            return res:set('Content-Type', 'text/css; charset=utf-8'):send(content)
        end
        res:status(404):send('404 Not Found')
    end)
    ]]--
    
    -- ---------------------------------------------------------------------------------------------------
    -- Events from Server to Client
    -- ---------------------------------------------------------------------------------------------------
    
    app:get('/events', function(req, res) -- EventSource: send data from server to client
        -- mime: text/event-stream
        -- content\n\n
        -- string that begin with ':' is a comment -- can be used to keep connection alive
        -- key:value
        -- key can be event, data, id, retry
        -- @todo if multiline data string, break up per \n with 'data:' at the beginning (client will receive as one string)
        res:set('Content-Type', 'text/event-stream')
        res.client:send(res.headerFormat(res) .. '\n')
        
        local counter = 0
        eventStreamCoroutine = coroutine.create(function()
            while true do
                counter = counter + DeltaTime
                if counter > 10 then -- every 10 seconds, send a comment packet to keep connection alive
                    res.client:send(':keep alive\n\n')
                    counter = 0
                end
                while #events > 0 do
                    local evt = table.remove(events, 1) -- pop
                    assert(evt.type or evt.data)
                    local msg = ''
                    if evt.type then msg = msg .. 'event:'..evt.type..'\n' end
                    if evt.data then msg = msg .. 'data:'..evt.data..'\n' end
                    res.client:send(msg..'\n')
                end
                coroutine.yield()
            end
        end)
    end)
    
    -- ---------------------------------------------------------------------------------------------------
    -- FRONT
    -- ---------------------------------------------------------------------------------------------------
    
    -- @todo projects page
    app:get('/', function(req, res)
        stopCurrentProject()
        
        local projects = '<ul>'
        for i,projectName in ipairs(listProjects('Documents')) do
            -- remove the Documents or Example or Craft and the ':' before the project name
            -- local project = projectName:sub(projectName:find(':')+1, projectName:len()) 
            projects = projects..'<li><a href="/project/'..projectName..'">'..projectName..'</a></li>'
        end
        projects = projects..'</ul>'
        
        res:send([[<!DOCTYPE html>
            <head>
                <title>AirCodea - Projects</title>
                <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
            </head>
            <body>
                <h1>Codea projects</h1>
                <h3>For now, doesn't work with projects that contains ' ', '-', '&' and some others special chars</h3>
                <h3>You also need an internet connection to open a project because some css/js are not cached at this time...</h3>
                <p>You can play/pause your project, but you need to have an update callback function in order to use this functionnality</p>
                <p></p>
                ]] .. projects .. [[
            </body>
        </html>]])
    end)
    
    app:get('/project/:project', function(req, res)
        if not hasProject(req.params.project) then
            res:status(404):json({message = "Not Found"})
            return
        end
        
        -- init cache
        for i, tab in ipairs(listProjectTabs(req.params.project)) do
            projectCache[i] = {name=tab, content=readProjectTab(req.params.project .. ':' .. tab)}
        end
        
        local status, err = startProject(req.params.project) -- auto start project
        if status then
            sendEvent({type="status", data=json.encode({status="play"})})
        else
            sendEvent({type="status", data=json.encode({status="error", message=err})})
        end
        res:send(HTML(req.params.project, clientState))
    end)
    
    -- ---------------------------------------------------------------------------------------------------
    -- API
    -- ---------------------------------------------------------------------------------------------------
    
    -- start (or restart) project (if exist) and set it at the current project (auto reload on changes)
    app:get('/api/project/:project/start', function(req, res)
        if not hasProject(req.params.project) then
            res:status(404):json({message = "Not Found"})
            return
        end
        
        -- @todo check if it is current project?
        
        local status, err = startProject(req.params.project)
        if status then
            sendEvent({type="status", data=json.encode({status="play"})})
            res:status(200):json({ message = "Success" })
        else
            sendEvent({type="status", data=json.encode({status="error", message=err})})
            res:status(500):json({ message = "The project "..req.params.project.." have an error", error=err })
        end
    end)
    
    -- get the list of projects
    app:get('/api/projects', function(req, res)
        res:json(listProjects()) -- remove examples projects (contains ':')
    end)
    
    -- get the list of project tabs
    app:get('/api/project/:project', function(req, res)
        local tabs = listProjectTabs(req.params.project)
        if Table.count(tabs) > 0 then
            res:json(tabs)
        else
            res:status(404):json({})
        end
    end)
    
    -- get the tab content for a given project
    app:get('/api/project/:project/tab/:tab', function(req, res)
        if not pcall(function()
            res:set('Content-Type', 'text/plain; charset=utf-8'):send(readProjectTab(req.params.project .. ':' .. req.params.tab))
        end) then
            res:status(404):json({
                message = "Not Found",
                -- documentation_url
            })
        end
    end)
    
    -- create a new project
    app:post('/api/project/:project', function(req, res)
        if not hasProject(req.params.project) then
            createProject(req.params.project)
            res:status(200):json({}) -- @todo return a better success
        else
            res:status(404):json({}) -- @todo return a better error
        end
    end)
    
    -- delete a project
    app:delete('/api/project/:project', function(req, res)
        if hasProject(req.params.project) then
            print('delete project disabled')
            -- deleteProject(req.params.project)
            res:status(200):json({}) -- @todo return a better success
        else
            res:status(400):json({message="can't delete a non existing project"}) -- @todo return a better error
        end
    end)
    
    -- create a new tab
    app:post('/api/project/:project/tab/:tab', function(req, res) -- @assert body
        -- if tab already exist, return an error
        if hasTab(req.params.project, req.params.tab) then
            res:status(400):json({ message='tab '..req.params.tab..' already exist' }) -- @todo return a better error
            return
        end
        
        if clientState.autosave then
            saveProjectTab(req.params.project .. ':' .. req.params.tab, '') -- req.body from empty string to nil
        elseif req.params.project == currentProject then
            -- @todo assert cache not already contain it
            table.insert(projectCache, {name=req.params.tab, content=''})
        end
        
        res:status(200):json({}) -- @todo return a better success
    end)
    
    -- delete a tab
    app:delete('/api/project/:project/tab/:tab', function(req, res)
        if not hasTab(req.params.project, req.params.tab) or #listProjectTabs(req.params.project) <= 1 then
            res:status(400):json({"can't delete an non existing tab or the last one"})
            return
        end
        
        if clientState.autosave then
            saveProjectTab(req.params.project .. ':' .. req.params.tab, nil)
        elseif req.params.project == currentProject then
            local removedTab = false
            for i,tab in ipairs(projectCache) do
                if tab.name == req.params.tab then
                    table.remove(projectCache, i)
                    removedTab = true
                    break
                end
            end
            assert(removedTab)
        end
        
        res:status(200):json({}) -- @todo return a better success
    end)
    
    -- app:put('/api/project/:project') -- modify a project infos (tab order, description, author, image, ...)
    
    -- modify a tab
    -- @todo most efficient than send the complete code for each change ?
    app:put('/api/project/:project/tab/:tab', function(req, res) -- @assert body
        if not hasTab(req.params.project, req.params.tab) then
            print('tab not found')
            res:status(404):json({message='tab not found'})
            return
        end
    
        if clientState.autosave then
            saveProjectTab(req.params.project .. ':' .. req.params.tab, req.body or '') -- @todo safely (auto-gist backup?)
        elseif req.params.project == currentProject then
            local updatedTab = false
            for i,tab in ipairs(projectCache) do
                if tab.name == req.params.tab then
                    projectCache[i].content = req.body or ''
                    updatedTab = true
                    break
                end
            end
            assert(updatedTab)
        end
        
        if req.params.project == currentProject and clientState.autoplay then
            local status, err = startProject(req.params.project, true) -- no setup on auto reload
            if status then
                sendEvent({type="status", data=json.encode({status="play"})})
            else
                sendEvent({type="status", data=json.encode({status="error", message=err})})
            end
        end
    
        res:status(200):json({message='tab updated'}) -- @todo return a better success
    end)

    --[[
    -- check stack overflow questions 6528876
    -- middleware to handle 404 errors
    app:use(function(req, res)
        res:status(404):json({
            message = "Not Found",
            -- documentation_url
        })
    end
    ]]--
    
    -- @todo handle port already binded, retry every 1 seconds
    app:listen(80, function()
        currentIp = express.getIp()
        print('app running on '..currentIp..':80')
    end)

    local function saveCache()
        -- print('saveCache disabled')
        --if true then return end
    
        local newContent = Table.count(projectCache) ~= Table.count(listProjectTabs(currentProject))
        if not newContent then
            for _,tab in ipairs(projectCache) do
                if not hasTab(currentProject, tab.name) or tab.content ~= readProjectTab(currentProject .. ':' .. tab.name) then
                    newContent = true
                    break
                end
            end
        end
        
        -- if content is not the already saved one, save it
        if newContent then
            for _,tab in ipairs(projectCache) do
                saveProjectTab(currentProject .. ':' .. tab.name, tab.content)
            end
        
            -- remove tabs not in cache
            for _,tab in ipairs(listProjectTabs(currentProject)) do
                if not Table.containsKey(projectCache, tab.name) then
                    saveProjectTab(currentProject .. ':' .. tab.name, nil)
                end
            end
        end
    end

    -- used instead of websocket for simplicity
    app:post('/message', function(req, res)
        local msg = req.body
        --print("message",msg)
        
        -- valid messages: 
        -- save : convert cache into saved project
        -- (play | pause | autorefresh | autosave):(true | false) -- set value of clientState
        -- screenmode:(expand|compress)
        
        if msg == 'save' then
            if clientState.autosave then
                return res:status(400):send('the project is already autosaved')
            end
            saveCache()
            return res:status(200):send()
        end
    
        local stateKey, stateValue = string.match(msg, "([A-Za-z_]+)=([A-Za-z0-9_]+)")
        if stateKey and stateValue then -- update clientState if possible
            if stateKey == "screenmode" then
                if stateValue == "expand" then
                    displayMode(FULLSCREEN_NO_BUTTONS)
                    return res:status(200):send()
                elseif stateValue == "compress" then
                    displayMode(OVERLAY)
                    return res:status(200):send()
                else
                    return res:status(400):send('client state screenmode can only be set to "expand" or "compress"')
                end
            elseif clientState[stateKey] == nil then
                return res:status(400):send('try to update a non existing client state') -- @todo list existing client states in error message
            elseif not (stateValue == "true" or stateValue == "false") then
                return res:status(400):send('client state can only be set to bool as "true" or "false"')
            end
            clientState[stateKey] = stateValue == "true"
            saveLocalData('clientState', clientState) -- @todo maybe only if client save ? replace by client preferences menus ?
            return res:status(200):send()
        end

        res:status(400):send('message unknown')
    end)
end

local function projectCall(projectEnv, funcname, ...)
    pushStyle()
    pushMatrix()
    if projectEnv and projectEnv[funcname] then
        local status, err = pcall(projectEnv[funcname], ...) -- draw the current project if there is one
        if not status then
            sendEvent({ type="error", data=json.encode({status=status, err=err}) })
        end
    end
    popMatrix()
    popStyle()
end

function draw()
    if not currentProject then
        pushStyle()
        background(33)
        fontSize(32)
        text('AirCodea running on '..currentIp..':80', WIDTH*.5, HEIGHT*.5)
        popStyle()
    end

    if clientState.play and not clientState.pause then
        projectCall(projectEnv, 'update')
    --else
        --DeltaTime = 0 -- throw an error (in tweens?)
    end
    projectCall(projectEnv, 'draw')

    app:update() -- update express server coroutine
    if eventStreamCoroutine then coroutine.resume(eventStreamCoroutine) end -- send events to clients
end

function touched(touch)
    if clientState.play and not clientState.pause then projectCall(projectEnv, 'touched', touch) end
end

-- keyboard(key)
-- collide(contact)
-- DEPRECATED orientationChanged
