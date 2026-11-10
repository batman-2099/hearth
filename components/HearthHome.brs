sub init()
    m.ids = []
    m.items = []
    m.selection = 0
    m.tiles = []
    m.columns = 4
    m.rows = 3
    m.slotCount = m.columns * m.rows
    m.panes = [{indices: [], columns: 4, firstRow: 0}, {indices: [], columns: 1, firstRow: 0}]
    m.positions = []
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
        alert = HearthLabel(tile, "", 20, 54, 236, 40, m.theme.sensorText, 32)
        m.tiles.push({node: tile, border: border, body: body, title: title, value: value, toggle: toggle, alert: alert})
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
                    item = m.items[m.items.Count() - 1]
                    item.alert = HearthSensorAlert(state, m.top.sensorAlerts)
                    selectedControl = HearthContains(m.top.controlIds, id)
                    if selectedControl and item.available
                        domain = HearthEntityDomain(id)
                        if domain = "scene" then item.value = "Activate"
                        if domain = "script" then item.value = "Run"
                        if domain = "button" then item.value = "Press"
                    end if
                    item.action = "[OK] Details"
                    if selectedControl or item.isToggle
                        actions = HearthControlActions(id, states, {sensors: ids, controls: m.top.controlIds}, config)
                        if actions.Count() = 1 then item.action = "[OK] " + actions[0].name
                        if actions.Count() > 1 then item.action = "[OK] Choose action"
                    end if
                    if HearthEntityDomain(id) = "climate"
                        item.action = "[OK] Details"
                        if selectedControl then item.action = "[OK] Climate controls"
                    end if
                    item.brightness = selectedControl and HearthLightSupportsBrightness(state)
                    m.ids.push(id)
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
        for each pane in m.panes
            pane.firstRow = 0
        end for
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
    homeLayout()
    if not HearthContains(m.ids, previousId) and m.panes[0].indices.Count() > 0 then selected = m.panes[0].indices[0]
    homeSelect(selected)
end sub

sub homeLayout()
    for each pane in m.panes
        pane.indices = []
    end for
    m.panes[0].columns = 4
    m.positions = []
    for index = 0 to m.ids.Count() - 1
        side = 0
        domain = HearthEntityDomain(m.ids[index])
        if domain = "sensor" or domain = "binary_sensor" then side = 1
        pane = m.panes[side]
        m.positions.Push({side: side, offset: pane.indices.Count()})
        pane.indices.Push(index)
    end for
    if m.panes[1].indices.Count() > 0 then m.panes[0].columns = 3
    for each pane in m.panes
        maxFirst = Int((pane.indices.Count() + pane.columns - 1) / pane.columns) - m.rows
        if maxFirst < 0 then maxFirst = 0
        if pane.firstRow > maxFirst then pane.firstRow = maxFirst
    end for
end sub

function homeMove(index as integer, key as string) as integer
    if m.ids.Count() = 0 then return HearthGridMove(index, 0, 4, key)
    position = m.positions[index]
    pane = m.panes[position.side]
    offset = position.offset
    row = Int(offset / pane.columns)
    crossing = position.side = 1 and key = "left"
    if position.side = 0 and key = "right"
        crossing = offset mod pane.columns = pane.columns - 1 or offset = pane.indices.Count() - 1
    end if
    other = m.panes[1 - position.side]
    if crossing and other.indices.Count() > 0
        target = (other.firstRow + row - pane.firstRow) * other.columns
        if position.side = 1 then target = target + other.columns - 1
        if target >= other.indices.Count() then target = other.indices.Count() - 1
        return other.indices[target]
    end if
    target = HearthGridMove(offset, pane.indices.Count(), pane.columns, key)
    if target < 0 then return -1
    return pane.indices[target]
end function

sub homeSelectionChanged()
    if m.tiles = invalid or m.settingSelection = true then return
    homeSelect(m.top.selected)
end sub

