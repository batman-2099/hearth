' Run with components/HearthSettings.brs; no SceneGraph initialization is needed.
sub Main()
    AssertSettings(HearthSettingsConnectionError("http://homeassistant.local:8123", "test-token") = "", "LAN origin accepted")
    AssertSettings(HearthSettingsConnectionError("https://ha.example/base", "test-token") = "", "HTTPS base path accepted")
    AssertSettings(HearthSettingsConnectionError("http://[::1]:8123", "test-token") = "", "IPv6 accepted")
    for each url in ["ftp://ha.local", "https://user:pass@ha.local", "https://ha.local?token=x", "https://ha.local/#fragment", "http://ha.local:0", "http://ha.local:65536", "http://ha.local/a\b", "http://ha local"]
        AssertSettings(HearthSettingsConnectionError(url, "test-token") <> "", "unsafe address rejected")
    end for
    for each token in ["", "has spaces", "line" + Chr(10) + "break"]
        AssertSettings(HearthSettingsConnectionError("https://ha.local", token) <> "", "unsafe token rejected")
    end for
    ' Native list nodes are provided by the brs runner; no SceneGraph init.
    m.top = {config: {}, states: [], preferences: {controls: []}, visible: false}
    m.list = {itemFocused: 2}
    m.heading = {}
    m.hint = {}
    m.detail = {}
    m.save = {IsInFocusChain: SettingsTestUnfocused}
    m.saveGroup = {}
    m.draftConnection = {url: "", token: ""}
    m.connectionDirty = false
    m.mainPosition = 1
    m.preferencesPending = false
    m.preferencesFeedback = ""
    m.mode = "picker"
    m.pickerKind = "controls"
    m.pickerLimit = 2
    m.picked = []
    m.rooms = ["", "Room", "Other"]
    m.roomIndex = 0
    m.selectedOnly = false
    m.entities = [{id: "light.room", room: "Room", label: "Room / Light — light.room"}, {id: "switch.fan", room: "Other", label: "Unavailable — Other / Fan — switch.fan"}]
    settingsRenderPicker(2)
    m.list.content.getChild(0).title = "Unchanged filter node"
    settingsPickerSelected(2)
    AssertSettings(m.mode = "picker" and m.picked.count() = 1 and m.picked[0] = "light.room", "first device toggles without leaving picker")
    AssertSettings(m.list.content.getChild(0).title = "Unchanged filter node", "toggle does not rebuild the list")
    AssertSettings(Instr(1, m.detail.text, "light.room") > 0, "focused detail exposes complete entity ID")
    AssertSettings(m.top.preferencesChanged = invalid, "draft selection is not committed by toggling")
    settingsPickerSelected(0)
    AssertSettings(m.visibleEntities.count() = 1 and m.visibleEntities[0].id = "light.room", "room filter excludes other rooms")
    settingsPickerSelected(0)
    settingsPickerSelected(1)
    AssertSettings(m.visibleEntities.count() = 0 and m.picked.count() = 1, "combined empty filter preserves hidden selection")
    m.roomIndex = 0
    settingsRenderPicker(2)
    AssertSettings(m.visibleEntities.count() = 1, "selected-only shows selected entities")
    settingsPickerSelected(2)
    AssertSettings(m.visibleEntities.count() = 0 and m.list.content.getChildCount() = 2, "selected-only deselection removes only the affected row")
    m.selectedOnly = false
    settingsRenderPicker(2)
    settingsPickerSelected(2)
    settingsPickerSelected(3)
    m.pickerLimit = 1
    settingsPickerSelected(3)
    settingsPickerSelected(3)
    AssertSettings(m.picked.count() = 1, "limit refuses additions without dropping existing selections")
    settingsSaveSelection()
    AssertSettings(m.top.preferencesChanged.controls[0] = "light.room" and m.mode = "picker" and m.preferencesPending, "Save requests persistence without leaving picker")
    m.top.preferencesChanged = invalid
    settingsSaveSelection()
    settingsPickerSelected(2)
    onKeyEvent("back", true)
    AssertSettings(m.top.preferencesChanged = invalid and m.picked.count() = 1 and m.mode = "picker", "pending save blocks duplicate submission, edits and navigation")
    m.top.preferencesSaveResult = {ok: false, error: "Preference storage failed."}
    settingsPreferencesSaveResult()
    settingsFocusChanged()
    AssertSettings(not m.preferencesPending and m.mode = "picker" and m.picked[0] = "light.room", "failed picker save retains draft")
    AssertSettings(m.hint.text = "Preference storage failed.", "picker failure survives focus update")
    settingsSaveSelection()
    m.top.preferences = m.top.preferencesChanged
    m.top.preferencesSaveResult = {ok: true, error: ""}
    settingsPreferencesSaveResult()
    AssertSettings(m.mode = "main" and not m.preferencesPending, "successful acknowledgment leaves picker")
    m.top.preferences = m.top.preferencesChanged
    m.top.preferencesChanged = invalid
    m.top.states = [{entity_id: "light.room", state: "off", attributes: {}}, {entity_id: "switch.fan", state: "unavailable", attributes: {}}]
    m.top.areas = {"light.room": "Room"}
    settingsOpenPicker("controls")
    AssertSettings(m.roomIndex = 0 and m.visibleEntities.count() = 2, "omitted preferred room shows all rooms")
    m.top.preferredRoom = "Other"
    settingsOpenPicker("controls")
    AssertSettings(m.rooms[m.roomIndex] = "Other" and m.visibleEntities.count() = 1 and m.visibleEntities[0].id = "switch.fan", "preferred room can hide saved devices")
    AssertSettings(m.picked.count() = 1 and m.picked[0] = "light.room" and m.top.preferences.controls[0] = "light.room", "room default preserves hidden saved selections")
    m.top.preferredRoom = "Room"
    settingsOpenPicker("controls")
    AssertSettings(m.rooms[m.roomIndex] = "Room" and m.visibleEntities.count() = 1 and m.visibleEntities[0].id = "light.room", "preferred room filters initial devices")
    AssertSettings(m.picked.count() = 1 and m.picked[0] = "light.room", "initial room retains saved selections")
    for i = 1 to m.rooms.count()
        settingsPickerSelected(0)
        if m.roomIndex = 0 then exit for
    end for
    AssertSettings(m.roomIndex = 0 and m.visibleEntities.count() = 2, "All rooms remains reachable from preferred room")
    m.top.preferredRoom = "Missing room"
    settingsOpenPicker("controls")
    AssertSettings(m.roomIndex = 0 and m.visibleEntities.count() = 2, "unavailable preferred room falls back to all rooms")
    m.top.preferredRoom = ""
    settingsOpenPicker("controls")
    AssertSettings(m.roomIndex = 0 and m.visibleEntities.count() = 2, "empty preferred room shows all rooms")
    settingsPickerSelected(3)
    onKeyEvent("back", true)
    AssertSettings(m.top.preferencesChanged = invalid and m.top.preferences.controls.count() = 1, "Back discards unsaved device selection")
    m.top.states = []
    m.top.preferences = {controls: ["switch.missing"]}
    settingsOpenPicker("controls")
    AssertSettings(m.entities.count() = 1 and m.entities[0].id = "switch.missing", "missing selected entity remains removable")
    settingsPickerSelected(1)
    AssertSettings(m.visibleEntities.count() = 1, "selected-only retains unavailable selection")
    settingsMain()
    ' Exercise discovery rather than injecting picker entities.
    m.top.config = {homeAssistant: {actions: [{entityId: "lock.front", domain: "lock", service: "unlock", name: "Unlock"}]}}
    m.top.states = [
        {entity_id: "lock.front", state: "locked", attributes: {friendly_name: "Front door"}}
        {entity_id: "light.kitchen", state: "on", attributes: {friendly_name: "Kitchen light"}}
        {entity_id: "sensor.temperature", state: "22", attributes: {}}
        {entity_id: "camera.porch", state: "idle", attributes: {}}
        {entity_id: "switch.offline", state: "unavailable", attributes: {}}
    ]
    m.top.areas = {"lock.front": "Entry", "light.kitchen": "Kitchen"}
    m.top.preferences = {controls: ["lock.front"]}
    settingsOpenPicker("controls")
    AssertSettings(m.entities.count() = 3, "live discovery includes standard controls and explicit configured action, excludes unrelated domains")
    AssertSettings(m.entities[0].id = "lock.front" and m.entities[0].room = "Entry", "discovery applies areas and sorting")
    settingsPickerSelected(2)
    settingsSaveSelection()
    m.top.preferences = m.top.preferencesChanged
    m.top.preferencesSaveResult = {ok: true, error: ""}
    settingsPreferencesSaveResult()
    settingsOpenPicker("controls")
    AssertSettings(m.entities[0].id = "lock.front" and not HearthContains(m.picked, "lock.front"), "configured action remains discoverable after saved deselection")
    settingsPickerSelected(2)
    AssertSettings(HearthContains(m.picked, "lock.front"), "configured action can be reselected through actual discovery")
    m.top.preferencesChanged = invalid
    onKeyEvent("back", true)
    AssertSettings(m.top.preferencesChanged = invalid and m.top.preferences.controls.count() = 0, "discovery picker cancel preserves committed selections")
    settingsOpenPicker("sensors")
    AssertSettings(m.entities.count() = 3, "Home discovery uses live supported domains")
    onKeyEvent("back", true)
    settingsOpenPicker("cameras")
    AssertSettings(m.entities.count() = 1 and m.entities[0].id = "camera.porch", "camera discovery uses live states")
    onKeyEvent("back", true)
    m.top.states = [
        {entity_id: "button.first_use", state: "unknown", attributes: {}}
        {entity_id: "scene.first_use", state: "unknown", attributes: {}}
        {entity_id: "scene.offline", state: "unavailable", attributes: {}}
        {entity_id: "light.unknown", state: "unknown", attributes: {}}
    ]
    m.top.config = {}
    m.top.preferences = {controls: ["scene.missing"]}
    settingsOpenPicker("controls")
    AssertSettings(m.entities.count() = 5, "picker retains first-use, unavailable, and missing controls")
    for each entity in m.entities
        if entity.id = "button.first_use" or entity.id = "scene.first_use"
            AssertSettings(Instr(1, entity.label, "Unavailable") = 0, "first-use button or scene is not labeled unavailable: " + entity.id)
        else
            AssertSettings(Instr(1, entity.label, "Unavailable") = 1, "unknown light, unavailable scene, and missing scene stay labeled unavailable: " + entity.id)
        end if
    end for
    onKeyEvent("back", true)
    for each choice in [
        {field: "theme", labels: ["Dark", "Light"], values: ["dark", "light"]}
        {field: "wallpaper", labels: ["Slate", "None"], values: ["slate", "none"]}
        {field: "clock24", labels: ["24-hour", "12-hour"], values: [true, false]}
    ]
        settingsChoices(choice.field, "Choose", choice.labels, choice.values)
        m.list.itemSelected = 2
        settingsSelected()
        AssertSettings(m.mode = "choice" and m.preferencesPending, "choice waits for persistence")
        m.top.preferencesChanged = invalid
        settingsSelected()
        AssertSettings(m.top.preferencesChanged = invalid, "choice blocks duplicate save")
        m.top.preferencesSaveResult = {ok: false, error: "Choice failed."}
        settingsPreferencesSaveResult()
        settingsInputsChanged()
        AssertSettings(m.mode = "choice" and m.hint.text = "Choice failed.", "failed choice stays visible for retry")
        settingsSelected()
        AssertSettings(m.top.preferencesChanged[choice.field] = choice.values[1], "choice retry preserves chosen value")
        m.top.preferences = m.top.preferencesChanged
        m.top.preferencesSaveResult = {ok: true, error: ""}
        settingsPreferencesSaveResult()
        AssertSettings(m.mode = "main", "choice success returns to main")
        m.top.preferencesChanged = invalid
        settingsChoices(choice.field, "Choose", choice.labels, choice.values)
        m.list.itemSelected = 0
        settingsSelected()
        AssertSettings(m.mode = "main" and m.top.preferencesChanged = invalid, "choice cancel does not save")
    end for
    m.editField = "refreshSeconds"
    for each value in ["", "4", "3601", "5.5", "abc"]
        m.dialog = {text: value, buttonSelected: 0, close: false}
        settingsKeyboardSelected()
        AssertSettings(not m.dialog.close and m.top.preferencesChanged = invalid, "invalid refresh stays open without save")
    end for
    m.dialog = {text: "45", buttonSelected: 0, close: false}
    settingsKeyboardSelected()
    AssertSettings(m.preferencesPending and not m.dialog.close and m.top.preferencesChanged.refreshSeconds = 45, "refresh waits for acknowledgment")
    m.top.preferencesChanged = invalid
    settingsKeyboardSelected()
    AssertSettings(m.top.preferencesChanged = invalid, "refresh blocks duplicate save")
    m.top.preferencesSaveResult = {ok: false, error: "Refresh failed."}
    settingsPreferencesSaveResult()
    AssertSettings(not m.dialog.close and m.dialog.text = "45" and m.dialog.message = "Refresh failed.", "refresh failure keeps keyboard text and visible error")
    settingsKeyboardSelected()
    m.top.preferences = m.top.preferencesChanged
    m.top.preferencesSaveResult = {ok: true, error: ""}
    settingsPreferencesSaveResult()
    AssertSettings(m.dialog.close and not m.preferencesPending, "refresh success closes keyboard")
    m.top.preferencesChanged = invalid
    m.dialog = {text: "90", buttonSelected: 1, close: false}
    settingsKeyboardSelected()
    AssertSettings(m.dialog.close and m.top.preferencesChanged = invalid and m.top.preferences.refreshSeconds = 45, "refresh cancel preserves saved value")
    m.dialog = invalid
    m.draftConnection = {url: "https://ha.local/base///", token: "test-token"}
    m.connectionDirty = true
    settingsSaveConnection()
    AssertSettings(m.connectionDirty and m.top.connectionChanged.url = "https://ha.local/base", "save request normalizes URL but retains dirty draft")
    m.top.connectionSaveResult = {ok: false, error: "Storage failed."}
    settingsConnectionSaveResult()
    m.top.connection = {url: "https://old.local", token: "old-token"}
    settingsConnectionChanged()
    AssertSettings(m.connectionDirty and m.draftConnection.token = "test-token", "rejected save retains draft despite connection updates")
    AssertSettings(Instr(1, m.hint.text, "Storage failed.") > 0, "save error remains visible")
    failureFeedback = m.hint.text
    settingsRenderMain()
    AssertSettings(m.hint.text = failureFeedback and m.connectionDirty, "surface updates preserve failed save feedback and draft")
    settingsSaveConnection()
    m.top.connectionSaveResult = {ok: true, error: ""}
    settingsConnectionSaveResult()
    AssertSettings(not m.connectionDirty, "only successful acknowledgment clears dirty state")
    successFeedback = m.hint.text
    settingsRenderMain()
    AssertSettings(m.hint.text = successFeedback, "surface updates preserve acknowledged save feedback")
    for each url in ["http://ha.local:8123/base", "http://ha..local", "http://ha.local/a@b", "https://ha.local?query"]
        AssertSettings((HearthSettingsConnectionError(url, "test-token") = "") = HearthConnectionValid({url: url, token: "test-token"}), "settings and shared connection policy agree")
    end for
    m.top.states = [{entity_id: "climate.room", state: "heat", attributes: {friendly_name: "Thermostat"}}, {entity_id: "sensor.room", state: "20", attributes: {}}]
    m.top.preferences = {controls: []}
    m.top.preferredRoom = ""
    settingsOpenPicker("controls")
    AssertSettings(m.visibleEntities.Count() = 1 and m.visibleEntities[0].id = "climate.room", "thermostats are discoverable as controls without configured commands")
    settingsPickerSelected(2)
    settingsSaveSelection()
    AssertSettings(m.top.preferencesChanged.controls[0] = "climate.room", "thermostat selection uses the normal explicit Save flow")
    TestDeviceNameEditor()
    TestScenePicker()
    TestDisplayPreferences()
    print "HEARTH_SETTINGS_TESTS_PASSED"
