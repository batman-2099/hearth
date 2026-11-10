sub Main()
    m.columns = 4
    m.rows = 3
    m.slotCount = m.columns * m.rows
    m.panes = [{indices: [], columns: 4, firstRow: 0}, {indices: [], columns: 1, firstRow: 0}]
    m.selection = 0
    m.ids = []
    m.items = []
    m.tiles = []
    m.empty = {}
    m.range = {}
    m.roomLabel = {}
    m.room = ""
    m.theme = HearthTheme("dark")
    m.top = {selected: 0, pendingId: "", focused: false, IsInFocusChain: function() as boolean
        return m.focused
    end function}
    for i = 0 to 29
        m.ids.push("sensor.test_" + i.toStr())
        m.items.push({title: "Sensor", value: "1", available: true, action: "[OK] Details"})
    end for
    for i = 0 to m.slotCount - 1
        m.tiles.push({node: {}, title: {font: {}}, body: {}, value: {font: {}}, alert: {}, border: {focused: false, hasFocus: HomeTestHasFocus, setFocus: HomeTestSetFocus}, toggle: {node: {}, track: {}, thumb: {}}})
    end for
    homeLayout()
    homeSelect(m.columns - 1)
    onKeyEvent("right", true)
    CheckHome(m.selection = m.columns - 1, "Right does not wrap into another row")
    homeSelect(27)
    onKeyEvent("down", true)
    onKeyEvent("down", true)
    CheckHome(m.selection = 29, "Down reaches the final stacked sensor")
    onKeyEvent("fastforward", true)
    CheckHome(m.selection = 29, "room navigation before discovery leaves selection intact")
    CheckHome(m.selection >= m.panes[1].firstRow and m.selection < m.panes[1].firstRow + m.rows, "selected sensor remains in its visible window")
    homeSelect(0)
    onKeyEvent("up", true)
    CheckHome(m.top.leave = true, "Up from the first row returns to navigation")
    homeSelect(1)
    m.top.itemSelected = ""
    onKeyEvent("OK", true)
    CheckHome(m.top.itemSelected = "" and homeHint(1) = "", "sensors neither activate nor advertise an action")
    m.top.entityIds = ["sensor.test_2", "sensor.test_1", "sensor.test_0"]
    m.top.states = [{entity_id: "sensor.test_1", state: "1", attributes: {friendly_name: "Sensor"}}]
    homeDataChanged()
    CheckHome(m.selection = 1 and m.ids[m.selection] = "sensor.test_1", "refresh preserves selected entity identity")
    CheckHome(m.tiles.Count() = 12, "refresh retains the fixed slot pool")
    CheckHome(Instr(1, m.tiles[7].border.audioGuideText, "Sensor, 1") > 0, "focused poster description includes title and reading")
    m.top.focused = true
    homeRender()
    CheckHome(m.tiles[7].border.hasFocus() and m.tiles[7].border.blendColor <> m.tiles[3].border.blendColor, "entering Home focuses and highlights the selected sensor")
    homeSelect(2)
    CheckHome(m.tiles[11].border.hasFocus() and m.tiles[11].border.blendColor <> m.tiles[7].border.blendColor and m.tiles[7].border.blendColor = m.tiles[3].border.blendColor, "navigation moves focus and removes the old highlight")
    m.top.focused = false
    homeRender()
    CheckHome(m.tiles[11].border.blendColor = m.tiles[7].border.blendColor, "leaving Home removes its active focus highlight")
    m.top.areas = {"sensor.test_2": "Bedroom", "sensor.test_1": "Kitchen"}
    homeDataChanged()
    CheckHome(m.room = "Other" and m.ids.Count() = 1 and m.ids[0] = "sensor.test_0", "unassigned entities retain their own room")
    onKeyEvent("fastforward", true)
    CheckHome(m.room = "Bedroom" and m.ids[0] = "sensor.test_2", "next room wraps and filters tiles")
    onKeyEvent("fastforward", true)
    CheckHome(m.room = "Kitchen" and m.ids[0] = "sensor.test_1", "rooms sort alphabetically before Other")
    onKeyEvent("OK", true)
    CheckHome(m.top.itemSelected = "", "changing rooms does not make sensors actionable")
    homeDataChanged()
    CheckHome(m.room = "Kitchen" and m.ids[0] = "sensor.test_1", "refresh preserves active room and entity")
    onKeyEvent("rewind", true)
    CheckHome(m.room = "Bedroom", "rewind selects previous room")
    m.top.entityIds = ["sensor.test_1"]
    homeDataChanged()
    CheckHome(m.room = "Kitchen" and m.ids.Count() = 1, "removing the active room selects a remaining room")
    m.top.entityIds = []
    homeDataChanged()
    onKeyEvent("fastforward", true)
    CheckHome(m.ids.Count() = 0 and m.rooms.Count() = 0 and m.roomLabel.text = "", "empty selections clear room navigation safely")
    m.top.areas = {}
    m.top.config = {}
    m.top.entityIds = ["sensor.reading", "climate.status", "climate.control", "light.status", "light.control", "light.relay", "scene.evening", "script.bedtime", "button.bell"]
    m.top.controlIds = ["climate.control", "light.control", "light.relay", "scene.evening", "script.bedtime", "button.bell"]
    m.top.states = []
    for each id in m.top.entityIds
        m.top.states.Push({entity_id: id, state: "off", attributes: {}})
    end for
    m.top.states[3].attributes = {supported_color_modes: ["brightness"]}
    m.top.states[4].attributes = {supported_color_modes: ["brightness"]}
    homeDataChanged()
    CheckHome(homeHint(0) = "" and homeHint(1) = "[OK] Details", "sensors omit actions while Home-only climate retains details")
    CheckHome(homeHint(2) = "[OK] Climate controls", "control-selected climate exposes climate controls")
    CheckHome(Instr(1, m.tiles[1].border.audioGuideText, "Climate controls") > 0, "Audio Guide describes climate controls")
    CheckHome(homeHint(3) = "[OK] Toggle", "Home-only light retains toggle without brightness")
    CheckHome(homeHint(4) = "[OK] Toggle     [Play] Light controls", "selected supported light exposes toggle and light controls")
    CheckHome(homeHint(5) = "[OK] Toggle", "unsupported control light omits brightness")
    CheckHome(homeHint(6) = "[OK] Activate" and homeHint(7) = "[OK] Run" and homeHint(8) = "[OK] Press", "scene script and button hints describe their actions")
    CheckHome(m.items[6].value = "Activate" and m.items[7].value = "Run" and m.items[8].value = "Press", "action tiles show verbs rather than raw state timestamps")
    for index = 6 to 8
        homeSelect(index)
        m.top.itemSelected = ""
        onKeyEvent("OK", true)
        CheckHome(m.top.itemSelected = m.ids[index], "control activation retains itemSelected event")
    end for
    for each index in [3, 5]
        homeSelect(index)
        m.top.brightness = ""
        handled = onKeyEvent("play", true)
        CheckHome(not handled and m.top.brightness = "", "Home-only and unsupported lights cannot emit brightness")
    end for
    homeSelect(4)
    handled = onKeyEvent("play", true)
    CheckHome(handled and m.top.brightness = "light.control", "supported selected control emits brightness")
    m.top.brightness = ""
    m.top.pendingId = "light.control"
    homeRender()
    handled = onKeyEvent("play", true)
    CheckHome(not handled and m.top.brightness = "" and homeHint(4) = "Sending…", "pending light suppresses brightness event and hint")
    CheckHome(Instr(1, m.tiles[4].border.audioGuideText, "Sending…") > 0 and Instr(1, m.tiles[4].border.audioGuideText, "Brightness") = 0, "pending Audio Guide describes sending instead of brightness")
    m.top.pendingId = ""
    m.top.states[4].state = "unavailable"
    homeDataChanged()
    handled = onKeyEvent("play", true)
    CheckHome(not handled and m.top.brightness = "" and homeHint(4) = "Device unavailable", "unavailable light suppresses brightness event and hint")
    m.top.states[4].state = "on"
    m.top.controlIds = []
    homeDataChanged()
    handled = onKeyEvent("play", true)
    CheckHome(not handled and m.top.brightness = "" and homeHint(4) = "[OK] Toggle", "removing Controls selection revokes brightness while retaining Home toggle")
    CheckHome(homeHint(2) = "[OK] Details" and homeHint(6) = "[OK] Details", "Home presence alone grants neither climate nor scene actions")
    m.top.entityIds = []
    for index = 0 to 77
        m.top.entityIds.Push("sensor.union_" + index.ToStr())
    end for
    m.top.entityIds.Push("sensor.union_0")
    m.top.entityIds.Push("sensor.union_77")
    homeDataChanged()
    CheckHome(m.ids.Count() = 78 and m.allIds.Count() = 78, "full union remains accessible and duplicate IDs appear once")
    homeSelect(0)
    for index = 1 to 77
        onKeyEvent("down", true)
    end for
    onKeyEvent("right", true)
    CheckHome(m.selection = 77 and m.ids[m.selection] = "sensor.union_77", "remote navigation reaches the final stacked sensor")
    CheckHome(m.panes[1].firstRow = 75 and m.tiles[11].node.visible and not m.tiles[0].node.visible, "sensor-only rooms stay stacked at the right")
    m.top.itemSelected = ""
    onKeyEvent("OK", true)
    CheckHome(m.top.itemSelected = "", "last sensor remains scrollable without activation")
    m.room = ""
    m.top.entityIds = ["light.a", "light.b", "light.c", "light.d", "sensor.a", "binary_sensor.b", "sensor.c", "sensor.d"]
    m.top.states = []
    homeDataChanged()
    homeSelect(5)
    m.top.itemSelected = ""
    onKeyEvent("OK", true)
    CheckHome(m.top.itemSelected = "" and homeHint(5) = "", "binary sensors are also non-clickable")
    CheckHome(m.panes[0].columns = 3 and m.panes[1].indices.Count() = 4, "mixed rooms reserve the right column for sensors and binary sensors")
    homeSelect(2)
    onKeyEvent("right", true)
    CheckHome(m.selection = 4, "Right from the controls edge enters the sensor at the same visible row")
    onKeyEvent("down", true)
    onKeyEvent("down", true)
    onKeyEvent("down", true)
    CheckHome(m.selection = 7 and m.panes[1].firstRow = 1 and m.panes[0].firstRow = 0, "sensor stack scrolls without moving controls")
    homeDataChanged()
    CheckHome(m.selection = 7 and m.panes[1].firstRow = 1, "refresh preserves sensor selection and scrolling")
    m.top.density = "comfortable"
    homeRender()
    CheckHome(m.selection = 7 and m.panes[1].firstRow = 1 and m.panes[0].firstRow = 0, "density preserves independent sensor scrolling and selection")
    CheckHome(m.tiles[11].node.translation[0] = 924 and m.tiles[11].node.scale[0] = 0.825 and m.tiles[11].node.scale[1] = 0.825, "comfortable sensors remain at the right with undistorted uniform scaling")
    m.top.density = "compact"
    homeRender()
    CheckHome(m.tiles[11].node.translation[0] = 1014 and m.tiles[11].node.scale[0] = 0.5, "compact restores original dimensions without navigation changes")
    onKeyEvent("left", true)
    CheckHome(m.selection = 3, "Left returns to the nearest control in a short final row")
    onKeyEvent("right", true)
    CheckHome(m.selection = 6, "Right from a short control row enters the aligned sensor")
    m.top.entityIds = ["light.a", "light.b", "light.c", "light.d"]
    homeDataChanged()
    CheckHome(m.panes[0].columns = 4 and m.tiles[3].node.visible, "rooms without sensors retain the full-width control grid")
    m.top.entityIds = ["sensor.battery"]
    m.top.states = [{entity_id: "sensor.battery", state: "20", attributes: {device_class: "battery", unit_of_measurement: "%"}}]
    m.top.sensorAlerts = {"enabled": true}
    m.top.statesFresh = true
    homeDataChanged()
    CheckHome(m.tiles[3].alert.visible and m.tiles[3].alert.text = "Low battery" and m.tiles[3].value.text = "20 %", "alert has a text label without replacing sensor reading")
    CheckHome(m.tiles[3].title.font.size * m.tiles[3].node.scale[0] >= 16 and m.tiles[3].title.maxLines = 1, "alert keeps a readable single-line title above warning and value")
    m.top.statesFresh = false
    homeRender()
    CheckHome(not m.tiles[3].alert.visible, "failed refresh immediately suppresses stale alerts")
    m.top.statesFresh = true
    m.top.states[0].state = "unavailable"
    homeDataChanged()
    CheckHome(not m.tiles[3].alert.visible, "unavailable sensors never alert")
    print "HEARTH_HOME_TESTS_PASSED"
end sub

function HomeTestHasFocus() as boolean
    return m.focused
end function

sub HomeTestSetFocus(focused as boolean)
    m.focused = focused
end sub

sub CheckHome(condition as boolean, message as string)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
