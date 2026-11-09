sub init()
    m.list = m.top.findNode("settingsList")
    m.saveGroup = m.top.findNode("pickerSave")
    m.save = m.top.findNode("saveSelection")
    m.save.observeField("itemSelected", "settingsSaveSelection")
    m.heading = m.top.findNode("heading")
    m.hint = m.top.findNode("hint")
    m.detail = m.top.findNode("pickerDetail")
    m.mode = "main"
    m.mainPosition = 0
    m.connectionDirty = false
    m.connectionFeedback = ""
    m.preferencesPending = false
    m.preferencesFeedback = ""
    m.draftConnection = {url: "", token: ""}
    m.list.observeField("itemSelected", "settingsSelected")
    m.list.observeField("itemFocused", "settingsPickerDetail")
    m.top.observeField("focusedChild", "settingsFocusChanged")
    m.top.observeField("visible", "settingsVisibilityChanged")
    settingsThemeChanged()
    settingsConnectionChanged()
    settingsRenderMain()
end sub

sub settingsThemeChanged()
    if m.list = invalid then return
    t = HearthTheme(m.top.themeMode)
    m.top.findNode("panel").color = t.surface
    m.heading.color = t.text
    m.hint.color = t.muted
    m.hint.keyBackground = t.surface
    m.detail.color = t.text
    m.detail.font = t.fontBody
    m.detail.font.size = t.smallSize
    m.list.color = t.text
    m.list.focusedColor = t.activeText
    m.list.focusBitmapBlendColor = t.active
    m.list.focusBitmapUri = "pkg:/images/flat.9.png"
    m.list.focusFootprintBitmapUri = "pkg:/images/flat.9.png"
    m.list.focusFootprintBlendColor = t.surfaceAlt
    m.list.font = t.fontBody
    m.list.font.size = t.bodySize
    m.list.focusedFont = m.list.font
    m.save.color = t.text
    m.save.focusedColor = t.activeText
    m.save.focusBitmapBlendColor = t.active
    m.save.focusBitmapUri = "pkg:/images/flat.9.png"
    m.save.focusFootprintBitmapUri = "pkg:/images/flat.9.png"
    m.save.focusFootprintBlendColor = t.surfaceAlt
    m.save.font = m.list.font
    m.save.focusedFont = m.list.font
    m.top.findNode("saveBackground").color = t.surfaceAlt
    m.hint.fontSize = t.smallSize
    m.heading.font = t.fontBold
    m.heading.font.size = t.headingSize
end sub

sub settingsFocusChanged()
    if m.top.visible and m.top.hasFocus() then m.list.setFocus(true)
    if m.mode = "picker"
        m.hint.text = "[OK] Toggle / filter     [Right] Save     [Rew/Fwd] Page     [Back] Cancel"
        if m.save.IsInFocusChain() then m.hint.text = "[OK] Save selection     [Left] Devices     [Back] Cancel"
        if m.preferencesFeedback <> "" then m.hint.text = m.preferencesFeedback
    end if
end sub

sub settingsVisibilityChanged()
    if not m.top.visible
        if m.dialog <> invalid then m.dialog.close = true
        m.mode = "main"
        m.connectionDirty = false
        m.connectionFeedback = ""
        settingsConnectionChanged()
    else
        settingsRenderMain()
    end if
end sub

sub settingsInputsChanged()
    if m.list = invalid then return
    if m.top.visible and m.mode = "main" then settingsRenderMain()
end sub

sub settingsConnectionChanged()
    if m.list = invalid then return
    if not m.connectionDirty
        m.draftConnection = {url: "", token: ""}
        if m.top.connection <> invalid then m.draftConnection = ParseJson(FormatJson(m.top.connection))
    end if
    if m.top.visible and m.mode = "main" then settingsRenderMain()
end sub

function settingsPreferences() as object
    defaults = HearthDefaultPreferences(m.top.config, m.top.states)
    return HearthNormalizePreferences(m.top.preferences, defaults)
end function

sub settingsRows(rows as object, position = 0 as integer)
    content = CreateObject("roSGNode", "ContentNode")
    for each text in rows
        child = content.createChild("ContentNode")
        child.title = text
    end for
    m.list.content = content
    if position >= rows.count() then position = rows.count() - 1
    if position >= 0 then m.list.jumpToItem = position
end sub

