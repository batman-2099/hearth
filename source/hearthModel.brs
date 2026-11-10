' Pure Hearth preferences, display and authorization. No network or SceneGraph access.
function HearthIsString(value as dynamic) as boolean
    return type(value) = "String" or type(value) = "roString"
end function

function HearthIsNumber(value as dynamic) as boolean
    kind = type(value)
    return kind = "Integer" or kind = "LongInteger" or kind = "Float" or kind = "Double" or kind = "roInt" or kind = "roInteger" or kind = "roLongInteger" or kind = "roFloat" or kind = "roDouble"
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

function HearthDeviceNameValid(value as dynamic) as boolean
    if not HearthIsString(value) then return false
    if value.Trim() = "" or Len(value.Trim()) > 64 then return false
    return not CreateObject("roRegex", "[\x00-\x1f\x7f]", "").IsMatch(value)
end function

function HearthEntityTitle(state as dynamic, config as dynamic) as string
    if type(state) <> "roAssociativeArray" then return "Unavailable"
    id = HearthText(state.entity_id)
    if type(config) = "roAssociativeArray"
        if type(config.deviceNames) = "roAssociativeArray"
            title = config.deviceNames[id]
            if HearthDeviceNameValid(title) then return title.Trim()
        end if
    end if
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
    result = {sensors: [], controls: [], cameras: [], deviceNames: {}, theme: "dark", clock24: true, wallpaper: "slate", refreshSeconds: 30}
    result["density"] = "compact"
    result["sensorAlerts"] = HearthNormalizeSensorAlerts(invalid)
    ha = HearthHaConfig(config)
    result.sensors = HearthSelection(ha.entities, "sensors", 30)
    controls = []
    for each action in HearthConfiguredActions(config)
        controls.Push(action.entityId)
    end for
    result.controls = HearthSelection(controls, "controls", 48)
    if type(config) = "roAssociativeArray"
        if HearthRefreshValid(config.refreshSeconds) then result["refreshSeconds"] = Int(config.refreshSeconds)
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
    result["deviceNames"] = {}
    names = defaults.deviceNames
    if raw.DoesExist("deviceNames") then names = raw["deviceNames"]
    if type(names) = "roAssociativeArray"
        for each id in names
            if HearthEntityIdValid(id) and HearthDeviceNameValid(names[id]) then result.deviceNames[id] = names[id].Trim()
        end for
    end if
    for each key in ["theme", "wallpaper", "clock24", "refreshSeconds", "density", "sensorAlerts"]
        value = defaults[key]
        if value = invalid then value = base[key]
        result[key] = value
        if raw.DoesExist(key) then result[key] = raw[key]
    end for
    if not HearthContains(["dark", "light", "auto"], result.theme) then result.theme = base.theme
    if not HearthContains(["slate", "sand", "mist", "none"], result.wallpaper) then result.wallpaper = base.wallpaper
    if type(result.clock24) <> "Boolean" and type(result.clock24) <> "roBoolean" then result.clock24 = base.clock24
    if not HearthRefreshValid(result.refreshSeconds) then result["refreshSeconds"] = base.refreshSeconds
    result["refreshSeconds"] = Int(result.refreshSeconds)
    if not HearthContains(["compact", "comfortable"], result.density) then result.density = "compact"
    result["sensorAlerts"] = HearthNormalizeSensorAlerts(result.sensorAlerts)
    return result
end function

function HearthLightSupportsBrightness(state as dynamic) as boolean
    if type(state) <> "roAssociativeArray" then return false
    if HearthEntityDomain(state.entity_id) <> "light" then return false
    attributes = HearthAttributes(state)
    if type(attributes.supported_color_modes) = "roArray"
        for each mode in attributes.supported_color_modes
            if HearthContains(["brightness", "color_temp", "hs", "xy", "rgb", "rgbw", "rgbww", "white"], mode) then return true
        end for
    end if
    if attributes.DoesExist("supported_color_modes") then return false
    if HearthIsNumber(attributes.brightness)
        if attributes.brightness >= 0 and attributes.brightness <= 255 then return true
    end if
    return HearthClimateFeature(attributes, 1) or HearthClimateFeature(attributes, 2)
end function

