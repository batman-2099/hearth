sub Main()
    TestCombinedSurfaces()
    m.registry = {values: {connection: "old", preferences: "keep"}, writeOk: true, flushOk: false, Exists: TestExists, Read: TestRead, Write: TestWrite, Flush: TestFlush, Delete: TestDelete}
    connection = {url: "https://ha.local", token: "test-token"}
    AssertScene(not saveRegistryValue("connection", connection), "failed flush must reject save")
    AssertScene(m.registry.values.connection = "old" and m.registry.values.preferences = "keep", "failed flush restores prior buffer without changing other settings")
    m.registry.values.Delete("connection")
    AssertScene(not saveRegistryValue("connection", connection) and not m.registry.values.DoesExist("connection"), "failed first save removes uncommitted buffer")
    m.registry.values.connection = "old"
    m.registry.writeOk = false
    AssertScene(not saveRegistryValue("connection", connection) and m.registry.values.connection = "old", "failed write keeps previous connection")
    m.registry.writeOk = true
    m.registry.flushOk = true
    AssertScene(saveRegistryValue("connection", connection), "successful persistence accepted")
    AssertScene(ParseJson(m.registry.values.connection).url = connection.url and m.registry.values.preferences = "keep", "successful save preserves unrelated settings")
    m.registry.flushOk = false
    m.settings = {connectionChanged: connection}
    m.theme = {muted: "muted", error: "error", success: "success"}
    m.status = {}
    m.connectionMark = {}
    m.statesFresh = false
    m.preferenceSaveError = ""
    m.connection = {url: "https://previous.local", token: "previous-token"}
    connectionChanged()
    AssertScene(not m.settings.connectionSaveResult.ok, "persistence failure acknowledged to form")
    AssertScene(m.connection.url = "https://previous.local", "failed save must not replace active connection")
    banner = m.status.text
    updateStatus("Updating")
    AssertScene(m.status.text = banner, "background activity cannot erase save failure")
    m.settings.connectionChanged.url = "http://-invalid"
    connectionChanged()
    AssertScene(not m.settings.connectionSaveResult.ok and m.connection.url = "https://previous.local", "invalid draft cannot replace active connection")
    _brs_.mockFunction("updateSurfaces")
    m.config = {}
    m.states = []
    m.saveError = ""
    m.errorDetail = ""
    m.statesFresh = true
    updateStatus("Home Assistant connected")
    connectedIcon = m.connectionMark.uri
    AssertScene(m.status.text = "" and m.connectionMark.blendColor = m.theme.success, "successful connection uses the footer indicator rather than a connected banner")
    m.saveError = "Save failed"
    updateStatus()
    AssertScene(m.connectionMark.uri = connectedIcon and m.status.text <> "", "save failure preserves healthy connection indication and detailed error")
    m.saveError = ""
    m.statesFresh = false
    updateStatus()
    AssertScene(m.connectionMark.uri <> connectedIcon and m.connectionMark.blendColor = m.theme.error, "stale state cannot retain the connected check")
    m.preferences = HearthNormalizePreferences({controls: ["light.keep"], deviceNames: {"light.keep": "Original"}}, invalid)
    m.savedPreferences = m.preferences
    m.registry.values.preferences = FormatJson(m.preferences)
    m.settings.preferencesChanged = {controls: ["switch.new"], deviceNames: {"light.keep": "Renamed"}, refreshSeconds: 45}
    preferencesChanged()
    AssertScene(not m.settings.preferencesSaveResult.ok, "preference failure is acknowledged")
    AssertScene(m.preferences.controls[0] = "light.keep" and m.savedPreferences.controls[0] = "light.keep", "failed preferences never become active")
    AssertScene(ParseJson(m.registry.values.preferences).controls[0] = "light.keep", "failed preference flush restores previous buffer")
    AssertScene(m.preferences.deviceNames["light.keep"] = "Original" and ParseJson(m.registry.values.preferences).deviceNames["light.keep"] = "Original", "failed rename preserves active and persisted device names")
    failureBanner = m.status.text
    m.registry.flushOk = true
    preferencesChanged()
    AssertScene(m.settings.preferencesSaveResult.ok and m.preferences.controls[0] = "switch.new", "retry applies preferences after successful persistence")
    AssertScene(ParseJson(m.registry.values.preferences).refreshSeconds = 45 and m.savedPreferences.controls[0] = "switch.new", "saved and active preference snapshots agree")
    AssertScene(m.preferences.deviceNames["light.keep"] = "Renamed" and ParseJson(m.registry.values.preferences).deviceNames["light.keep"] = "Renamed", "successful rename updates active and persisted device names")
    AssertScene(m.preferenceSaveError = "" and m.status.text <> failureBanner, "successful retry clears stale failure feedback")
    _brs_.mockComponent("HearthTask", {observeField: sub(field as string, callback as string)
    end sub})
    m.home = {}
    m.shortcuts = {}
    m.top = {}
    m.video = {visible: false}
    m.photo = {visible: false}
    m.settingsOpen = false
    m.busy = true
    m.refreshPending = false
    m.generation = 0
    m.requestGeneration = 0
    m.requestOp = "refresh"
    m.preferencesReady = true
    m.areas = {"light.keep": "Old room"}
    m.task = {result: {states: [], areas: m.areas, statesFresh: false, error: "", message: ""}}
    AssertScene(onKeyEvent("replay", true) and m.refreshPending, "Replay queues behind an in-flight request")
    received()
    AssertScene(m.task.request.op = "refresh" and m.task.request.areas = invalid, "queued Replay rediscovers rooms even after the old response restores its cache")
    AssertScene(not m.refreshPending, "queued Replay starts only once")
    m.task.result = {states: [], areas: {"light.keep": "New room"}, statesFresh: false, error: "", message: ""}
    received()
    AssertScene(m.areas["light.keep"] = "New room" and not m.busy, "new room metadata replaces the old cache")
    AssertScene(m.home.pendingId = "" and m.shortcuts.pendingId = "", "completed requests clear Home and Scenes pending state")
    AssertScene(onKeyEvent("replay", true) and m.task.request.areas = invalid, "idle Replay also rediscovers rooms")
    m.busy = false
    startRequest("action", {entityId: "light.test", domain: "light", service: "toggle"})
    AssertScene(m.home.pendingId = "light.test" and m.shortcuts.pendingId = "light.test", "actions mark both Home and Scenes pending")
    _brs_.mockComponent("Dialog", {observeField: sub(field as string, callback as string)
    end sub, unobserveField: sub(field as string)
    end sub})
    _brs_.mockFunction("startRequest", sub(op as string, action as object)
        m.sentAction = action
    end sub)
    TestLightDialogs()
    TestHomeActions()
    TestClimateDialogs()
    TestSceneShortcuts()
    TestConditionalScenesTab()
    print "HEARTH_SCENE_TESTS_PASSED"