sub settingsRenderMain()
    m.saveGroup.visible = false
    m.detail.visible = false
    m.list.numRows = 7
    m.list.clippingRect = [-24, -4, 1152, 368]
    p = settingsPreferences()
    clock = "12-hour"
    if p.clock24 then clock = "24-hour"
    address = m.draftConnection.url
    if address = "" then address = "Not configured"
    tokenStatus = "Not configured"
    if m.draftConnection.token <> "" then tokenStatus = "Configured (hidden)"
    suffix = ""
    if m.connectionDirty then suffix = " — unsaved edits"
    position = m.list.itemFocused
    m.heading.text = "Settings"
    m.hint.text = "[OK] Edit / choose     [Back] Leave; unsaved connection edits are discarded"
    if HearthIsString(m.connectionFeedback)
        if m.connectionFeedback <> "" then m.hint.text = m.connectionFeedback
    end if
    settingsRows(["Home tiles: " + p.sensors.count().toStr() + "/30", "Controls: " + p.controls.count().toStr() + "/48", "Cameras: " + p.cameras.count().toStr() + "/9", "Theme: " + p.theme, "Wallpaper: " + p.wallpaper, "Clock: " + clock, "Refresh: " + p.refreshSeconds.toStr() + " seconds", "HA address: " + address, "Access token: " + tokenStatus, "Save connection" + suffix, "Cancel connection edits"], position)
end sub

sub settingsSelected()
    if m.preferencesPending = true then return
    index = m.list.itemSelected
    if m.mode = "picker"
        settingsPickerSelected(index)
        return
    end if
    if m.mode = "choice"
        if index = 0
            settingsMain()
        else
            p = settingsPreferences()
            p[m.choiceField] = m.choiceValues[index - 1]
            settingsSavePreferences(p)
        end if
        return
    end if
    m.mainPosition = index
    if index < 3
        kinds = ["sensors", "controls", "cameras"]
        settingsOpenPicker(kinds[index])
    else if index = 3
        settingsChoices("theme", "Theme", ["Dark", "Light", "Automatic (sun)"], ["dark", "light", "auto"])
    else if index = 4
        settingsChoices("wallpaper", "Wallpaper", ["Slate", "Sand", "Mist", "None"], ["slate", "sand", "mist", "none"])
    else if index = 5
        settingsChoices("clock24", "Clock", ["12-hour", "24-hour"], [false, true])
    else if index = 6
        settingsKeyboard("refreshSeconds", "Refresh interval (5–3600 seconds)", settingsPreferences().refreshSeconds.toStr())
    else if index = 7
        settingsKeyboard("url", "Home Assistant address (http:// or https://)", m.draftConnection.url)
    else if index = 8
        settingsKeyboard("token", "Home Assistant long-lived access token", "")
    else if index = 9
        settingsSaveConnection()
    else if index = 10
        m.connectionDirty = false
        m.connectionFeedback = "Connection edits discarded."
        settingsConnectionChanged()
        m.hint.text = "Connection edits discarded."
    end if
end sub

sub settingsChoices(field as string, title as string, labels as object, values as object)
    m.mode = "choice"
    m.preferencesFeedback = ""
    m.choiceField = field
    m.choiceValues = values
    m.heading.text = title
    m.hint.text = "[OK] Save choice     [Back] Cancel"
    rows = ["Cancel"]
    current = settingsPreferences()[field]
    position = 0
    for i = 0 to labels.count() - 1
        prefix = "[ ] "
        if current = values[i]
            prefix = "[x] "
            position = i + 1
        end if
        rows.push(prefix + labels[i])
    end for
    settingsRows(rows, position)
end sub


sub settingsOpenPicker(kind as string)
    m.mode = "picker"
    m.preferencesFeedback = ""
    m.pickerKind = kind
    limits = {sensors: 30, controls: 48, cameras: 9}
    m.pickerLimit = limits[kind]
    p = settingsPreferences()
    m.picked = []
    for each id in p[kind]
        m.picked.push(id)
    end for
    domains = {sensors: "|sensor|binary_sensor|climate|person|light|switch|input_boolean|", controls: "|light|switch|scene|script|button|input_boolean|", cameras: "|camera|"}
    m.entities = []
    seen = {}
    states = m.top.states
    config = m.top.config
    areas = m.top.areas
    eligible = []
    for each id in m.picked
        eligible.push(id)
    end for
    if kind = "controls"
        for each action in HearthConfiguredActions(config)
            if not HearthContains(eligible, action.entityId) then eligible.push(action.entityId)
        end for
    end if
    if states = invalid then states = []
    for each state in states
        if state <> invalid and state.entity_id <> invalid
            id = state.entity_id
            domain = HearthEntityDomain(id)
            if domain <> "" and (Instr(1, domains[kind], "|" + domain + "|") > 0 or HearthContains(eligible, id))
                room = "Other"
                if areas <> invalid
                    if areas[id] <> invalid then room = areas[id]
                end if
                title = HearthEntityTitle(state, config)
                label = room + " / " + title
                if not HearthStateAvailable(state) then label = "Unavailable — " + label
                m.entities.push({id: id, room: room, label: label, sortKey: LCase(room + " / " + title + " / " + id)})
                seen[id] = true
            end if
        end if
    end for
    for each id in eligible
        if not seen.doesExist(id)
            m.entities.push({id: id, room: "Other", label: "Unavailable (missing) — Other / " + id, sortKey: "other / " + id})
        end if
    end for
    m.entities.sortBy("sortKey")
    m.rooms = [""]
    for each entity in m.entities
        if not HearthContains(m.rooms, entity.room) then m.rooms.push(entity.room)
    end for
    m.roomIndex = 0
    for i = 1 to m.rooms.count() - 1
        if m.rooms[i] = m.top.preferredRoom
            m.roomIndex = i
            exit for
        end if
    end for
    m.selectedOnly = false
    settingsRenderPicker(0)
