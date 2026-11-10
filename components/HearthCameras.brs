sub init()
    m.tilesRoot = m.top.FindNode("cameraTiles")
    m.empty = m.top.FindNode("cameraEmpty")
    m.tiles = []
    m.ids = []
    m.refreshNewOnly = false
    m.serial = 0
    m.selectionGuard = false
    m.top.ObserveField("entityIds", "BuildCameras")
    m.top.ObserveField("connection", "BuildCameras")
    m.top.ObserveField("themeMode", "ApplyCameraTheme")
    m.top.ObserveField("config", "UpdateCameraMetadata")
    m.top.ObserveField("states", "UpdateCameraMetadata")
    m.top.ObserveField("refreshTick", "RefreshCameraImages")
    m.top.ObserveField("visible", "CameraVisibilityChanged")
    m.top.ObserveField("selected", "UpdateCameraFocus")
    m.top.ObserveField("focusedChild", "UpdateCameraFocus")
    m.top.visible = false
    BuildCameras()
end sub

sub CameraVisibilityChanged()
    if m.top.visible
        UpdateCameraMetadata()
        UpdateCameraFocus()
        RefreshCameraImages()
    else
        ClearCameraImages()
    end if
end sub

sub ClearCameraImages()
    for each tile in m.tiles
        tile.requesting = false
        tile.hasReady = false
        tile.failed = false
        tile.snapshot = "waiting"
        tile.poster.uri = ""
        tile.loader.uri = ""
        ' Do not leave bearer credentials attached to hidden or discarded image nodes.
        tile.poster.SetHttpAgent(CreateObject("roHttpAgent"))
        tile.loader.SetHttpAgent(CreateObject("roHttpAgent"))
        RenderCameraStatus(tile)
    end for
end sub

sub BuildCameras()
    m.selectionGuard = true
    restoreFocus = m.top.IsInFocusChain()
    if restoreFocus then m.top.SetFocus(true)
    priorId = ""
    if m.top.selected >= 0 and m.top.selected < m.ids.Count() then priorId = m.ids[m.top.selected]
    ClearCameraImages()
    m.tilesRoot.RemoveChildrenIndex(m.tilesRoot.GetChildCount(), 0)
    m.tiles = []
    m.ids = []
    seen = {}
    if type(m.top.entityIds) = "roArray"
        for each id in m.top.entityIds
            if HaCameraIdValid(id)
                if not seen.DoesExist(id) and m.ids.Count() < 9
                    m.ids.Push(id)
                    seen[id] = true
                end if
            end if
        end for
    end if
    theme = HearthTheme(m.top.themeMode)
    m.empty.color = theme.text
    m.empty.font = theme.fontBody
    m.empty.font.size = theme.bodySize
    m.empty.text = "No cameras selected. Open Settings to choose your Home Assistant cameras."
    m.empty.visible = m.ids.Count() = 0
    positions = CameraLayout(m.ids.Count())
    selection = m.top.selected
    for i = 0 to m.ids.Count() - 1
        if m.ids[i] = priorId then selection = i
        rect = positions[i]
        group = CreateObject("roSGNode", "Group")
        group.translation = [rect.x, rect.y]
        border = CreateObject("roSGNode", "Rectangle")
        border.width = rect.w
        border.height = rect.h
        border.color = theme.rule
        group.AppendChild(border)
        panel = CreateObject("roSGNode", "Rectangle")
        panel.translation = [3, 3]
        panel.width = rect.w - 6
        panel.height = rect.h - 6
        panel.color = theme.surface
        group.AppendChild(panel)
        poster = CreateObject("roSGNode", "Poster")
        poster.translation = [4, 4]
        poster.width = rect.w - 8
        poster.height = rect.h - 74
        poster.loadWidth = rect.w - 8
        poster.loadHeight = poster.height
        poster.loadDisplayMode = "scaleToFit"
        poster.ObserveField("loadStatus", "CameraImageStatusChanged")
        group.AppendChild(poster)
        loader = CreateObject("roSGNode", "Poster")
        loader.translation = poster.translation
        loader.width = poster.width
        loader.height = poster.height
        loader.loadWidth = poster.loadWidth
        loader.loadHeight = poster.loadHeight
        loader.loadDisplayMode = "scaleToFit"
        loader.opacity = 0
        loader.ObserveField("loadStatus", "CameraImageStatusChanged")
        group.AppendChild(loader)
        title = CameraLabel(group, [14, rect.h - 56], rect.w - 28, 28, theme.text, theme.fontBold, theme.smallSize)
        title.horizAlign = "center"
        status = CameraLabel(group, [14, rect.h - 29], rect.w - 28, 26, theme.muted, theme.fontBody, theme.smallSize)
        loading = CameraLabel(group, [12, Int(poster.height / 2) - 10], rect.w - 24, 28, theme.muted, theme.fontBody, theme.smallSize)
        loading.horizAlign = "center"
        m.tilesRoot.AppendChild(group)
        m.tiles.Push({group: group, panel: panel, poster: poster, loader: loader, title: title, status: status, loading: loading, border: border, rect: rect, available: false, snapshot: "waiting", hasReady: false, failed: false, requesting: false})
    end for
    if selection < 0 then selection = 0
    if selection >= m.ids.Count() then selection = 0
    m.selectionGuard = true
    m.top.selected = selection
    m.selectionGuard = false
    UpdateCameraMetadata()
    if restoreFocus then m.top.SetFocus(true)
    UpdateCameraFocus()
    RefreshCameraImages()
