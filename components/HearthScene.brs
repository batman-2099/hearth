sub init()
    m.config = {}
    text = ReadAsciiFile("pkg:/config.json")
    if text <> ""
        parsed = ParseJson(text)
        if type(parsed) = "roAssociativeArray" then m.config = parsed
    end if
    m.registry = CreateObject("roRegistrySection", "Hearth")
    m.connection = {url: "", token: ""}
    if HearthConnectionValid(m.config.homeAssistant) then m.connection = {url: HearthBaseUrl(m.config.homeAssistant.url), token: m.config.homeAssistant.token}
    if m.registry.Exists("connection")
        saved = ParseJson(m.registry.Read("connection"))
        if HearthConnectionValid(saved) then m.connection = saved
    end if
    m.savedPreferences = {}
    if m.registry.Exists("preferences")
        saved = ParseJson(m.registry.Read("preferences"))
        if type(saved) = "roAssociativeArray" then m.savedPreferences = saved
    end if
    m.states = []
    m.areas = invalid
    m.preferences = HearthNormalizePreferences(m.savedPreferences, HearthDefaultPreferences(m.config, m.states))
    m.preferencesReady = false
    m.page = 0
    m.tabIndex = 0
    m.toolbarFocused = true
    m.settingsOpen = false
    m.busy = false
    m.refreshPending = false
    m.errorDetail = ""
    m.saveError = ""
    m.preferenceSaveError = ""
    m.lastRefreshText = ""
    m.statesFresh = false
    m.generation = 0
    m.streamWanted = false
    m.photoId = ""
    m.dialogActions = []
    m.dialogMode = ""
    m.home = m.top.findNode("home")
    m.shortcuts = m.top.findNode("shortcuts")
    m.cameras = m.top.findNode("cameras")
    m.settings = m.top.findNode("settings")
    m.pages = [m.home, m.shortcuts, m.cameras]
    m.status = m.top.findNode("status")
    m.connectionMark = m.top.findNode("connectionMark")
    m.hint = m.top.findNode("hint")
    m.video = m.top.findNode("video")
    m.photo = m.top.findNode("photo")
    m.photo.observeField("loadStatus", "photoLoaded")
    m.video.observeField("state", "videoChanged")
    for each page in m.pages
        page.observeField("leave", "toToolbar")
    end for
    m.home.observeField("itemSelected", "homeActivated")
    m.home.observeField("hint", "updateHint")
    m.home.observeField("brightness", "controlBrightness")
    m.shortcuts.observeField("activate", "shortcutActivated")
    m.shortcuts.observeField("hint", "updateHint")
    m.cameras.observeField("itemSelected", "cameraActivated")
    m.cameras.observeField("hint", "updateHint")
    m.settings.observeField("preferencesChanged", "preferencesChanged")
    m.settings.observeField("connectionChanged", "connectionChanged")
    m.settings.observeField("closed", "closeSettings")
    m.top.findNode("poll").observeField("fire", "poll")
    m.top.findNode("clockTimer").observeField("fire", "updateClock")
    m.top.findNode("cameraTimer").observeField("fire", "cameraTick")
    m.top.findNode("clockTimer").control = "start"
    m.top.findNode("cameraTimer").control = "start"
    m.tabs = []
    m.tabLabels = []
    m.tabMarkers = []
    m.theme = HearthTheme("dark")
    names = ["Home", "Scenes", "Cameras", "Settings"]
    for index = 0 to names.count() - 1
        face = HearthPanel(m.top.findNode("toolbar"), index * 146, 0, 138, 44, m.theme.surface)
        label = HearthLabel(m.top.findNode("toolbar"), names[index], index * 146, 5, 138, 36, m.theme.text, m.theme.bodySize)
        label.horizAlign = "center"
        m.tabs.push(face)
        m.tabLabels.push(label)
        marker = HearthRectangle(m.top.findNode("toolbar"), index * 146 + 16, 46, 106, 3, m.theme.focus)
        m.tabMarkers.push(marker)
    end for
    m.home.config = m.config
    m.cameras.config = m.config
    m.settings.config = m.config
    updateSurfaces()
    showPage()
    m.top.findNode("poll").control = "start"
    startRequest("refresh")
