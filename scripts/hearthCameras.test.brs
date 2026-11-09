sub Main()
    ' The interpreter cannot resolve Roku system-font URIs; use native Font nodes.
    m.testTheme = HearthTheme("dark")
    m.testTheme.fontBody = CreateObject("roSGNode", "Font")
    m.testTheme.fontBold = CreateObject("roSGNode", "Font")
    _brs_.mockFunction("HearthTheme", function(mode as string) as object
        return m.testTheme
    end function)
    _brs_.mockFunction("CameraLabel", function(parent as object, position as object, width as integer, height as integer, color as string, font as dynamic, size as integer) as object
        label = parent.createChild("Label")
        label.font = font
        label.font.size = size
        return label
    end function)
    for count = 1 to 9
        rects = CameraLayout(count)
        for each rect in rects
            AssertCamera(rect.y >= 0 and rect.y + rect.h <= 438, "camera stacks stay within vertical safe area")
        end for
        AssertCamera(CameraSpatialMove(rects, 0, "up") = -1, "top row returns to navigation")
    end for
    rects = CameraLayout(9)
    AssertCamera(CameraSpatialMove(rects, 0, "down") = 1, "down selects the second camera in a stack")
    AssertCamera(CameraSpatialMove(rects, 1, "right") = 3, "right preserves the bottom row")
    AssertCamera(CameraSpatialMove(rects, 6, "right") = 8, "right reaches the final column")
    AssertCamera(CameraSpatialMove(rects, 8, "left") = 6, "left returns from the final column")
    AssertCamera(CameraSpatialMove(rects, 7, "right") = 8, "right reaches an incomplete final column")
    AssertCamera(CameraSpatialMove(rects, 8, "right") = 8, "right edge retains selection")
    AssertCamera(CameraSpatialMove(rects, 1, "down") = 1, "bottom edge retains selection")
    rects = CameraLayout(3)
    AssertCamera(CameraSpatialMove(rects, 1, "down") = 2, "three-camera right column remains navigable")
    TestCameraBuildAndRefresh()
    m.top = {visible: true, themeMode: "dark", selected: 0, config: {}, states: [{entity_id: "camera.front", state: "idle", attributes: {friendly_name: "Front door"}}], IsInFocusChain: function() as boolean
        return false
    end function}
    m.ids = ["camera.front"]
    m.selectionGuard = false
    front = CameraTestPoster("front", "ready", "last-good-image")
    back = CameraTestPoster("back", "failed", "replacement-image")
    tile = {title: {text: "Front door"}, status: {}, loading: {}, poster: front, loader: back, border: {}, group: {}, rect: {x: 0, y: 0}, available: true, stateText: "idle", snapshot: "loading", hasReady: true, failed: false, requesting: true}
    m.tiles = [tile]
    CameraImageStatusChanged(CameraTestEvent("failed", back))
    AssertCamera(tile.failed and not tile.requesting and tile.poster.uri = "last-good-image" and not tile.loading.visible, "failed refresh preserves last image")
    m.top.states[0].state = "streaming"
    UpdateCameraMetadata()
    AssertCamera(tile.failed and Instr(1, tile.poster.audioGuideText, "failed") > 0, "metadata refresh cannot clear or conceal image failure")
    tile.requesting = true
    back.loadStatus = "loading"
    CameraImageStatusChanged(CameraTestEvent("ready", back))
    AssertCamera(tile.requesting and tile.failed and tile.poster.IsSameNode(front), "stale ready event cannot replace the last good image")
    back.loadStatus = "ready"
    CameraImageStatusChanged(CameraTestEvent("ready", back))
    AssertCamera(not tile.failed and not tile.requesting and tile.hasReady and tile.poster.IsSameNode(back), "successful callback swaps the image and clears failure")
    AssertCamera(tile.loader.uri = "" and tile.poster.opacity = 1 and tile.loader.opacity = 0, "completed swap releases old request without hiding new image")
    _brs_.mockComponent("roHttpAgent", {})
    m.refreshNewOnly = false
    m.serial = 0
    m.top.visible = false
    CameraVisibilityChanged()
    AssertCamera(not tile.hasReady and not tile.failed and not tile.requesting and tile.poster.uri = "" and tile.loader.uri = "", "hiding releases images and resets asynchronous state")
    AssertCamera(not tile.poster.agent.DoesExist("Authorization") and not tile.loader.agent.DoesExist("Authorization"), "hidden image nodes release bearer agents")
    CameraImageStatusChanged(CameraTestEvent("ready", back))
    AssertCamera(not tile.hasReady, "hidden completion cannot resurrect an image")
    m.top.visible = true
    CameraVisibilityChanged()
    AssertCamera(tile.poster.IsSameNode(back) and tile.loading.visible and tile.snapshot = "connection", "reentry uses real refresh and reports missing connection")
    m.top.states[0].state = "unavailable"
    UpdateCameraMetadata()
    AssertCamera(not tile.available and tile.loading.visible and Instr(1, tile.poster.audioGuideText, "Press OK") = 0, "unavailable camera does not promise playback")
    print "HEARTH_CAMERAS_TESTS_PASSED"
end sub

