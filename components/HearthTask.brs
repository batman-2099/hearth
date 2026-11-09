sub init()
    m.top.functionName = "HearthRunRequest"
end sub

sub HearthRunRequest()
    ' One Task invocation owns one request; never observe and replay action fields.
    request = m.top.request
    result = {ok: false, error: "", message: "", states: [], areas: invalid, streamUrl: "", statesFresh: false}
    if type(request) <> "roAssociativeArray"
        result.error = "No Home Assistant request supplied."
        m.top.result = result
        return
    end if
    if type(request.states) = "roArray" then result.states = request.states
    if type(request.areas) = "roAssociativeArray" then result.areas = request.areas
    preferences = HearthNormalizePreferences(request.preferences, HearthDefaultPreferences(request.config, result.states))
    if not HearthConnectionValid(request.connection)
        result.error = "Save a valid Home Assistant HTTP(S) address and access token in Settings."
        m.top.result = result
        return
    end if
    connection = {url: HearthBaseUrl(request.connection.url), token: request.connection.token}
    if request.op = "stream"
        if HearthEntityDomain(request.entityId) <> "camera"
            result.error = "Choose a valid Home Assistant camera."
        else if not HearthContains(preferences.cameras, request.entityId)
            result.error = "This camera is not selected in Settings."
        else if not HearthStateAvailable(HearthStateById(result.states, request.entityId))
            result.error = "Camera unavailable."
        else
            stream = HaCameraStream(connection, request.entityId)
            result.ok = stream.ok
            result.error = stream.error
            if stream.ok then result.streamUrl = stream.url
        end if
        m.top.result = result
        return
    end if
    if request.op <> "refresh" and request.op <> "action"
        result.error = "Unknown Home Assistant operation."
        m.top.result = result
        return
    end if
    errors = []
    if request.op = "action"
        if not HearthActionAllowed(request.action, result.states, preferences, request.config)
            errors.Push("Action refused: unavailable entity or operation not authorized in Settings or the configured allowlist.")
        else
            action = request.action
            body = {entity_id: action.entityId}
            if type(action.data) = "roAssociativeArray"
                if action.data.DoesExist("brightness_pct") then body.brightness_pct = action.data.brightness_pct
            end if
            response = HearthHttp(connection, "/api/services/" + action.domain + "/" + action.service, FormatJson(body))
            if response.ok
                result.message = "Action sent."
            else
                errors.Push("Action: " + response.error + " Check its state before trying again; the action may have reached Home Assistant.")
            end if
            ' No automatic retry: a timeout does not prove a service failed to execute.
            Sleep(1000)
        end if
    end if
    response = HearthHttp(connection, "/api/states")
    if response.ok
        if HearthStatesValid(response.data)
            result.states = response.data
            result.statesFresh = true
        else
            errors.Push("Home Assistant returned invalid states; showing the last received values.")
        end if
    else
        errors.Push("States: " + response.error + " Showing the last received values.")
    end if
    if type(request.areas) <> "roAssociativeArray"
        ' Static template: entity IDs are read server-side, never interpolated from input.
        template = "{% set ns = namespace(items=[]) %}{% for s in states %}{% set room = area_name(s.entity_id) %}{% if room %}{% set ns.items = ns.items + [[s.entity_id, room]] %}{% endif %}{% endfor %}{{ dict(ns.items) | to_json }}"
        response = HearthHttp(connection, "/api/template", FormatJson({template: template}))
        if response.ok and type(response.data) = "roAssociativeArray"
            result.areas = {}
            for each id in response.data
                if HearthEntityIdValid(id)
                    if HearthIsString(response.data[id]) then result.areas[id] = response.data[id]
                end if
            end for
        else
            errors.Push("Rooms unavailable; unassigned entities appear in Other.")
        end if
    end if
    result.error = errors.Join(" | ")
    result.ok = errors.Count() = 0
    m.top.result = result
end sub

function HearthStatesValid(states as dynamic) as boolean
    if type(states) <> "roArray" then return false
    for each state in states
        if type(state) <> "roAssociativeArray" then return false
        if not HearthEntityIdValid(state.entity_id) or not HearthIsString(state.state) then return false
    end for
    return true
end function

function HearthHttp(connection as object, path as string, body = invalid as dynamic) as object
    ' All callers supply static paths or validated identifiers, always on the HA base.
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.SetMessagePort(port)
    transfer.SetUrl(connection.url + path)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.EnablePeerVerification(true)
    transfer.EnableHostVerification(true)
    transfer.AddHeader("Accept", "application/json")
    transfer.AddHeader("Authorization", "Bearer " + connection.token)
    transfer.EnableEncodings(true)
    elapsed = CreateObject("roTimespan")
    elapsed.Mark()
    if body = invalid
        started = transfer.AsyncGetToString()
    else
        transfer.AddHeader("Content-Type", "application/json")
        started = transfer.AsyncPostFromString(body)
    end if
    if not started then return {ok: false, data: invalid, error: "Could not start request."}
    while true
        remaining = 10000 - elapsed.TotalMilliseconds()
        if remaining <= 0
            transfer.AsyncCancel()
            return {ok: false, data: invalid, error: "Timed out after 10 seconds."}
        end if
        event = wait(remaining, port)
        if type(event) = "roUrlEvent"
            if event.GetSourceIdentity() = transfer.GetIdentity()
                status = event.GetResponseCode()
                if status >= 200 and status < 300
                    data = invalid
                    text = event.GetString()
                    if text <> "" then data = ParseJson(text)
                    return {ok: true, data: data, error: ""}
                end if
                ' Never surface server response bodies, request URLs, or transport payloads.
                if status > 0 then return {ok: false, data: invalid, error: "HTTP " + status.ToStr().Trim() + "."}
                return {ok: false, data: invalid, error: "Connection failed; check network and TLS certificate."}
            end if
        end if
    end while
end function