end sub

function resolvedTheme() as string
    if m.preferences.theme <> "auto" then return m.preferences.theme
    sun = HearthStateById(m.states, "sun.sun")
    if sun <> invalid
        if sun.state = "above_horizon" then return "light"
    end if
    return "dark"
end function

function selectedStates(ids as object, byId as object) as object
    result = []
    for each id in ids
        if byId.DoesExist(id) then result.push(byId[id])
    end for
    return result
end function

sub updateSurfaces()
    m.config.deviceNames = m.preferences.deviceNames
    m.home.config = m.config
    m.cameras.config = m.config
    m.settings.config = m.config
    mode = resolvedTheme()
    byId = {}
    for each state in m.states
        byId[state.entity_id] = state
    end for
    m.theme = HearthTheme(mode)
    m.top.backgroundColor = m.theme.background
    m.top.backgroundUri = ""
    m.top.findNode("veil").color = m.theme.background
    m.top.findNode("veil").opacity = 0.88
    if mode = "light" then m.top.findNode("veil").opacity = 0.86
    wall = m.top.findNode("wallpaper")
    wall.visible = m.preferences.wallpaper <> "none"
    if wall.visible then wall.uri = "pkg:/images/" + m.preferences.wallpaper + ".jpg"
    m.top.findNode("photoBackdrop").color = m.theme.background
    m.top.findNode("photoHintBackground").color = m.theme.surface
    for each id in ["clock", "date", "status", "connectionLabel"]
        node = m.top.findNode(id)
        node.color = m.theme.text
        node.font = m.theme.fontBody
        node.font.size = m.theme.smallSize
    end for
    for each id in ["hint", "photoHint"]
        m.top.findNode(id).color = m.theme.text
        m.top.findNode(id).keyBackground = m.theme.surface
        m.top.findNode(id).fontSize = m.theme.smallSize
    end for
    m.top.findNode("brandFrame").blendColor = m.theme.text
    m.top.findNode("clock").font.size = m.theme.valueSize
    m.status.color = m.theme.muted
    displayAreas = m.areas
    if type(displayAreas) <> "roAssociativeArray" then displayAreas = {}
    homeIds = []
    seen = {}
    for each ids in [m.preferences.sensors, m.preferences.controls]
        for each id in ids
            if not seen.DoesExist(id)
                homeIds.Push(id)
                seen[id] = true
            end if
        end for
    end for
    m.home.entityIds = homeIds
    m.home.controlIds = m.preferences.controls
    m.home.density = m.preferences.density
    m.home.sensorAlerts = m.preferences.sensorAlerts
    m.home.statesFresh = m.statesFresh
    m.home.areas = displayAreas
    m.home.states = selectedStates(homeIds, byId)
    m.home.themeMode = mode
    m.shortcuts.data = {states: selectedStates(m.preferences.controls, byId), preferences: m.preferences, config: m.config, areas: displayAreas, themeMode: mode}
    if FormatJson(m.cameras.connection) <> FormatJson(m.connection) then m.cameras.connection = m.connection
    if FormatJson(m.cameras.entityIds) <> FormatJson(m.preferences.cameras) then m.cameras.entityIds = m.preferences.cameras
    m.cameras.states = selectedStates(m.preferences.cameras, byId)
    m.cameras.themeMode = mode
    m.settings.connection = m.connection
    m.settings.preferences = m.preferences
    m.settings.states = m.states
    m.settings.areas = displayAreas
    m.settings.themeMode = mode
    m.top.findNode("poll").duration = m.preferences.refreshSeconds
    updateClock()
    updateToolbar()
    updateHint()
    updateStatus()
end sub

