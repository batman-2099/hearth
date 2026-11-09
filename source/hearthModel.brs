' Pure Hearth preferences, display and authorization. No network or SceneGraph access.
function HearthIsString(value as dynamic) as boolean
    return type(value) = "String" or type(value) = "roString"
end function

function HearthIsNumber(value as dynamic) as boolean
    kind = type(value)
    return kind = "Integer" or kind = "LongInteger" or kind = "Float" or kind = "Double" or kind = "roInt" or kind = "roLongInteger" or kind = "roFloat" or kind = "roDouble"
end function

function HearthText(value as dynamic) as string
    if HearthIsString(value) then return value
    if HearthIsNumber(value) then return value.ToStr().Trim()
    if type(value) = "Boolean" or type(value) = "roBoolean"
        if value then return "Yes"
        return "No"
    end if
    return ""
end function

function HearthMatches(value as dynamic, pattern as string) as boolean
    if not HearthIsString(value) then return false
    return CreateObject("roRegex", pattern, "").IsMatch(value)
end function

function HearthEntityIdValid(value as dynamic) as boolean
    return HearthMatches(value, "^[a-z0-9_]+\.[a-z0-9_]+$")
end function

function HearthEntityDomain(value as dynamic) as string
    if not HearthEntityIdValid(value) then return ""
    return value.Split(".")[0]
end function

function HearthContains(values as dynamic, value as dynamic) as boolean
    if type(values) <> "roArray" or not HearthIsString(value) then return false
    for each item in values
        if HearthIsString(item)
            if item = value then return true
        end if
    end for
    return false
end function

function HearthParseUrl(value as dynamic) as dynamic
    if not HearthIsString(value) then return invalid
    if Len(value) > 2048 then return invalid
    if CreateObject("roRegex", "[\s\x00-\x20\x7f\\]", "").IsMatch(value) then return invalid
    parts = CreateObject("roRegex", "^(https?)://(\[[0-9a-f:]+\]|[a-z0-9]([a-z0-9.-]*[a-z0-9])?)(:[0-9]{1,5})?([/?][^#]*)?$", "i").Match(value)
    if parts.Count() = 0 then return invalid
    scheme = LCase(parts[1])
    host = LCase(parts[2])
    port = 80
    if scheme = "https" then port = 443
    portText = HearthText(parts[4])
    if portText <> "" then port = Val(Mid(portText, 2))
    if port < 1 or port > 65535 then return invalid
    authority = host
    if (scheme = "http" and port <> 80) or (scheme = "https" and port <> 443) then authority = authority + ":" + port.ToStr().Trim()
    path = HearthText(parts[5])
    while Right(path, 1) = "/"
        path = Left(path, Len(path) - 1)
    end while
    origin = scheme + "://" + authority
    return {scheme: scheme, host: host, port: port, authority: authority, url: origin, path: path, base: origin + path}
end function

function HearthUrlOrigin(value as dynamic) as string
    parsed = HearthParseUrl(value)
    if parsed = invalid then return ""
    return parsed.url
end function

function HearthBaseUrl(value as dynamic) as string
    if HearthUrlOrigin(value) = "" then return ""
    if Instr(1, value, "?") > 0 then return ""
    result = value
    while Right(result, 1) = "/"
        result = Left(result, Len(result) - 1)
    end while
    return result
end function

function HearthConnectionValid(connection as dynamic) as boolean
    if type(connection) <> "roAssociativeArray" then return false
    if HearthBaseUrl(connection.url) = "" then return false
    return HearthTokenValid(connection.token)
end function

function HearthTokenValid(token as dynamic) as boolean
    if not HearthIsString(token) then return false
    return Len(token) > 0 and Len(token) <= 8192 and CreateObject("roRegex", "^[!-~]+$", "").IsMatch(token)
end function

function HearthHaConfig(config as dynamic) as object
    if type(config) = "roAssociativeArray"
        if type(config.homeAssistant) = "roAssociativeArray" then return config.homeAssistant
    end if
    return {}
end function

function HearthStateById(states as dynamic, id as dynamic) as dynamic
    if not HearthEntityIdValid(id) or type(states) <> "roArray" then return invalid
    for each state in states
        if type(state) = "roAssociativeArray"
            if HearthIsString(state.entity_id)
                if state.entity_id = id then return state
            end if
        end if
    end for
    return invalid
end function

function HearthStateAvailable(state as dynamic) as boolean
    if type(state) <> "roAssociativeArray" then return false
    if not HearthIsString(state.state) then return false
    ' Buttons and scenes report unknown until first use; authorization is checked separately.
    if state.state = "unknown"
        domain = HearthEntityDomain(state.entity_id)
        if domain = "button" or domain = "scene" then return true
    end if
    return state.state <> "" and state.state <> "unknown" and state.state <> "unavailable"
