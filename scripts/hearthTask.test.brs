sub Main()
    _brs_.mockFunction("HearthHttp", TaskHttp)
    _brs_.mockFunction("Sleep", TaskSleep)
    _brs_.mockFunction("HaCameraStream", TaskStream)
    m.streamCalls = 0
    m.streamResult = {ok: true, url: "http://fixture/live.m3u8", error: ""}
    m.statesFail = false
    m.serviceFail = false
    m.templateFails = true
    m.templateCalls = 0
    m.serviceCalls = 0
    m.requestEvents = []
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
    m.serviceFail = false
    climate = {entity_id: "climate.hall", state: "heat", attributes: {supported_features: 11, temperature: 21, target_temp_low: 19, target_temp_high: 24, min_temp: 7, max_temp: 35, target_temp_step: 0.5, hvac_modes: ["off", "heat", "heat_cool"], fan_mode: "auto", fan_modes: ["auto", "low"]}}
    m.httpStates = [climate]
    m.top.request = {op: "action", connection: {url: "http://ha.local", token: "test"}, preferences: {controls: ["climate.hall"]}, states: [climate], areas: {}, config: {}}
    cases = [
        {mode: "heat", service: "set_temperature", data: {temperature: 21.5}}
        {mode: "heat_cool", service: "set_temperature", data: {target_temp_low: 19.5, target_temp_high: 24}}
        {mode: "heat", service: "set_hvac_mode", data: {hvac_mode: "heat_cool"}}
        {mode: "heat", service: "set_fan_mode", data: {fan_mode: "low"}}
    ]
    for each fixture in cases
        climate.state = fixture.mode
        m.top.request.action = {entityId: "climate.hall", domain: "climate", service: fixture.service, data: fixture.data}
        before = m.serviceCalls
        m.requestEvents = []
        HearthRunRequest()
        CheckTask(m.top.result.ok and m.top.result.message = "Action sent." and m.top.result.statesFresh, "authorized climate action succeeds and refreshes")
        CheckTask(m.serviceCalls = before + 1 and m.servicePath = "/api/services/climate/" + fixture.service, "climate action posts once to its actual service")
        CheckTask(m.serviceBody.entity_id = "climate.hall" and m.serviceBody.Count() = fixture.data.Count() + 1, "climate payload contains only selected entity and authorized data")
        for each key in fixture.data
            if HearthIsNumber(fixture.data[key])
                CheckTask(HearthIsNumber(m.serviceBody[key]), "climate temperature remains a JSON number")
            else
                CheckTask(HearthIsString(m.serviceBody[key]), "climate mode remains a JSON string")
            end if
            CheckTask(m.serviceBody[key] = fixture.data[key], "climate payload preserves every service value")
        end for
        CheckTask(m.requestEvents.Join("|") = m.servicePath + "|sleep:1000|/api/states", "climate action waits one second then refreshes without retries")
    end for
    m.serviceFail = true
    m.top.request.action = {entityId: "climate.hall", domain: "climate", service: "set_temperature", data: {temperature: 22}}
    before = m.serviceCalls
    m.requestEvents = []
    HearthRunRequest()
    CheckTask(m.serviceCalls = before + 1 and not m.top.result.ok and m.top.result.message = "" and m.top.result.statesFresh, "failed climate action posts once and still refreshes")
    CheckTask(m.requestEvents.Join("|") = "/api/services/climate/set_temperature|sleep:1000|/api/states", "failed climate action retains delay and never retries")
    CheckTask(Instr(1, m.top.result.error, "may have reached Home Assistant") > 0, "failed climate action preserves ambiguous-result warning")
    m.top.request.op = "refresh"
    HearthRunRequest()
    CheckTask(m.serviceCalls = before + 1 and m.top.result.ok, "refresh never replays failed climate action")
    m.serviceFail = false
    m.top.request.op = "action"
    m.top.request.preferences = {controls: [], sensors: ["climate.hall"]}
    before = m.serviceCalls
    m.requestEvents = []
    HearthRunRequest()
    CheckTask(not m.top.result.ok and m.top.result.statesFresh and m.serviceCalls = before, "discovered climate on Home without Controls selection cannot POST")
    CheckTask(m.requestEvents.Join("|") = "/api/states", "unselected climate only refreshes")
    m.top.request.preferences = {controls: ["climate.hall"]}
    m.top.request.action.data.entity_id = "climate.other"
    m.requestEvents = []
    HearthRunRequest()
    CheckTask(not m.top.result.ok and m.top.result.statesFresh and m.serviceCalls = before, "extra climate target is rejected before POST")
    CheckTask(m.requestEvents.Join("|") = "/api/states", "extra target only refreshes and never reaches transport")
    print "HEARTH_TASK_TESTS_PASSED"
end sub

function TaskHttp(connection as object, path as string, body = invalid as dynamic) as object
    m.requestEvents.Push(path)
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
    m.servicePath = path
    m.serviceBody = ParseJson(body)
    if m.serviceFail then return {ok: false, data: invalid, error: "Timed out."}
    return {ok: true, data: [], error: ""}
end function

sub TaskSleep(milliseconds as integer)
    m.requestEvents.Push("sleep:" + milliseconds.ToStr().Trim())
end sub

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