sub homeSelect(index as integer)
    count = m.ids.count()
    if index >= count then index = count - 1
    if index < 0 then index = 0
    m.selection = index
    if count > 0
        position = m.positions[index]
        pane = m.panes[position.side]
        row = Int(position.offset / pane.columns)
        if row < pane.firstRow then pane.firstRow = row
        if row >= pane.firstRow + m.rows then pane.firstRow = row - m.rows + 1
        maxFirst = Int((pane.indices.Count() + pane.columns - 1) / pane.columns) - m.rows
        if maxFirst < 0 then maxFirst = 0
        if pane.firstRow > maxFirst then pane.firstRow = maxFirst
    end if
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
    if count > 0 then m.top.hint = homeHint(m.selection) + "     [Back] Pages     [*] Settings"
    if m.rooms <> invalid
        if m.rooms.Count() > 1 then m.top.hint = m.top.hint + "     [Rew/Fwd] Rooms"
        m.roomLabel.text = m.room
        m.top.currentRoom = m.room
    end if
    m.empty.visible = count = 0
    m.range.visible = false
    if count > 0
        position = m.positions[m.selection]
        pane = m.panes[position.side]
        capacity = pane.columns * m.rows
        m.range.visible = pane.indices.Count() > capacity
        last = pane.firstRow * pane.columns + capacity
        if last > pane.indices.Count() then last = pane.indices.Count()
        prefix = "Devices "
        if position.side = 1 then prefix = "Sensors "
        m.range.text = prefix + (pane.firstRow * pane.columns + 1).toStr() + "–" + last.toStr() + " of " + pane.indices.Count().toStr()
    end if
    for slot = 0 to m.slotCount - 1
        tile = m.tiles[slot]
        column = slot mod 4
        row = Int(slot / 4)
        pane = m.panes[0]
        if column = 3 and m.panes[1].indices.Count() > 0
            pane = m.panes[1]
            column = 0
        end if
        offset = (pane.firstRow + row) * pane.columns + column
        index = -1
        if offset < pane.indices.Count() then index = pane.indices[offset]
        tile.node.visible = index >= 0
        if index >= 0
            item = m.items[index]
            sensor = m.positions[index].side = 1
            tile.node.scale = [0.5, 0.5]
            tile.node.translation = [(slot mod 4) * 146, row * 87]
            if m.top.density = "comfortable"
                tile.node.scale = [0.825, 0.825]
                tile.node.translation = [(slot mod 4) * 242, row * 146]
            end if
            tile.body.visible = true
            tile.body.uri = "pkg:/images/panel.png"
            tile.body.translation = [3, 3]
            tile.body.width = 270
            tile.body.height = 154
            tile.body.blendColor = m.theme.surface
            tile.border.uri = "pkg:/images/panel.png"
            tile.border.translation = [0, 0]
            tile.border.width = 276
            tile.border.height = 160
            tile.title.font.size = m.theme.compactTextSize
            tile.title.translation = [20, 12]
            tile.title.width = 236
            tile.title.height = 84
            tile.title.color = m.theme.muted
            tile.value.translation = [20, 104]
            tile.toggle.node.translation = [172, 110]
            tile.value.height = 44
            if sensor
                tile.node.translation = [1014, row * 87]
                if m.top.density = "comfortable" then tile.node.translation = [924, row * 146]
                tile.border.uri = "pkg:/images/flat.9.png"
                tile.body.uri = "pkg:/images/flat.9.png"
                tile.body.translation = [6, 6]
                tile.body.width = 264
                tile.body.height = 148
                tile.body.blendColor = m.theme.sensorSurface
                tile.title.color = m.theme.sensorText
                tile.value.translation = [20, 104]
                tile.value.height = 44
            end if
            tile.title.text = item.title
            tile.value.text = item.value
            pending = m.top.pendingId = m.ids[index]
            if pending then tile.value.text = "Sending…"
            tile.border.audioGuideText = item.title + ", " + tile.value.text + ". " + homeHint(index)
            tile.value.color = m.theme.text
            tile.border.blendColor = m.theme.rule
            if sensor
                tile.border.blendColor = m.theme.sensorSurface
                tile.value.color = m.theme.sensorText
            end if
            tile.alert.visible = false
            tile.title.height = 84
            tile.title.maxLines = 2
            if sensor and m.top.statesFresh = true and item.alert <> ""
                tile.alert.visible = true
                tile.alert.text = item.alert.Replace("Alert: ", "")
                tile.alert.color = m.theme.activeText
                tile.body.blendColor = m.theme.active
                tile.border.blendColor = m.theme.active
                tile.title.color = m.theme.activeText
                tile.value.color = m.theme.activeText
                tile.title.translation = [20, 8]
                tile.title.maxLines = 1
                tile.title.height = 44
                tile.border.audioGuideText = tile.border.audioGuideText + ". " + item.alert
            end if
            if index = m.selection and focused
                tile.border.blendColor = m.theme.focus
                if sensor
                    tile.border.blendColor = m.theme.sensorText
                    if not tile.alert.visible then tile.body.blendColor = m.theme.sensorFocus
                end if
                if not tile.border.hasFocus() then tile.border.setFocus(true)
            end if
            tile.value.font.size = m.theme.valueSize
            if Len(item.value) > 12 then tile.value.font.size = m.theme.compactTextSize
            tile.toggle.node.visible = false
            tile.value.width = 236
            if item.isToggle = true and not pending
                HearthToggleState(tile.toggle, item.state)
                if tile.toggle.node.visible then tile.value.width = 144
            end if
        end if
    end for
end sub

function homeHint(index as integer) as string
    if m.positions[index].side = 1 then return ""
    item = m.items[index]
    if m.top.pendingId = m.ids[index] then return "Sending…"
    if item.available <> true then return "Device unavailable"
    hint = item.action
    if item.brightness = true then hint = hint + "     [Play] Light controls"
    return hint
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        m.top.leave = true
        return true
    end if
    count = m.ids.count()
    index = m.selection
    if key = "up" or key = "down" or key = "left" or key = "right"
        index = homeMove(index, key)
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
        for each pane in m.panes
            pane.firstRow = 0
        end for
        homeRoomChanged("")
        return true
    else if key = "play"
        if count = 0 then return false
        if m.positions[index].side = 1 then return false
        item = m.items[index]
        if m.top.pendingId = m.ids[index] or item.available <> true or item.brightness <> true then return false
        m.top.brightness = m.ids[index]
        return true
    else if key = "OK"
        if count > 0
            if m.positions[index].side = 0 and m.top.pendingId <> m.ids[index] then m.top.itemSelected = m.ids[index]
        end if
        return true
    else
        return false
    end if
    homeSelect(index)
    return true
end function