sub updateClock()
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    hours = now.GetHours()
    suffix = ""
    if not m.preferences.clock24
        suffix = " am"
        if hours >= 12 then suffix = " pm"
        hours = hours mod 12
        if hours = 0 then hours = 12
    end if
    minutes = now.GetMinutes().toStr().trim()
    if Len(minutes) = 1 then minutes = "0" + minutes
    m.top.findNode("clock").text = hours.toStr().trim() + ":" + minutes + suffix
    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    m.top.findNode("date").text = now.GetDayOfMonth().toStr().trim() + " " + months[now.GetMonth() - 1] + " " + now.GetYear().toStr().trim()
end sub

sub updateToolbar()
    if m.theme = invalid then return
    scenesVisible = false
    for each id in m.preferences.controls
        if HearthContains(["scene", "script"], HearthEntityDomain(id))
            scenesVisible = true
            exit for
        end if
    end for
    visibleTabs = [true, scenesVisible, m.preferences.cameras.Count() > 0, true]
    if not visibleTabs[m.page] then m.page = 0
    if not visibleTabs[m.tabIndex] then m.tabIndex = 0
    position = 0
    active = m.page
    if m.settingsOpen then active = m.pages.count()
    for index = 0 to m.tabs.count() - 1
        shown = visibleTabs[index]
        m.tabs[index].visible = shown
        m.tabLabels[index].visible = shown
        m.tabs[index].translation = [position * 146, 0]
        m.tabLabels[index].translation = [position * 146, 5]
        m.tabMarkers[index].translation = [position * 146 + 16, 46]
        if shown then position = position + 1
        m.tabs[index].blendColor = m.theme.surface
        m.tabLabels[index].color = m.theme.muted
        m.tabMarkers[index].color = m.theme.focus
        m.tabMarkers[index].visible = shown and index = active
        description = m.tabLabels[index].text + ". Page."
        if index = active
            m.tabLabels[index].color = m.theme.text
            description = description + " Current page."
        end if
        m.tabs[index].audioGuideText = description + " Press OK to open."
        if m.toolbarFocused and index = m.tabIndex and not m.settingsOpen
            m.tabs[index].blendColor = m.theme.focus
            m.tabLabels[index].color = m.theme.background
        end if
    end for
end sub

sub updateHint()
    if m.settingsOpen
        m.hint.text = ""
    else if m.toolbarFocused
        m.hint.text = "[Left/Right] Page     [OK/Down] Open     [Back] Home/exit     [*] Settings"
    else
        m.hint.text = m.pages[m.page].hint
    end if
end sub

sub showPage()
    updateToolbar()
    for index = 0 to m.pages.count() - 1
        m.pages[index].visible = not m.settingsOpen and index = m.page and not m.photo.visible and not m.video.visible
    end for
    if m.settingsOpen
        m.settings.setFocus(true)
    else if m.toolbarFocused
        m.tabs[m.tabIndex].setFocus(true)
    else
        m.pages[m.page].setFocus(true)
    end if
    updateHint()
end sub

sub toToolbar()
    m.streamWanted = false
    m.toolbarFocused = true
    m.tabIndex = m.page
    showPage()
end sub

sub openSettings()
    m.settings.preferredRoom = ""
    if m.page = 0 then m.settings.preferredRoom = m.home.currentRoom
    m.streamWanted = false
    m.settingsOpen = true
    m.settings.visible = true
    showPage()
end sub

sub closeSettings()
    m.settingsOpen = false
    m.settings.visible = false
    m.toolbarFocused = true
    m.tabIndex = m.pages.count()
    showPage()
end sub

sub preferencesChanged()
    preferences = HearthNormalizePreferences(m.settings.preferencesChanged, HearthDefaultPreferences(m.config, m.states))
    if not saveRegistryValue("preferences", preferences)
        m.preferenceSaveError = "Preferences could not be saved. Your changes are retained; try saving again."
        m.settings.preferencesSaveResult = {ok: false, error: m.preferenceSaveError}
        updateStatus()
        return
    end if
    m.preferenceSaveError = ""
    m.savedPreferences = preferences
    m.preferences = preferences
    updateSurfaces()
    m.settings.preferencesSaveResult = {ok: true, error: ""}
    updateStatus("Settings saved.")
end sub