end sub

sub TestScenePicker()
    m.preferencesPending = false
    m.top.hasFocus = function() as boolean
        return false
    end function
    m.mode = "main"
    m.top.config = {}
    m.top.preferredRoom = ""
    m.top.areas = {}
    m.top.states = [{entity_id: "scene.test", state: "unknown", attributes: {}}, {entity_id: "script.test", state: "off", attributes: {}}, {entity_id: "light.test", state: "off", attributes: {}}]
    m.top.preferences = {controls: ["light.test", "scene.missing"], cameras: ["camera.keep"]}
    m.list.itemSelected = 3
    settingsSelected()
    AssertSettings(m.pickerKind = "scenes" and m.entities.Count() = 3 and m.picked[0] = "scene.missing", "Scenes opens its own picker including missing selections but excluding ordinary controls")
    AssertSettings(m.pickerLimit = 47, "scene capacity reserves slots for existing controls")
    m.picked = ["scene.test", "script.test"]
    settingsSaveSelection()
    AssertSettings(m.top.preferencesChanged.controls.Count() = 3 and HearthContains(m.top.preferencesChanged.controls, "light.test"), "saving scenes preserves unrelated controls")
    AssertSettings(HearthContains(m.top.preferencesChanged.controls, "script.test") and not HearthContains(m.top.preferencesChanged.controls, "scene.missing"), "scene save replaces only shortcut selections")
    AssertSettings(m.top.preferencesChanged.cameras[0] = "camera.keep", "scene save preserves camera selections")
    m.top.preferencesSaveResult = {ok: true}
    settingsPreferencesSaveResult()
    m.top.preferencesChanged = invalid
    settingsOpenPicker("scenes")
    m.picked = []
    onKeyEvent("back", true)
    AssertSettings(m.top.preferencesChanged = invalid, "scene picker cancel does not save changes")
    m.top.states = [{entity_id: "scene.one", state: "unknown", attributes: {friendly_name: "Evening"}}, {entity_id: "scene.two", state: "unknown", attributes: {friendly_name: "Evening"}}]
    m.top.preferences = {controls: []}
    settingsOpenPicker("scenes")
    AssertSettings(m.entities[0].label <> m.entities[1].label, "same-name entities remain distinguishable even within one domain")
    for each entity in m.entities
        AssertSettings(Instr(1, entity.label, entity.id) > 0, "duplicate rows include their unique entity ID")
    end for
