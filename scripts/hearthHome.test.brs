sub Main()
    m.columns = 4
    m.rows = 3
    m.slotCount = m.columns * m.rows
    m.firstRow = 0
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
        m.items.push({title: "Sensor", value: "1", available: true})
    end for
    for i = 0 to m.slotCount - 1
        m.tiles.push({node: {}, title: {}, value: {font: {}}, border: {focused: false, hasFocus: HomeTestHasFocus, setFocus: HomeTestSetFocus}, toggle: {node: {}}})
    end for
    homeSelect(m.columns - 1)
    onKeyEvent("right", true)
    CheckHome(m.selection = m.columns - 1, "Right does not wrap into another row")
    homeSelect(27)
    onKeyEvent("down", true)
    CheckHome(m.selection = 29, "Down reaches the last tile in a partial final row")
    onKeyEvent("fastforward", true)
    CheckHome(m.selection = 29, "room navigation before discovery leaves selection intact")
    CheckHome(Int(m.selection / m.columns) >= m.firstRow and Int(m.selection / m.columns) < m.firstRow + m.rows, "Selected tile remains in the visible window")
    homeSelect(0)
    onKeyEvent("up", true)
    CheckHome(m.top.leave = true, "Up from the first row returns to navigation")
    homeSelect(1)
    m.top.pendingId = m.ids[1]
    homeRender()
    CheckHome(m.tiles[1].value.text = "Sending…" and m.items[1].value = "1", "pending feedback does not optimistically mutate the reading")
    CheckHome(Instr(1, m.top.hint, "Sending") > 0, "Home footer describes pending command")
    m.top.itemSelected = ""
    onKeyEvent("OK", true)
    CheckHome(m.top.itemSelected = "", "pending tile cannot send twice")
    m.top.pendingId = ""
    onKeyEvent("OK", true)
    CheckHome(m.top.itemSelected = m.ids[1], "completed tile can be activated again")
    m.top.entityIds = ["sensor.test_2", "sensor.test_1", "sensor.test_0"]
    m.top.states = [{entity_id: "sensor.test_1", state: "1", attributes: {friendly_name: "Sensor"}}]
    homeDataChanged()
    CheckHome(m.selection = 1 and m.ids[m.selection] = "sensor.test_1", "refresh preserves selected entity identity")
    CheckHome(m.tiles.Count() = 12, "refresh retains the fixed slot pool")
    CheckHome(Instr(1, m.tiles[1].border.audioGuideText, "Sensor, 1") > 0, "focused poster description includes title and reading")
    m.top.focused = true
    homeRender()
    CheckHome(m.tiles[1].border.hasFocus() and m.tiles[1].border.blendColor = m.theme.focus, "entering Home focuses and highlights the selected device")
    homeSelect(2)
    CheckHome(m.tiles[2].border.hasFocus() and m.tiles[2].border.blendColor = m.theme.focus and m.tiles[1].border.blendColor = m.theme.rule, "navigation moves focus and removes the old highlight")
    m.top.focused = false
    homeRender()
    CheckHome(m.tiles[2].border.blendColor = m.theme.rule, "leaving Home removes its active focus highlight")
    m.top.areas = {"sensor.test_2": "Bedroom", "sensor.test_1": "Kitchen"}
    homeDataChanged()
    CheckHome(m.room = "Other" and m.ids.Count() = 1 and m.ids[0] = "sensor.test_0", "unassigned entities retain their own room")
    onKeyEvent("fastforward", true)
    CheckHome(m.room = "Bedroom" and m.ids[0] = "sensor.test_2", "next room wraps and filters tiles")
    onKeyEvent("fastforward", true)
    CheckHome(m.room = "Kitchen" and m.ids[0] = "sensor.test_1", "rooms sort alphabetically before Other")
    onKeyEvent("OK", true)
    CheckHome(m.top.itemSelected = "sensor.test_1", "room selection activates the actual entity, not its former index")
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