sub connectionChanged()
    connection = m.settings.connectionChanged
    error = ""
    if not HearthConnectionValid(connection)
        error = "Enter a valid Home Assistant address and token."
    else if not saveRegistryValue("connection", connection)
        error = "Connection could not be saved. Your edits are retained; try Save connection again."
    end if
    m.saveError = error
    if error <> ""
        m.settings.connectionSaveResult = {ok: false, error: error}
        updateStatus()
        return
    end if
    m.connection = connection
    m.generation = m.generation + 1
    m.states = []
    m.areas = invalid
    m.lastRefreshText = ""
    m.statesFresh = false
    m.errorDetail = ""
    m.settings.connectionSaveResult = {ok: true, error: ""}
    updateSurfaces()
    startRequest("refresh")
end sub

function saveRegistryValue(key as string, value as object) as boolean
    previous = invalid
    if m.registry.Exists(key) then previous = m.registry.Read(key)
    if m.registry.Write(key, FormatJson(value))
        if m.registry.Flush() then return true
    end if
    ' Restore the registry buffer too: an unrelated later flush must not save a rejected draft.
    if previous = invalid
        m.registry.Delete(key)
    else
        m.registry.Write(key, previous)
    end if
    m.registry.Flush()
    return false
end function

sub updateStatus(message = "" as string)
    m.status.color = m.theme.muted
    connected = m.statesFresh = true and HearthConnectionValid(m.connection)
    m.home.statesFresh = connected
    m.connectionMark.uri = "pkg:/images/connection-error.png"
    m.connectionMark.blendColor = m.theme.error
    m.connectionMark.audioGuideText = "Home Assistant disconnected."
    if connected
        m.connectionMark.uri = "pkg:/images/connection-ok.png"
        m.connectionMark.blendColor = m.theme.success
        m.connectionMark.audioGuideText = "Home Assistant connected."
    end if
    if m.saveError <> ""
        m.status.text = "Connection not saved. Play: details."
        m.status.color = m.theme.error
    else if m.preferenceSaveError <> ""
        m.status.text = "Preferences not saved. Play: details."
        m.status.color = m.theme.error
    else if m.errorDetail <> ""
        m.status.text = "Home Assistant needs attention. Play: details."
        if not m.statesFresh then m.status.text = "Values may be stale. Play: details."
        m.status.color = m.theme.error
    else if message <> ""
        m.status.text = message
        if message = "Home Assistant connected" then m.status.text = ""
    end if
end sub

sub showStatusDetails()
    detail = m.saveError
    if m.preferenceSaveError <> ""
        if detail <> "" then detail = detail + Chr(10) + Chr(10)
        detail = detail + m.preferenceSaveError
    end if
    if m.errorDetail <> ""
        if detail <> "" then detail = detail + Chr(10) + Chr(10)
        detail = detail + m.errorDetail
    end if
    if detail = "" then return
    freshness = "No successful state refresh this session."
    if m.lastRefreshText <> "" then freshness = "Last successful state refresh: " + m.lastRefreshText
    showMessage("Home Assistant status", detail + Chr(10) + Chr(10) + freshness + Chr(10) + "Replay refreshes dashboard values.")
end sub

sub poll()
    if m.settingsOpen or m.top.dialog <> invalid or m.video.visible or m.photo.visible then return
    if m.busy then return
    startRequest("refresh")
end sub

sub startRequest(op as string, action = invalid as dynamic, entityId = "" as string)
    if m.busy
        if op = "refresh"
            m.refreshPending = true
        else
            updateStatus("Please wait for the current request.")
        end if
        return
    end if
    if not HearthConnectionValid(m.connection)
        updateStatus("Open Settings to connect to Home Assistant.")
        return
    end if
    m.busy = true
    m.requestOp = op
    m.requestGeneration = m.generation
    if op = "action"
        m.home.pendingId = action.entityId
        m.shortcuts.pendingId = action.entityId
        updateStatus("Sending control…")
    end if
    if op = "stream"
        updateStatus("Opening camera…")
        m.photoId = entityId
        m.streamWanted = true
    end if
    m.task = CreateObject("roSGNode", "HearthTask")
    m.task.observeField("result", "received")
    m.task.request = {op: op, connection: m.connection, preferences: m.preferences, config: m.config, states: m.states, areas: m.areas, action: action, entityId: entityId}
    m.task.control = "RUN"
