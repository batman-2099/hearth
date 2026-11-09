sub Main()
    _brs_.mockFunction("HearthHttp", TaskHttp)
    _brs_.mockFunction("Sleep")
    _brs_.mockFunction("HaCameraStream", TaskStream)
    m.streamCalls = 0
    m.streamResult = {ok: true, url: "http://fixture/live.m3u8", error: ""}
    m.statesFail = false
    m.serviceFail = false
    m.templateFails = true
    m.templateCalls = 0
    m.serviceCalls = 0
    m.roomMap = {"light.one": "Kitchen"}
    m.httpStates = [{entity_id: "button.identify", state: "unknown", attributes: {}}]
    m.top = {request: {op: "refresh", connection: {url: "http://ha.local", token: "test"}, preferences: {}, states: [], areas: invalid, config: {}}}
    HearthRunRequest()
    CheckTask(not m.top.result.ok and m.top.result.areas = invalid and m.top.result.statesFresh, "failed discovery remains unloaded while states succeed")
    m.top.request.areas = m.top.result.areas
    m.templateFails = false
    HearthRunRequest()
    CheckTask(m.templateCalls = 2 and m.top.result.areas["light.one"] = "Kitchen", "next refresh retries and recovers room metadata")
    m.top.request.areas = m.top.result.areas
    HearthRunRequest()
    CheckTask(m.templateCalls = 2 and m.top.result.ok, "successful metadata remains cached")
    m.top.request.areas = invalid
    m.roomMap = {}
    HearthRunRequest()
    m.top.request.areas = m.top.result.areas
    HearthRunRequest()
    CheckTask(m.templateCalls = 3 and m.top.result.areas.Count() = 0, "successful empty metadata is cached, unlike failure")
    m.top.request.op = "action"
    m.top.request.states = m.httpStates
    m.top.request.preferences = {controls: ["button.identify"]}
    m.top.request.action = {entityId: "button.identify", domain: "button", service: "press"}
    HearthRunRequest()
    CheckTask(m.top.result.ok and m.serviceCalls = 1, "Task permits an explicitly selected first-use button")
    m.top.request.preferences = {controls: []}
    HearthRunRequest()
    CheckTask(not m.top.result.ok and m.serviceCalls = 1, "Task denies the same button when authorization is removed")
    m.top.request.preferences = {controls: ["button.identify"]}
    m.top.request.states[0].state = "unavailable"
    HearthRunRequest()
    CheckTask(not m.top.result.ok and m.serviceCalls = 1, "Task never sends an unavailable button command")
    ' Stream authorization happens before discovery; neither HTTP nor sockets are real.
    m.top.request = {op: "stream", connection: {url: "http://ha.local/", token: "test"}, preferences: {cameras: []}, states: [{entity_id: "camera.front", state: "idle", attributes: {}}], areas: {}, config: {}, entityId: "camera.front"}
    HearthRunRequest()
    CheckTask(not m.top.result.ok and m.streamCalls = 0, "unselected camera never reaches discovery")
    m.top.request.preferences.cameras = ["camera.front"]
    m.top.request.states[0].state = "unavailable"
    HearthRunRequest()
    CheckTask(not m.top.result.ok and m.streamCalls = 0, "unavailable camera never reaches discovery")
    m.top.request.states = []
    HearthRunRequest()
    CheckTask(not m.top.result.ok and m.streamCalls = 0, "missing camera never reaches discovery")
    m.top.request.states = [{entity_id: "camera.front", state: "idle", attributes: {}}]
    m.top.request.entityId = "light.one"
    HearthRunRequest()
    CheckTask(not m.top.result.ok and m.streamCalls = 0, "non-camera stream request denied")
    m.top.request.entityId = "camera.front"
    HearthRunRequest()
    CheckTask(m.top.result.ok and m.top.result.streamUrl = m.streamResult.url and m.streamCalls = 1, "stream success URL propagated")
    CheckTask(m.streamConnection.url = "http://ha.local" and m.streamEntity = "camera.front", "discovery receives normalized connection and selected entity")
    m.streamResult = {ok: false, url: "http://fixture/not-playable", error: "Fixture discovery failed."}
    HearthRunRequest()
    CheckTask(not m.top.result.ok and m.top.result.streamUrl = "" and m.top.result.error = m.streamResult.error and m.streamCalls = 2, "stream failure propagated without a playable URL")
    m.top.request.op = "refresh"
    cached = [{entity_id: "light.one", state: "on", attributes: {}}]
    m.top.request.states = cached
    m.statesFail = true
    HearthRunRequest()
    CheckTask(not m.top.result.ok and not m.top.result.statesFresh and m.top.result.states[0].state = "on", "failed refresh retains stale states")
    m.statesFail = false
    for each malformed in [invalid, {}, [invalid], [{entity_id: "bad/id", state: "on"}], [{entity_id: "light.one", state: 42}]]
        m.httpStates = malformed
        HearthRunRequest()
        CheckTask(not m.top.result.ok and not m.top.result.statesFresh and m.top.result.states[0].state = "on", "malformed states retain cached values")
    end for
    m.httpStates = []
    HearthRunRequest()
    CheckTask(m.top.result.ok and m.top.result.statesFresh and m.top.result.states.Count() = 0, "valid empty states replace stale values")
    m.top.request.op = "action"
    m.top.request.preferences = {controls: ["button.identify"]}
    m.top.request.states = [{entity_id: "button.identify", state: "unknown", attributes: {}}]
    m.top.request.action = {entityId: "button.identify", domain: "button", service: "press"}
    m.serviceFail = true
    before = m.serviceCalls
    HearthRunRequest()
    CheckTask(m.serviceCalls = before + 1 and not m.top.result.ok and m.top.result.message = "" and m.top.result.statesFresh, "ambiguous service failure sends exactly once and still refreshes")
    CheckTask(Instr(1, m.top.result.error, "may have reached Home Assistant") > 0, "ambiguous failure warns against blind retry")
    m.top.request.op = "refresh"
    HearthRunRequest()
    CheckTask(m.serviceCalls = before + 1 and m.top.result.ok, "refresh never replays retained action fields")
    print "HEARTH_TASK_TESTS_PASSED"
end sub

function TaskHttp(connection as object, path as string, body = invalid as dynamic) as object
    if path = "/api/states"
        if m.statesFail then return {ok: false, data: invalid, error: "Timed out."}
        return {ok: true, data: m.httpStates, error: ""}
    end if
    if path = "/api/template"
        m.templateCalls = m.templateCalls + 1
        if m.templateFails then return {ok: false, data: invalid, error: "Timed out."}
        return {ok: true, data: m.roomMap, error: ""}
    end if
    m.serviceCalls = m.serviceCalls + 1
    if m.serviceFail then return {ok: false, data: invalid, error: "Timed out."}
    return {ok: true, data: [], error: ""}
end function

function TaskStream(connection as object, id as string) as object
    m.streamCalls = m.streamCalls + 1
    m.streamConnection = connection
    m.streamEntity = id
    return m.streamResult
end function

sub CheckTask(condition as boolean, message as string)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