end sub

sub settingsRenderPicker(position as integer)
    m.saveGroup.visible = true
    m.detail.visible = true
    m.list.numRows = 5
    m.list.clippingRect = [-24, -4, 1152, 264]
    m.visibleEntities = []
    view = "All devices"
    if m.selectedOnly then view = "Selected only"
    roomLabel = m.rooms[m.roomIndex]
    if m.roomIndex = 0 then roomLabel = "All rooms"
    rows = ["Room: " + roomLabel + " — OK for next room", "View: " + view + " — OK to change"]
    for each entity in m.entities
        if (m.roomIndex = 0 or entity.room = m.rooms[m.roomIndex]) and (not m.selectedOnly or HearthContains(m.picked, entity.id))
            m.visibleEntities.push(entity)
            rows.push(settingsPickerRow(entity))
        end if
    end for
    settingsRows(rows, position)
    settingsPickerCount()
    settingsFocusChanged()
    settingsPickerDetail()
end sub

function settingsPickerRow(entity as object) as string
    prefix = "[ ] "
    if HearthContains(m.picked, entity.id) then prefix = "[x] "
    return prefix + entity.label
end function

sub settingsPickerCount()
    kind = m.pickerKind
    if kind = "sensors" then kind = "Home tiles"
    m.heading.text = "Choose " + kind + " (" + m.picked.count().toStr() + "/" + m.pickerLimit.toStr() + ")"
end sub

sub settingsPickerDetail()
    if m.mode <> "picker" then return
    index = m.list.itemFocused - 2
    if index >= 0 and index < m.visibleEntities.count()
        entity = m.visibleEntities[index]
        selection = "Not selected"
        if HearthContains(m.picked, entity.id) then selection = "Selected"
        m.detail.text = selection + " — " + entity.id
    else
        m.detail.text = m.visibleEntities.count().toStr() + " matching devices. Filters do not change your selection."
        if m.visibleEntities.count() = 0 then m.detail.text = "No matching devices. Change Room or View above; saved selections are retained."
    end if
end sub

sub settingsSaveSelection()
    if m.mode <> "picker" or m.preferencesPending = true then return
    p = settingsPreferences()
    p[m.pickerKind] = m.picked
    settingsSavePreferences(p)
end sub

sub settingsPickerSelected(index as integer)
    if m.preferencesPending = true then return
    if index = 0
        m.roomIndex = (m.roomIndex + 1) mod m.rooms.count()
        settingsRenderPicker(0)
        return
    else if index = 1
        m.selectedOnly = not m.selectedOnly
        settingsRenderPicker(1)
        return
    end if
    entityIndex = index - 2
    if entityIndex < 0 or entityIndex >= m.visibleEntities.count() then return
    entity = m.visibleEntities[entityIndex]
    id = entity.id
    if HearthContains(m.picked, id)
        retained = []
        for each selected in m.picked
            if selected <> id then retained.push(selected)
        end for
        m.picked = retained
    else if m.picked.count() < m.pickerLimit
        m.picked.push(id)
    else
        m.hint.text = "Selection limit reached. Deselect an entity before adding another."
        return
    end if
    if m.selectedOnly and not HearthContains(m.picked, id)
        m.visibleEntities.delete(entityIndex)
        m.list.content.removeChildIndex(index)
        if index >= m.list.content.getChildCount() then m.list.jumpToItem = index - 1
    else
        m.list.content.getChild(index).title = settingsPickerRow(entity)
    end if
    settingsPickerCount()
    settingsPickerDetail()
end sub

