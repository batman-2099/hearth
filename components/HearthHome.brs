sub init()
    m.ids = []
    m.items = []
    m.firstRow = 0
    m.selection = 0
    m.tiles = []
    m.columns = 4
    m.rows = 3
    m.slotCount = m.columns * m.rows
    m.theme = HearthTheme(m.top.themeMode)
    m.empty = m.top.findNode("empty")
    m.range = m.top.findNode("range")
    m.roomLabel = m.top.findNode("room")
    m.room = ""
    m.rooms = []
    host = m.top.findNode("tiles")
    ' ponytail: recycle one screen of native slots; the full selection stays scrollable.
    for slot = 0 to m.slotCount - 1
        tile = host.createChild("Group")
        tile.translation = [(slot mod m.columns) * 292, Int(slot / m.columns) * 146]
        border = tile.createChild("Poster")
        border.uri = "pkg:/images/panel.png"
        border.width = 276
        border.height = 132
        body = tile.createChild("Poster")
        body.uri = "pkg:/images/panel.png"
        body.translation = [3, 3]
        body.width = 270
        body.height = 126
        title = tile.createChild("Label")
        title.translation = [16, 12]
        title.width = 244
        title.height = 0
        title.wrap = true
        title.maxLines = 2
        value = tile.createChild("Label")
        value.translation = [16, 78]
        value.width = 244
        value.height = 44
        toggle = HearthToggle(tile, 176, 84)
        m.tiles.push({node: tile, border: border, body: body, title: title, value: value, toggle: toggle})
    end for
    m.top.observeField("focusedChild", "homeRender")
    homeThemeChanged()
    homeDataChanged()
end sub

sub homeThemeChanged()
    if m.tiles = invalid then return
    m.theme = HearthTheme(m.top.themeMode)
    m.empty.font = m.theme.fontBody
    m.empty.font.size = m.theme.smallSize
    m.empty.color = m.theme.text
    m.range.font = m.empty.font
    m.range.color = m.theme.muted
    m.roomLabel.font = m.theme.fontBold
    m.roomLabel.font.size = m.theme.headingSize
    m.roomLabel.color = m.theme.text
    for each tile in m.tiles
        tile.title.font = m.theme.fontBody
        tile.title.font.size = m.theme.bodySize
        tile.title.color = m.theme.muted
        tile.body.blendColor = m.theme.surface
        tile.value.font = m.theme.fontBold
        tile.value.font.size = m.theme.valueSize
    end for
    homeRender()
end sub

sub homeDataChanged()
    if m.tiles = invalid then return
    previousId = ""
    if m.selection >= 0 and m.selection < m.ids.count() then previousId = m.ids[m.selection]
    m.ids = []
    m.items = []
    states = m.top.states
    config = m.top.config
    ids = m.top.entityIds
    rooms = {}
    if ids <> invalid
        seen = {}
        for each id in ids
            if GetInterface(id, "ifString") <> invalid
                if id <> "" and not seen.doesExist(id)
                    seen[id] = true
                    state = HearthStateById(states, id)
                    titleState = state
                    if titleState = invalid then titleState = {entity_id: id, attributes: {}}
                    room = "Other"
                    if type(m.top.areas) = "roAssociativeArray"
                        if HearthIsString(m.top.areas[id])
                            if m.top.areas[id].Trim() <> "" then room = m.top.areas[id].Trim()
                        end if
                    end if
                    if LCase(room) = "other" then room = "Other"
                    rooms[room] = room
                    m.items.push({title: HearthEntityTitle(titleState, config), value: HearthTileValue(state), isToggle: HearthIsToggle(id), state: HearthText(titleState.state), available: HearthStateAvailable(state)})
                    m.items[m.items.Count() - 1].room = room
                    m.ids.push(id)
                    if m.ids.count() = 30 then exit for
                end if
            end if
        end for
    end if
    HearthDisambiguateTitles(m.items, m.ids, m.top.areas)
    m.allIds = m.ids
    m.allItems = m.items
    m.rooms = []
    for each room in rooms
        if LCase(room) <> "other" then m.rooms.Push(rooms[room])
    end for
    m.rooms.Sort("i")
    if rooms.DoesExist("Other") then m.rooms.Push("Other")
    if not HearthContains(m.rooms, m.room)
        m.room = ""
        if m.rooms.Count() > 0 then m.room = m.rooms[0]
    end if
    homeRoomChanged(previousId)
end sub