sub TestCameraBuildAndRefresh()
    m.agentAttachments = []
    m.nextAuthorization = ""
    m.nextCertificates = ""
    _brs_.mockComponent("Poster", {uri: "", SetHttpAgent: sub(agent as object)
        m.agentAttachments.Push({authorization: m.nextAuthorization, certificates: m.nextCertificates})
        m.nextAuthorization = ""
        m.nextCertificates = ""
    end sub})
    _brs_.mockComponent("roHttpAgent", {SetCertificatesFile: sub(path as string)
        m.nextCertificates = path
    end sub, AddHeader: sub(name as string, value as string)
        if name = "Authorization" then m.nextAuthorization = value
    end sub})
    m.top = {visible: true, selected: 0, themeMode: "dark", config: {}, connection: {url: "https://ha.example", token: "test-token"}, entityIds: [], states: [], IsInFocusChain: function() as boolean
        return false
    end function}
    m.tilesRoot = CreateObject("roSGNode", "Group")
    m.empty = {}
    m.tiles = []
    m.ids = []
    m.serial = 0
    m.refreshNewOnly = false
    for i = 0 to 8
        id = "camera.test_" + i.ToStr().Trim()
        m.top.entityIds.Push(id)
        m.top.states.Push({entity_id: id, state: "idle", attributes: {friendly_name: "Camera", entity_picture: "https://untrusted.example/image"}})
    end for
    BuildCameras()
    AssertCamera(m.tiles.Count() = 9 and m.tilesRoot.GetChildCount() = 9 and not m.empty.visible, "build creates one tile per selected camera")
    AssertCamera(m.tiles[0].requesting and m.tiles[3].requesting and not m.tiles[4].requesting and m.tiles[4].loader.uri = "", "initial build requests only the visible columns")
    firstUri = m.tiles[0].loader.uri
    AssertCamera(Instr(1, firstUri, "https://ha.example/api/camera_proxy/camera.test_0?width=") = 1 and Instr(1, firstUri, "&height=") > 0, "snapshot uses authenticated proxy and tile dimensions rather than entity_picture")
    AssertCamera(m.agentAttachments.Count() = 4, "each visible request attaches its own agent")
    for each attached in m.agentAttachments
        AssertCamera(attached.authorization = "Bearer test-token" and attached.certificates = "common:/certs/ca-bundle.crt", "real request setup configures scoped bearer and TLS certificates")
    end for
    RefreshCameraImages()
    AssertCamera(m.tiles[0].loader.uri = firstUri, "refresh does not replace an in-flight request")
    for each tile in m.tiles
        tile.requesting = false
        tile.loader.uri = ""
    end for
    m.top.selected = 8
    UpdateCameraFocus()
    RefreshCameraImages()
    AssertCamera(m.tiles[8].group.visible and m.tiles[8].requesting and not m.tiles[0].group.visible and m.tiles[0].loader.uri = "", "scrolling requests the selected visible camera but not offscreen cameras")
    for each tile in m.tiles
        if tile.group.visible
            AssertCamera(tile.group.translation[0] >= 248 and tile.group.translation[0] + tile.rect.w <= 904, "visible cameras remain inside the horizontal viewport")
            AssertCamera(tile.group.translation[1] >= 0 and tile.group.translation[1] + tile.rect.h <= 438, "visible cameras remain inside the vertical viewport")
        else
            AssertCamera(not tile.requesting and tile.loader.uri = "", "refresh never starts an offscreen request")
        end if
    end for
    oldLoader = m.tiles[8].loader
    m.top.entityIds = ["camera.test_8", "camera.test_0", "camera.test_1", "camera.test_2", "camera.test_3"]
    m.top.connection.token = "replacement-token"
    BuildCameras()
    AssertCamera(m.top.selected = 0 and m.ids[m.top.selected] = "camera.test_8", "rebuild preserves selected camera identity after reordering")
    AssertCamera(m.tilesRoot.GetChildCount() = 5 and not m.tiles[0].loader.IsSameNode(oldLoader), "rebuild replaces old visual nodes")
    AssertCamera(oldLoader.uri = "", "discarded loader releases its request")
    AssertCamera(m.tiles[0].requesting and m.agentAttachments.Peek().authorization = "Bearer replacement-token", "rebuilt visible requests attach the current bearer")
    m.agentAttachments = []
    m.top.visible = false
    CameraVisibilityChanged()
    RefreshCameraImages()
    AssertCamera(not m.tiles[0].requesting and m.tiles[0].loader.uri = "" and m.agentAttachments.Count() = 10, "hidden camera pairs release agents without starting requests")
    for each attached in m.agentAttachments
        AssertCamera(attached.authorization = "" and attached.certificates = "", "hidden cameras attach unauthenticated agents")
    end for
    m.top.visible = true
    CameraVisibilityChanged()
    AssertCamera(m.tiles[0].requesting and m.agentAttachments.Peek().authorization = "Bearer replacement-token" and not m.tiles[4].requesting, "reentry restores credentials and requests only visible cameras")
end sub

function CameraTestPoster(id as string, status as string, uri as string) as object
    return {id: id, loadStatus: status, uri: uri, agent: {Authorization: "test"}, IsSameNode: function(other as object) as boolean
        return m.id = other.id
    end function, SetHttpAgent: sub(agent as object)
        m.agent = agent
    end sub}
end function

function CameraTestEvent(status as string, node as object) as object
    return {status: status, node: node, GetData: function() as string
        return m.status
    end function, GetRoSGNode: function() as object
        return m.node
    end function}
end function

sub AssertCamera(condition as boolean, message as string)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