end sub

sub TestCombinedSurfaces()
    _brs_.mockFunction("HearthTheme", function(mode as string) as object
        return {background: "background", surface: "surface", text: "text", muted: "muted", focus: "focus", error: "error", success: "success", fontBody: {}, smallSize: 18, valueSize: 28}
    end function)
    m.config = {}
    m.connection = {url: "", token: ""}
    m.preferences = HearthNormalizePreferences({sensors: ["sensor.test", "light.test", "climate.home"], controls: ["light.test", "climate.control", "scene.test", "script.test", "button.test", "lock.front", "light.missing"], cameras: ["camera.test"]}, invalid)
    m.states = []
    for each id in ["sensor.test", "light.test", "climate.home", "climate.control", "scene.test", "script.test", "button.test", "lock.front", "camera.test", "switch.unselected"]
        m.states.Push({entity_id: id, state: "on", attributes: {}})
    end for
    m.areas = {"light.test": "Kitchen"}
    m.home = {}
    m.shortcuts = {}
    m.cameras = {}
    m.settings = {}
    m.status = {}
    m.connectionMark = {}
    m.hint = {}
    m.top = {nodes: {}, findNode: function(id as string) as object
        if not m.nodes.DoesExist(id) then m.nodes[id] = {font: {}}
        return m.nodes[id]
    end function}
    m.tabs = []
    m.page = 0
    m.tabIndex = 0
    m.settingsOpen = false
    m.toolbarFocused = true
    m.statesFresh = false
    m.errorDetail = ""
    m.saveError = ""
    m.preferenceSaveError = ""
    saved = FormatJson(m.preferences)
    updateSurfaces()
    AssertScene(m.home.entityIds.Count() = 9 and m.home.states.Count() = 8, "mixed Home and Controls selections form one deduplicated union with matching states")
    AssertScene(m.home.entityIds[0] = "sensor.test" and m.home.entityIds[3] = "climate.control", "union preserves Home order then appends unseen Controls")
    AssertScene(HearthContains(m.home.entityIds, "light.missing") and HearthStateById(m.home.states, "light.missing") = invalid, "missing selections remain visible without inventing a state")
    AssertScene(not HearthContains(m.home.entityIds, "switch.unselected") and HearthStateById(m.home.states, "switch.unselected") = invalid, "unselected discovered devices never enter Home")
    AssertScene(FormatJson(m.home.controlIds) = FormatJson(m.preferences.controls) and not HearthContains(m.home.controlIds, "climate.home"), "combined display retains explicit control authorization separately")
    AssertScene(m.shortcuts.data.states.Count() = 6 and HearthStateById(m.shortcuts.data.states, "scene.test") <> invalid and HearthStateById(m.shortcuts.data.states, "script.test") <> invalid, "Scenes receives its own selected-control state data")
    AssertScene(m.home.areas["light.test"] = "Kitchen" and m.cameras.states.Count() = 1, "room and camera data survive combined Home updates")
    AssertScene(FormatJson(m.preferences) = saved and FormatJson(m.settings.preferences) = saved, "combining pages never migrates saved selections or Settings categories")
    m.preferences.sensors = []
    m.preferences.controls = []
    m.states = []
    for index = 0 to 29
        id = "sensor.home_" + index.ToStr()
        m.preferences.sensors.Push(id)
        m.states.Push({entity_id: id, state: "10", attributes: {}})
    end for
    for index = 0 to 47
        id = "light.control_" + index.ToStr()
        m.preferences.controls.Push(id)
        m.states.Push({entity_id: id, state: "off", attributes: {}})
    end for
    saved = FormatJson(m.preferences)
    updateSurfaces()
    AssertScene(m.home.entityIds.Count() = 78 and m.home.states.Count() = 78 and m.home.controlIds.Count() = 48, "full 30 Home and 48 Controls selections reach the combined surface without truncation")
    AssertScene(FormatJson(m.preferences) = saved, "full selections are not rewritten by rendering")
    m.preferences.controls[0] = m.preferences.sensors[0]
    updateSurfaces()
    AssertScene(m.home.entityIds.Count() = 77 and m.home.states.Count() = 77 and m.preferences.controls.Count() = 48, "overlap deduplicates display without dropping either saved selection")