end function

function HearthAttributes(state as dynamic) as object
    if type(state) = "roAssociativeArray"
        if type(state.attributes) = "roAssociativeArray" then return state.attributes
    end if
    return {}
end function

function HearthEntityTitle(state as dynamic, config as dynamic) as string
    if type(state) <> "roAssociativeArray" then return "Unavailable"
    id = HearthText(state.entity_id)
    ha = HearthHaConfig(config)
    if type(ha.entityNames) = "roAssociativeArray"
        title = ha.entityNames[id]
        if HearthIsString(title)
            if title.Trim() <> "" then return title.Trim()
        end if
    end if
    title = HearthAttributes(state).friendly_name
    if HearthIsString(title)
        if title.Trim() <> "" then return title.Trim()
    end if
    return id
end function

function HearthReadable(value as string) as string
    if value = "partlycloudy" then return "Partly cloudy"
    value = value.Replace("_", " ").Replace("-", " ")
    if value = "" then return ""
    return UCase(Left(value, 1)) + Mid(value, 2)
end function

function HearthDisplayValue(state as dynamic) as string
    if not HearthStateAvailable(state) then return "Unavailable"
    attributes = HearthAttributes(state)
    value = state.state
    domain = HearthEntityDomain(state.entity_id)
    if domain = "binary_sensor"
        active = value = "on"
        category = HearthText(attributes.device_class)
        if HearthContains(["door", "window", "opening", "garage_door"], category)
            if active then return "Open"
            if value = "off" then return "Closed"
        else if category = "motion" or category = "occupancy" or category = "presence"
            if active then return "Detected"
            if value = "off" then return "Clear"
        else if category = "moisture"
            if active then return "Wet"
            if value = "off" then return "Dry"
        else if category = "connectivity"
            if active then return "Connected"
            if value = "off" then return "Disconnected"
        end if
    end if
    if domain = "person" and value = "not_home" then return "Away"
    ' Keep signed numeric readings intact; humanize only non-numeric states.
    if not HearthMatches(value, "^[+-]?[0-9]+(\.[0-9]+)?$") then value = HearthReadable(value)
    unit = HearthText(attributes.unit_of_measurement)
    if unit <> "" then value = value + " " + unit
    if domain = "climate"
        temperature = HearthText(attributes.current_temperature)
        if temperature <> "" then value = value + " | " + temperature + " " + HearthText(attributes.temperature_unit)
    end if
    return value.Trim()
end function

' Tile-only precision: dialogs and service data retain the original reading.
function HearthTileValue(state as dynamic) as string
    if not HearthStateAvailable(state) then return HearthDisplayValue(state)
    attributes = HearthAttributes(state)
    unit = HearthText(attributes.unit_of_measurement)
    category = HearthText(attributes.device_class)
    temperature = category = "temperature" or HearthContains(["°C", "°F", "C", "F", "K"], unit)
    humidity = category = "humidity"
    if not temperature and not humidity then return HearthDisplayValue(state)
    if not HearthMatches(state.state, "^[+-]?[0-9]+(\.[0-9]+)?$") then return HearthDisplayValue(state)
    scale = 10
    if humidity then scale = 1
    number = Val(state.state)
    rounded = Int(Abs(number) * scale + 0.5) / scale
    value = rounded.ToStr().Trim()
    if number < 0 and rounded > 0 then value = "-" + value
    if unit <> "" then value = value + " " + unit
    return value
end function

function HearthTileAction(id as string, available as boolean, pending as boolean) as string
    if pending then return "Sending…"
    if not available then return "Device unavailable"
    if HearthIsToggle(id) then return "[OK] Toggle"
    return "[OK] Details"
end function

sub HearthDisambiguateTitles(items as object, ids as object, areas as dynamic)
    counts = {}
    for each item in items
        key = LCase(item.title)
        if not counts.DoesExist(key) then counts[key] = 0
        counts[key] = counts[key] + 1
    end for
    candidates = []
    for index = 0 to items.Count() - 1
        title = items[index].title
        if counts[LCase(title)] > 1
            room = ""
            if type(areas) = "roAssociativeArray" then room = HearthText(areas[ids[index]]).Trim()
            if room = "" then room = ids[index]
            title = title + " / " + room
        end if
        candidates.Push(title)
    end for
    ' ponytail: pairwise comparison is bounded by 30 Home tiles; index if that limit grows.
    for index = 0 to items.Count() - 1
        title = candidates[index]
        duplicate = false
        for other = 0 to candidates.Count() - 1
            if other <> index and LCase(candidates[other]) = LCase(title) then duplicate = true
        end for
        if duplicate then title = title + " / " + ids[index]
        items[index].title = title
    end for
