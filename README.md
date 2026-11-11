# Hearth for Roku

<img src="images/channel-icon-hd.png" alt="Hearth logo: a blue flame inside a fireplace" width="145" height="109">

Home Assistant on your TV, controlled with your Roku remote.

**[Get started](#getting-started)** | [Remote controls](#using-the-remote) | [Troubleshooting](#cameras-and-troubleshooting) | [Contributing](#support-and-contributing)

Native BrightScript/SceneGraph. Direct Home Assistant connection. No browser wrapper or companion server.

## Features

- **Combined Home dashboard:** view sensors, statuses, and device controls together by room. Home tiles and Controls selections are merged, with each device shown once.
- **Device controls:** select up to 48 controllable devices alongside up to 30 Home tiles; toggle lights, switches, and input booleans, adjust supported light brightness, and activate scenes, scripts, and buttons.
- **Climate controls:** adjust supported thermostat targets, heat/cool ranges, HVAC modes, and fan modes.
- **Scene shortcuts:** run selected Home Assistant scenes and scripts with one press from a dedicated Scenes tab.
- **Cameras:** select up to nine cameras, browse refreshed snapshots, and open supported HLS streams.
- **Personalization:** dark, light, or automatic theme; three minimalist backgrounds; 12/24-hour clock; configurable refresh interval.
- **Local device names:** rename selected devices, scenes, and cameras on your Roku without changing Home Assistant.
- **Remote-first navigation:** visible focus, on-screen button hints, room filters, and saved device selections.

Hearth is a native dashboard, not a Lovelace renderer. It does not transcode video or browse Frigate recordings.

## Requirements

- A physical Roku with developer mode enabled.
- A Home Assistant instance reachable from the Roku and a long-lived access token.
- Node.js **22 or later**, npm, and Git on your computer.
- For live cameras: Home Assistant stream support and a video codec supported by your Roku model.

> [!IMPORTANT]
> Native live-stream discovery supports HTTP over IPv4/DNS. HTTPS and IPv6 connections use snapshots instead; Hearth never downgrades HTTPS. Use HTTP only on a trusted LAN.

## Getting started

### 1. Build the channel

```sh
git clone https://github.com/batman-2099/hearth.git
cd hearth
npm ci
npm test
npm run check
npm run build
```

The installable channel is `out/ha-roku.zip`. No configuration file is required when you enter the connection details on the Roku.

### 2. Install on Roku

1. Enable [Roku developer mode](https://developer.roku.com/dev/docs/developer-setup). The remote sequence is **Home ×3, Up ×2, Right, Left, Right, Left, Right**.
2. Set a developer password and reboot when prompted.
3. Open `http://<roku-ip>` in your computer's browser. Sign in as `rokudev` using that password.
4. Upload `out/ha-roku.zip` and select **Install**.

> [!NOTE]
> Roku supports one sideloaded development channel at a time. Installing Hearth replaces the existing development channel.

### 3. Connect Home Assistant

1. Create a long-lived access token in your Home Assistant user profile.
2. Open Hearth's **Settings**, enter the Home Assistant address and token, and choose **Save connection**.
3. Choose **Home tiles** for status information, **Controls** for device commands, **Scenes** for shortcuts, and **Cameras** for feeds. Home tiles and Controls appear together on **Home**.
4. In a device picker, press **Right**, then **OK**, to save. **Back** discards unsaved changes.

Saved settings, including the refresh interval, layout density, and alert limits, persist on the Roku. Room names come from Home Assistant areas; unassigned devices appear under **Other**. Room and selected-only filters do not discard hidden selections.

On Home, sensors and binary sensors stack in the right-hand column; other devices stay in the left grid. Each side scrolls independently. Left/Right crosses between them, and Up/Down scrolls the focused side. Sensors are display-only: OK does nothing, and focus is retained for scrolling and Audio Guide readings. Rooms without sensors use the full-width grid.

Home and Scenes use compact tiles with enlarged labels and action text. Sensor readouts stack against the right edge as solid, square-edged panels: light gray in dark mode and blue in light mode, with dark readings. Focus adds a contrasting outline and lighter fill without making sensors clickable. Interactive controls retain their rounded boxes and focus outline. Home scene, script, and button shortcuts show their action instead of a raw timestamp.

Compact tiles include 10-pixel side padding and 6-pixel top/bottom padding at the 720p design resolution. Their 80-pixel height accommodates two-line names without crowding the reading or action.

Settings shows contextual help for Home tiles, Controls, and Scenes. Duplicate device labels include their entity IDs, and focusing a device shows its full ID in the detail area.

### Layout density

In **Settings**, choose **Compact** for smaller tiles or **Comfortable** for larger labels and controls. The choice applies to Home and Scenes and is saved on the Roku. Sensor readings remain stacked on the right; both layouts retain remote navigation and scrolling.

### Sensor alerts

Sensor alerts are off by default. Enable them in **Settings** to highlight selected sensor readings without sending commands or running automations:

- Battery readings at or below your percentage threshold.
- Open doors and windows when opening alerts are enabled.
- Temperatures below your minimum or above your maximum. Choose Celsius or Fahrenheit for the limits; reported readings are converted for comparison, not relabeled.

Alerts include a text warning, not just a color. Missing, unavailable, or stale readings do not produce alerts. Limits apply across selected sensors; these visual alerts are not a replacement for Home Assistant safety automations or notifications.

## Using the remote

| Context | Controls |
| --- | --- |
| Page tabs | Left/Right selects a page; OK or Down enters it. |
| Home | Arrows navigate devices; Rewind/Fast-forward changes rooms. |
| Device tile | OK toggles a supported device, opens its actions, or shows read-only details. |
| Supported light selected in Settings > Controls | Play opens light settings on Home: brightness, white temperature, and color presets supported by that device. |
| Thermostat selected in Settings > Controls | OK opens climate settings on Home; select a setting, then a temperature adjustment or mode. |
| Scenes | Arrows choose a shortcut; OK runs it immediately; Back returns to the tabs. |
| Cameras | Arrows choose a camera; OK opens it; Back closes playback or snapshots. |
| Navigation | Back returns to the tabs; from the tabs, Back returns Home, then exits. |
| Settings | Star opens Settings. |
| Refresh | Replay refreshes states and room assignments. |
| Error banner | Play opens error details, taking priority over light settings. |

The bottom-right Home Assistant indicator shows a green check for a successful fresh state fetch and a red X for an unconfirmed or stale connection. Save failures are reported separately.

Device actions are sent once, followed by a one-second wait and state refresh. Tiles display **Sending…** until completion, then show Home Assistant's reported state. Failed actions are not automatically retried; check the device's state before retrying.

### Scene shortcuts

Choose scenes and scripts in **Settings > Scenes**, then press **Right**, **OK** to save; **Back** cancels unsaved changes. The **Scenes** tab appears when at least one scene or script is selected and hides when the last is removed. Existing selections carry over. Shortcuts also appear on Home and share the 48-device Controls selection limit; saving Scenes preserves other selected controls.

Press **OK** to activate a scene or run a script immediately—there is no confirmation dialog on this page. **Sending…** blocks repeat activation until the request and one-second refresh finish. Unavailable entities cannot run. A successful request means the command was sent, not that every action inside the scene or script has completed.

Duplicate shortcut names include their Home Assistant room, with the entity ID as a fallback when needed. The same disambiguated names are used for Audio Guide descriptions.

### Light controls

Select lights in **Settings > Controls** to enable their advanced settings. **OK** still toggles the light; **Play** opens its supported light controls. Unsupported settings are omitted. Commands apply immediately and refresh the reported state after one second; Back or Cancel sends nothing.

- Brightness offers 10-percentage-point adjustments and 25/50/75/100% presets.
- Color temperature offers bounded steps and presets within the light's reported range.
- Color-capable lights offer Red, Green, Blue, and Amber presets.

Each command is checked again against the current device capabilities and Controls selection before sending.

### Climate controls

Select thermostats in **Settings > Controls**, then press **Right**, **OK** to save. Open a thermostat with **OK** to see its current temperature and supported settings.

- Temperature adjustments follow the reported step and limits; when no step is reported, Hearth uses one degree. Heat/cool range edits send both bounds and cannot cross them.
- HVAC, fan, and preset menus offer only options reported by that device. **Off** appears only when supported.
- Choosing an adjustment or mode sends it immediately, closes the menu, and refreshes the state after one second. **Back** or **Close** sends nothing.
- Missing targets or limits remain read-only; some thermostats only report a target after leaving Off. Auto, Dry, and Fan-only modes do not offer target adjustments.
- Temperatures use Home Assistant's reported units without conversion. If the unit label is absent, Hearth shows `°` rather than guessing Celsius or Fahrenheit.

Thermostats selected only in **Settings > Home tiles** remain read-only. Select them in **Settings > Controls** to enable commands on the same Home tile. Combining the pages does not enable additional commands or discard existing selections.

### Device names

Open **Settings > Device names**, choose a selected device, and enter a name of up to 64 characters. **Save name** applies it across Home, Scenes, and Cameras and keeps it after restarting the app. Devices in multiple selections appear once in the editor.

**Reset name**, or saving an empty name, restores the file-configured name when present, otherwise Home Assistant's friendly name or the entity ID. **Cancel** discards the edit. Names are stored only on this Roku; renaming does not change Home Assistant entities, selections, or commands.

## Configuration

The on-device Settings screen is the recommended setup method. Selecting a device authorizes its supported commands; discovery alone does not enable control. Non-toggle Home tiles remain read-only. Selected scenes and buttons can be activated before their first use; missing or unavailable entities remain blocked.

<details>
<summary>Optional file-based setup and custom actions</summary>

Copy [config.example.json](config.example.json) to the ignored `config.json`, edit it locally, then run `npm run build:local` and install `out/ha-roku-local.zip`. A saved on-device connection takes precedence over bundled credentials. The standard `npm run build` excludes this file.

| Field | Purpose |
| --- | --- |
| `homeAssistant.url` | Reachable HTTP(S) base URL without embedded credentials, query parameters, or a fragment. |
| `homeAssistant.token` | Home Assistant long-lived access token. |
| `homeAssistant.entities` | Initial Home selections. Suggested sensors are used when this list is empty. |
| `homeAssistant.entityNames` | Optional entity-ID-to-display-name map; saved on-device names take precedence. |
| `homeAssistant.actions` | Explicit `{name, domain, service, entityId}` commands; these seed Controls selections. |
| `refreshSeconds` | Initial refresh interval: 5–3600 seconds; default 30. |

Other service operations require an explicit configured action. For complex service payloads, create a Home Assistant script and select it in Hearth. Lights, switches, and input booleans retain their direct toggle behavior.

> [!WARNING]
> Local builds include `config.json` when present. Never share `config.json` or `out/ha-roku-local.zip` containing real credentials. Use `npm run build` for a distributable channel.

</details>

## Cameras and troubleshooting

The **Cameras** tab appears when at least one camera is saved in **Settings > Cameras** and hides when the last camera is deselected. Offline cameras remain selected and do not hide the tab.

Camera snapshots refresh every five seconds while visible. A failed refresh retains the last successful image and shows a failure status. Unsupported or failed live streams fall back to refreshed full-screen snapshots.

| Problem | What to check |
| --- | --- |
| Cannot connect to Home Assistant | Verify the address, token, network access, and TLS certificate. `localhost` refers to the Roku itself. If `.local` resolution fails, try a reachable LAN address. |
| Device is missing or in the wrong room | Check its Home Assistant state and area assignment, press Replay, then review your selected devices in Settings. |
| Live camera falls back to snapshots | Check the HTTP/HTTPS limitation above, Home Assistant stream support, and the Roku's supported codecs. Hearth does not convert RTSP, WebRTC, or MJPEG. |
| Camera stalls during startup | Hearth requests Home Assistant's single-rendition HLS playlist. For Frigate, ensure each camera's `live.streams` references an existing go2rtc stream and reload the Home Assistant integration after changes. |
| Roku shows HDCP error 020 | Check the HDMI connection, cable, and TV port. Hearth cannot repair a system-level HDCP error or guarantee a software fallback for that overlay. |
| A save or action fails | Press Play when the error banner offers details. Unsaved drafts remain available for retry; check device state before resending an action. |

HLS URLs must stay on the configured Home Assistant origin. Snapshots use Home Assistant's authenticated proxy rather than arbitrary entity-picture hosts. Visible live playback still requires validation on your own Roku/TV combination.

## Security and publishing

- Keep tokens, passwords, camera URLs containing credentials, and private camera images out of issues, commits, and release assets.
- Publish source and `config.example.json`, not your whole working folder. `.gitignore` excludes local configuration, `.env` files, `out/`, `.hallmark/`, private keys, and `node_modules/`.
- Ignore rules do not protect force-added files, manual uploads, or existing Git history.
- Build public channel releases with `npm run build`; this excludes `config.json` even when it exists locally. Configure credentials on-device. Do not publish the explicit local-build ZIP.
- Roku registry storage is local persistence, not a secret vault. Use a Home Assistant account with only the permissions you need.
- Revoke and replace exposed credentials. Deleting them from a file or commit does not invalidate them.

If [Gitleaks](https://github.com/gitleaks/gitleaks) is installed, scan both files and history before publishing:

```sh
gitleaks dir . --redact
gitleaks git . --redact
```

## Development

| Command | Purpose |
| --- | --- |
| `npm ci` | Install the locked development dependencies. |
| `npm test` | Run seven desktop regression suites. |
| `npm run check` | Check compiler diagnostics without packaging. |
| `npm run build` | Build `out/ha-roku.zip` without local configuration. |
| `npm run build:local` | Build private `out/ha-roku-local.zip`, including `config.json` when present. |

Source is organized into [SceneGraph components](components/), [shared BrightScript code](source/), [tests and fixtures](scripts/), and [image assets](images/). Public packaging is configured in [bsconfig.json](bsconfig.json); [bsconfig.local.json](bsconfig.local.json) explicitly opts into bundling local configuration.

Desktop tests use native-boundary doubles; they do not prove SceneGraph layout, networking, Audio Guide output, or video playback. Test relevant changes on a physical Roku, including focus, scrolling, save/cancel, room changes, and camera fallback. Use only safe devices for control tests and restore their original state afterward.

<details>
<summary>Native model, WebSocket, and hint-layout checks</summary>

The WebSocket fixture requires Python 3 and uses synthetic credentials only. In one terminal, replace the placeholder with your computer's Roku-reachable IPv4 address:

```sh
python3 scripts/websocket_fixture.py --advertise-host <computer-LAN-IPv4>
```

In another terminal:

```sh
npx bsc --project bsconfig.native-tests.json
```

Sideload `out/native-tests.zip` and connect to the Roku debug console on TCP port 8085. Require `HA_WEBSOCKET_TRANSACTIONS_PASSED` and `HA_WEBSOCKET_TESTS_PASSED` there, plus `WEBSOCKET_FIXTURE_PASSED` in the fixture terminal. Scenarios cover discovery, authentication rejection, fragmented responses, ping handling, disconnects, deadlines, and short sends.

The fixture writes its public address to ignored `out/websocket-fixture.json`; Ctrl-C removes it. Without that file, transaction checks report skipped while parser and URL checks still run.

For native hint layout:

```sh
npx bsc --project bsconfig.hint-tests.json
```

Sideload `out/hint-tests.zip` and look for `HEARTH_HINT_TESTS_PASSED` on port 8085.

For model and climate authorization checks on Roku's actual numeric types:

```sh
npx bsc --project bsconfig.model-tests.json
```

Sideload `out/model-tests.zip` and require `HEARTH_MODEL_TESTS_PASSED` on port 8085. These checks send no Home Assistant commands.

**Reinstall the production channel after any test package.**

</details>

## Support and contributing

Maintained by [@batman-2099](https://github.com/batman-2099).

For bugs or feature requests, [open an issue](https://github.com/batman-2099/hearth/issues). Include reproduction steps, expected and actual behavior, Roku model and software version, Home Assistant version, and redacted logs. Never include tokens, passwords, or private camera images.

For contributions:

1. Fork the repository and create a focused branch.
2. Keep changes small and consistent with the existing native components; avoid unrelated refactors or new dependencies.
3. Add or update behavioral tests, then run `npm test`, `npm run check`, and `npm run build`.
4. Open a pull request describing the change and verification performed. State any hardware checks you could not complete.

## License and attribution

Hearth includes work by natureglass. See [LICENSE.hearth](LICENSE.hearth) for the upstream MIT license and copyright notice. The bundled minimalist wallpapers are original Hearth artwork.