end sub

sub TestHomeActions()
    m.config = {homeAssistant: {actions: [{entityId: "lock.front", domain: "lock", service: "unlock", name: "Unlock"}]}}
    m.preferences = {sensors: ["sensor.test", "climate.test", "light.home"], controls: ["light.control", "button.test", "lock.front", "lock.unsupported"]}
    m.states = [
        {entity_id: "sensor.test", state: "21", attributes: {unit_of_measurement: "°C"}}
        {entity_id: "climate.test", state: "heat", attributes: {temperature: 20, supported_features: 1, min_temp: 15, max_temp: 25}}
        {entity_id: "light.home", state: "off", attributes: {}}
        {entity_id: "light.control", state: "on", attributes: {}}
        {entity_id: "button.test", state: "unknown", attributes: {}}
        {entity_id: "lock.front", state: "locked", attributes: {}}
        {entity_id: "lock.unsupported", state: "locked", attributes: {}}
    ]
    m.areas = {"sensor.test": "Kitchen"}
    m.sentAction = invalid
    m.home.itemSelected = "sensor.test"
    homeActivated()
    AssertScene(m.dialogMode = "message" and Instr(1, m.top.dialog.message, "Room: Kitchen") > 0 and m.sentAction = invalid, "read-only Home status retains its value and room details")
    m.home.itemSelected = "climate.test"
    homeActivated()
    AssertScene(m.dialogMode = "message" and m.sentAction = invalid, "Home-only climate remains read-only")
    m.preferences.controls.Push("climate.test")
    homeActivated()
    AssertScene(m.dialogMode = "climate" and m.sentAction = invalid, "climate selected in Controls opens its existing dialog from Home")
    for each id in ["light.home", "light.control"]
        m.home.itemSelected = id
        homeActivated()
        AssertScene(m.sentAction.entityId = id and m.sentAction.service = "toggle", "Home-only and Controls-only lights retain toggle authorization")
    end for
    m.sentAction = invalid
    m.home.itemSelected = "button.test"
    homeActivated()
    AssertScene(m.dialogMode = "actions" and m.dialogActions[0].service = "press" and m.sentAction = invalid, "selected first-use button exposes its existing command from Home")
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction.entityId = "button.test" and m.sentAction.service = "press", "Home command selection submits the supported action")
    m.sentAction = invalid
    m.home.itemSelected = "lock.front"
    homeActivated()
    AssertScene(m.dialogMode = "actions" and m.dialogActions[0].service = "unlock", "Home preserves explicitly configured control commands")
    m.home.itemSelected = "lock.unsupported"
    homeActivated()
    AssertScene(m.dialogMode = "message" and m.top.dialog.title = "Control not enabled" and m.sentAction = invalid, "combined Home does not invent commands for unsupported controls")
    m.states[2].state = "unavailable"
    m.home.itemSelected = "light.home"
    homeActivated()
    AssertScene(m.top.dialog.title = "Device unavailable" and m.sentAction = invalid, "unavailable Home toggle cannot submit an action")
    m.home.itemSelected = "light.missing"
    homeActivated()
    AssertScene(m.top.dialog.title = "Entity unavailable" and m.sentAction = invalid, "missing Home entity retains unavailable feedback")