function HearthLightFields(state as dynamic) as object
    fields = []
    if not HearthStateAvailable(state) then return fields
    if HearthEntityDomain(state.entity_id) <> "light" then return fields
    attributes = HearthAttributes(state)
    if HearthLightSupportsBrightness(state)
        value = invalid
        if HearthIsNumber(attributes.brightness)
            if attributes.brightness >= 0 and attributes.brightness <= 255 then value = Int(attributes.brightness * 100 / 255 + 0.5)
        end if
        if state.state = "off" then value = 0
        fields.Push({key: "brightness_pct", name: "Brightness", kind: "number", value: value, min: 0, max: 100, step: 10, unit: "%", presets: [25, 50, 75, 100]})
    end if
    modes = attributes.supported_color_modes
    temperature = HearthContains(modes, "color_temp")
    if not attributes.DoesExist("supported_color_modes") then temperature = HearthClimateFeature(attributes, 2)
    if temperature
        key = "color_temp_kelvin"
        low = attributes.min_color_temp_kelvin
        high = attributes.max_color_temp_kelvin
        stepValue = 250
        unit = "K"
        if not attributes.DoesExist("min_color_temp_kelvin") and not attributes.DoesExist("max_color_temp_kelvin")
            key = "color_temp"
            low = attributes.min_mireds
            high = attributes.max_mireds
            stepValue = 25
            unit = "mired"
        end if
        if HearthIsNumber(low) and HearthIsNumber(high)
            if low > 0 and low <= high and high <= 1000000
                if Int(low) = low and Int(high) = high
                    fields.Push({key: key, name: "Color temperature", kind: "number", value: attributes[key], min: low, max: high, step: stepValue, unit: unit, presets: [low, Int((low + high) / 2), high]})
                end if
            end if
        end if
    end if
    for each mode in ["hs", "rgb", "rgbw", "rgbww", "xy"]
        if HearthContains(modes, mode)
            colors = []
            if mode = "hs" then colors = [[0, 100], [120, 100], [240, 100], [30, 100]]
            if mode = "rgb" then colors = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 128, 0]]
            if mode = "rgbw" then colors = [[255, 0, 0, 0], [0, 255, 0, 0], [0, 0, 255, 0], [255, 128, 0, 0]]
            if mode = "rgbww" then colors = [[255, 0, 0, 0, 0], [0, 255, 0, 0, 0], [0, 0, 255, 0, 0], [255, 128, 0, 0, 0]]
            if mode = "xy" then colors = [[0.701, 0.299], [0.172, 0.747], [0.136, 0.04], [0.612, 0.375]]
            fields.Push({key: mode + "_color", name: "Color presets", kind: "color", names: ["Red", "Green", "Blue", "Amber"], presets: colors})
            exit for
        end if
    end for
    return fields
end function

function HearthLightDataAllowed(state as dynamic, data as dynamic) as boolean
    if type(data) <> "roAssociativeArray" then return false
    if data.Count() <> 1 then return false
    for each field in HearthLightFields(state)
        if data.DoesExist(field.key)
            value = data[field.key]
            if field.kind = "number"
                if not HearthIsNumber(value) then return false
                if value < field.min or value > field.max then return false
                if field.key <> "brightness_pct" and Int(value) <> value then return false
                return true
            end if
            if type(value) <> "roArray" then return false
            if value.Count() <> field.presets[0].Count() then return false
            for index = 0 to value.Count() - 1
                if not HearthIsNumber(value[index]) then return false
                maximum = 255
                if field.key = "hs_color"
                    maximum = 100
                    if index = 0 then maximum = 360
                else if field.key = "xy_color"
                    maximum = 1
                end if
                if value[index] < 0 or value[index] > maximum then return false
                if maximum = 255 and Int(value[index]) <> value[index] then return false
            end for
            return true
        end if
    end for
    return false
end function

function HearthLightAction(state as dynamic, key as dynamic, value as dynamic) as dynamic
    if not HearthIsString(key) then return invalid
    data = {}
    data[key] = value
    if not HearthLightDataAllowed(state, data) then return invalid
    return {domain: "light", service: "turn_on", entityId: state.entity_id, data: data}
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

function HearthClimateFeature(attributes as object, flag as integer) as boolean
    features = attributes.supported_features
    if not HearthIsNumber(features) then return false
    if features < 0 or features > 2147483647 then return false
    if Int(features) <> features then return false
    return (Int(features) and flag) <> 0
end function