end sub

sub received()
    result = m.task.result
    m.busy = false
    m.home.pendingId = ""
    m.shortcuts.pendingId = ""
    if m.requestGeneration <> m.generation
        m.refreshPending = false
        startRequest("refresh")
        return
    end if
    if m.requestOp = "stream"
        m.errorDetail = result.error
        updateStatus("Camera stream ready.")
        if m.streamWanted
            if result.ok and result.streamUrl <> ""
                playCamera(result.streamUrl)
            else
                showSnapshot(result.error)
            end if
        end if
    else
        m.states = result.states
        m.areas = result.areas
        m.statesFresh = (result.statesFresh = true)
        if m.statesFresh
            now = CreateObject("roDateTime")
            now.ToLocalTime()
            m.lastRefreshText = now.AsDateString("short-date") + " " + now.GetHours().toStr() + ":" + Right("0" + now.GetMinutes().toStr(), 2)
        end if
        if not m.preferencesReady and m.states.count() > 0
            m.preferences = HearthNormalizePreferences(m.savedPreferences, HearthDefaultPreferences(m.config, m.states))
            m.preferencesReady = true
        end if
        updateSurfaces()
        m.errorDetail = result.error
        message = "Home Assistant connected"
        if result.message <> "" then message = result.message
        updateStatus(message)
    end if
    if m.refreshPending
        m.refreshPending = false
        m.areas = invalid
        startRequest("refresh")
    end if
end sub

sub homeActivated()
    id = m.home.itemSelected
    state = HearthStateById(m.states, id)
    if state = invalid
        showMessage("Entity unavailable", "This entity is not currently reported by Home Assistant.")
        return
    end if
    if HearthIsToggle(id) or HearthSelectedControl(id, m.preferences)
        activateControl(id)
        return
    end if
    body = HearthDisplayValue(state)
    if m.areas <> invalid
        if HearthIsString(m.areas[id]) then body = body + Chr(10) + "Room: " + m.areas[id]
    end if
    body = body + Chr(10) + id
    showMessage(HearthEntityTitle(state, m.config), body)
end sub


sub showMessage(title as string, message as string)
    m.dialogMode = "message"
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = title
    dialog.message = message
    dialog.buttons = ["Close"]
    dialog.observeField("buttonSelected", "dialogSelected")
    dialog.observeField("wasClosed", "dialogClosed")
    m.top.dialog = dialog
end sub

sub shortcutActivated()
    if m.busy
        updateStatus("Please wait for the current request.")
        return
    end if
    id = m.shortcuts.activate
    if not HearthContains(["scene", "script"], HearthEntityDomain(id)) then return
    action = HearthStandardAction(id)
    if not HearthSelectedControl(id, m.preferences) or not HearthActionAllowed(action, m.states, m.preferences, m.config)
        showMessage("Shortcut unavailable", "Select this scene or script in Settings > Controls and refresh with Replay.")
        return
    end if
    startRequest("action", action)
end sub

sub activateControl(id as string)
    state = HearthStateById(m.states, id)
    if not HearthStateAvailable(state)
        showMessage("Device unavailable", "Home Assistant does not currently report an available state. Try refreshing with Replay.")
        return
    end if
    if HearthEntityDomain(id) = "climate" and HearthSelectedControl(id, m.preferences)
        showClimateDialog(id)
        return
    end if
    actions = HearthControlActions(id, m.states, m.preferences, m.config)
    if actions.count() = 0
        showMessage("Control not enabled", "Select this device in Settings > Controls to enable its supported commands.")
        return
    end if
    if actions.count() = 1 and actions[0].service = "toggle"
        startRequest("action", actions[0])
        return
    end if
    m.dialogActions = actions
    m.dialogMode = "actions"
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = HearthEntityTitle(state, m.config)
    dialog.message = "Choose a command to send to Home Assistant."
    buttons = ["Cancel"]
    for each action in actions
        buttons.push(action.name)
    end for
    dialog.buttons = buttons
    dialog.observeField("buttonSelected", "dialogSelected")
    dialog.observeField("wasClosed", "dialogClosed")
    m.top.dialog = dialog