end sub

sub TestSceneShortcuts()
    m.top.dialog = invalid
    m.config = {homeAssistant: {actions: [{entityId: "scene.test", domain: "scene", service: "reload", name: "Custom action"}]}}
    m.preferences = {controls: ["scene.test", "script.test"]}
    m.states = [{entity_id: "scene.test", state: "unknown", attributes: {}}, {entity_id: "script.test", state: "off", attributes: {}}]
    m.shortcuts.activate = "scene.test"
    m.sentAction = invalid
    shortcutActivated()
    AssertScene(m.top.dialog = invalid and m.sentAction.domain = "scene" and m.sentAction.service = "turn_on", "first-use scene runs directly, never a different configured command")
    m.shortcuts.activate = "script.test"
    shortcutActivated()
    AssertScene(m.sentAction.entityId = "script.test" and m.sentAction.domain = "script" and m.sentAction.service = "turn_on", "script shortcut uses its explicit turn_on service")
    m.sentAction = invalid
    m.busy = true
    shortcutActivated()
    AssertScene(m.sentAction = invalid, "busy shortcut cannot submit a duplicate command")
    m.busy = false
    m.preferences.controls = []
    shortcutActivated()
    AssertScene(m.sentAction = invalid and m.top.dialog <> invalid, "removed shortcut authorization blocks execution with feedback")
    m.preferences.controls = ["scene.test"]
    m.shortcuts.activate = "scene.test"
    m.states[0].state = "unavailable"
    shortcutActivated()
    AssertScene(m.sentAction = invalid, "unavailable scenes never run")
    m.shortcuts.activate = "light.test"
    shortcutActivated()
    AssertScene(m.sentAction = invalid, "shortcut route cannot run other device domains")
end sub