end sub

sub UpdateCameraMetadata()
    for i = 0 to m.ids.Count() - 1
        tile = m.tiles[i]
        state = HearthStateById(m.top.states, m.ids[i])
        tile.title.text = HearthEntityTitle({entity_id: m.ids[i]}, m.top.config)
        tile.available = false
        tile.stateText = "Unavailable"
        if state <> invalid
            tile.title.text = HearthEntityTitle(state, m.top.config)
            tile.available = state.state <> "unavailable" and state.state <> "unknown"
            tile.stateText = state.state
        end if
        if not tile.available
            tile.requesting = false
            tile.poster.uri = ""
            tile.loader.uri = ""
            tile.hasReady = false
            tile.snapshot = "waiting"
        end if
        RenderCameraStatus(tile)
    end for
end sub

sub RenderCameraStatus(tile as object)
    text = "Waiting for snapshot"
    if tile.snapshot = "loading"
        text = "Loading snapshot…"
        if tile.hasReady then text = "Refreshing snapshot…"
    else if tile.snapshot = "ready"
        text = "Snapshot (not live)"
    else if tile.snapshot = "connection"
        text = "Set up connection in Settings"
    end if
    if tile.failed
        text = "Snapshot failed. Will retry"
        if tile.requesting then text = "Snapshot failed; retrying"
    end if
    if not tile.available then text = "Camera unavailable"
    tile.status.text = text
    tile.status.visible = tile.failed or not tile.hasReady or not tile.available
    tile.loading.text = text
    tile.loading.visible = not tile.hasReady
    action = " Press OK for live camera."
    if not tile.available then action = " Check this camera in Home Assistant."
    tile.poster.audioGuideText = tile.title.text + ". " + text + ". Camera reports " + tile.stateText + "." + action
end sub

sub ApplyCameraTheme()
    theme = HearthTheme(m.top.themeMode)
    m.empty.color = theme.text
    m.empty.font = theme.fontBody
    m.empty.font.size = theme.bodySize
    for each tile in m.tiles
        tile.panel.color = theme.surface
        tile.title.color = theme.text
        tile.title.font = theme.fontBold
        tile.title.font.size = theme.smallSize
        tile.status.color = theme.muted
        tile.status.font = theme.fontBody
        tile.status.font.size = theme.smallSize
        tile.loading.color = theme.muted
        tile.loading.font = theme.fontBody
        tile.loading.font.size = theme.smallSize
    end for
    UpdateCameraFocus()
end sub

sub RefreshCameraImages()
    if not m.top.visible then return
    connection = m.top.connection
    origin = invalid
    authenticated = false
    if type(connection) = "roAssociativeArray"
        origin = HaCameraOrigin(connection.url)
        authenticated = HearthTokenValid(connection.token)
    end if
    m.serial = m.serial + 1
    stamp = CreateObject("roDateTime").AsSeconds().ToStr().Trim() + "-" + m.serial.ToStr().Trim()
    for i = 0 to m.tiles.Count() - 1
        tile = m.tiles[i]
        shouldRefresh = not m.refreshNewOnly or tile.snapshot = "waiting"
        if origin = invalid or not authenticated
            tile.requesting = false
            tile.poster.uri = ""
            tile.loader.uri = ""
            tile.hasReady = false
            tile.snapshot = "connection"
            RenderCameraStatus(tile)
        else if tile.available and tile.group.visible and not tile.requesting and shouldRefresh
            ' Keep the last successful image while the second Poster fetches its replacement.
            ' Scope the bearer to this Poster only; never use entity_picture URLs.
            agent = CreateObject("roHttpAgent")
            agent.SetCertificatesFile("common:/certs/ca-bundle.crt")
            agent.AddHeader("Authorization", "Bearer " + connection.token)
            tile.loader.SetHttpAgent(agent)
            tile.requesting = true
            tile.snapshot = "loading"
            RenderCameraStatus(tile)
            tile.loader.uri = origin.base + "/api/camera_proxy/" + m.ids[i] + "?width=" + Int(tile.loader.width).ToStr().Trim() + "&height=" + Int(tile.loader.height).ToStr().Trim() + "&hearth=" + stamp
        end if
    end for
end sub