end sub

sub controlBrightness()
    if m.errorDetail <> "" or m.saveError <> "" or m.preferenceSaveError <> ""
        showStatusDetails()
        return
    end if
    if m.busy then return
    showLightDialog(m.home.brightness)
end sub

sub showLightDialog(id as string, key = "" as string)
    if m.busy then return
    state = HearthStateById(m.states, id)
    if not HearthSelectedControl(id, m.preferences) or not HearthStateAvailable(state) then return
    fields = HearthLightFields(state)
    if fields.Count() = 0 then return
    buttons = ["Close"]
    choices = [invalid]
    title = HearthEntityTitle(state, m.config)
    message = "Light controls"
    if key = ""
        for each field in fields
            buttons.Push(field.name + "…")
            choices.Push({field: field.key})
        end for
    else
        buttons = ["Back"]
        choices = [{field: ""}]
        for each field in fields
            if field.key = key
                title = field.name
                message = HearthEntityTitle(state, m.config)
                if field.kind = "number"
                    current = HearthText(field.value)
                    if current = "" then current = "Not reported"
                    message = message + Chr(10) + "Current: " + current + " " + field.unit
                    message = message + Chr(10) + "Range: " + HearthText(field.min) + "–" + HearthText(field.max) + " " + field.unit
                    if HearthIsNumber(field.value)
                        for each delta in [-1, 1]
                            target = field.value + delta * field.step
                            if target < field.min then target = field.min
                            if target > field.max then target = field.max
                            action = HearthLightAction(state, key, target)
                            if action <> invalid and ((delta < 0 and target < field.value) or (delta > 0 and target > field.value))
                                label = "Decrease to "
                                if delta > 0 then label = "Increase to "
                                buttons.Push(label + HearthText(target) + " " + field.unit)
                                choices.Push({action: action})
                            end if
                        end for
                    end if
                end if
                for index = 0 to field.presets.Count() - 1
                    value = field.presets[index]
                    action = HearthLightAction(state, key, value)
                    if action <> invalid
                        if field.kind = "color"
                            label = field.names[index]
                        else
                            label = HearthText(value) + " " + field.unit
                        end if
                        buttons.Push(label)
                        choices.Push({action: action})
                    end if
                end for
            end if
        end for
    end if
    m.lightId = id
    m.lightChoices = choices
    m.dialogMode = "light"
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = title
    dialog.message = message
    dialog.buttons = buttons
    dialog.observeField("buttonSelected", "dialogSelected")
    dialog.observeField("wasClosed", "dialogClosed")
    m.top.dialog = dialog
end sub

