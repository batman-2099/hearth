sub Main()
    boxed = {temperature: 70}
    AssertTrue(HearthText(boxed.temperature) = "70", "native boxed integer temperatures remain visible")
    states = [
        {entity_id: "sensor.temperature", state: "-2.5", attributes: {friendly_name: "Temperature", unit_of_measurement: "C"}}
        {entity_id: "sensor.battery", state: "80", attributes: {unit_of_measurement: "%"}}
        {entity_id: "sensor.internal", state: "7", attributes: {entity_category: "diagnostic"}}
        {entity_id: "binary_sensor.door", state: "on", attributes: {device_class: "door"}}
        {entity_id: "light.room", state: "on", attributes: {friendly_name: "Room", supported_color_modes: ["brightness"], brightness: 120}}
        {entity_id: "light.relay", state: "off", attributes: {supported_color_modes: ["onoff"]}}
        {entity_id: "switch.fan", state: "off", attributes: {}}
        {entity_id: "input_boolean.guest", state: "off", attributes: {}}
        {entity_id: "scene.evening", state: "2026-01-01T00:00:00Z", attributes: {}}
        {entity_id: "script.bedtime", state: "off", attributes: {}}
        {entity_id: "button.doorbell", state: "2026-01-01T00:00:00Z", attributes: {}}
        {entity_id: "lock.front", state: "locked", attributes: {}}
        {entity_id: "weather.home", state: "partlycloudy", attributes: {temperature: 12, temperature_unit: "C"}}
        {entity_id: "camera.offline_fluent", state: "unavailable", attributes: {}}
        {entity_id: "camera.main", state: "idle", attributes: {}}
        {entity_id: "camera.substream", state: "idle", attributes: {}}
    ]
    config = {refreshSeconds: 45, homeAssistant: {
        entities: ["sensor.temperature", "binary_sensor.door", "light.room", "sensor.temperature", "weather.home"]
        entityNames: {"sensor.temperature": "Outside", "light.room": " "}
        actions: [
            {name: "Room toggle", domain: "light", service: "toggle", entityId: "light.room"}
            {name: "Unlock front", domain: "lock", service: "unlock", entityId: "lock.front"}
            {name: "Invalid path", domain: "light/../lock", service: "unlock", entityId: "light.room"}
        ]
    }}
    defaults = HearthDefaultPreferences(config, states)
    AssertTrue(defaults.sensors.Count() = 3 and HearthContains(defaults.sensors, "light.room"), "Home selections retain toggles, filter unsupported domains and dedupe")
    AssertTrue(defaults.controls.Count() = 2, "initial controls include only explicit configured actions")
    AssertTrue(defaults.controls[1] = "lock.front", "arbitrary explicit action entities remain selected")
    AssertTrue(not HearthContains(defaults.controls, "switch.fan"), "discovery is not write authorization")
    AssertTrue(defaults.cameras[0] = "camera.substream", "available low-bandwidth camera preferred")
    AssertTrue(defaults.cameras[1] = "camera.main", "available main camera beats unavailable fluent")
    AssertTrue(not defaults.DoesExist("weather"), "defaults have no weather preference")
    AssertTrue(defaults.refreshSeconds = 45 and defaults.clock24, "configured interval and 24 hour default")
    suggestions = HearthDefaultPreferences({}, states)
    AssertTrue(suggestions.sensors.Count() = 2, "suggest only useful numeric and door states, not diagnostics")
    AssertTrue(suggestions.controls.Count() = 0, "empty config never authorizes discovered controls")
    AssertTrue(HearthDefaultPreferences(invalid, invalid).sensors.Count() = 0, "no fake states on first launch")

    prefs = HearthNormalizePreferences({sensors: [], controls: [], cameras: [], theme: "auto", clock24: false, wallpaper: "none", refreshSeconds: 5}, defaults)
    AssertTrue(prefs.sensors.Count() = 0 and prefs.controls.Count() = 0 and prefs.cameras.Count() = 0, "intentional empty selections stay empty")
    AssertTrue(not prefs.clock24 and prefs.wallpaper = "none", "explicit none and false survive")
    saved = HearthNormalizePreferences({sensors: ["weather.home", "sensor.temperature", "weather.missing"], controls: ["light.room"], cameras: ["camera.main"], weather: "weather.home", theme: "light", clock24: false, wallpaper: "sand", refreshSeconds: 60}, defaults)
    AssertTrue(not saved.DoesExist("weather"), "old saved weather preference discarded")
    AssertTrue(saved.sensors.Count() = 1 and saved.sensors[0] = "sensor.temperature", "saved weather sensor selections discarded")
    AssertTrue(saved.controls.Count() = 1 and saved.controls[0] = "light.room" and saved.cameras.Count() = 1 and saved.cameras[0] = "camera.main", "remaining saved entity selections preserved")
    AssertTrue(saved.theme = "light" and not saved.clock24 and saved.wallpaper = "sand" and saved.refreshSeconds = 60, "remaining saved preferences preserved")
    roundTrip = HearthNormalizePreferences(ParseJson(FormatJson(saved)), defaults)
    AssertTrue(roundTrip.refreshSeconds = 60, "refresh interval survives registry JSON round trip")
    for each wallpaper in ["slate", "sand", "mist", "none"]
        appearance = HearthNormalizePreferences({wallpaper: wallpaper}, defaults)
        AssertTrue(appearance.wallpaper = wallpaper, "selected wallpaper survives normalization")
    end for
    for each wallpaper in ["forest", "dunes"]
        appearance = HearthNormalizePreferences({wallpaper: wallpaper}, defaults)
        AssertTrue(appearance.wallpaper = HearthDefaultPreferences(invalid, invalid).wallpaper, "removed wallpaper falls back to an available default")
    end for
    missing = HearthNormalizePreferences({}, defaults)
    AssertTrue(missing.sensors.Count() = 3 and missing.controls.Count() = 2, "missing fields inherit defaults")
    missing.controls.Push("switch.fan")
    AssertTrue(defaults.controls.Count() = 2, "normalizing does not alias input selection arrays")
    malformed = HearthNormalizePreferences({sensors: ["sensor.temperature", "sensor.temperature", "light.room", "sensor.bad/path", 7, {}], controls: "light.room", cameras: ["camera.main", "sensor.temperature"], theme: {}, wallpaper: "video", clock24: "false", refreshSeconds: 5.5}, defaults)
    AssertTrue(malformed.sensors.Count() = 2 and HearthContains(malformed.sensors, "light.room") and malformed.cameras.Count() = 1, "invalid IDs, domains and duplicates removed without dropping Home toggles")
    AssertTrue(malformed.controls.Count() = 0, "malformed explicit control list grants nothing")
    AssertTrue(malformed.theme = "dark" and malformed.wallpaper = HearthDefaultPreferences(invalid, invalid).wallpaper and malformed.clock24, "malformed appearance safely normalized")
    AssertTrue(malformed.refreshSeconds = 30, "fractional interval rejected")
    many = {sensors: [], controls: [], cameras: []}
    for i = 0 to 60
        suffix = i.ToStr().Trim()
        many.sensors.Push("sensor.item_" + suffix)
        many.controls.Push("light.item_" + suffix)
        many.cameras.Push("camera.item_" + suffix)
    end for
    limited = HearthNormalizePreferences(many, defaults)
    AssertTrue(limited.sensors.Count() = 30 and limited.controls.Count() = 48 and limited.cameras.Count() = 9, "selection limits enforced")
    AssertTrue(HearthNormalizePreferences({refreshSeconds: 3600}, defaults).refreshSeconds = 3600, "refresh upper boundary accepted")
    AssertTrue(HearthNormalizePreferences({refreshSeconds: 3601}, defaults).refreshSeconds = 30, "refresh out of bounds rejected")

    AssertTrue(HearthStateById(states, "sensor.missing") = invalid, "missing entity never fabricated")
    AssertTrue(HearthStateById([{entity_id: {}}], "sensor.missing") = invalid, "malformed state identity ignored")
    AssertTrue(HearthEntityTitle(states[0], config) = "Outside", "configured title wins")
    AssertTrue(HearthEntityTitle(states[4], config) = "Room", "blank override retains friendly name")
    AssertTrue(HearthEntityTitle(states[5], config) = "light.relay", "missing title falls back to ID")
    AssertTrue(HearthDisplayValue(states[0]) = "-2.5 C", "signed numeric value and unit preserved")
    AssertTrue(HearthDisplayValue(states[3]) = "Open", "door state humanized")
    AssertTrue(HearthDisplayValue({entity_id: "person.pat", state: "not_home"}) = "Away", "person state humanized")
    AssertTrue(HearthDisplayValue(invalid) = "Unavailable", "missing reading unavailable")
    AssertTrue(HearthDisplayValue({state: "unknown"}) = "Unavailable", "unknown reading not fake off state")
    AssertTrue(HearthDisplayValue({state: "unavailable"}) = "Unavailable", "unavailable reading explicit")
    reading = {entity_id: "sensor.temp", state: "-0.06", attributes: {device_class: "temperature", unit_of_measurement: "°C"}}
    AssertTrue(HearthTileValue(reading) = "-0.1 °C", "negative near-zero temperature rounds with its sign")
    reading.state = "-0.04"
    AssertTrue(HearthTileValue(reading) = "0 °C", "rounded zero has no misleading negative sign")
    reading.state = "21.2567"
    AssertTrue(HearthTileValue(reading) = "21.3 °C", "temperature uses one decimal")
    AssertTrue(HearthDisplayValue(reading) = "21.2567 °C" and reading.state = "21.2567", "details and business state retain raw precision")
    reading.attributes = {device_class: "humidity", unit_of_measurement: "%"}
    AssertTrue(HearthTileValue(reading) = "21 %", "humidity uses whole percent")
    reading.attributes = {unit_of_measurement: "%"}
    AssertTrue(HearthTileValue(reading) = "21.2567 %", "other percentage sensors retain precision")
    reading.attributes = {unit_of_measurement: "°F"}
    AssertTrue(HearthTileValue(reading) = "21.3 °F", "temperature unit works without device class")
    titles = [{title: "Temperature"}, {title: "Temperature"}, {title: "Alias"}]
    ids = ["sensor.a", "sensor.b", "sensor.c"]
    HearthDisambiguateTitles(titles, ids, {"sensor.a": "Kitchen", "sensor.b": "Bedroom"})
    AssertTrue(titles[0].title = "Temperature / Kitchen" and titles[1].title = "Temperature / Bedroom" and titles[2].title = "Alias", "duplicate titles gain rooms and unique aliases remain intact")
    titles = [{title: "Temperature"}, {title: "Temperature"}]
    HearthDisambiguateTitles(titles, ids, {"sensor.a": "Kitchen", "sensor.b": "Kitchen"})
    AssertTrue(titles[0].title = "Temperature / Kitchen / sensor.a" and titles[1].title = "Temperature / Kitchen / sensor.b", "same-room duplicates retain meaningful device identities")
    titles = [{title: "Temperature"}, {title: "Temperature"}]
    HearthDisambiguateTitles(titles, ids, invalid)
    AssertTrue(titles[0].title = "Temperature / sensor.a" and titles[1].title = "Temperature / sensor.b", "missing rooms fall back to device identities")
    AssertTrue(HearthGridMove(3, 9, 4, "right") = 3, "compact grid does not wrap right")
    AssertTrue(HearthGridMove(4, 9, 4, "left") = 4, "compact grid does not wrap left")
    AssertTrue(HearthGridMove(7, 9, 4, "down") = 8, "compact grid clamps down to partial last row")
    AssertTrue(HearthGridMove(8, 9, 4, "up") = 4, "compact grid preserves column going up")
    AssertTrue(HearthGridMove(8, 9, 4, "down") = 8, "compact grid stops at last row")
    AssertTrue(HearthGridMove(2, 9, 4, "up") = -1, "compact grid exits to toolbar only from first row")

    prefs = {controls: ["light.room", "light.relay", "switch.fan", "input_boolean.guest", "scene.evening", "script.bedtime", "button.doorbell", "lock.front"]}
    AssertTrue(HearthControlActions("light.room", states, prefs, config).Count() = 1, "configured standard action not duplicated")
    for each id in prefs.controls
        actions = HearthControlActions(id, states, prefs, config)
        AssertTrue(actions.Count() = 1, "supported selected or explicit control has one action: " + id)
        AssertTrue(HearthActionAllowed(actions[0], states, prefs, config), "listed control action authorized: " + id)
    end for
    AssertTrue(HearthControlActions("lock.front", states, prefs, {}).Count() = 0, "unsupported selected domain grants no standard service")
    toggle = {entityId: "light.room", domain: "light", service: "toggle"}
    for each id in ["light.room", "switch.fan", "input_boolean.guest"]
        homePrefs = {controls: [], sensors: [id]}
        action = HearthStandardAction(id)
        AssertTrue(HearthActionAllowed(action, states, homePrefs, {}), "Home toggle selection authorizes toggle: " + id)
        AssertTrue(not HearthActionAllowed(action, states, {controls: [], sensors: []}, {}), "unselected toggle remains unauthorized: " + id)
        explicit = {homeAssistant: {actions: [{name: "On", entityId: id, domain: action.domain, service: "turn_on"}]}}
        choices = HearthControlActions(id, states, homePrefs, explicit)
        AssertTrue(choices.Count() = 1 and choices[0].service = "toggle", "selected toggle replaces configured command menu: " + id)
        AssertTrue(not HearthActionAllowed(action, [{entity_id: id, state: "unavailable"}], homePrefs, explicit), "unavailable Home toggle remains disabled: " + id)
    end for
    AssertTrue(not HearthActionAllowed({entityId: "lock.front", domain: "lock", service: "unlock"}, states, {controls: [], sensors: ["lock.front"]}, {}), "Home selection does not authorize other domains")
    AssertTrue(HearthActionAllowed(toggle, states, {controls: []}, config), "explicit allowlist survives preference deselection")
    AssertTrue(not HearthActionAllowed({entityId: "lock.front", domain: "lock", service: "lock"}, states, prefs, config), "allowlist requires exact service")
    AssertTrue(not HearthActionAllowed({entityId: "light.room", domain: "switch", service: "toggle"}, states, prefs, config), "selected standard domain cannot be substituted")
    AssertTrue(not HearthActionAllowed({entityId: "light.room", domain: "light", service: "turn_off"}, states, prefs, {}), "unselected standard service denied")
    AssertTrue(not HearthActionAllowed(toggle, [{entity_id: "light.room", state: "unknown"}], prefs, config), "unknown state blocks device commands")
    AssertTrue(not HearthActionAllowed(toggle, [{entity_id: "light.room", state: "unavailable"}], prefs, config), "unavailable state blocks allowlisted commands")
    AssertTrue(not HearthActionAllowed(toggle, [], prefs, config), "missing state blocks commands")
    press = {entityId: "button.doorbell", domain: "button", service: "press"}
    firstUse = [{entity_id: "button.doorbell", state: "unknown"}]
    AssertTrue(HearthStateAvailable(firstUse[0]), "first-use button is available")
    AssertTrue(HearthControlActions(press.entityId, firstUse, prefs, {}).Count() = 1, "first-use selected button exposes press")
    AssertTrue(HearthActionAllowed(press, firstUse, prefs, {}), "explicitly selected first-use button can be pressed")
    AssertTrue(HearthActionAllowed(press, firstUse, {controls: []}, {homeAssistant: {actions: [press]}}), "configured first-use button can be pressed")
    AssertTrue(not HearthActionAllowed(press, firstUse, {controls: [], sensors: [press.entityId]}, {}), "first-use state and Home selection do not grant button permission")
    AssertTrue(not HearthActionAllowed({entityId: press.entityId, domain: "button", service: "toggle"}, firstUse, prefs, {}), "first-use button grants only selected press service")
    for each buttonState in ["", "unavailable"]
        blockedButton = [{entity_id: press.entityId, state: buttonState}]
        AssertTrue(not HearthStateAvailable(blockedButton[0]), "empty or unavailable button remains unavailable")
        AssertTrue(not HearthActionAllowed(press, blockedButton, prefs, {}), "empty or unavailable button press denied")
    end for
    AssertTrue(not HearthActionAllowed(press, [], prefs, {}), "missing button press denied")
    AssertTrue(not HearthActionAllowed(press, [{entity_id: press.entityId}], prefs, {}), "missing button state denied")
    activate = {entityId: "scene.evening", domain: "scene", service: "turn_on"}
    firstScene = [{entity_id: activate.entityId, state: "unknown"}]
    sceneConfig = {homeAssistant: {actions: [activate]}}
    AssertTrue(HearthStateAvailable(firstScene[0]), "first-use scene is available")
    AssertTrue(HearthControlActions(activate.entityId, firstScene, prefs, {}).Count() = 1, "first-use selected scene exposes activation")
    AssertTrue(HearthActionAllowed(activate, firstScene, prefs, {}), "selected first-use scene can be activated")
    AssertTrue(HearthActionAllowed(activate, firstScene, {controls: []}, sceneConfig), "configured first-use scene can be activated")
    AssertTrue(HearthControlActions(activate.entityId, firstScene, {controls: []}, {}).Count() = 0, "unselected first-use scene exposes no action")
    AssertTrue(not HearthActionAllowed(activate, firstScene, {controls: [], sensors: [activate.entityId]}, {}), "first-use state and Home selection do not grant scene permission")
    AssertTrue(not HearthActionAllowed({entityId: activate.entityId, domain: "scene", service: "toggle"}, firstScene, prefs, {}), "first-use scene grants only selected activation service")
    for each sceneState in ["", "unavailable"]
        blockedScene = [{entity_id: activate.entityId, state: sceneState}]
        AssertTrue(not HearthStateAvailable(blockedScene[0]), "empty or unavailable scene remains unavailable")
        AssertTrue(not HearthActionAllowed(activate, blockedScene, prefs, sceneConfig), "empty or unavailable scene activation denied even when configured")
    end for
    AssertTrue(not HearthActionAllowed(activate, [], prefs, sceneConfig), "missing scene activation denied")
    AssertTrue(not HearthActionAllowed(activate, [{entity_id: activate.entityId}], prefs, sceneConfig), "missing scene state denied")
    AssertTrue(not HearthActionAllowed({entityId: "light.room", domain: "light", service: "toggle", data: {entity_id: "lock.front"}}, states, prefs, config), "service data cannot retarget allowlisted action")
    AssertTrue(not HearthActionAllowed({entityId: "light.room", domain: "light", service: "toggle", data: {transition: 1}}, states, prefs, config), "extra service payload rejected")
    AssertTrue(not HearthActionAllowed({entityId: "light.room", domain: "light", service: "toggle", data: []}, states, prefs, config), "non-object payload rejected")
    dimAction = {entityId: "light.room", domain: "light", service: "turn_on", data: {brightness_pct: 0}}
    AssertTrue(HearthActionAllowed(dimAction, states, prefs, config), "zero percent brightness valid")
    dimAction.data.brightness_pct = 100
    AssertTrue(HearthActionAllowed(dimAction, states, prefs, config), "full brightness valid")
    dimAction.data.brightness_pct = 100.1
    AssertTrue(not HearthActionAllowed(dimAction, states, prefs, config), "brightness overflow refused")
    dimAction.data.brightness_pct = -1
    AssertTrue(not HearthActionAllowed(dimAction, states, prefs, config), "negative brightness refused")
    dimAction.data.brightness_pct = "50"
    AssertTrue(not HearthActionAllowed(dimAction, states, prefs, config), "string brightness refused")
    dimAction.data.brightness_pct = 50
    AssertTrue(not HearthActionAllowed(dimAction, states, {controls: []}, config), "brightness requires explicit selected light")
    dimAction.entityId = "light.relay"
    AssertTrue(not HearthActionAllowed(dimAction, states, prefs, config), "on/off-only light cannot be dimmed")
    AssertTrue(HearthLightSupportsBrightness({entity_id: "light.color", attributes: {supported_color_modes: ["rgb"]}}), "color capability implies dimming")
    AssertTrue(not HearthLightSupportsBrightness({entity_id: "switch.fake", attributes: {brightness: 100}}), "brightness attribute on non-light grants nothing")

    AssertTrue(HearthConnectionValid({url: "https://ha.example:8123/base/", token: "test-token"}), "HTTPS connection accepted")
    AssertTrue(HearthBaseUrl("https://ha.example/base///") = "https://ha.example/base", "trailing slashes normalized")
    AssertTrue(HearthUrlOrigin("https://HA.example:443/base") = "https://ha.example", "origin canonicalized")
    for each url in ["http://user:pass@ha.example", "https://ha.example/?token=secret", "https://ha.example/#secret", "file:///tmp/config", "http://ha.example:0", "http://ha.example:65536", "http://ha.example\@evil.example", "http://ha.example" + Chr(10) + "evil"]
        AssertTrue(not HearthConnectionValid({url: url, token: "test-token"}), "unsafe connection URL refused")
    end for
    AssertTrue(not HearthConnectionValid({url: "http://ha.example", token: "bad" + Chr(13) + Chr(10) + "Header: value"}), "header injection token refused")
    AssertTrue(not HearthConnectionValid({url: "http://ha.example", token: ""}), "empty token refused")
    AssertTrue(not HearthConnectionValid(invalid), "missing connection refused")
    for each url in ["http://ha.local", "HTTP://HA.local:80/base/", "https://ha.local:443/base", "http://192.0.2.1:8123", "https://[::1]/base", "http://ha.local/a@b"]
        AssertTrue(HearthConnectionValid({url: url, token: "test-token"}), "shared policy accepts supported URL: " + url)
    end for
    for each url in ["http://-host", "http://host-", "http://.host", "http://host.", "http://ha.local/" + String(2048, "a")]
        AssertTrue(not HearthConnectionValid({url: url, token: "test-token"}), "shared policy rejects malformed or oversized URL")
    end for
    for each token in [invalid, 123, "", "has space", "has" + Chr(9) + "tab", "nonascii" + Chr(233), String(8193, "a")]
        AssertTrue(not HearthTokenValid(token), "shared token policy rejects unsafe type, bytes or length")
    end for
    AssertTrue(HearthTokenValid(String(8192, "a")), "token length boundary accepted")
    AssertTrue(HearthUrlOrigin("http://HA.local:00080/base?token=value") = "http://ha.local", "origin helper ignores path and query and canonicalizes port")
    AssertTrue(not HearthConnectionValid({url: "http://ha.local/base?token=value", token: "test-token"}), "origin query support does not permit saved connection queries")

    TestClimateModel()
    TestClimatePresets()
    TestLightModel()
    TestDeviceNames()
    print "HEARTH_MODEL_TESTS_PASSED"