end sub

function HearthGridMove(index as integer, count as integer, columns as integer, key as string) as integer
    if key = "up"
        if index < columns then return -1
        return index - columns
    else if key = "down"
        if index + columns < count then return index + columns
        if Int(index / columns) < Int((count - 1) / columns) then return count - 1
    else if key = "left"
        if index mod columns > 0 then return index - 1
    else if key = "right"
        if index mod columns < columns - 1 and index + 1 < count then return index + 1
    end if
    return index
end function

function HearthSelection(values as dynamic, kind as string, maximum as integer) as object
    result = []
    seen = {}
    if type(values) <> "roArray" then return result
    for each id in values
        if HearthEntityIdValid(id)
            domain = HearthEntityDomain(id)
            allowed = kind = "controls"
            if kind = "sensors" then allowed = HearthContains(["sensor", "binary_sensor", "climate", "person", "light", "switch", "input_boolean"], domain)
            if kind = "cameras" then allowed = domain = "camera"
            if allowed and not seen.DoesExist(id)
                result.Push(id)
                seen[id] = true
                if result.Count() >= maximum then exit for
            end if
        end if
    end for
    return result
end function

function HearthConfiguredActions(config as dynamic) as object
    result = []
    ha = HearthHaConfig(config)
    if type(ha.actions) <> "roArray" then return result
    for each action in ha.actions
        if type(action) = "roAssociativeArray"
            if HearthEntityIdValid(action.entityId) and HearthMatches(action.domain, "^[a-z0-9_]+$") and HearthMatches(action.service, "^[a-z0-9_]+$")
                name = HearthText(action.name).Trim()
                if name = "" then name = HearthReadable(action.service)
                result.Push({name: name, domain: action.domain, service: action.service, entityId: action.entityId})
            end if
        end if
    end for
    return result
end function

function HearthRefreshValid(value as dynamic) as boolean
    if not HearthIsNumber(value) then return false
    return value >= 5 and value <= 3600 and Int(value) = value
end function

function HearthDefaultPreferences(config as dynamic, states as dynamic) as object
    result = {sensors: [], controls: [], cameras: [], theme: "dark", clock24: true, wallpaper: "slate", refreshSeconds: 30}
    ha = HearthHaConfig(config)
    result.sensors = HearthSelection(ha.entities, "sensors", 30)
    controls = []
    for each action in HearthConfiguredActions(config)
        controls.Push(action.entityId)
    end for
    result.controls = HearthSelection(controls, "controls", 48)
    if type(config) = "roAssociativeArray"
        if HearthRefreshValid(config.refreshSeconds) then result.refreshSeconds = Int(config.refreshSeconds)
    end if
    suggestions = []
    cameraBuckets = [[], [], [], []]
    if type(states) = "roArray"
        for each state in states
            if type(state) = "roAssociativeArray"
                domain = HearthEntityDomain(state.entity_id)
                attributes = HearthAttributes(state)
                available = HearthStateAvailable(state)
                if domain = "camera"
                    bucket = 2
                    if available then bucket = 0
                    preferred = Instr(1, state.entity_id, "fluent") > 0 or Instr(1, state.entity_id, "substream") > 0 or Instr(1, state.entity_id, "sub_stream") > 0
                    if not preferred then bucket = bucket + 1
                    cameraBuckets[bucket].Push(state.entity_id)
                end if
                if available and suggestions.Count() < 30
                    diagnostic = HearthText(attributes.entity_category) = "diagnostic"
                    if HearthMatches(state.entity_id, "(rssi|signal_strength|uptime|last_seen|last_boot|firmware|linkquality|battery|voltage|diagnostic)") then diagnostic = true
                    suggest = false
                    if domain = "sensor" then suggest = HearthMatches(state.state, "^[+-]?[0-9]+(\.[0-9]+)?$")
                    if domain = "binary_sensor" then suggest = HearthContains(["door", "window", "opening", "garage_door", "motion", "occupancy", "moisture"], attributes.device_class)
                    if suggest and not diagnostic then suggestions.Push(state.entity_id)
                end if
            end if
        end for
    end if
    ' ponytail: simple priority buckets, no speculative camera-name pairing heuristics.
    cameraIds = []
    for each bucket in cameraBuckets
        cameraIds.Append(bucket)
    end for
    result.cameras = HearthSelection(cameraIds, "cameras", 9)
    if result.sensors.Count() = 0 then result.sensors = HearthSelection(suggestions, "sensors", 30)
    return result
end function

