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
    m.empty = {}
    m.range = {}
    m.roomLabel = {}
    m.tiles = []
    for slot = 0 to 7
        m.tiles.Push({node: {}, border: {focused: false, hasFocus: ControlsTestHasFocus, setFocus: ControlsTestSetFocus}, body: {}, title: {}, value: {}})
    end for
    m.top = {selected: 0, pendingId: "", focused: false, IsInFocusChain: ControlsTestHasFocus, data: {themeMode: "dark", config: {}, preferences: {controls: []}, areas: {}, states: []}}
    TestControlsViewport()
    TestShortcutTiles()
    TestDuplicateShortcutNames()
    m.top.data.preferences.controls = ["scene.test", "script.test"]
    dataChanged()
    previousId = m.entries[m.top.selected].id
    previousRow = m.firstRow
    m.top.data.preferences.density = "comfortable"
    dataChanged()
    CheckControls(m.entries[m.top.selected].id = previousId and m.firstRow = previousRow, "density preserves shortcut identity and scrolling")
    CheckControls(m.tiles[0].node.scale[0] = 0.825 and m.tiles[0].node.scale[1] = 0.825 and m.tiles[4].node.translation[1] = 188, "Scenes use undistorted comfortable tile dimensions")
    m.top.data.preferences.density = "compact"
    dataChanged()
    CheckControls(m.tiles[0].node.scale[0] = 0.5, "Scenes restore compact density")
    print "HEARTH_CONTROLS_TESTS_PASSED"
end sub

sub TestShortcutTiles()
    m.top.data.preferences.controls = ["light.test", "scene.test", "script.test"]
    m.top.data.states = [{entity_id: "scene.test", state: "unknown", attributes: {}}, {entity_id: "script.test", state: "off", attributes: {}}, {entity_id: "scene.unselected", state: "unknown", attributes: {}}]
    m.top.data.areas = {"scene.test": "Kitchen", "script.test": "Bedroom"}
    dataChanged()
    CheckControls(m.entries.Count() = 2 and m.entries[0].id = "scene.test" and m.entries[1].id = "script.test", "shortcuts include only selected scenes and scripts across rooms")
    m.top.selected = 1
    m.top.data.preferences.controls = ["script.test", "scene.test"]
    dataChanged()
    CheckControls(m.top.selected = 0 and m.entries[0].id = "script.test", "shortcut refresh preserves focused entity after reorder")
    m.top.pendingId = "script.test"
    m.top.activate = invalid
    render()
    onKeyEvent("OK", true)
    CheckControls(m.top.activate = invalid and m.tiles[0].value.text = "Sending…", "pending shortcut shows progress and blocks duplicate OK")
    m.top.pendingId = ""
    m.top.data.preferences.controls = ["light.test"]
    dataChanged()
    CheckControls(m.empty.visible and not m.tiles[0].node.visible, "empty shortcuts offer setup without leaking other controls")
end sub

sub TestDuplicateShortcutNames()
    m.top.data.preferences.controls = ["scene.evening", "script.evening"]
    m.top.data.states = [{entity_id: "scene.evening", state: "unknown", attributes: {friendly_name: "Evening"}}, {entity_id: "script.evening", state: "off", attributes: {friendly_name: "Evening"}}]
    for each areas in [{"scene.evening": "Kitchen", "script.evening": "Bedroom"}, {"scene.evening": "Kitchen", "script.evening": "Kitchen"}, {}]
        m.top.data.areas = areas
        dataChanged()
        CheckControls(m.tiles[0].title.text <> m.tiles[1].title.text, "duplicate shortcuts have distinct visible names")
        CheckControls(m.tiles[0].border.audioGuideText <> m.tiles[1].border.audioGuideText, "duplicate shortcuts have distinct spoken names")
        m.top.selected = 1
        onKeyEvent("OK", true)
        CheckControls(m.top.activate = "script.evening", "disambiguation preserves the selected command target")
    end for
end sub

sub TestControlsViewport()
    m.top.data.preferences.controls = []
    m.top.data.states = []
    m.top.data.areas = {}
    for index = 0 to 10
        id = "scene.viewport_" + index.ToStr().Trim()
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
    CheckControls(m.top.activate = "scene.viewport_8", "scrolled activation targets the selected entity")
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
