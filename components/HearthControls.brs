sub init()
    m.entries = []
    m.firstRow = 0
    m.tiles = []
    canvas = m.top.createChild("Group")
    m.theme = HearthTheme("dark")
    m.empty = HearthLabel(canvas, "Choose scenes or scripts in Settings > Scenes, then press Right and OK to save.", 0, 140, 1152, 100, m.theme.text, m.theme.bodySize)
    m.empty.wrap = true
    m.range = HearthLabel(canvas, "", 832, 4, 320, 28, m.theme.muted, m.theme.smallSize)
    m.range.horizAlign = "right"
    m.roomLabel = HearthLabel(canvas, "Scenes", 0, 0, 820, 38, m.theme.text, m.theme.headingSize)
    m.roomLabel.font = m.theme.fontBold
    m.roomLabel.font.size = m.theme.headingSize
    ' ponytail: recycle one screen of scene shortcuts.
    for slot = 0 to 7
        node = canvas.createChild("Group")
        node.scale = [0.5, 0.5]
        node.translation = [(slot mod 4) * 146, 42 + Int(slot / 4) * 87]
        border = HearthPanel(node, 0, 0, 272, 160, m.theme.rule)
        body = HearthPanel(node, 3, 3, 266, 154, m.theme.surface)
        title = HearthLabel(node, "", 20, 12, 232, 84, m.theme.text, m.theme.compactTextSize)
        title.wrap = true
        title.maxLines = 2
        value = HearthLabel(node, "", 20, 104, 232, 44, m.theme.muted, m.theme.valueSize)
        m.tiles.Push({node: node, border: border, body: body, title: title, value: value})
    end for
    m.top.observeField("focusedChild", "focusChanged")
end sub

sub dataChanged()
    data = m.top.data
    if data = invalid then return
    previousId = ""
    if m.top.selected >= 0 and m.top.selected < m.entries.Count() then previousId = m.entries[m.top.selected].id
    m.theme = HearthTheme(data.themeMode)
    ids = []
    for each id in data.preferences.controls
        if HearthContains(["scene", "script"], HearthEntityDomain(id)) then ids.Push(id)
    end for
    m.entries = []
    for each id in ids
        state = HearthStateById(data.states, id)
        if state = invalid then state = {entity_id: id, state: "unavailable", attributes: {}}
        action = "[OK] " + HearthStandardAction(id).name
        m.entries.Push({id: id, state: state, title: HearthEntityTitle(state, data.config), action: action})
    end for
    HearthDisambiguateTitles(m.entries, ids, data.areas)
    selected = 0
    for index = 0 to m.entries.Count() - 1
        if m.entries[index].id = previousId then selected = index
    end for
    m.top.selected = selected
    render()
end sub

sub render()
    if m.tiles = invalid then return
    count = m.entries.Count()
    m.empty.visible = count = 0
    m.empty.color = m.theme.text
    m.range.visible = count > 8
    m.range.color = m.theme.muted
    m.roomLabel.color = m.theme.text
    row = Int(m.top.selected / 4)
    if row < m.firstRow then m.firstRow = row
    if row >= m.firstRow + 2 then m.firstRow = row - 1
    maximum = Int((count + 3) / 4) - 2
    if maximum < 0 then maximum = 0
    if m.firstRow > maximum then m.firstRow = maximum
    last = m.firstRow * 4 + 8
    if last > count then last = count
    m.range.text = (m.firstRow * 4 + 1).ToStr() + "–" + last.ToStr() + " of " + count.ToStr()
    for slot = 0 to 7
        tile = m.tiles[slot]
        tile.node.scale = [0.5, 0.5]
        tile.node.translation = [(slot mod 4) * 146, 42 + Int(slot / 4) * 87]
        if m.top.data <> invalid
            if m.top.data.preferences.density = "comfortable"
                tile.node.scale = [0.825, 0.825]
                tile.node.translation = [(slot mod 4) * 242, 42 + Int(slot / 4) * 146]
            end if
        end if
        index = m.firstRow * 4 + slot
        tile.node.visible = index < count
        if index < count
            entry = m.entries[index]
            pending = entry.id = m.top.pendingId
            tile.title.text = entry.title
            tile.title.color = m.theme.text
            tile.body.blendColor = m.theme.surface
            value = "Activate"
            if HearthEntityDomain(entry.id) = "script" then value = "Run"
            if not HearthStateAvailable(entry.state) then value = "Unavailable"
            if pending then value = "Sending…"
            tile.value.text = value
            tile.value.color = m.theme.text
            tile.value.font = m.theme.fontBold
            tile.value.font.size = m.theme.valueSize
            if Len(tile.value.text) > 12 then tile.value.font.size = m.theme.compactTextSize
            tile.value.height = 44
            spokenValue = HearthTileValue(entry.state)
            tile.border.audioGuideText = entry.title + ", Scenes, " + spokenValue + ". " + controlHint(entry)
        end if
    end for
    focusChanged()
end sub

function controlHint(entry as object) as string
    if entry.id = m.top.pendingId then return "Sending…"
    if not HearthStateAvailable(entry.state) then return "Device unavailable"
    return entry.action
end function

sub focusChanged()
    if m.tiles = invalid then return
    focused = m.top.IsInFocusChain()
    for slot = 0 to m.tiles.Count() - 1
        tile = m.tiles[slot]
        tile.border.blendColor = m.theme.rule
        if tile.node.visible and focused and m.firstRow * 4 + slot = m.top.selected
            tile.border.blendColor = m.theme.focus
            if not tile.border.hasFocus() then tile.border.setFocus(true)
        end if
    end for
    hint = ""
    if m.entries.Count() > 0 then hint = controlHint(m.entries[m.top.selected]) + "     "
    m.top.hint = hint + "[Back] Pages     [*] Settings"
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        m.top.leave = true
        return true
    end if
    count = m.entries.Count()
    if count = 0
        if key = "up" then m.top.leave = true
        return key = "up" or key = "down" or key = "left" or key = "right" or key = "OK"
    end if
    index = m.top.selected
    current = m.entries[index]
    if key = "OK"
        if current.id <> m.top.pendingId then m.top.activate = current.id
        return true
    end if
    if key <> "up" and key <> "down" and key <> "left" and key <> "right" then return false
    index = HearthGridMove(index, count, 4, key)
    if index < 0
        m.top.leave = true
        return true
    end if
    if index <> m.top.selected
        m.top.selected = index
        render()
    end if
    return true
end function
