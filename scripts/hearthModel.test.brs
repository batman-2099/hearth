sub Main()
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
    AssertTrue(HearthTileAction("light.room", false, false) = "Device unavailable", "unavailable does not promise a toggle")
    AssertTrue(HearthTileAction("light.room", true, true) = "Sending…", "pending replaces action prompt")
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

    print "HEARTH_MODEL_TESTS_PASSED"
end sub

sub AssertTrue(condition as boolean, message as string)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