sub showClimateDialog(id as string, key = "" as string)
    if m.busy
        updateStatus("Please wait for the current request.")
        return
    end if
    state = HearthStateById(m.states, id)
    if not HearthStateAvailable(state) or not HearthSelectedControl(id, m.preferences)
        showMessage("Climate control unavailable", "Refresh with Replay and select this thermostat in Settings > Controls.")
        return
    end if
    fields = HearthClimateFields(state)
    attributes = HearthAttributes(state)
    unit = HearthText(attributes.temperature_unit)
    if unit = "" then unit = "°"
    message = "Mode: " + HearthReadable(state.state)
    if HearthIsNumber(attributes.current_temperature) then message = message + Chr(10) + "Current temperature: " + HearthText(attributes.current_temperature) + " " + unit
    buttons = ["Close"]
    choices = [invalid]
    title = HearthEntityTitle(state, m.config)
    if key = ""
        for each field in fields
            value = HearthText(field.value)
            if value = "" then value = "Not reported"
            if field.kind = "temperature" then value = value + " " + unit else value = HearthReadable(value)
            buttons.Push(field.name + ": " + value + "…")
            choices.Push({field: field.key})
        end for
        for each action in HearthControlActions(id, m.states, m.preferences, m.config)
            buttons.Push(action.name)
            choices.Push({action: action})
        end for
        if fields.Count() = 0 then message = message + Chr(10) + "No adjustable climate settings reported."
    else
        buttons = ["Back"]
        choices = [{field: ""}]
        for each field in fields
            if field.key = key
                title = field.name
                value = HearthText(field.value)
                if value = "" then value = "Not reported"
                if field.kind <> "temperature" then value = HearthReadable(value)
                message = HearthEntityTitle(state, m.config) + Chr(10) + "Current setting: " + value
                if field.kind = "temperature"
                    message = message + " " + unit + Chr(10) + "Step: " + HearthText(field.step) + " " + unit
                    for each delta in [-1, 1]
                        target = field.value + delta * field.step
                        if target < field.min then target = field.min
                        if target > field.max then target = field.max
                        action = HearthClimateAction(state, key, target)
                        if action <> invalid and ((delta < 0 and target < field.value) or (delta > 0 and target > field.value))
                            label = "Decrease to "
                            if delta > 0 then label = "Increase to "
                            buttons.Push(label + HearthText(target) + " " + unit)
                            choices.Push({action: action})
                        end if
                    end for
                else
                    for each option in field.options
                        if option <> field.value
                            action = HearthClimateAction(state, key, option)
                            if action <> invalid
                                buttons.Push(HearthReadable(option))
                                choices.Push({action: action})
                            end if
                        end if
                    end for
                end if
            end if
        end for
        if choices.Count() = 1 then message = message + Chr(10) + "No other settings available. Back returns."
    end if
    m.climateId = id
    m.climateChoices = choices
    m.dialogMode = "climate"
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = title
    dialog.message = message
    dialog.buttons = buttons
    dialog.observeField("buttonSelected", "dialogSelected")
    dialog.observeField("wasClosed", "dialogClosed")
    m.top.dialog = dialog
end sub

sub dialogSelected()
    selected = m.top.dialog.buttonSelected
    action = invalid
    if m.dialogMode = "climate" or m.dialogMode = "light"
        choices = m.climateChoices
        if m.dialogMode = "light" then choices = m.lightChoices
        if selected >= 0 and selected < choices.Count()
            choice = choices[selected]
            if choice <> invalid
                if choice.DoesExist("field")
                    ' Replacing the dialog must not let the old close callback reset the new menu.
                    m.top.dialog.unobserveField("wasClosed")
                    m.top.dialog.close = true
                    if m.dialogMode = "light"
                        showLightDialog(m.lightId, choice.field)
                    else
                        showClimateDialog(m.climateId, choice.field)
                    end if
                    return
                end if
                action = choice.action
            end if
        end if
    end if
    if m.dialogMode = "actions" and selected > 0 and selected <= m.dialogActions.count() then action = m.dialogActions[selected - 1]
    m.top.dialog.close = true
    if action <> invalid and not m.busy
        if HearthActionAllowed(action, m.states, m.preferences, m.config) then startRequest("action", action)
    end if
end sub

sub dialogClosed()
    m.dialogMode = ""
    m.dialogActions = []
    m.climateChoices = []
    m.climateId = ""
    m.lightChoices = []
    m.lightId = ""
    if m.photo.visible
        m.photo.setFocus(true)
    else if m.video.visible
        m.video.setFocus(true)
    else
        showPage()
    end if
end sub

sub cameraActivated()
    id = m.cameras.itemSelected
    if not HearthStateAvailable(HearthStateById(m.states, id))
        showMessage("Camera unavailable", "Check this camera in Home Assistant before opening it again.")
        return
    end if
    startRequest("stream", invalid, id)
end sub

sub playCamera(url as string)
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.streamFormat = "hls"
    content.HttpCertificatesFile = "common:/certs/ca-bundle.crt"
    m.video.content = content
    m.video.visible = true
    for each page in m.pages
        page.visible = false
    end for
    m.video.setFocus(true)
    m.video.control = "play"
end sub