end sub

sub TestDeviceNames()
    state = {entity_id: "light.test", state: "on", attributes: {friendly_name: "Original name"}}
    raw = {controls: ["light.test"], deviceNames: {"light.test": "  Desk  ", "bad/id": "Invalid", "sensor.empty": " ", "sensor.number": 4, "sensor.lines": "Bad" + Chr(10) + "name"}}
    prefs = HearthNormalizePreferences(raw, invalid)
    AssertTrue(prefs.deviceNames.Count() = 1 and prefs.deviceNames["light.test"] = "Desk", "name normalization trims aliases and rejects invalid IDs, types and control characters")
    config = {homeAssistant: {entityNames: {"light.test": "File name"}}, deviceNames: prefs.deviceNames}
    AssertTrue(HearthEntityTitle(state, config) = "Desk", "Roku name takes precedence over file and HA names")
    restored = HearthNormalizePreferences(ParseJson(FormatJson(prefs)), invalid)
    AssertTrue(restored.deviceNames["light.test"] = "Desk", "local names survive preference serialization")
    restored.deviceNames.Delete("light.test")
    AssertTrue(prefs.deviceNames["light.test"] = "Desk", "editing a normalized draft cannot change saved names")
    config.deviceNames = restored.deviceNames
    AssertTrue(HearthEntityTitle(state, config) = "File name", "reset reveals configured name")
    config.homeAssistant.entityNames = {}
    AssertTrue(HearthEntityTitle(state, config) = "Original name", "reset without configured name reveals Home Assistant name")
    AssertTrue(HearthDeviceNameValid(String(64, "a")) and not HearthDeviceNameValid(String(65, "a")), "name length boundary is enforced")
    AssertTrue(HearthDeviceNameValid("Lámpara") and not HearthDeviceNameValid("Bad" + Chr(9) + "name"), "Unicode names work without allowing control characters")
    invalidNames = HearthNormalizePreferences({deviceNames: []}, invalid)
    AssertTrue(invalidNames.deviceNames.Count() = 0, "malformed saved name map is safely ignored")
    AssertTrue(not HearthActionAllowed(HearthStandardAction("light.test"), [state], {controls: [], deviceNames: {"light.test": "Desk"}}, {}), "naming a device never authorizes control")
