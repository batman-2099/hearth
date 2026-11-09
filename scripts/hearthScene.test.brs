sub Main()
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
    m.preferences = HearthNormalizePreferences({controls: ["light.keep"]}, invalid)
    m.savedPreferences = m.preferences
    m.registry.values.preferences = FormatJson(m.preferences)
    m.settings.preferencesChanged = {controls: ["switch.new"], refreshSeconds: 45}
    preferencesChanged()
    AssertScene(not m.settings.preferencesSaveResult.ok, "preference failure is acknowledged")
    AssertScene(m.preferences.controls[0] = "light.keep" and m.savedPreferences.controls[0] = "light.keep", "failed preferences never become active")
    AssertScene(ParseJson(m.registry.values.preferences).controls[0] = "light.keep", "failed preference flush restores previous buffer")
    failureBanner = m.status.text
    m.registry.flushOk = true
    preferencesChanged()
    AssertScene(m.settings.preferencesSaveResult.ok and m.preferences.controls[0] = "switch.new", "retry applies preferences after successful persistence")
    AssertScene(ParseJson(m.registry.values.preferences).refreshSeconds = 45 and m.savedPreferences.controls[0] = "switch.new", "saved and active preference snapshots agree")
    AssertScene(m.preferenceSaveError = "" and m.status.text <> failureBanner, "successful retry clears stale failure feedback")
    _brs_.mockComponent("HearthTask", {observeField: sub(field as string, callback as string)
    end sub})
    m.home = {}
    m.controls = {}
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
    AssertScene(onKeyEvent("replay", true) and m.task.request.areas = invalid, "idle Replay also rediscovers rooms")
    _brs_.mockComponent("Dialog", {observeField: sub(field as string, callback as string)
    end sub})
    _brs_.mockFunction("startRequest", sub(op as string, action as object)
        m.sentAction = action
    end sub)
    m.busy = false
    m.controls = {brightness: "light.test"}
    m.states = [{entity_id: "light.test", state: "on", attributes: {supported_color_modes: ["brightness"], brightness: 255}}]
    m.top = {}
    controlBrightness()
    m.top.dialog.buttonSelected = 0
    dialogSelected()
    AssertScene(m.controls.dim = invalid and m.sentAction = invalid, "cancel brightness sends no device command")
    controlBrightness()
    m.top.dialog.buttonSelected = 2
    dialogSelected()
    controlDimmed()
    AssertScene(m.sentAction.entityId = "light.test" and m.sentAction.data.brightness_pct = 100, "Brighten clamps at full brightness")
    m.states[0].attributes.brightness = 5
    controlBrightness()
    m.top.dialog.buttonSelected = 1
    dialogSelected()
    controlDimmed()
    AssertScene(m.sentAction.data.brightness_pct = 0, "Dim clamps at zero brightness")
    m.sentAction = invalid
    m.errorDetail = "States request failed."
    m.lastRefreshText = ""
    controlBrightness()
    AssertScene(m.dialogMode = "message" and m.top.dialog.title = "Home Assistant status", "Play on a dimmable light prioritizes error details")
    AssertScene(m.sentAction = invalid and Instr(1, m.top.dialog.message, m.errorDetail) > 0, "error details retain the failure without sending a command")
    m.top.dialog = invalid
    AssertScene(onKeyEvent("play", true) and m.dialogMode = "message", "bubbled Play opens the same error details")
    m.errorDetail = ""
    controlBrightness()
    AssertScene(m.dialogMode = "brightness", "brightness is available again after errors clear")
    print "HEARTH_SCENE_TESTS_PASSED"
end sub

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
