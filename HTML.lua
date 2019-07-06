HTML = function(projectName, clientState)
    clientState = clientState or {} -- @todo
    return [[<!DOCTYPE html>
    <head>
        <title>AirCodea</title>
        <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
        <style>
            html {
                height: 100%;
            }
            body {
                height: 100%;
                margin:0;
                display: grid;
                grid-template-columns: 0px auto;
                grid-template-rows: 32px auto;
            }
            #action-bar {
                grid-column: 1 / 3;
                grid-row: 1;
                background: #2c2c2c;
                display: flex;
                align-items: center;
                justify-content: space-between;
                padding: 0px 4px;
            }
            #action-bar-center {
                flex: 1;
                display: flex;
                justify-content: center;
            }
            #action-bar-left {
                flex: 1;
                display: flex;
                align-items: center;
            }
            #action-bar-right {
                flex: 1;
                display: flex;
                justify-content: right;
            }
            .action-btn {
                background: #1e1e1e;
                color: white;
                border: none;
                padding: 3px 14px;
                font-size: medium;
            }
            .action-btn:hover { background: #484848; }
            .action-btn:active { background: #ccc; }
            .action-btn.enabled { background: #31cb9a; }
            .action-btn.enabled:hover { background: #54e9b9; }
            #play-status {
                color: #505050;
                font-size: larger;
                padding-left: 8px;
            }
            #play-status.play { color: #31cb9a; }
            #play-status.pause { color: #cb9e31; }
            #play-status.restart { color: #319acb; }
            #play-status.error { color: #cb5731; }
            #saved-status {
                font-size: larger;
                padding-left: 8px;
            }
            #saved-status.fa-check-circle { color: #31cb9a; }
            #saved-status.fa-exclamation-circle { color: #cb5731; }
            #hierarchy {
                grid-column: 1;
                grid-row: 2;
            }
            #code-editor {
                background: #2c2c2c;
                display: flex;
                flex-direction: column;
                grid-column: 2;
                grid-row: 2;
                height: 100%;
                overflow: hidden;
            }
            #editor { flex-grow: 1; }
            #console {
                flex-basis: 15%;
                list-style-type: none;
                font-family: Menlo, Monaco, "Courier New", monospace;
                padding: 10px 5px;
                background: #090909;
                color: white;
                overflow-y: auto;
                font-size: x-small;
            }
            #tabs {
                background: #2c2c2c;
                /*overflow-x: auto;*/
                /*min-height: 32px;*/
                padding: 2px 0;
            }
            #new-tab {
                display:none;
                margin: auto;
            }
            #new-tab-input {
                background: #3f3f3f;
                color: white;
                padding: 5px;
                font-family: Menlo, Monaco, "Courier New", monospace;
                font-size: 14px;
                border: none;
            }
            .tab {
                background: #484848;
                font-family: Menlo, Monaco, "Courier New", monospace;
                font-weight: normal;
                font-size: 14px;
                letter-spacing: 0px;
                padding: 4px 16px;
                cursor: pointer;
                color: #ccc;
            }
            .tab.active {
                color: #fff;
                background: #1e1e1e;
            }
        </style>
        <link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.7.0/css/all.css" integrity="sha384-lZN37f5QGtY3VHgisS14W3ExzMWZxybE1SJSEsQp9S+oqd12jhcu+A56Ebc1zFSJ" crossorigin="anonymous">
    </head>
    <body>
        <div id="action-bar">
            <div id="action-bar-left">
                <a href="/"><button id="btn-return" class="action-btn" title="return to projects menu"><i class="fas fa-times"></i></button></a>
                <i id="play-status" class="fas fa-circle" title="play status on codea"></i>
                <i id="saved-status" class="fas fa-check-circle" title="saved status on codea"></i>
            </div>
            <div id="action-bar-center">
                <button id="btn-play" class="action-btn ]] .. (clientState.play and 'enabled' or '') .. [[" title="play"><i class="fas fa-play"></i></button>
                <button id="btn-pause" class="action-btn ]] .. (clientState.pause and 'enabled' or '') .. [[" title="pause"><i class="fas fa-pause"></i></button>
                <button id="btn-autoplay" class="action-btn ]] .. (clientState.autoplay and 'enabled' or '') .. [[" title="autoplay"><i class="fas fa-sync"></i></button>
                <button id="btn-autosave" class="action-btn ]] .. (clientState.autosave and 'enabled' or '') .. [[" title="autosave"><i class="fas fa-cloud-upload-alt"></i></button>
            </div>
            <div id="action-bar-right">
                <button id="btn-screenmode" class="action-btn" title="change display mode in codea"><i class="fas fa-expand"></i></button>
                <button id="btn-help" class="action-btn" title="- Alt-s to save if you're not already in autosave&#13;- Alt-t to create a new tab&#13;- Alt-w to delete the current tab&#13;- Alt-r to restart&#13;- play/pause only works during development if you have an update fallback function"><i class="fas fa-question-circle"></i></button>
            </div>
        </div>
        <div id="hierarchy"></div>
        <div id="code-editor">
            <!-- <button id="btn-home">Home</button><button id="btn-new-tab">New Tab</button> -->
            <div id="tabs"></div>
            <div id="new-tab"><input id="new-tab-input" type="text" pattern="[A-Za-z_]+" placeholder="Filename" max-length="32" required/></div>
            <div id="editor"></div>
            <div id="console"></div>
        </div>

        <script src="https://unpkg.com/monaco-editor@0.16.1/min/vs/loader.js"></script> <!-- import require -->
        <script>
            /* @TODO change monaco-editor to CodeMirror */
            require.config({ paths: { 'vs': 'https://unpkg.com/monaco-editor@0.16.1/min/vs' }})
            require(['vs/editor/editor.main'], function() {
                const editor = monaco.editor.create(document.getElementById('editor'), {
                    language: 'lua',
                    theme: 'vs-dark',
                    model: null
                })
                editor.layout();
    
                const projectName = ']] .. projectName .. [[';
                const viewStates = {};
                let activeTab = null;
                const addTab = function(tab, value) {
                    let span = document.createElement('span');
                    span.classList.add('tab');
                    let tabText = document.createTextNode(tab);
                    span.appendChild(tabText);
                    document.getElementById('tabs').appendChild(span);
                    let model = monaco.editor.createModel(value, 'lua');
                    span.addEventListener('click', function() {
                        if (activeTab == span) { return; } // if already active : do nothing and return
                        if (activeTab != null) {
                            viewStates[activeTab.textContent] = editor.saveViewState(); // save state of cursor, selection, ...
                            activeTab.classList.remove('active'); // remove active class on current active
                        }
                        span.classList.add('active'); // add active class
                        editor.setModel(model);
                        if (tab in viewStates) { editor.restoreViewState(viewStates[tab]); }
                        editor.focus()
                        activeTab = span;
                    });
                    span.addEventListener('disposeTab', function() {
                        model.dispose(); // remove model from editor
                        span.remove(); // remove from tabs
                    });
                    return span
                };
                const removeTab = function(tabElement) {
                    tabElement.dispatchEvent(new Event("disposeTab"));
                    tabs.getElementsByClassName('tab')[0].click(); // change focus to first tab
                };

                window.onresize = function() { editor.layout(); };
    
                //document.getElementById('btn-home').style.display = "none"; // DEV don't show this not stylized button
                //document.getElementById('btn-new-tab').style.display = "none"; // DEV don't show this not stylized button
    
                const newTab = document.getElementById('new-tab');
                const newTabInput = document.getElementById('new-tab-input');
                const newTabAction = function() {
                    newTab.style.display = "initial"; // show name input and done button
                    newTabInput.focus(); // auto-focus
                };
                //document.getElementById('btn-new-tab').addEventListener('click', newTabAction);
                const cancel = function() {
                    newTab.style.display = "none";
                    newTabInput.value = "";
                };
                newTabInput.addEventListener('focusout', cancel); // on input unfocus, cancel
                newTabInput.addEventListener('keyup', function(evt) {
                    if (evt.keyCode !== 13) { // press enter
                        return;
                    }
                    evt.preventDefault();
    
                    if (newTabInput.checkValidity()) { // and not in already existing tab names
                        // console.log('create new tab', newTabInput.value);
                        const tabName = newTabInput.value;
                        fetch('/api/project/'+projectName+'/tab/'+tabName, {method: 'POST'})
                        .then(function(response) { // @todo create tab and model in editor
                            if (response.status == 200) {
                                addTab(tabName, '');
                            }
                        });
                        cancel();
                    }
                });
    
                // restart shortcut
                editor.addCommand(monaco.KeyMod.Alt | monaco.KeyCode.KEY_R, function() {
                    fetch('/api/project/'+projectName+'/start');
                });
    
                // new tab shortcut
                editor.addCommand(monaco.KeyMod.Alt | monaco.KeyCode.KEY_T, newTabAction);
    
                // delete tab shortcut
                editor.addCommand(monaco.KeyMod.Alt | monaco.KeyCode.KEY_W, function() {
                    //console.log('DELETE TAB',activeTab.textContent);
                    const tabName = activeTab.textContent;
                    fetch('/api/project/'+projectName+'/tab/'+tabName, {method: 'DELETE'})
                    .then(function(response) {
                        if (response.status == 200) {
                            removeTab(activeTab);
                        }
                    });
                });

                // limit rate of call and fire last call after limit rate
                const throttle = function(func, limit) { // limit in milliseconds
                    let lastFunc;
                    let lastRan;
                    return function() {
                        const context = this;
                        const args = arguments;
                        if (!lastRan || (Date.now() - lastRan) >= limit) {
                            func.apply(context, args);
                            lastRan = Date.now();
                        } else {
                            clearTimeout(lastFunc);
                            lastFunc = setTimeout(function() {
                                if ((Date.now() - lastRan) >= limit) {
                                    func.apply(context, args);
                                    lastRan = Date.now();
                                }
                            }, limit - (Date.now() - lastRan));
                        }
                    };
                };
    
                const savedStatus = document.getElementById('saved-status');
                const saved = function(value) {
                    if (value) {
                        savedStatus.classList.add('fa-check-circle');
                        savedStatus.classList.remove('fa-exclamation-circle');
                    } else {
                        savedStatus.classList.add('fa-exclamation-circle');
                        savedStatus.classList.remove('fa-check-circle');
                    }
                };
    
                const updateTab = throttle(function(evt) {
                    fetch('/api/project/'+projectName+'/tab/'+activeTab.textContent, {method: 'PUT', body:editor.getValue()})
                        .then(res => {
                            if (res.status == 503) { // if response have code 503, retry...
                                updateTab();
                            } else if (res.status == 200) {
                                saved(document.getElementById('btn-autosave').classList.contains('enabled'));
                            } else { // @todo
                                console.log(res);
                            }
                        }).catch(console.log);
                }, 500);
                editor.onDidChangeModelContent(updateTab);
                
                fetch('/api/project/'+projectName).then(data => data.json()).then(res => {
                    const firstTabName = res[0];
                    res.forEach(tabName => {
                        fetch('/api/project/'+projectName+'/tab/'+tabName) // actually this doesn't enforce order
                        .then(data => data.text())
                        .then(tabValue => {
                            const span = addTab(tabName, tabValue);
                            if (tabName == res[0]) { // first tab @todo better
                                span.click(); // click on first created Tab to auto-load and focus
                            }
                        })
                        .catch(console.log);
                    });
                }).catch(console.log);
    
                const csl = document.getElementById('console');
                const consoleClear = function() {
                    while (csl.firstChild) {
                        csl.removeChild(csl.firstChild);
                    }
                };
                const consoleLog = function(message) {
                    const li = document.createElement('li');
                    li.textContent = message;
                    csl.appendChild(li);
                };
    
                const evtSource = new EventSource('/events');
                evtSource.addEventListener('projectstart', function(e) {
                    //console.log(e);
                    const li = document.createElement('li');
                    li.textContent = "[projectstart] "+e.data;
                    document.getElementById('console').appendChild(li);
                });
                const playStatus = document.getElementById('play-status');
                evtSource.addEventListener('status', function(e) {
                    const res = JSON.parse(e.data);
    
                    // remove previous status
                    if (playStatus.classList.contains('play')) { playStatus.classList.remove('play'); }
                    else if (playStatus.classList.contains('pause')) { playStatus.classList.remove('pause'); }
                    else if (playStatus.classList.contains('restart')) { playStatus.classList.remove('restart'); }
                    else if (playStatus.classList.contains('error')) { playStatus.classList.remove('error'); }
    
                    // set current status
                    if (res.status == 'play') {
                        playStatus.classList.add('play');
                        consoleClear();
                    } else if (res.status == 'pause') {
                        playStatus.classList.add('pause');
                    } else if (res.status == 'restart') {
                        playStatus.classList.add('restart');
                    } else if (res.status == 'error') {
                        playStatus.classList.add('error');
                        consoleClear();
                        consoleLog(res.message);
                    }
                });
                evtSource.addEventListener('print', function(e) {
                    const json = JSON.parse(e.data);
                    console.log(json);
                    consoleLog(json);
                });
                evtSource.onmessage = console.log;
                evtSource.onerror = console.log;
    
                // set toggle button and send events to server through websocket
                const btnOnOff = function(name) {
                    return function() {
                        if (this.classList.contains('enabled')) {
                            this.classList.remove('enabled');
                            fetch('/message', {method: 'POST', body:name+'=false'})
                        } else {
                            this.classList.add('enabled');
                            fetch('/message', {method: 'POST', body:name+'=true'})
                        }
                    };
                };
                document.getElementById('btn-play').addEventListener('click', btnOnOff('play'));
                document.getElementById('btn-pause').addEventListener('click', btnOnOff('pause'));
                document.getElementById('btn-autoplay').addEventListener('click', btnOnOff('autoplay'));
                document.getElementById('btn-autosave').addEventListener('click', btnOnOff('autosave'));
    
                document.getElementById('btn-screenmode').addEventListener('click', function() {
                    const icon = this.querySelector('i')
                    if (icon.classList.contains('fa-expand')) {
                        fetch('/message', {method: 'POST', body:'screenmode=expand'})
                        icon.classList.remove('fa-expand');
                        icon.classList.add('fa-compress');
                    } else {
                        fetch('/message', {method: 'POST', body:'screenmode=compress'})
                        icon.classList.add('fa-expand');
                        icon.classList.remove('fa-compress');
                    }
                });
    
                editor.addCommand(monaco.KeyMod.Alt | monaco.KeyCode.KEY_S, function() {
                    fetch('/message', {method: 'POST', body:'save'})
                    saved(true);
                });
            })
        </script>
    </body>
</html>
]] end