function HearthClimateOptions(value as dynamic) as object
    result = []
    if type(value) <> "roArray" then return result
    for each option in value
        if not HearthIsString(option) then return []
        if option = "" then return []
        if not HearthContains(result, option) then result.Push(option)
    end for
    return result
end function

function HearthClimateFields(state as dynamic) as object
    result = []
    if not HearthStateAvailable(state) then return result
    if HearthEntityDomain(state.entity_id) <> "climate" then return result
    attributes = HearthAttributes(state)
    singleTarget = HearthClimateFeature(attributes, 1)
    rangeTarget = HearthClimateFeature(attributes, 2)
    stepValue = 1
    if attributes.DoesExist("target_temp_step") then stepValue = attributes.target_temp_step
    temperaturesValid = HearthIsNumber(stepValue) and HearthIsNumber(attributes.min_temp) and HearthIsNumber(attributes.max_temp)
    if temperaturesValid then temperaturesValid = stepValue > 0 and attributes.min_temp <= attributes.max_temp
    if HearthContains(["auto", "dry", "fan_only"], state.state) then temperaturesValid = false
    if temperaturesValid
        keys = []
        names = []
        if rangeTarget and (state.state = "heat_cool" or not singleTarget)
            if HearthIsNumber(attributes.target_temp_low) and HearthIsNumber(attributes.target_temp_high)
                if attributes.target_temp_low <= attributes.target_temp_high
                    keys = ["target_temp_low", "target_temp_high"]
                    names = ["Minimum target", "Maximum target"]
                end if
            end if
        else if singleTarget and HearthIsNumber(attributes.temperature)
            keys = ["temperature"]
            names = ["Target temperature"]
        end if
        for index = 0 to keys.Count() - 1
            key = keys[index]
            result.Push({key: key, name: names[index], value: attributes[key], kind: "temperature", min: attributes.min_temp, max: attributes.max_temp, step: stepValue})
        end for
    end if
    options = HearthClimateOptions(attributes.hvac_modes)
    if options.Count() > 0 then result.Push({key: "hvac_mode", name: "HVAC mode", value: state.state, kind: "choice", options: options})
    if HearthClimateFeature(attributes, 8)
        options = HearthClimateOptions(attributes.fan_modes)
        if options.Count() > 0 then result.Push({key: "fan_mode", name: "Fan mode", value: attributes.fan_mode, kind: "choice", options: options})
    end if
    if HearthClimateFeature(attributes, 16)
        options = HearthClimateOptions(attributes.preset_modes)
        if options.Count() > 0 then result.Push({key: "preset_mode", name: "Preset", value: attributes.preset_mode, kind: "choice", options: options})
    end if
    return result
end function

function HearthClimateDataAllowed(state as dynamic, service as string, data as dynamic) as boolean
    if type(data) <> "roAssociativeArray" then return false
    if service = "set_temperature"
        if data.DoesExist("temperature")
            if data.Count() <> 1 then return false
        else
            if data.Count() <> 2 then return false
            if not HearthIsNumber(data.target_temp_low) or not HearthIsNumber(data.target_temp_high) then return false
            if data.target_temp_low > data.target_temp_high then return false
        end if
    else if service = "set_hvac_mode"
        if data.Count() <> 1 or not data.DoesExist("hvac_mode") then return false
    else if service = "set_fan_mode"
        if data.Count() <> 1 or not data.DoesExist("fan_mode") then return false
    else if service = "set_preset_mode"
        if data.Count() <> 1 or not data.DoesExist("preset_mode") then return false
    else
        return false
    end if
    fields = HearthClimateFields(state)
    for each key in data
        matched = false
        for each field in fields
            if field.key = key
                if field.kind = "temperature"
                    if service <> "set_temperature" or not HearthIsNumber(data[key]) then return false
                    if HearthIsNumber(field.min)
                        if data[key] < field.min then return false
                    end if
                    if HearthIsNumber(field.max)
                        if data[key] > field.max then return false
                    end if
                else
                    if not HearthContains(field.options, data[key]) then return false
                end if
                matched = true
            end if
        end for
        if not matched then return false
    end for
    return true
end function