sub homeRoomChanged(previousId as string)
    m.ids = []
    m.items = []
    selected = 0
    for index = 0 to m.allIds.Count() - 1
        if LCase(m.allItems[index].room) = LCase(m.room)
            m.ids.Push(m.allIds[index])
            m.items.Push(m.allItems[index])
            if m.allIds[index] = previousId then selected = m.ids.Count() - 1
        end if
    end for
    homeSelect(selected)
end sub

sub homeSelectionChanged()
    if m.tiles = invalid or m.settingSelection = true then return
    homeSelect(m.top.selected)
end sub

sub homeSelect(index as integer)
    count = m.ids.count()
    if index >= count then index = count - 1
    if index < 0 then index = 0
    m.selection = index
    row = Int(index / m.columns)
    if row < m.firstRow then m.firstRow = row
    if row >= m.firstRow + m.rows then m.firstRow = row - m.rows + 1
    maxFirst = Int((count + m.columns - 1) / m.columns) - m.rows
    if maxFirst < 0 then maxFirst = 0
    if m.firstRow > maxFirst then m.firstRow = maxFirst
    m.settingSelection = true
    m.top.selected = index
    m.settingSelection = false
    homeRender()
end sub

sub homeRender()
    if m.theme = invalid or m.tiles = invalid then return
    count = m.items.count()
    focused = m.top.IsInFocusChain()
    m.top.hint = "[Back] Pages     [*] Settings"
    if count > 0 then m.top.hint = HearthTileAction(m.ids[m.selection], m.items[m.selection].available = true, m.top.pendingId = m.ids[m.selection]) + "     [Back] Pages     [*] Settings"
    if m.rooms <> invalid
        if m.rooms.Count() > 1 then m.top.hint = m.top.hint + "     [Rew/Fwd] Rooms"
        m.roomLabel.text = m.room
        m.top.currentRoom = m.room
    end if
    m.empty.visible = count = 0
    m.range.visible = count > m.slotCount
    last = m.firstRow * m.columns + m.slotCount
    if last > count then last = count
    m.range.text = (m.firstRow * m.columns + 1).toStr() + "–" + last.toStr() + " of " + count.toStr()
    for slot = 0 to m.slotCount - 1
        tile = m.tiles[slot]
        index = m.firstRow * m.columns + slot
        tile.node.visible = index < count
        if index < count
            item = m.items[index]
            tile.title.text = item.title
            tile.value.text = item.value
            pending = m.top.pendingId = m.ids[index]
            if pending then tile.value.text = "Sending…"
            tile.border.audioGuideText = item.title + ", " + item.value + ". " + HearthTileAction(m.ids[index], item.available = true, pending)
            tile.value.color = m.theme.text
            tile.border.blendColor = m.theme.rule
            if index = m.selection and focused
                tile.border.blendColor = m.theme.focus
                if not tile.border.hasFocus() then tile.border.setFocus(true)
            end if
            ' Long states retain the minimum readable TV size; OK reveals the full value.
            tile.value.font.size = m.theme.valueSize
            if Len(item.value) > 12 then tile.value.font.size = m.theme.headingSize
            if Len(item.value) > 18 then tile.value.font.size = m.theme.bodySize
            tile.toggle.node.visible = false
            tile.value.width = 244
            if item.isToggle = true and not pending
                HearthToggleState(tile.toggle, item.state)
                if tile.toggle.node.visible then tile.value.width = 148
            end if
        end if
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        m.top.leave = true
        return true
    end if
    count = m.ids.count()
    index = m.selection
    if key = "up" or key = "down" or key = "left" or key = "right"
        index = HearthGridMove(index, count, m.columns, key)
        if index < 0
            m.top.leave = true
            return true
        end if
    else if key = "rewind" or key = "fastforward"
        if m.rooms = invalid then return true
        if m.rooms.Count() = 0 then return true
        roomIndex = 0
        for position = 0 to m.rooms.Count() - 1
            if m.rooms[position] = m.room then roomIndex = position
        end for
        if key = "rewind" then roomIndex = roomIndex - 1 else roomIndex = roomIndex + 1
        roomIndex = (roomIndex + m.rooms.Count()) mod m.rooms.Count()
        m.room = m.rooms[roomIndex]
        m.firstRow = 0
        homeRoomChanged("")
        return true
    else if key = "OK"
        if count > 0
            if m.top.pendingId <> m.ids[index] then m.top.itemSelected = m.ids[index]
        end if
        return true
    else
        return false
    end if
    homeSelect(index)
    return true
end function