end sub

sub TestLightModel()
    light = {entity_id: "light.test", state: "on", attributes: {supported_color_modes: ["color_temp", "hs"], brightness: 128, color_temp_kelvin: 4000, min_color_temp_kelvin: 2000, max_color_temp_kelvin: 6500}}
    selected = {controls: [light.entity_id]}
    unselected = {controls: [], sensors: [light.entity_id]}
    fields = HearthLightFields(light)
    AssertTrue(fields.Count() = 3 and fields[0].key = "brightness_pct" and fields[1].key = "color_temp_kelvin" and fields[2].key = "hs_color", "light exposes only reported brightness, Kelvin and native color controls")
    AssertTrue(fields[0].step = 10 and fields[0].presets.Count() = 4 and fields[1].step = 250, "brightness steps and presets coexist with Kelvin steps")
    for each value in [2000, 4000, 6500]
        action = HearthLightAction(light, "color_temp_kelvin", value)
        AssertTrue(action.service = "turn_on" and action.data.color_temp_kelvin = value, "Kelvin action retains native service key and value")
        AssertTrue(HearthActionAllowed(action, [light], selected, {}), "reported Kelvin endpoints authorized")
    end for
    configured = {homeAssistant: {actions: [{entityId: light.entity_id, domain: "light", service: "turn_on"}]}}
    AssertTrue(not HearthActionAllowed(action, [light], unselected, configured), "Home display and configured service do not authorize parameterized light writes")
    for each value in [1999, 6501, 3000.5, "4000", true, invalid]
        AssertTrue(HearthLightAction(light, "color_temp_kelvin", value) = invalid, "invalid Kelvin temperature refused by builder")
        action.data = {color_temp_kelvin: value}
        AssertTrue(not HearthActionAllowed(action, [light], selected, configured), "forged Kelvin temperature cannot bypass boundary checks")
    end for
    for each data in [{color_temp_kelvin: 4000, entity_id: "light.other"}, {color_temp_kelvin: 4000, brightness_pct: 50}, {transition: 2}, {color_name: "red"}, {color_temp: 250}, {hs_color: [0]}, {hs_color: [0, 100, 1]}, {hs_color: [-1, 50]}, {hs_color: [361, 50]}, {hs_color: [30, 101]}, {hs_color: ["30", 50]}, {hs_color: "red"}, {rgb_color: [255, 0, 0]}]
        action.data = data
        AssertTrue(not HearthActionAllowed(action, [light], selected, configured), "forged, mixed, unsupported or malformed light payload refused")
    end for
    action = HearthLightAction(light, "hs_color", [30, 100])
    AssertTrue(HearthActionAllowed(action, [light], selected, {}), "native HS preset authorized")
    action.target = {entity_id: "light.other"}
    AssertTrue(not HearthActionAllowed(action, [light], selected, {}), "top-level light retargeting refused")
    action.Delete("target")
    action.domain = "switch"
    AssertTrue(not HearthActionAllowed(action, [light], selected, {}), "light domain substitution refused")
    action.domain = "light"
    action.service = "toggle"
    AssertTrue(not HearthActionAllowed(action, [light], selected, {}), "color payload cannot accompany toggle")
    action.service = "turn_on"
    light.attributes.supported_color_modes = ["color_temp"]
    AssertTrue(not HearthActionAllowed(action, [light], selected, {}), "removed color capability rejects an already-built action")
    action = HearthLightAction(light, "color_temp_kelvin", 6500)
    light.attributes.max_color_temp_kelvin = 5000
    AssertTrue(not HearthActionAllowed(action, [light], selected, {}), "changed temperature bounds reject stale light choice")
    light.state = "unavailable"
    AssertTrue(HearthLightFields(light).Count() = 0 and not HearthActionAllowed(action, [light], selected, {}), "unavailable lights expose and authorize no controls")
    light.state = "off"
    AssertTrue(HearthLightFields(light)[0].value = 0, "off light steps begin at zero rather than stored brightness")
    light.attributes = {supported_color_modes: ["onoff"], brightness: 120, min_color_temp_kelvin: 2000, max_color_temp_kelvin: 6500}
    AssertTrue(HearthLightFields(light).Count() = 0 and not HearthLightSupportsBrightness(light), "explicit onoff mode overrides stale brightness and temperature attributes")
    light.attributes = {supported_color_modes: ["color_temp"]}
    AssertTrue(HearthLightFields(light).Count() = 1, "temperature controls require reported bounds")
    light.attributes = {supported_color_modes: ["color_temp"], min_mireds: 153, max_mireds: 500, color_temp: 250}
    fields = HearthLightFields(light)
    AssertTrue(fields.Count() = 2 and fields[1].key = "color_temp" and fields[1].step = 25, "legacy mired range remains native and bounded")
    for each value in [153, 250, 500]
        AssertTrue(HearthActionAllowed(HearthLightAction(light, "color_temp", value), [light], selected, {}), "legacy mired endpoints authorized")
    end for
    AssertTrue(HearthLightAction(light, "color_temp", 152) = invalid and HearthLightAction(light, "color_temp", 501) = invalid, "mired bounds enforced")
    light.attributes.min_color_temp_kelvin = "2000"
    AssertTrue(HearthLightFields(light).Count() = 1, "malformed partial modern range cannot silently fall back to legacy limits")
    light.attributes = {supported_features: 2, min_mireds: 153, max_mireds: 500}
    AssertTrue(HearthLightFields(light).Count() = 2, "legacy temperature feature grants reported mired and implied brightness controls")
    for each mode in ["hs", "rgb", "rgbw", "rgbww", "xy"]
        light.attributes = {supported_color_modes: [mode]}
        fields = HearthLightFields(light)
        AssertTrue(fields.Count() = 2 and fields[1].key = mode + "_color", "color presets use explicitly supported native color mode")
        for each preset in fields[1].presets
            AssertTrue(HearthActionAllowed(HearthLightAction(light, fields[1].key, preset), [light], selected, {}), "each advertised color preset passes boundary authorization")
        end for
        AssertTrue(HearthLightAction(light, fields[1].key, [999, 0, 0]) = invalid, "oversized native color channels refused")
    end for
    light.attributes = {supported_color_modes: ["rgb"]}
    AssertTrue(HearthLightAction(light, "rgb_color", [255, 0.5, 0]) = invalid, "RGB channels require integers")
    light.attributes = {supported_color_modes: ["xy"]}
    AssertTrue(HearthLightAction(light, "xy_color", [1.01, 0.2]) = invalid, "XY channel bounds enforced")
    AssertTrue(HearthLightFields(invalid).Count() = 0 and HearthLightAction(light, {}, 50) = invalid, "missing state and malformed key rejected")
    light.entity_id = "switch.test"
    AssertTrue(HearthLightFields(light).Count() = 0, "non-light attributes cannot grant light controls")
