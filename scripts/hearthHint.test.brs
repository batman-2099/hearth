sub init()
    m.top.addFields({text: "[OK] Toggle", color: "0xFFFFFFFF", keyBackground: "0x24282CFF", fontSize: 22, width: 1152, height: 96, wrap: true, bottomAligned: false})
    renderHint()
    if hintLabels(m.top) <> "Toggle" then stop
    m.top.text = "Connection failed. Try again."
    renderHint()
    if hintLabels(m.top) <> m.top.text or m.top.getChild(0).getChildCount() <> 1 then stop
    m.top.text = "[Unknown] action"
    renderHint()
    if hintLabels(m.top) <> m.top.text then stop
    m.top.text = "Unclosed [message"
    renderHint()
    if hintLabels(m.top) <> m.top.text then stop
    m.top.text = "Live video unavailable." + Chr(10) + "[Back] Cameras"
    renderHint()
    if hintLabels(m.top) <> "Live video unavailable.Cameras" then stop
    m.top.width = 400
    m.top.text = "[OK] Toggle the living room lights     [Back] Pages     [*] Settings"
    renderHint()
    if hintLabels(m.top) <> "Toggle the living room lightsPagesSettings" then stop
    if m.top.getChild(1).translation[1] <= m.top.getChild(0).translation[1] then stop
    for each item in m.top.getChildren(-1, 0)
        if item.translation[0] + item.boundingRect().width > m.top.width + 1 then stop
        if item.translation[1] + item.boundingRect().height > m.top.height then stop
    end for
    m.top.bottomAligned = true
    renderHint()
    for each item in m.top.getChildren(-1, 0)
        if item.translation[1] + item.boundingRect().height > 0 then stop
        if item.translation[1] < -m.top.height then stop
    end for
    m.top.text = ""
    renderHint()
    if m.top.getChildCount() <> 0 then stop
    print "HEARTH_HINT_TESTS_PASSED"
end sub

function hintLabels(node as object) as string
    result = ""
    if node.subtype() = "Label" then return node.text
    for each child in node.getChildren(-1, 0)
        result += hintLabels(child)
    end for
    return result
end function
