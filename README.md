# Hearth for Roku

<img src="images/channel-icon-hd.png" alt="Hearth logo: a blue flame inside a fireplace" width="145" height="109">

Home Assistant on your TV, controlled with your Roku remote.

**[Get started](#getting-started)** | [Remote controls](#using-the-remote) | [Troubleshooting](#cameras-and-troubleshooting) | [Contributing](#support-and-contributing)

Native BrightScript/SceneGraph. Direct Home Assistant connection. No browser wrapper or companion server.

## Features

- **Room-based dashboard:** display up to 30 selected sensors, statuses, and toggles, grouped by Home Assistant area.
- **Device controls:** select up to 48 devices; toggle lights, switches, and input booleans, adjust supported light brightness, and activate scenes, scripts, and buttons.
- **Cameras:** select up to nine cameras, browse refreshed snapshots, and open supported HLS streams.
- **Personalization:** dark, light, or automatic theme; three minimalist backgrounds; 12/24-hour clock; configurable refresh interval.
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
3. Choose devices for **Home tiles**, **Controls**, and **Cameras**.
4. In a device picker, press **Right**, then **OK**, to save. **Back** discards unsaved changes.

Saved settings persist on the Roku. Room names come from Home Assistant areas; unassigned devices appear under **Other**. Room and selected-only filters do not discard hidden selections.

## Using the remote

| Context | Controls |
| --- | --- |
| Page tabs | Left/Right selects a page; OK or Down enters it. |
| Home and Controls | Arrows navigate devices; Rewind/Fast-forward changes rooms. |
| Device tile | OK toggles a supported device, opens its actions, or shows read-only details. |
| Dimmable light | Play opens brightness adjustment. |
| Cameras | Arrows choose a camera; OK opens it; Back closes playback or snapshots. |
| Navigation | Back returns to the tabs; from the tabs, Back returns Home, then exits. |
| Settings | Star opens Settings. |
| Refresh | Replay refreshes states and room assignments. |
| Error banner | Play opens error details, taking priority over brightness. |

The bottom-right Home Assistant indicator shows a green check for a successful fresh state fetch and a red X for an unconfirmed or stale connection. Save failures are reported separately.

Device actions are sent once, followed by a one-second wait and state refresh. Tiles display **Sending…** until completion, then show Home Assistant's reported state. Failed actions are not automatically retried; check the device's state before retrying.

## Configuration

The on-device Settings screen is the recommended setup method. Selecting a device authorizes its supported commands; discovery alone does not enable control. Non-toggle Home tiles remain read-only. Selected scenes and buttons can be activated before their first use; missing or unavailable entities remain blocked.

<details>
<summary>Optional file-based setup and custom actions</summary>

Copy [config.example.json](config.example.json) to the ignored `config.json`, edit it locally, then rebuild and install. A saved on-device connection takes precedence over bundled credentials.

| Field | Purpose |
| --- | --- |
| `homeAssistant.url` | Reachable HTTP(S) base URL without embedded credentials, query parameters, or a fragment. |
| `homeAssistant.token` | Home Assistant long-lived access token. |
| `homeAssistant.entities` | Initial Home selections. Suggested sensors are used when this list is empty. |
| `homeAssistant.entityNames` | Optional entity-ID-to-display-name map. |
| `homeAssistant.actions` | Explicit `{name, domain, service, entityId}` commands; these seed Controls selections. |
| `refreshSeconds` | Initial refresh interval: 5–3600 seconds; default 30. |

Other service operations require an explicit configured action. For complex service payloads, create a Home Assistant script and select it in Hearth. Lights, switches, and input booleans retain their direct toggle behavior.

> [!WARNING]
> Builds include `config.json` when present. Do not share that file or a channel ZIP containing real credentials.

</details>

## Cameras and troubleshooting

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
- Build public channel releases from a clean checkout **without `config.json`**, then configure credentials on-device.
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
| `npm run build` | Build `out/ha-roku.zip`. |

Source is organized into [SceneGraph components](components/), [shared BrightScript code](source/), [tests and fixtures](scripts/), and [image assets](images/). Packaging is configured in [bsconfig.json](bsconfig.json).

Desktop tests use native-boundary doubles; they do not prove SceneGraph layout, networking, Audio Guide output, or video playback. Test relevant changes on a physical Roku, including focus, scrolling, save/cancel, room changes, and camera fallback. Use only safe devices for control tests and restore their original state afterward.

<details>
<summary>Native WebSocket and hint-layout checks</summary>

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

Sideload `out/hint-tests.zip` and look for `HEARTH_HINT_TESTS_PASSED` on port 8085. **Reinstall the production channel after either test package.**

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