sub showSnapshot(reason as string)
    m.video.control = "stop"
    m.video.visible = false
    m.video.content = invalid
    m.top.findNode("photoBackdrop").visible = true
    m.photo.visible = true
    m.top.findNode("photoHint").visible = true
    m.top.findNode("photoHintBackground").visible = true
    m.errorDetail = reason
    if reason = "" then m.errorDetail = "The live stream is unavailable. Check this camera's stream support in Home Assistant."
    m.photoReason = "Live video unavailable. Snapshots refresh every 5 seconds." + Chr(10) + "[Play] Details     [Back] Cameras"
    m.top.findNode("photoHint").text = m.photoReason
    m.photo.audioGuideText = m.photoReason
    for each page in m.pages
        page.visible = false
    end for
    agent = CreateObject("roHttpAgent")
    agent.SetCertificatesFile("common:/certs/ca-bundle.crt")
    agent.AddHeader("Authorization", "Bearer " + m.connection.token)
    m.photo.SetHttpAgent(agent)
    m.photo.setFocus(true)
    cameraTick()
end sub

sub cameraTick()
    if m.photo.visible
        if HearthEntityIdValid(m.photoId)
            clock = CreateObject("roDateTime")
            m.photo.uri = HearthBaseUrl(m.connection.url) + "/api/camera_proxy/" + m.photoId + "?t=" + clock.AsSeconds().toStr().trim()
        end if
    else if m.cameras.visible
        m.cameras.refreshTick = m.cameras.refreshTick + 1
    end if
end sub

sub photoLoaded()
    if not m.photo.visible then return
    if m.photo.loadStatus = "failed"
        m.top.findNode("photoHint").text = "Snapshot unavailable. Check the camera in Home Assistant. Back returns."
    else if m.photo.loadStatus = "ready"
        m.top.findNode("photoHint").text = m.photoReason
    end if
    m.photo.audioGuideText = m.top.findNode("photoHint").text
end sub

sub videoChanged()
    if m.video.state = "error"
        showSnapshot("Roku could not play this camera stream.")
    else if m.video.state = "finished"
        closeMedia()
    end if
end sub

sub closeMedia()
    m.streamWanted = false
    m.video.control = "stop"
    m.video.visible = false
    m.video.content = invalid
    m.photo.visible = false
    m.photo.uri = ""
    m.photo.SetHttpAgent(CreateObject("roHttpAgent"))
    m.top.findNode("photoBackdrop").visible = false
    m.top.findNode("photoHint").visible = false
    m.top.findNode("photoHintBackground").visible = false
    m.toolbarFocused = false
    showPage()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.top.dialog <> invalid then return false
    if key = "play" and (m.errorDetail <> "" or m.saveError <> "" or m.preferenceSaveError <> "")
        showStatusDetails()
        return true
    end if
    if m.video.visible or m.photo.visible
        if key = "back"
            closeMedia()
            return true
        end if
        return false
    end if
    if m.settingsOpen then return false
    if key = "options"
        openSettings()
        return true
    end if
    if key = "replay"
        m.areas = invalid
        startRequest("refresh")
        return true
    end if
    if not m.toolbarFocused then return false
    if key = "left" or key = "right"
        nextTab = m.tabIndex
        if key = "left" and nextTab > 0 then nextTab = nextTab - 1
        if key = "right" and nextTab < m.tabs.count() - 1 then nextTab = nextTab + 1
        while not m.tabs[nextTab].visible
            if key = "left" then nextTab = nextTab - 1 else nextTab = nextTab + 1
        end while
        m.tabIndex = nextTab
        if nextTab < m.pages.count() then m.page = nextTab
        m.streamWanted = false
        showPage()
        return true
    end if
    if key = "OK" or key = "down"
        if m.tabIndex = m.pages.count()
            openSettings()
        else
            m.toolbarFocused = false
            showPage()
        end if
        return true
    end if
    if key = "up" then return true
    if key = "back" and (m.page <> 0 or m.tabIndex <> 0)
        m.page = 0
        m.tabIndex = 0
        showPage()
        return true
    end if
    return false
end function