end sub

sub TestDeviceNameEditor()
    m.preferencesPending = false
    m.top.preferencesChanged = invalid
    m.top.preferences = {sensors: ["light.test"], controls: ["light.test", "scene.test"], cameras: ["camera.missing"], deviceNames: {"scene.test": "Evening"}}
    m.top.config = {homeAssistant: {entityNames: {"light.test": "File lamp"}}}
    m.top.states = [{entity_id: "light.test", state: "on", attributes: {friendly_name: "Original lamp"}}, {entity_id: "scene.test", state: "unknown", attributes: {}}]
    m.top.scene = {}
    m.top.getScene = function() as object
        return m.scene
    end function
    _brs_.mockComponent("KeyboardDialog", {close: false, observeField: sub(field as string, callback as string)
    end sub, unobserveField: sub(field as string)
    end sub})
    m.mode = "main"
    m.list.itemSelected = 4
    settingsSelected()
    AssertSettings(m.mode = "names" and m.nameIds.Count() = 3 and m.nameIds[2] = "camera.missing", "editor deduplicates selected devices and retains missing devices for rename/reset")
    m.list.itemSelected = 1
    settingsSelected()
    AssertSettings(m.dialog.text = "File lamp", "keyboard starts with the current displayed name")
    m.dialog.text = "  Desk  "
    m.dialog.buttonSelected = 0
    settingsKeyboardSelected()
    AssertSettings(m.preferencesPending and not m.dialog.close, "rename waits for persistence acknowledgment")
    AssertSettings(m.top.preferencesChanged.deviceNames["light.test"] = "Desk" and m.top.preferencesChanged.deviceNames["scene.test"] = "Evening", "rename trims input and preserves other aliases")
    AssertSettings(m.top.preferences.deviceNames["light.test"] = invalid and m.top.preferencesChanged.controls.Count() = 2, "pending rename leaves current names and control selections unchanged")
    m.top.preferencesSaveResult = {ok: false, error: "Save failed."}
    settingsPreferencesSaveResult()
    AssertSettings(not m.dialog.close and m.dialog.text = "  Desk  " and m.dialog.message = "Save failed.", "failed rename retains draft and feedback for retry")
    settingsKeyboardSelected()
    m.top.preferences = m.top.preferencesChanged
    m.top.config.deviceNames = m.top.preferences.deviceNames
    m.top.preferencesSaveResult = {ok: true, error: ""}
    settingsPreferencesSaveResult()
    AssertSettings(m.dialog.close, "successful rename closes the editor")
    m.top.visible = true
    m.list.setFocus = sub(focus as boolean)
    end sub
    settingsDialogClosed()
    AssertSettings(m.mode = "names" and m.list.content.GetChild(1).title = "Desk" and m.list.jumpToItem = 1, "save returns to renamed device in the list")
    m.top.preferencesChanged = invalid
    m.list.itemSelected = 1
    settingsSelected()
    m.dialog.text = String(65, "a")
    m.dialog.buttonSelected = 0
    settingsKeyboardSelected()
    AssertSettings(not m.preferencesPending and m.top.preferencesChanged = invalid and not m.dialog.close, "oversized name stays editable without saving")
    m.dialog.buttonSelected = 2
    settingsKeyboardSelected()
    AssertSettings(m.dialog.close and m.top.preferences.deviceNames["light.test"] = "Desk", "Cancel keeps the saved name")
    settingsDialogClosed()
    settingsSelected()
    m.dialog.buttonSelected = 1
    settingsKeyboardSelected()
    AssertSettings(not m.top.preferencesChanged.deviceNames.DoesExist("light.test") and m.top.preferencesChanged.deviceNames["scene.test"] = "Evening", "Reset removes only this device's local name")