end sub

sub TestClimatePresets()
    climate = {entity_id: "climate.test", state: "heat", attributes: {supported_features: 16, preset_mode: "none", preset_modes: ["none", "eco", "comfort"]}}
    selected = {controls: [climate.entity_id]}
    fields = HearthClimateFields(climate)
    AssertTrue(fields.Count() = 1 and fields[0].key = "preset_mode" and fields[0].value = "none", "bit16 and reported options expose climate presets")
    for each mode in climate.attributes.preset_modes
        action = HearthClimateAction(climate, "preset_mode", mode)
        AssertTrue(action.service = "set_preset_mode" and action.data.Count() = 1 and action.data.preset_mode = mode, "climate preset uses dedicated service and exact reported string")
        AssertTrue(HearthActionAllowed(action, [climate], selected, {}), "selected climate preset authorized")
    end for
    configured = {homeAssistant: {actions: [{entityId: climate.entity_id, domain: "climate", service: "set_preset_mode"}]}}
    AssertTrue(not HearthActionAllowed(action, [climate], {controls: [], sensors: [climate.entity_id]}, configured), "climate presets require explicit Controls selection")
    for each value in ["away", 1, true, invalid]
        AssertTrue(HearthClimateAction(climate, "preset_mode", value) = invalid, "unsupported climate presets rejected")
        action.data = {preset_mode: value}
        AssertTrue(not HearthActionAllowed(action, [climate], selected, configured), "forged climate preset rejected at boundary")
    end for
    action = HearthClimateAction(climate, "preset_mode", "eco")
    action.data.entity_id = "climate.other"
    AssertTrue(not HearthActionAllowed(action, [climate], selected, configured), "preset payload cannot retarget another thermostat")
    action.data.Delete("entity_id")
    action.service = "set_fan_mode"
    AssertTrue(not HearthActionAllowed(action, [climate], selected, {}), "preset payload cannot substitute fan service")
    action.service = "set_preset_mode"
    climate.attributes.preset_modes = ["none"]
    AssertTrue(not HearthActionAllowed(action, [climate], selected, {}), "removed preset rejects stale action")
    for each options in [[], ["eco", 1], ["eco", ""], "eco", invalid]
        climate.attributes.preset_modes = options
        AssertTrue(HearthClimateFields(climate).Count() = 0, "malformed preset lists expose no choices")
    end for
    climate.attributes.preset_modes = ["eco"]
    climate.attributes.supported_features = 0
    AssertTrue(HearthClimateFields(climate).Count() = 0 and not HearthActionAllowed(action, [climate], selected, {}), "preset list without bit16 grants no control")
    climate.attributes.supported_features = 16
    climate.state = "unavailable"
    AssertTrue(not HearthActionAllowed(action, [climate], selected, {}), "unavailable thermostat cannot accept preset")
