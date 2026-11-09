sub Main()
    ' The interpreter cannot resolve Roku system-font URIs; use native Font nodes.
    m.testTheme = HearthTheme("dark")
    m.testTheme.fontBody = CreateObject("roSGNode", "Font")
    m.testTheme.fontBold = CreateObject("roSGNode", "Font")
    _brs_.mockFunction("HearthTheme", function(mode as string) as object
        return m.testTheme
    end function)
    m.entries = []
    m.firstRow = 0
    m.room = ""
    m.rooms = []
    m.empty = {}
    m.range = {}
    m.roomLabel = {}
    m.tiles = []
    for slot = 0 to 7
        m.tiles.Push({node: {}, border: {focused: false, hasFocus: ControlsTestHasFocus, setFocus: ControlsTestSetFocus}, body: {}, title: {}, value: {}, toggle: {node: {}, track: {}, thumb: {}}, track: {}, fill: {}})
    end for
    m.top = {selected: 0, pendingId: "", focused: false, IsInFocusChain: ControlsTestHasFocus, data: {themeMode: "dark", config: {}, preferences: {controls: ["light.first", "switch.second"]}, areas: {}, states: [{entity_id: "light.first", state: "off", attributes: {}}, {entity_id: "switch.second", state: "on", attributes: {}}]}}
    for each room in ["other", "OTHER", "Other"]
        m.top.data.areas = {"light.first": room}
        dataChanged()
        CheckControls(m.entries.Count() = 2 and m.entries[0].id = "light.first" and m.entries[1].id = "switch.second", "reserved room variants never duplicate controls")
        m.top.data.areas["switch.second"] = room
        dataChanged()
        CheckControls(m.entries.Count() = 2, "named Other room works without an unassigned device")
    end for
    m.top.selected = 1
    m.top.data.areas = {"light.first": "Zebra", "switch.second": "Attic"}
    dataChanged()
    CheckControls(m.top.selected = 0 and m.entries[0].id = "switch.second", "room reordering preserves focused device identity")
    CheckControls(m.room = "Attic" and m.entries.Count() = 1, "Controls filters entries to the active room")
    onKeyEvent("fastforward", true)
    CheckControls(m.room = "Zebra" and m.entries[0].id = "light.first" and m.top.dim = invalid, "room switching never sends brightness commands")
    onKeyEvent("OK", true)
    CheckControls(m.top.activate = "light.first", "room-local selection activates the correct entity")
    dataChanged()
    CheckControls(m.room = "Zebra" and m.entries[0].id = "light.first", "refresh preserves room and selection")
    m.top.data.states[0].attributes = {supported_color_modes: ["brightness"], brightness: 128}
    dataChanged()
    handled = onKeyEvent("play", true)
    CheckControls(handled and m.top.brightness = "light.first" and m.top.dim = invalid, "Play handles an available dimmable light without changing the device")
    CheckControls(m.tiles[0].track.visible and m.tiles[0].fill.visible and Instr(1, m.tiles[0].value.text, "50%") > 0, "brightness is rendered on the active tile")
    m.top.brightness = invalid
    m.top.pendingId = "light.first"
    render()
    handled = onKeyEvent("play", true)
    CheckControls(not handled and m.top.brightness = invalid, "pending device leaves Play unhandled")
    CheckControls(m.tiles[0].value.text = "Sending…" and not m.tiles[0].track.visible and not m.tiles[0].toggle.node.visible, "pending state replaces brightness and toggle feedback")
    m.top.activate = invalid
    onKeyEvent("OK", true)
    CheckControls(m.top.activate = invalid and Instr(1, m.top.hint, "Sending") > 0, "pending tile blocks duplicate activation and announces progress")
    m.top.pendingId = ""
    m.top.data.states[0].state = "unavailable"
    dataChanged()
    handled = onKeyEvent("play", true)
    CheckControls(not handled and m.top.brightness = invalid and not m.tiles[0].track.visible, "unavailable light leaves Play unhandled and hides brightness")
    m.top.data.states[0].state = "on"
    dataChanged()
    CheckControls(m.tiles[0].track.visible and m.tiles[0].toggle.node.visible, "completion restores brightness and toggle feedback")
    onKeyEvent("OK", true)
    CheckControls(m.top.activate = "light.first", "completed device accepts activation again")
    onKeyEvent("fastforward", true)
    CheckControls(m.room = "Attic", "next room wraps")
    CheckControls(not onKeyEvent("play", true) and m.top.brightness = invalid, "nondimmable control leaves Play unhandled")
    onKeyEvent("rewind", true)
    CheckControls(m.room = "Zebra", "previous room wraps")
    m.top.data.preferences.controls = ["switch.second"]
    dataChanged()
    CheckControls(m.room = "Attic" and m.entries.Count() = 1, "removed room falls back to a remaining room")
    m.top.data.preferences.controls = []
    dataChanged()
    onKeyEvent("fastforward", true)
    CheckControls(m.room = "" and m.entries.Count() = 0, "empty Controls has no stale room")
    CheckControls(m.empty.visible and not m.tiles[0].node.visible and not onKeyEvent("play", true), "empty Controls clears tiles and leaves Play unhandled")
    TestControlsViewport()
    print "HEARTH_CONTROLS_TESTS_PASSED"
end sub

sub TestControlsViewport()
    m.top.data.preferences.controls = []
    m.top.data.states = []
    m.top.data.areas = {}
    for index = 0 to 10
        id = "light.viewport_" + index.ToStr().Trim()
        title = "Device " + index.ToStr().Trim()
        m.top.data.preferences.controls.Push(id)
        m.top.data.states.Push({entity_id: id, state: "on", attributes: {friendly_name: title}})
    end for
    m.top.focused = true
    dataChanged()
    CheckControls(m.tiles[0].border.hasFocus() and m.tiles[0].border.blendColor = m.theme.focus, "entering Controls focuses the first tile")
    onKeyEvent("down", true)
    CheckControls(m.tiles[4].border.blendColor = m.theme.focus and m.tiles[0].border.blendColor = m.theme.rule, "navigation transfers the focus highlight")
    onKeyEvent("down", true)
    CheckControls(m.top.selected = 8 and m.range.visible, "more than eight controls scroll to the third row")
    CheckControls(m.tiles[4].node.visible and m.tiles[4].title.text = "Device 8" and m.tiles[4].border.hasFocus(), "selected third-row device is rendered and focused in the viewport")
    CheckControls(m.tiles[6].title.text = "Device 10" and not m.tiles[7].node.visible, "partial last row hides the unused recycled tile")
    onKeyEvent("OK", true)
    CheckControls(m.top.activate = "light.viewport_8", "scrolled activation targets the selected entity")
    onKeyEvent("up", true)
    onKeyEvent("up", true)
    CheckControls(m.tiles[0].title.text = "Device 0" and m.tiles[0].border.blendColor = m.theme.focus, "scrolling back restores the first selected device")
    m.top.focused = false
    focusChanged()
    CheckControls(m.tiles[0].border.blendColor = m.theme.rule, "leaving Controls removes focus highlighting")
end sub

function ControlsTestHasFocus() as boolean
    return m.focused
end function

sub ControlsTestSetFocus(focused as boolean)
    m.focused = focused
end sub

sub CheckControls(condition as boolean, message as string)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