sub settingsKeyboard(field as string, title as string, value as string)
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    dialog.title = title
    dialog.buttons = ["Save edit", "Cancel"]
    if field = "token"
        ' Roku's documented secure-entry field; never offer a reveal button.
        dialog.keyboard.textEditBox.secureMode = true
        dialog.message = "Replace token. Text remains hidden. Save connection to apply."
    end if
    dialog.text = value
    m.editField = field
    m.dialog = dialog
    dialog.observeField("buttonSelected", "settingsKeyboardSelected")
    dialog.observeField("wasClosed", "settingsDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub settingsKeyboardSelected()
    if m.preferencesPending = true then return
    if m.dialog.buttonSelected = 0
        value = m.dialog.text.trim()
        if m.editField = "refreshSeconds"
            valid = CreateObject("roRegex", "^[0-9]+$", "")
            if not valid.isMatch(value) or Val(value) < 5 or Val(value) > 3600
                m.dialog.message = "Enter a whole number from 5 to 3600."
                return
            end if
            p = settingsPreferences()
            p.refreshSeconds = Int(Val(value))
            settingsSavePreferences(p)
            return
        else
            m.draftConnection[m.editField] = value
            m.connectionDirty = true
            m.connectionFeedback = ""
        end if
    end if
    m.dialog.close = true
end sub

sub settingsDialogClosed()
    if m.dialog <> invalid
        m.dialog.unobserveField("buttonSelected")
        m.dialog.unobserveField("wasClosed")
        m.dialog.text = ""
        m.dialog = invalid
    end if
    if m.top.visible
        settingsRenderMain()
        m.list.setFocus(true)
    end if
end sub

sub settingsSaveConnection()
    url = m.draftConnection.url.trim()
    token = m.draftConnection.token.trim()
    error = HearthSettingsConnectionError(url, token)
    if error <> ""
        m.connectionFeedback = error
        m.hint.text = error
        return
    end if
    url = HearthBaseUrl(url)
    m.draftConnection = {url: url, token: token}
    m.connectionDirty = true
    m.connectionFeedback = "Saving connection…"
    m.hint.text = "Saving connection…"
    m.top.connectionChanged = {url: url, token: token}
end sub

sub settingsConnectionSaveResult()
    result = m.top.connectionSaveResult
    if result = invalid then return
    if result.ok = true
        m.connectionDirty = false
        m.connectionFeedback = "Connection saved."
    else
        m.connectionDirty = true
        m.connectionFeedback = "Connection was not saved. Edits retained; try Save connection again."
        if result.error <> invalid and result.error <> "" then m.connectionFeedback = result.error
    end if
    settingsRenderMain()
end sub

sub settingsSavePreferences(preferences as object)
    if m.preferencesPending = true then return
    m.preferencesPending = true
    m.preferencesFeedback = "Saving settings…"
    m.hint.text = m.preferencesFeedback
    if m.dialog <> invalid then m.dialog.message = m.preferencesFeedback
    m.top.preferencesChanged = preferences
end sub

sub settingsPreferencesSaveResult()
    if m.preferencesPending <> true then return
    result = m.top.preferencesSaveResult
    if result = invalid then return
    m.preferencesPending = false
    if result.ok = true
        m.preferencesFeedback = ""
        if m.dialog <> invalid and m.editField = "refreshSeconds"
            m.dialog.close = true
        else
            settingsMain()
        end if
    else
        m.preferencesFeedback = "Settings were not saved. Edits retained; try Save again."
        if HearthIsString(result.error)
            if result.error <> "" then m.preferencesFeedback = result.error
        end if
        m.hint.text = m.preferencesFeedback
        if m.dialog <> invalid then m.dialog.message = m.preferencesFeedback
    end if
end sub

sub settingsMain()
    m.mode = "main"
    settingsRenderMain()
    m.list.jumpToItem = m.mainPosition
    if m.top.visible then m.list.setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.preferencesPending = true then return true
    if m.mode = "picker"
        if key = "right"
            m.save.setFocus(true)
            return true
        else if key = "left" and m.save.IsInFocusChain()
            m.list.setFocus(true)
            return true
        end if
    end if
    if key = "fastforward" or key = "rewind"
        position = m.list.itemFocused + m.list.numRows
        if key = "rewind" then position = m.list.itemFocused - m.list.numRows
        if position < 0 then position = 0
        count = m.list.content.getChildCount()
        if position >= count then position = count - 1
        if position >= 0 then m.list.jumpToItem = position
        return true
    end if
    if key = "back"
        if m.mode <> "main"
            settingsMain()
        else
            m.connectionDirty = false
            m.top.closed = true
        end if
        return true
    end if
    return false
end function

function HearthSettingsConnectionError(url as string, token as string) as string
    if HearthBaseUrl(url) = "" then return "Use an HTTP(S) address with a valid port and no credentials, query, fragment, spaces, or backslashes."
    if not HearthConnectionValid({url: url, token: token}) then return "Enter a nonempty access token without spaces or control characters."
    return ""
end function