function HearthClimateAction(state as dynamic, key as dynamic, value as dynamic) as dynamic
    if not HearthIsString(key) then return invalid
    for each field in HearthClimateFields(state)
        if field.key = key
            data = {}
            data[key] = value
            service = "set_temperature"
            if key = "target_temp_low" or key = "target_temp_high"
                attributes = HearthAttributes(state)
                data = {target_temp_low: attributes.target_temp_low, target_temp_high: attributes.target_temp_high}
                data[key] = value
            else if key = "hvac_mode"
                service = "set_hvac_mode"
            else if key = "fan_mode"
                service = "set_fan_mode"
            else if key = "preset_mode"
                service = "set_preset_mode"
            end if
            if not HearthClimateDataAllowed(state, service, data) then return invalid
            return {name: field.name, domain: "climate", service: service, entityId: state.entity_id, data: data}
        end if
    end for
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
    if action.data <> invalid
        if type(action.data) <> "roAssociativeArray" then return false
        if action.data.Count() > 0
            for each key in action
                if not HearthContains(["name", "domain", "service", "entityid", "data"], LCase(key)) then return false
            end for
            if action.domain <> HearthEntityDomain(action.entityId) then return false
            if not HearthSelectedControl(action.entityId, preferences) then return false
            if action.domain = "climate" then return HearthClimateDataAllowed(state, action.service, action.data)
            if action.domain = "light" and action.service = "turn_on" then return HearthLightDataAllowed(state, action.data)
            return false
        end if
    end if
    for each allowed in HearthControlActions(action.entityId, states, preferences, config)
        if action.domain = allowed.domain and action.service = allowed.service then return true
    end for
    return false
end function

function HearthAlertNumber(value as dynamic) as dynamic
    if HearthIsString(value)
        if not HearthMatches(value, "^[+-]?[0-9]+(\.[0-9]+)?$") then return invalid
        value = Val(value)
    end if
    if not HearthIsNumber(value) then return invalid
    if value < -100000 or value > 100000 then return invalid
    return value
end function

function HearthNormalizeSensorAlerts(raw as dynamic) as object
    result = {"enabled": false, "batteryPercent": 20, "openDoors": true, "temperatureUnit": "°C", "temperatureMin": invalid, "temperatureMax": invalid}
    if type(raw) <> "roAssociativeArray" then return result
    for each key in ["enabled", "openDoors"]
        if type(raw[key]) = "Boolean" or type(raw[key]) = "roBoolean" then result[key] = raw[key]
    end for
    battery = HearthAlertNumber(raw.batteryPercent)
    if battery <> invalid
        if battery >= 0 and battery <= 100 then result["batteryPercent"] = battery
    end if
    if HearthContains(["°C", "°F"], raw.temperatureUnit) then result["temperatureUnit"] = raw.temperatureUnit
    low = HearthAlertNumber(raw.temperatureMin)
    high = HearthAlertNumber(raw.temperatureMax)
    if low <> invalid and high <> invalid
        if low > high
            low = invalid
            high = invalid
        end if
    end if
    result["temperatureMin"] = low
    result["temperatureMax"] = high
    return result
end function

function HearthSensorAlert(state as dynamic, raw as dynamic) as string
    if not HearthStateAvailable(state) then return ""
    domain = HearthEntityDomain(state.entity_id)
    if domain <> "sensor" and domain <> "binary_sensor" then return ""
    config = HearthNormalizeSensorAlerts(raw)
    if not config.enabled then return ""
    attrs = HearthAttributes(state)
    category = HearthText(attrs.device_class)
    if domain = "binary_sensor"
        if config.openDoors and HearthContains(["door", "window", "opening", "garage_door"], category) and state.state = "on" then return "Alert: Open"
        if category = "battery" and state.state = "on" then return "Alert: Low battery"
        return ""
    end if
    value = HearthAlertNumber(state.state)
    if value = invalid then return ""
    unit = HearthText(attrs.unit_of_measurement)
    if category = "battery" and unit = "%"
        if value >= 0 and value <= config.batteryPercent then return "Alert: Low battery"
    end if
    if category <> "temperature" or not HearthContains(["°C", "°F"], unit) then return ""
    if unit <> config.temperatureUnit
        if unit = "°C" then value = value * 9 / 5 + 32 else value = (value - 32) * 5 / 9
    end if
    if config.temperatureMin <> invalid
        if value < config.temperatureMin then return "Alert: Cold"
    end if
    if config.temperatureMax <> invalid
        if value > config.temperatureMax then return "Alert: Hot"
    end if
    return ""
end function