sub TestConditionalScenesTab()
    m.top.dialog = invalid
    m.photo = {visible: false}
    m.video = {visible: false}
    m.settingsOpen = false
    m.toolbarFocused = true
    m.hint = {}
    m.home = {currentRoom: "Kitchen"}
    m.settings = {setFocus: sub(focused as boolean)
        m.focused = focused
    end sub}
    m.pages = []
    for index = 0 to 2
        m.pages.Push({hint: "Page hint", setFocus: sub(focused as boolean)
            m.focused = focused
        end sub})
    end for
    m.tabs = []
    m.tabLabels = []
    m.tabMarkers = []
    for each name in ["Home", "Scenes", "Cameras", "Settings"]
        m.tabs.Push({setFocus: sub(focused as boolean)
            m.focused = focused
        end sub})
        m.tabLabels.Push({text: name})
        m.tabMarkers.Push({})
    end for
    m.preferences = {controls: ["light.test"], cameras: ["camera.test"]}
    m.page = 0
    m.tabIndex = 0
    showPage()
    AssertScene(not m.tabs[1].visible and not m.tabLabels[1].visible and not m.tabMarkers[1].visible, "no selected shortcut hides the entire Scenes tab")
    AssertScene(onKeyEvent("right", true) and m.page = 2 and m.tabs[2].focused, "Right skips hidden Scenes and focuses Cameras")
    AssertScene(onKeyEvent("left", true) and m.page = 0, "Left skips hidden Scenes and returns to Home")
    for each id in ["scene.test", "script.test"]
        m.preferences.controls = [id]
        showPage()
        AssertScene(m.tabs[1].visible, "either selected shortcut domain reveals Scenes even before state discovery")
        AssertScene(onKeyEvent("right", true) and m.page = 1, "revealed Scenes is reachable")
        AssertScene(onKeyEvent("right", true) and m.page = 2, "Cameras follows Scenes when both are visible")
        AssertScene(onKeyEvent("left", true) and m.page = 1, "Left returns from Cameras to visible Scenes")
        m.preferences.controls = []
        showPage()
        AssertScene(m.page = 0 and m.tabIndex = 0 and m.tabs[0].focused and not m.pages[1].visible, "removing the last shortcut returns safely to Home")
    end for
    m.preferences.cameras = []
    showPage()
    AssertScene(not m.tabs[2].visible and not m.tabLabels[2].visible and not m.tabMarkers[2].visible, "no selected camera hides the entire Cameras tab")
    AssertScene(onKeyEvent("right", true) and m.tabIndex = 3 and m.tabs[3].focused, "Right skips both hidden tabs to Settings")
    AssertScene(onKeyEvent("left", true) and m.tabIndex = 0, "Left skips both hidden tabs to Home")
    m.preferences.cameras = ["camera.test"]
    showPage()
    AssertScene(m.tabs[2].visible, "saved cameras reveal their tab independently of availability")
    AssertScene(onKeyEvent("right", true) and m.page = 2, "revealed Cameras is reachable")
    AssertScene(onKeyEvent("down", true) and not m.toolbarFocused and m.pages[2].focused, "Down enters the camera page")
    dialogClosed()
    AssertScene(m.page = 2 and m.pages[2].focused, "closing a camera dialog restores the camera page")
    toToolbar()
    AssertScene(m.tabIndex = 2 and m.tabs[2].focused, "leaving Cameras focuses its new tab index")
    openSettings()
    AssertScene(m.settings.preferredRoom = "", "Settings opened from Cameras does not borrow the Home room")
    closeSettings()
    AssertScene(m.tabIndex = 3 and m.tabs[3].focused, "closing Settings focuses its new tab index")
    m.preferences.cameras = []
    showPage()
    AssertScene(m.page = 0 and not m.pages[2].visible, "removing the last camera returns safely to Home")
    m.tabIndex = 0
    m.preferences.controls = ["scene.test"]
    showPage()
    AssertScene(onKeyEvent("right", true) and m.tabIndex = 1, "Scenes remains reachable without cameras")
    AssertScene(onKeyEvent("right", true) and m.tabIndex = 3, "navigation skips Cameras when Scenes is visible")
    AssertScene(onKeyEvent("left", true) and m.tabIndex = 1, "reverse navigation skips Cameras when Scenes is visible")
    openSettings()
    AssertScene(m.settings.preferredRoom = "", "Settings opened from Scenes does not borrow the Home room")
    closeSettings()
    AssertScene(onKeyEvent("back", true) and m.page = 0 and m.tabIndex = 0, "Back returns to combined Home")
    openSettings()
    AssertScene(m.settings.preferredRoom = "Kitchen", "Settings opened from Home retains its current room")
    closeSettings()
end sub