function HearthNormalizePreferences(raw as dynamic, defaults as dynamic) as object
    base = HearthDefaultPreferences(invalid, invalid)
    if type(defaults) <> "roAssociativeArray" then defaults = base
    if type(raw) <> "roAssociativeArray" then raw = {}
    result = {}
    for each key in ["sensors", "controls", "cameras"]
        values = defaults[key]
        if raw.DoesExist(key) then values = raw[key]
        maximum = 30
        if key = "controls" then maximum = 48
        if key = "cameras" then maximum = 9
        result[key] = HearthSelection(values, key, maximum)
    end for
    for each key in ["theme", "wallpaper", "clock24", "refreshSeconds"]
        value = defaults[key]
        if value = invalid then value = base[key]
        result[key] = value
        if raw.DoesExist(key) then result[key] = raw[key]
    end for
    if not HearthContains(["dark", "light", "auto"], result.theme) then result.theme = base.theme
    if not HearthContains(["slate", "sand", "mist", "none"], result.wallpaper) then result.wallpaper = base.wallpaper
    if type(result.clock24) <> "Boolean" and type(result.clock24) <> "roBoolean" then result.clock24 = base.clock24
    if not HearthRefreshValid(result.refreshSeconds) then result.refreshSeconds = base.refreshSeconds
    result.refreshSeconds = Int(result.refreshSeconds)
    return result
end function

function HearthLightSupportsBrightness(state as dynamic) as boolean
    if type(state) <> "roAssociativeArray" then return false
    if HearthEntityDomain(state.entity_id) <> "light" then return false
    attributes = HearthAttributes(state)
    if HearthIsNumber(attributes.brightness) then return true
    if type(attributes.supported_color_modes) = "roArray"
        for each mode in attributes.supported_color_modes
            if HearthContains(["brightness", "color_temp", "hs", "xy", "rgb", "rgbw", "rgbww", "white"], mode) then return true
        end for
    end if
    return false
end function

function HearthSelectedControl(id as dynamic, preferences as dynamic) as boolean
    if type(preferences) <> "roAssociativeArray" then return false
    return HearthContains(preferences.controls, id)
end function

function HearthIsToggle(id as dynamic) as boolean
    domain = HearthEntityDomain(id)
    return domain = "light" or domain = "switch" or domain = "input_boolean"
end function

function HearthStandardAction(id as dynamic) as dynamic
    domain = HearthEntityDomain(id)
    if HearthIsToggle(id) then return {name: "Toggle", domain: domain, service: "toggle", entityId: id}
    if domain = "scene" then return {name: "Activate", domain: domain, service: "turn_on", entityId: id}
    if domain = "script" then return {name: "Run", domain: domain, service: "turn_on", entityId: id}
    if domain = "button" then return {name: "Press", domain: domain, service: "press", entityId: id}
    return invalid
end function

function HearthControlActions(id as dynamic, states as dynamic, preferences as dynamic, config as dynamic) as object
    result = []
    if not HearthStateAvailable(HearthStateById(states, id)) then return result
    if HearthIsToggle(id) and type(preferences) = "roAssociativeArray"
        if HearthSelectedControl(id, preferences) or HearthContains(preferences.sensors, id) then return [HearthStandardAction(id)]
    end if
    for each action in HearthConfiguredActions(config)
        if action.entityId = id then result.Push(action)
    end for
    if HearthSelectedControl(id, preferences)
        standard = HearthStandardAction(id)
        if standard <> invalid
            duplicate = false
            for each action in result
                if action.domain = standard.domain and action.service = standard.service then duplicate = true
            end for
            if not duplicate then result.Push(standard)
        end if
    end if
    return result
end function

function HearthActionAllowed(action as dynamic, states as dynamic, preferences as dynamic, config as dynamic) as boolean
    if type(action) <> "roAssociativeArray" then return false
    if not HearthEntityIdValid(action.entityId) then return false
    if not HearthMatches(action.domain, "^[a-z0-9_]+$") or not HearthMatches(action.service, "^[a-z0-9_]+$") then return false
    state = HearthStateById(states, action.entityId)
    if not HearthStateAvailable(state) then return false
    hasBrightness = false
    if action.data <> invalid
        if type(action.data) <> "roAssociativeArray" then return false
        for each key in action.data
            if key <> "brightness_pct" then return false
            hasBrightness = true
        end for
    end if
    if hasBrightness
        if action.domain <> "light" or action.service <> "turn_on" or HearthEntityDomain(action.entityId) <> "light" then return false
        if not HearthSelectedControl(action.entityId, preferences) or not HearthLightSupportsBrightness(state) then return false
        value = action.data.brightness_pct
        if not HearthIsNumber(value) then return false
        return value >= 0 and value <= 100
    end if
    for each allowed in HearthControlActions(action.entityId, states, preferences, config)
        if action.domain = allowed.domain and action.service = allowed.service then return true
    end for
    return false
end function