end sub

sub AssertSettings(condition as boolean, message as string)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub

function SettingsTestUnfocused() as boolean
    return false
end function

sub TestDisplayPreferences()
    defaults = HearthDefaultPreferences(invalid, invalid)
    AssertSettings(defaults.density = "compact" and not defaults.sensorAlerts.enabled, "density stays compact and alerts require opt-in")
    raw = ParseJson("{""density"":""comfortable"",""sensorAlerts"":{""enabled"":true,""batteryPercent"":25,""openDoors"":false,""temperatureUnit"":""°F"",""temperatureMin"":32,""temperatureMax"":86}}")
    normalized = HearthNormalizePreferences(raw, defaults)
    normalized = ParseJson(FormatJson(normalized))
    AssertSettings(normalized.DoesExist("sensorAlerts") and normalized.sensorAlerts.DoesExist("batteryPercent") and normalized.sensorAlerts.DoesExist("temperatureMin"), "native JSON preserves camelCase preference keys")
    restored = HearthNormalizePreferences(normalized, defaults)
    AssertSettings(restored.density = "comfortable" and restored.sensorAlerts.batteryPercent = 25 and not restored.sensorAlerts.openDoors and restored.sensorAlerts.temperatureUnit = "°F", "density and alert options roundtrip")
    sensor = {entity_id: "sensor.temperature", state: "0", attributes: {device_class: "temperature", unit_of_measurement: "°C"}}
    AssertSettings(HearthSensorAlert(sensor, restored.sensorAlerts) = "", "temperature at lower limit is not an alert after unit conversion")
    sensor.state = "-1"
    AssertSettings(HearthSensorAlert(sensor, restored.sensorAlerts) = "Alert: Cold", "temperature below converted lower limit alerts")
    sensor.state = "30"
    AssertSettings(HearthSensorAlert(sensor, restored.sensorAlerts) = "", "temperature at upper limit is not an alert")
    sensor.state = "31"
    AssertSettings(HearthSensorAlert(sensor, restored.sensorAlerts) = "Alert: Hot", "temperature above converted upper limit alerts")
    sensor.state = "31oops"
    AssertSettings(HearthSensorAlert(sensor, restored.sensorAlerts) = "", "malformed sensor numbers do not alert")
    sensor = {entity_id: "sensor.battery", state: "25", attributes: {device_class: "battery", unit_of_measurement: "%"}}
    AssertSettings(HearthSensorAlert(sensor, restored.sensorAlerts) = "Alert: Low battery", "battery threshold is inclusive")
    sensor.state = "26"
    AssertSettings(HearthSensorAlert(sensor, restored.sensorAlerts) = "", "battery above threshold is normal")
    sensor = {entity_id: "binary_sensor.door", state: "on", attributes: {device_class: "door"}}
    AssertSettings(HearthSensorAlert(sensor, restored.sensorAlerts) = "", "door alerts honor opt-out")
    restored.sensorAlerts.openDoors = true
    AssertSettings(HearthSensorAlert(sensor, restored.sensorAlerts) = "Alert: Open", "open selected door can alert")
    sensor.state = "off"
    AssertSettings(HearthSensorAlert(sensor, restored.sensorAlerts) = "", "closed doors do not alert")
    invalidConfig = HearthNormalizeSensorAlerts({"enabled": "true", "batteryPercent": "NaN", "temperatureMin": 40, "temperatureMax": 20})
    AssertSettings(not invalidConfig.enabled and invalidConfig.batteryPercent = 20 and invalidConfig.temperatureMin = invalid and invalidConfig.temperatureMax = invalid, "normalization rejects invalid booleans numbers and inverted limits")
    m.preferencesPending = false
    m.top.preferences = restored
    m.top.preferencesChanged = invalid
    m.editField = "temperatureMin"
    m.dialog = {text: "90", buttonSelected: 0, close: false}
    settingsKeyboardSelected()
    AssertSettings(not m.preferencesPending and not m.dialog.close and m.top.preferencesChanged = invalid, "editor rejects lower limit above upper limit")
    m.dialog.text = "20F"
    settingsKeyboardSelected()
    AssertSettings(not m.preferencesPending, "editor rejects units and numeric suffixes")
    m.dialog.text = ""
    settingsKeyboardSelected()
    AssertSettings(m.preferencesPending and m.top.preferencesChanged.sensorAlerts.temperatureMin = invalid, "blank temperature disables only that limit")
end sub