end sub

sub TestClimateModel()
    climate = {entity_id: "climate.room", state: "heat", attributes: {
        supported_features: 9, temperature: 20.5, current_temperature: 19.25
        min_temp: 7, max_temp: 30, target_temp_step: 0.5
        hvac_modes: ["off", "heat", "cool", "heat_cool", "auto", "dry", "fan_only"]
        fan_mode: "auto", fan_modes: ["auto", "low", "high"]
    }}
    states = [climate]
    selected = {controls: [climate.entity_id]}
    unselected = {controls: [], sensors: [climate.entity_id]}
    fields = HearthClimateFields(climate)
    AssertTrue(fields.Count() = 3, "single target, HVAC and supported fan controls exposed")
    AssertTrue(fields[0].kind = "temperature" and fields[0].value = 20.5 and fields[0].step = 0.5, "Celsius target retains raw half steps")
    AssertTrue(fields[0].min = 7 and fields[0].max = 30, "reported limits retained")
    AssertTrue(fields[1].kind = "choice" and fields[1].value = "heat", "HVAC descriptor reports current state")
    AssertTrue(fields[2].key = "fan_mode" and fields[2].value = "auto", "fan descriptor retains current mode")
    action = HearthClimateAction(climate, "temperature", 21)
    AssertTrue(action.domain = "climate" and action.service = "set_temperature" and action.entityId = climate.entity_id, "temperature service target")
    AssertTrue(action.data.Count() = 1 and action.data.temperature = 21, "single target payload only")
    AssertTrue(HearthActionAllowed(action, states, selected, {}), "selected climate target authorized")
    AssertTrue(not HearthActionAllowed(action, states, unselected, {}), "Home climate selection does not authorize changes")
    AssertTrue(not HearthActionAllowed(action, states, HearthDefaultPreferences({}, states), {}), "climate discovery does not authorize changes")
    configured = {homeAssistant: {actions: [{domain: "climate", service: "set_temperature", entityId: climate.entity_id}]}}
    AssertTrue(not HearthActionAllowed(action, states, unselected, configured), "configured service cannot grant parameterized climate writes")
    AssertTrue(HearthActionAllowed(configured.homeAssistant.actions[0], states, unselected, configured), "legacy configured no-data action preserved")
    AssertTrue(HearthControlActions(climate.entity_id, states, selected, {}).Count() = 0, "climate does not gain implicit toggle or cycling action")
    for each value in [7, 30, 21.5]
        AssertTrue(HearthActionAllowed(HearthClimateAction(climate, "temperature", value), states, selected, {}), "temperature within reported limits")
    end for
    for each value in [6.5, 30.5, "21", true, invalid]
        AssertTrue(HearthClimateAction(climate, "temperature", value) = invalid, "invalid temperature rejected before sending")
        action.data = {temperature: value}
        AssertTrue(not HearthActionAllowed(action, states, selected, {}), "forged invalid temperature refused")
    end for
    for each data in [{temperature: 21, hvac_mode: "heat"}, {temperature: 21, entity_id: "climate.other"}, {temperature: 21, target: {entity_id: "climate.other"}}, {temperature: 21, unexpected: 1}, {brightness_pct: 50}, [], "21"]
        action.data = data
        AssertTrue(not HearthActionAllowed(action, states, selected, configured), "unknown or malformed climate payload refused despite allowlist")
    end for
    action.data = {temperature: 21}
    action.domain = "light"
    AssertTrue(not HearthActionAllowed(action, states, selected, {}), "climate cannot substitute another domain")
    action.domain = "climate"
    action.target = {entity_id: "climate.other"}
    AssertTrue(not HearthActionAllowed(action, states, selected, {}), "top-level target override refused")
    action.Delete("target")
    action.entityId = "light.room"
    AssertTrue(not HearthActionAllowed(action, [{entity_id: "light.room", state: "on", attributes: climate.attributes}], {controls: ["light.room"]}, {}), "climate service cannot target non-climate entity")
    AssertTrue(HearthClimateFields({entity_id: "sensor.fake", state: "heat", attributes: climate.attributes}).Count() = 0, "climate attributes do not grant non-climate controls")
    for each mode in climate.attributes.hvac_modes
        action = HearthClimateAction(climate, "hvac_mode", mode)
        AssertTrue(action.service = "set_hvac_mode" and action.data.hvac_mode = mode, "reported HVAC mode maps to explicit service")
        AssertTrue(HearthActionAllowed(action, states, selected, {}), "reported HVAC mode authorized")
    end for
    AssertTrue(HearthClimateAction(climate, "hvac_mode", "emergency_heat") = invalid, "unreported HVAC mode refused")
    AssertTrue(HearthClimateAction(climate, "fan_mode", "turbo") = invalid, "unreported fan mode refused")
    for each value in ["unsupported", 1, invalid]
        AssertTrue(not HearthActionAllowed({domain: "climate", service: "set_hvac_mode", entityId: climate.entity_id, data: {hvac_mode: value}}, states, selected, {}), "forged unsupported HVAC mode refused")
        AssertTrue(not HearthActionAllowed({domain: "climate", service: "set_fan_mode", entityId: climate.entity_id, data: {fan_mode: value}}, states, selected, {}), "forged unsupported fan mode refused")
    end for
    AssertTrue(not HearthActionAllowed({domain: "climate", service: "set_temperature", entityId: climate.entity_id, data: {}}, states, selected, {}), "selected climate does not authorize empty target payload")
    AssertTrue(not HearthActionAllowed({domain: "climate", service: "turn_off", entityId: climate.entity_id}, states, selected, {}), "selected climate does not authorize power toggling")
    action = HearthClimateAction(climate, "fan_mode", "low")
    AssertTrue(action.service = "set_fan_mode" and HearthActionAllowed(action, states, selected, {}), "reported fan mode authorized with bit8")
    AssertTrue(not HearthActionAllowed(action, states, unselected, {}), "fan mode requires Controls selection")
    climate.attributes.fan_modes = ["low", 1]
    AssertTrue(HearthClimateAction(climate, "fan_mode", "low") = invalid, "malformed fan capability array refused")
    climate.attributes.fan_modes = ["auto", "low", "high"]
    climate.attributes.supported_features = 1
    AssertTrue(HearthClimateFields(climate).Count() = 2, "fan list alone does not expose fan control")
    AssertTrue(not HearthActionAllowed(action, states, selected, {}), "fan list without bit8 cannot authorize write")
    AssertTrue(HearthClimateAction(climate, "fan_mode", "low") = invalid, "fan builder requires bit8")
    for each mode in ["auto", "dry", "fan_only"]
        climate.state = mode
        AssertTrue(HearthClimateFields(climate).Count() = 1, "non-manual HVAC mode has no temperature controls")
        AssertTrue(HearthClimateAction(climate, "temperature", 21) = invalid, "non-manual HVAC mode rejects target write")
    end for
    for each mode in ["unavailable", "unknown", ""]
        climate.state = mode
        AssertTrue(HearthClimateFields(climate).Count() = 0, "unavailable climate exposes no controls")
        AssertTrue(not HearthActionAllowed({domain: "climate", service: "set_hvac_mode", entityId: climate.entity_id, data: {hvac_mode: "heat"}}, states, selected, {}), "unavailable climate cannot change mode")
    end for
    climate.state = "heat"
    for each features in ["9", -1, 1.5, true, invalid]
        climate.attributes.supported_features = features
        AssertTrue(HearthClimateFields(climate).Count() = 1, "malformed feature mask grants neither temperature nor fan capability")
    end for
    climate.attributes.supported_features = 1
    for each value in [0, -0.5, "0.5", invalid]
        climate.attributes.target_temp_step = value
        AssertTrue(HearthClimateAction(climate, "temperature", 21) = invalid, "malformed reported step does not fall back")
    end for
    climate.attributes.Delete("target_temp_step")
    AssertTrue(HearthClimateFields(climate)[0].step = 1, "absent step alone falls back to one")
    climate.attributes.temperature = 70
    climate.attributes.min_temp = 45
    climate.attributes.max_temp = 90
    climate.attributes.target_temp_step = 1
    fields = HearthClimateFields(climate)
    AssertTrue(fields[0].value = 70 and fields[0].step = 1, "Fahrenheit targets preserve integer unit values")
    AssertTrue(HearthActionAllowed(HearthClimateAction(climate, "temperature", 71), states, selected, {}), "Fahrenheit integer target authorized without conversion")
    climate.attributes.target_temp_step = 0.5
    climate.attributes.min_temp = 45.2
    AssertTrue(HearthClimateAction(climate, "temperature", 70.5) <> invalid, "reported minimum need not align target step grid")
    climate.attributes.min_temp = "45"
    AssertTrue(HearthClimateAction(climate, "temperature", 70.5) = invalid, "nonnumeric limit rejected")
    climate.attributes.min_temp = 100
    AssertTrue(HearthClimateAction(climate, "temperature", 70.5) = invalid, "reversed reported limits rejected")
    climate.attributes.Delete("min_temp")
    climate.attributes.Delete("max_temp")
    fields = HearthClimateFields(climate)
    AssertTrue(fields.Count() = 1 and fields[0].key = "hvac_mode", "absent limits leave mode choices but no invented temperature limits")
    AssertTrue(HearthClimateAction(climate, "temperature", 71) = invalid, "numeric target stays read-only without reported limits")
    climate.attributes.min_temp = 45
    climate.attributes.max_temp = 90
    climate.attributes.temperature = invalid
    AssertTrue(HearthClimateAction(climate, "temperature", 71) = invalid, "missing target stays read-only despite current temperature")
    climate.attributes.temperature = "70"
    AssertTrue(HearthClimateAction(climate, "temperature", 71) = invalid, "string target is not coerced")
    for each options in [["heat", 1], "heat", [], invalid]
        climate.attributes.hvac_modes = options
        AssertTrue(HearthClimateFields(climate).Count() = 0, "malformed HVAC capabilities do not create mode choices")
    end for

    climate.attributes = {supported_features: 3, temperature: 21, target_temp_low: 18, target_temp_high: 24, min_temp: 10, max_temp: 30, target_temp_step: 0.5}
    climate.state = "heat_cool"
    fields = HearthClimateFields(climate)
    AssertTrue(fields.Count() = 2 and fields[0].key = "target_temp_low" and fields[1].key = "target_temp_high", "heat_cool prefers both range bounds")
    action = HearthClimateAction(climate, "target_temp_low", 18.5)
    AssertTrue(action.data.Count() = 2 and action.data.target_temp_low = 18.5 and action.data.target_temp_high = 24, "low edit includes unchanged high bound")
    AssertTrue(HearthActionAllowed(action, states, selected, {}), "selected paired range write authorized")
    action = HearthClimateAction(climate, "target_temp_high", 25)
    AssertTrue(action.data.target_temp_low = 18 and action.data.target_temp_high = 25, "high edit includes unchanged low bound")
    AssertTrue(HearthClimateAction(climate, "target_temp_low", 24) <> invalid, "equal range endpoints allowed")
    AssertTrue(HearthClimateAction(climate, "target_temp_low", 24.5) = invalid, "low cannot exceed high")
    AssertTrue(HearthClimateAction(climate, "target_temp_high", 17.5) = invalid, "high cannot fall below low")
    for each data in [{target_temp_low: 25, target_temp_high: 24}, {target_temp_low: 9, target_temp_high: 24}, {target_temp_low: 18, target_temp_high: 31}, {target_temp_low: 18}, {target_temp_high: 24}, {target_temp_low: "18", target_temp_high: 24}, {target_temp_low: 18, target_temp_high: 24, temperature: 21}, {temperature: 21}]
        action.data = data
        AssertTrue(not HearthActionAllowed(action, states, selected, {}), "invalid, incomplete, reversed or wrong-shape range refused")
    end for
    climate.state = "heat"
    AssertTrue(HearthClimateFields(climate)[0].key = "temperature", "heat prefers single target when both capabilities exist")
    climate.attributes.supported_features = 2
    AssertTrue(HearthClimateFields(climate).Count() = 2, "range-only capability retains both bounds")
    climate.attributes.target_temp_low = 26
    AssertTrue(HearthClimateFields(climate).Count() = 0, "reversed reported range stays read-only")
    climate.attributes.target_temp_low = invalid
    AssertTrue(HearthClimateFields(climate).Count() = 0, "missing range endpoint stays read-only")
    AssertTrue(HearthClimateAction(invalid, "temperature", 21) = invalid, "missing climate state rejected")
    AssertTrue(HearthClimateAction(climate, {}, 21) = invalid, "malformed field key rejected")
end sub

sub AssertTrue(condition as boolean, message as string)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
