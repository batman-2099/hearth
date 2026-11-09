sub renderHint()
    m.top.removeChildrenIndex(m.top.getChildCount(), 0)
    if m.top.text = "" or m.top.width <= 0 then return
    icons = {"Left/Right": "left-right", "OK/Down": "ok-down", "OK": "ok", "Back": "back", "*": "star", "Play": "play", "Rew/Fwd": "rew-fwd", "Arrows": "arrows", "Right": "right", "Left": "left"}
    m.hintX = 0
    m.hintY = 0
    for each line in m.top.text.Split(Chr(10))
        remaining = line
        while remaining <> ""
            start = Instr(1, remaining, "[")
            finish = Instr(1, remaining, "]")
            if start = 0 or finish <= start
                hintItem("", "", remaining.Trim())
                exit while
            end if
            if start > 1 then hintItem("", "", Left(remaining, start - 1).Trim())
            key = Mid(remaining, start + 1, finish - start - 1)
            remaining = Mid(remaining, finish + 1)
            nextKey = Instr(1, remaining, "[")
            action = remaining
            if nextKey > 0 then action = Left(remaining, nextKey - 1)
            if icons.DoesExist(key)
                hintItem(key, icons[key], action.Trim())
            else
                hintItem("", "", "[" + key + "] " + action.Trim())
            end if
            remaining = Mid(remaining, Len(action) + 1)
        end while
        m.hintX = 0
        m.hintY += 52
    end for
    if m.top.bottomAligned
        for each item in m.top.getChildren(-1, 0)
            item.translation = [item.translation[0], item.translation[1] - m.hintY + 8]
        end for
    end if
end sub

sub hintItem(key as string, image as string, text as string)
    if text = "" and key = "" then return
    item = m.top.createChild("Group")
    iconWidth = 0
    if key <> ""
        iconWidth = 44
        if Instr(1, key, "/") > 0 then iconWidth = 88
        if key = "Back" then iconWidth = 80
        if key = "Play" then iconWidth = 64
        edge = item.createChild("Poster")
        edge.uri = "pkg:/images/panel.png"
        edge.width = iconWidth
        edge.height = 44
        edge.blendColor = m.top.color
        face = item.createChild("Poster")
        face.uri = edge.uri
        face.translation = [2, 2]
        face.width = iconWidth - 4
        face.height = 40
        face.blendColor = m.top.keyBackground
        icon = item.createChild("Poster")
        icon.uri = "pkg:/images/remote-" + image + ".png"
        icon.translation = [4, 2]
        icon.width = iconWidth - 8
        icon.height = 40
        icon.loadDisplayMode = "scaleToFit"
        icon.audioGuideText = key + ". " + text
        if key = "*" then icon.audioGuideText = "Star. " + text
        iconWidth += 10
    end if
    label = item.createChild("Label")
    label.text = text
    label.color = m.top.color
    label.font = "font:MediumSystemFont"
    label.font.size = m.top.fontSize
    textWidth = label.boundingRect().width
    if textWidth > m.top.width - iconWidth then textWidth = m.top.width - iconWidth
    width = iconWidth + textWidth
    if m.hintX > 0 and m.hintX + width > m.top.width
        m.hintX = 0
        m.hintY += 52
    end if
    label.translation = [iconWidth, 0]
    label.width = textWidth
    label.height = 44
    label.vertAlign = "center"
    if key = "" and width = m.top.width
        label.wrap = m.top.wrap
        label.height = m.top.height - m.hintY
    end if
    item.translation = [m.hintX, m.hintY]
    m.hintX += width + 24
end sub