sub TestLightDialogs()
    m.busy = false
    m.config = {}
    m.home = {brightness: "light.test"}
    m.preferences = {sensors: ["light.test"], controls: ["light.test"]}
    m.states = [{entity_id: "light.test", state: "on", attributes: {supported_color_modes: ["brightness"], brightness: 255}}]
    m.top = {}
    m.sentAction = invalid
    controlBrightness()
    AssertScene(m.dialogMode = "light" and m.lightChoices.Count() = 2, "Play opens a capability-aware light menu without commands")
    m.top.dialog.buttonSelected = 0
    dialogSelected()
    AssertScene(m.sentAction = invalid, "closing light controls sends no command")
    controlBrightness()
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.top.dialog.title = "Brightness" and m.lightChoices[1].action.data.brightness_pct = 90, "brightness submenu decreases by ten points")
    AssertScene(m.lightChoices.Count() = 6, "full brightness hides increase and retains four presets")
    m.top.dialog.buttonSelected = 5
    dialogSelected()
    AssertScene(m.sentAction.entityId = "light.test" and m.sentAction.data.brightness_pct = 100, "full brightness preset sends bounded value")
    m.states[0].attributes.brightness = 5
    showLightDialog("light.test", "brightness_pct")
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction.data.brightness_pct = 0, "decrease clamps at zero brightness")
    m.sentAction = invalid
    showLightDialog("light.test", "brightness_pct")
    m.top.dialog.buttonSelected = 0
    dialogSelected()
    AssertScene(m.lightChoices[1].field = "brightness_pct" and m.sentAction = invalid, "Back restores light categories without sending")
    m.errorDetail = "States request failed."
    m.lastRefreshText = ""
    controlBrightness()
    AssertScene(m.dialogMode = "message" and m.top.dialog.title = "Home Assistant status", "Play prioritizes error details over light controls")
    AssertScene(m.sentAction = invalid and Instr(1, m.top.dialog.message, m.errorDetail) > 0, "error details retain failure without sending")
    m.top.dialog = invalid
    AssertScene(onKeyEvent("play", true) and m.dialogMode = "message", "bubbled Play opens error details")
    m.errorDetail = ""
    controlBrightness()
    AssertScene(m.dialogMode = "light", "light controls return after errors clear")
    m.top.dialog = invalid
    m.preferences.controls = []
    controlBrightness()
    AssertScene(m.top.dialog = invalid, "Home-only light cannot open advanced controls")
    m.preferences.controls = ["light.test"]
    showLightDialog("light.test", "brightness_pct")
    m.preferences.controls = []
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction = invalid, "removing Controls selection while light dialog is open blocks submission")
    m.preferences.controls = ["light.test"]
    m.states[0].attributes = {supported_color_modes: ["color_temp", "hs"], brightness: 128, min_color_temp_kelvin: 2000, max_color_temp_kelvin: 6500, color_temp_kelvin: 6400}
    controlBrightness()
    AssertScene(m.lightChoices.Count() = 4 and m.lightChoices[2].field = "color_temp_kelvin" and m.lightChoices[3].field = "hs_color", "light menu exposes reported temperature and color categories")
    m.top.dialog.buttonSelected = 2
    dialogSelected()
    AssertScene(m.lightChoices[2].action.data.color_temp_kelvin = 6500, "temperature increase clamps to reported maximum")
    m.top.dialog.buttonSelected = 2
    dialogSelected()
    AssertScene(m.sentAction.service = "turn_on" and m.sentAction.data.color_temp_kelvin = 6500, "temperature uses Kelvin service payload")
    showLightDialog("light.test", "hs_color")
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction.data.hs_color[0] = 0 and m.sentAction.data.hs_color[1] = 100, "Red uses the supported native HS mode")
    m.sentAction = invalid
    showLightDialog("light.test", "hs_color")
    m.states[0].attributes.supported_color_modes = ["color_temp"]
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction = invalid, "removed color capability blocks an open dialog's stale choice")
    showLightDialog("light.test", "color_temp_kelvin")
    m.states[0].attributes.max_color_temp_kelvin = 5000
    m.top.dialog.buttonSelected = 2
    dialogSelected()
    AssertScene(m.sentAction = invalid, "changed temperature bounds block an open dialog's stale choice")
    m.states[0].attributes = {supported_color_modes: ["color_temp"], min_mireds: 153, max_mireds: 500, color_temp: 490}
    showLightDialog("light.test", "color_temp")
    m.top.dialog.buttonSelected = 2
    dialogSelected()
    AssertScene(m.sentAction.data.color_temp = 500, "legacy mired increase clamps and retains legacy service key")
    m.sentAction = invalid
    showLightDialog("light.test", "color_temp")
    m.busy = true
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction = invalid, "busy dialog cannot submit duplicate actions")
    m.busy = false
    showLightDialog("light.test", "color_temp")
    m.states[0].state = "unavailable"
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction = invalid, "unavailable light blocks stale dialog submission")
    m.states[0].state = "on"
    m.states[0].attributes = {supported_color_modes: ["onoff"]}
    m.top.dialog = invalid
    controlBrightness()
    AssertScene(m.top.dialog = invalid, "onoff-only light has no advanced menu")
end sub

