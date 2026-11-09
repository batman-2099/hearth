sub init()
    m.entries = []
    m.firstRow = 0
    m.tiles = []
    m.room = ""
    m.rooms = []
    canvas = m.top.createChild("Group")
    m.theme = HearthTheme("dark")
    m.empty = HearthLabel(canvas, "Choose lights, switches, scenes and buttons in Settings > Controls.", 0, 140, 1152, 100, m.theme.text, m.theme.bodySize)
    m.empty.wrap = true
    m.range = HearthLabel(canvas, "", 832, 4, 320, 28, m.theme.muted, m.theme.smallSize)
    m.range.horizAlign = "right"
    m.roomLabel = HearthLabel(canvas, "", 0, 0, 820, 38, m.theme.text, m.theme.headingSize)
    m.roomLabel.font = m.theme.fontBold
    m.roomLabel.font.size = m.theme.headingSize
    ' Recycle one screen within the current room.
    for slot = 0 to 7
        node = canvas.createChild("Group")
        node.translation = [(slot mod 4) * 288, 42 + Int(slot / 4) * 148]
        border = HearthPanel(node, 0, 0, 272, 132, m.theme.rule)
        body = HearthPanel(node, 3, 3, 266, 126, m.theme.surface)
        title = HearthLabel(node, "", 16, 10, 240, 66, m.theme.text, m.theme.bodySize)
        title.wrap = true
        title.maxLines = 2
        value = HearthLabel(node, "", 16, 78, 240, 36, m.theme.muted, m.theme.bodySize)
        toggle = HearthToggle(node, 172, 80)
        track = HearthRectangle(node, 16, 120, 240, 4, m.theme.rule)
        fill = HearthRectangle(node, 16, 120, 0, 4, m.theme.text)
        m.tiles.Push({node: node, border: border, body: body, title: title, value: value, toggle: toggle, track: track, fill: fill})
    end for
    m.top.observeField("focusedChild", "focusChanged")
end sub

sub dataChanged()
    data = m.top.data
    if data = invalid then return
    previousId = ""
    if m.top.selected >= 0 and m.top.selected < m.entries.Count() then previousId = m.entries[m.top.selected].id
    m.theme = HearthTheme(data.themeMode)
    m.entries = []
    groups = {}
    rooms = []
    for each id in data.preferences.controls
        room = "Other"
        if data.areas <> invalid
            if HearthIsString(data.areas[id])
                if data.areas[id].Trim() <> "" then room = data.areas[id].Trim()
            end if
        end if
        if not groups.DoesExist(room)
            groups[room] = []
            if LCase(room) <> "other" then rooms.Push(room)
        end if
        state = HearthStateById(data.states, id)
        if state = invalid then state = {entity_id: id, state: "unavailable", attributes: {}}
        actions = HearthControlActions(id, data.states, data.preferences, data.config)
        action = "No actions available"
        if actions.Count() = 1 then action = "[OK] " + actions[0].name
        if actions.Count() > 1 then action = "[OK] Choose action"
        groups[room].Push({id: id, state: state, room: room, title: HearthEntityTitle(state, data.config), action: action})
    end for
    rooms.Sort("i")
    if groups.DoesExist("Other") then rooms.Push("Other")
    m.rooms = rooms
    m.groups = groups
    if not HearthContains(m.rooms, m.room)
        m.room = ""
        if m.rooms.Count() > 0 then m.room = m.rooms[0]
    end if
    controlsRoomChanged(previousId)
end sub

sub controlsRoomChanged(previousId as string)
    m.entries = []
    if m.room <> "" then m.entries = m.groups[m.room]
    selected = 0
    for index = 0 to m.entries.Count() - 1
        if m.entries[index].id = previousId then selected = index
    end for
    if selected >= m.entries.Count() then selected = m.entries.Count() - 1
    if selected < 0 then selected = 0
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
    m.roomLabel.text = m.room
    m.top.currentRoom = m.room
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
        index = m.firstRow * 4 + slot
        tile.node.visible = index < count
        if index < count
            entry = m.entries[index]
            pending = entry.id = m.top.pendingId
            tile.title.text = entry.title
            tile.title.color = m.theme.text
            tile.body.blendColor = m.theme.surface
            value = HearthTileValue(entry.state)
            domain = HearthEntityDomain(entry.id)
            if domain = "scene" then value = "Activate"
            if domain = "script" then value = "Run"
            if domain = "button" then value = "Press"
            if not HearthStateAvailable(entry.state) then value = "Unavailable"
            if pending then value = "Sending…"
            tile.value.text = value
            tile.value.color = m.theme.text
            tile.value.width = 240
            tile.toggle.node.visible = false
            if HearthIsToggle(entry.id) and not pending
                HearthToggleState(tile.toggle, HearthText(entry.state.state))
                if tile.toggle.node.visible then tile.value.width = 148
            end if
            tile.track.visible = false
            tile.fill.visible = false
            if HearthLightSupportsBrightness(entry.state) and HearthStateAvailable(entry.state) and not pending
                brightness = HearthAttributes(entry.state).brightness
                if HearthIsNumber(brightness)
                    percent = Int(brightness * 100 / 255 + 0.5)
                    tile.value.text = value + " " + percent.ToStr().Trim() + "%"
                    tile.track.visible = true
                    tile.track.color = m.theme.rule
                    tile.fill.visible = percent > 0
                    tile.fill.color = m.theme.text
                    tile.fill.width = 240 * percent / 100
                end if
            end if
            tile.value.font = m.theme.fontBold
            tile.value.font.size = m.theme.valueSize
            if Len(tile.value.text) > 12 then tile.value.font.size = m.theme.headingSize
            if Len(tile.value.text) > 18 then tile.value.font.size = m.theme.bodySize
            if tile.toggle.node.visible and Len(tile.value.text) > 4 then tile.value.font.size = m.theme.bodySize
            tile.value.height = 44
            spokenValue = tile.value.text
            if pending or domain = "scene" or domain = "script" or domain = "button" then spokenValue = HearthTileValue(entry.state)
            tile.border.audioGuideText = entry.title + ", " + entry.room + ", " + spokenValue + ". " + controlHint(entry)
        end if
    end for
    focusChanged()
end sub

function controlHint(entry as object) as string
    if entry.id = m.top.pendingId then return "Sending…"
    if not HearthStateAvailable(entry.state) then return "Device unavailable"
    hint = entry.action
    if HearthLightSupportsBrightness(entry.state) then hint = hint + "     [Play] Brightness"
    return hint
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
    if m.rooms.Count() > 1 then m.top.hint = m.top.hint + "     [Rew/Fwd] Rooms"
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
    if key = "play"
        if current.id = m.top.pendingId or not HearthLightSupportsBrightness(current.state) or not HearthStateAvailable(current.state) then return false
        m.top.brightness = current.id
        return true
    end if
    if key = "rewind" or key = "fastforward"
        roomIndex = 0
        for position = 0 to m.rooms.Count() - 1
            if m.rooms[position] = m.room then roomIndex = position
        end for
        if key = "rewind" then roomIndex = roomIndex - 1 else roomIndex = roomIndex + 1
        roomIndex = (roomIndex + m.rooms.Count()) mod m.rooms.Count()
        m.room = m.rooms[roomIndex]
        m.firstRow = 0
        controlsRoomChanged("")
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