sub CameraImageStatusChanged(event as object)
    if not m.top.visible then return
    for each tile in m.tiles
        if tile.requesting and event.GetRoSGNode().IsSameNode(tile.loader)
            status = event.GetData()
            ' Ignore queued notifications from an image request cleared before tab re-entry.
            if status <> tile.loader.loadStatus then return
            if status = "ready"
                tile.requesting = false
                tile.hasReady = true
                tile.failed = false
                tile.snapshot = "ready"
                previous = tile.poster
                tile.poster = tile.loader
                tile.loader = previous
                tile.poster.opacity = 1
                tile.loader.opacity = 0
                RenderCameraStatus(tile)
                UpdateCameraFocus()
                tile.loader.uri = ""
            else if status = "failed"
                tile.requesting = false
                tile.failed = true
                RenderCameraStatus(tile)
            end if
        end if
    end for
end sub

sub UpdateCameraFocus()
    if m.selectionGuard then return
    m.selectionGuard = true
    first = 0
    if m.tiles.Count() > 4 and m.top.selected >= 4 then first = (Int(m.top.selected / 2) - 1) * 2
    last = first + 3
    if last >= m.tiles.Count() then last = m.tiles.Count() - 1
    offset = 0
    if first > 0 then offset = m.tiles[first].rect.x - m.tiles[0].rect.x
    theme = HearthTheme(m.top.themeMode)
    for i = 0 to m.tiles.Count() - 1
        tile = m.tiles[i]
        tile.group.visible = i >= first and i <= last
        tile.group.translation = [tile.rect.x - offset, tile.rect.y]
        color = theme.rule
        if i = m.top.selected and m.top.IsInFocusChain() then color = theme.focus
        m.tiles[i].border.color = color
    end for
    if m.top.visible and m.top.IsInFocusChain()
        if m.top.selected >= 0 and m.top.selected < m.tiles.Count()
            poster = m.tiles[m.top.selected].poster
            if not poster.HasFocus() then poster.SetFocus(true)
        end if
    end if
    m.top.hint = "Settings: choose cameras"
    if m.tiles.Count() > 0
        m.top.hint = "[Arrows] Cameras   [OK] Live camera   [Back] Pages"
        if m.tiles.Count() > 4
            m.top.hint = (first + 1).ToStr().Trim() + "–" + (last + 1).ToStr().Trim() + " of " + m.tiles.Count().ToStr().Trim() + "   [Arrows] Cameras   [Left/Right] Scroll   [OK] Live camera   [Back] Pages"
        end if
    end if
    m.selectionGuard = false
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        m.top.leave = true
        return true
    end if
    if key = "OK"
        if m.top.selected >= 0 and m.top.selected < m.ids.Count() then m.top.itemSelected = m.ids[m.top.selected]
        return true
    end if
    if key <> "up" and key <> "down" and key <> "left" and key <> "right" then return false
    if m.tiles.Count() = 0
        if key = "up" then m.top.leave = true
        return true
    end if
    index = CameraSpatialMove(CameraLayout(m.tiles.Count()), m.top.selected, key)
    if index < 0
        m.top.leave = true
    else
        m.top.selected = index
        m.refreshNewOnly = true
        RefreshCameraImages()
        m.refreshNewOnly = false
    end if
    return true
end function

function CameraLabel(parent as object, position as object, width as integer, height as integer, color as string, font as string, size as integer) as object
    label = CreateObject("roSGNode", "Label")
    label.translation = position
    label.width = width
    label.height = height
    label.color = color
    label.font = font
    label.font.size = size
    parent.AppendChild(label)
    return label
end function

function CameraLayout(count as integer) as object
    if count = 0 then return []
    if count = 1 then return [{x: 248, y: 0, w: 656, h: 438}]
    if count = 3 then return [{x: 248, y: 0, w: 432, h: 438}, {x: 696, y: 0, w: 208, h: 211}, {x: 696, y: 227, w: 208, h: 211}]
    columns = 2
    rows = 2
    if count = 2 then rows = 1
    width = Int((656 - (columns - 1) * 16) / columns)
    height = Int((438 - (rows - 1) * 16) / rows)
    result = []
    for i = 0 to count - 1
        result.Push({x: 248 + Int(i / rows) * (width + 16), y: (i mod rows) * (height + 16), w: width, h: height})
    end for
    return result
end function

function CameraSpatialMove(rects as object, selected as integer, key as string) as integer
    if selected < 0 or selected >= rects.Count() then return 0
    source = rects[selected]
    sx = source.x + source.w / 2
    sy = source.y + source.h / 2
    best = selected
    score = 1e20
    for i = 0 to rects.Count() - 1
        target = rects[i]
        tx = target.x + target.w / 2
        ty = target.y + target.h / 2
        direction = false
        distance = 0
        if key = "left" or key = "right"
            direction = (key = "left" and target.x + target.w <= source.x) or (key = "right" and target.x >= source.x + source.w)
            distance = Abs(tx - sx) + Abs(ty - sy) * 3
        else
            direction = (key = "up" and target.y + target.h <= source.y) or (key = "down" and target.y >= source.y + source.h)
            distance = Abs(ty - sy) + Abs(tx - sx) * 3
        end if
        if direction and distance < score
            best = i
            score = distance
        end if
    end for
    if key = "up" and best = selected then return -1
    return best
end function