sub TestClimateDialogs()
    m.config = {}
    m.preferences = {controls: ["climate.test"]}
    m.states = [{entity_id: "climate.test", state: "heat", attributes: {friendly_name: "Thermostat", supported_features: 25, temperature: 20, current_temperature: 19, temperature_unit: "°C", min_temp: 15, max_temp: 25, target_temp_step: 0.5, hvac_modes: ["off", "heat"], fan_mode: "auto", fan_modes: ["auto", "on"], preset_mode: "none", preset_modes: ["none", "eco", "comfort"]}}]
    m.sentAction = invalid
    activateControl("climate.test")
    AssertScene(m.dialogMode = "climate" and m.sentAction = invalid, "opening thermostat controls never changes the device")
    m.top.dialog.buttonSelected = ClimateFieldIndex("temperature")
    dialogSelected()
    AssertScene(m.climateChoices[1].action.data.temperature = 19.5 and m.climateChoices[2].action.data.temperature = 20.5, "temperature controls use the reported half-degree step")
    m.top.dialog.buttonSelected = 0
    dialogSelected()
    AssertScene(ClimateFieldIndex("hvac_mode") > 0 and m.sentAction = invalid, "Back restores the thermostat menu without sending")
    m.top.dialog.buttonSelected = 0
    dialogSelected()
    AssertScene(m.top.dialog.close and m.sentAction = invalid, "closing thermostat controls is non-mutating")
    showClimateDialog("climate.test", "hvac_mode")
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction.service = "set_hvac_mode" and m.sentAction.data.hvac_mode = "off", "mode selection sends the supported mode, not a toggle")
    showClimateDialog("climate.test", "fan_mode")
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction.service = "set_fan_mode" and m.sentAction.data.fan_mode = "on", "fan selection sends its reported option")
    showClimateDialog("climate.test")
    AssertScene(ClimateFieldIndex("preset_mode") > 0, "thermostat menu includes supported presets alongside temperature HVAC and fan")
    m.top.dialog.buttonSelected = ClimateFieldIndex("preset_mode")
    dialogSelected()
    AssertScene(m.climateChoices.Count() = 3 and m.climateChoices[1].action.data.preset_mode = "eco", "preset menu shows only alternatives to current reported mode")
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction.service = "set_preset_mode" and m.sentAction.data.preset_mode = "eco", "preset selection sends the reported preset")
    m.sentAction = invalid
    showClimateDialog("climate.test", "preset_mode")
    m.states[0].attributes.preset_modes = ["none"]
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction = invalid, "removed preset blocks a stale thermostat menu choice")
    m.states[0].attributes.preset_modes = ["none", "eco", "comfort"]
    showClimateDialog("climate.test", "preset_mode")
    m.preferences.controls = []
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction = invalid, "preset requires selected control at submission time")
    m.preferences.controls = ["climate.test"]
    m.states[0].attributes.temperature = 25
    showClimateDialog("climate.test", "temperature")
    AssertScene(m.climateChoices.Count() = 2 and m.climateChoices[1].action.data.temperature = 24.5, "upper limit removes the increase command")
    m.sentAction = invalid
    m.preferences.controls = []
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    AssertScene(m.sentAction = invalid, "removing authorization while a dialog is open prevents submission")
    m.preferences.controls = ["climate.test"]
    m.states[0].state = "heat_cool"
    m.states[0].attributes.supported_features = 11
    m.states[0].attributes.target_temp_low = 19
    m.states[0].attributes.target_temp_high = 22
    showClimateDialog("climate.test", "target_temp_low")
    m.top.dialog.buttonSelected = 2
    dialogSelected()
    AssertScene(m.sentAction.data.target_temp_low = 19.5 and m.sentAction.data.target_temp_high = 22, "range edit retains the other bound in the same request")
    m.sentAction = invalid
    m.states[0].state = "unavailable"
    activateControl("climate.test")
    AssertScene(m.dialogMode = "message" and m.sentAction = invalid, "unavailable thermostat cannot open actionable controls")
end sub

function ClimateFieldIndex(key as string) as integer
    for index = 1 to m.climateChoices.Count() - 1
        if m.climateChoices[index].field = key then return index
    end for
    return -1
end function

function TestExists(key as string) as boolean
    return m.values.DoesExist(key)
end function
function TestRead(key as string) as string
    return m.values[key]
end function
function TestWrite(key as string, value as string) as boolean
    if not m.writeOk then return false
    m.values[key] = value
    return true
end function
function TestFlush() as boolean
    return m.flushOk
end function
function TestDelete(key as string) as boolean
    m.values.Delete(key)
    return true
end function
sub AssertScene(condition as boolean, message as string)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
