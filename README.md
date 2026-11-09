# Hearth for Roku

A native BrightScript/SceneGraph Home Assistant dashboard for Roku. No browser wrapper, companion server, or Samsung APIs.

Components, source files, tests, and on-device settings use the Hearth name. The connected Roku's saved connection and device selections were copied and verified during the storage cutover; no legacy-name fallback is shipped. Other existing installations must configure the Hearth settings namespace before use.

## Pages

- **Home:** up to 30 selected sensor/status and toggle tiles, split into Home Assistant room subpages. Rewind/Fast-forward cycles rooms alphabetically, with unassigned devices under **Other** at the end. A bold header identifies the current room; a device range appears only when scrolling is needed. Arrows navigate and scroll within the current room; up to 12 tiles remain visible. Refreshes preserve the active room and selected entity when possible. Duplicate titles include room/device context. OK toggles lights, switches, and input booleans; other tiles open details.
- **Controls:** up to 48 devices split into room subpages, with a room-name header and eight reusable visible slots. Tiles show the device name and state without repeating the room label. Rewind/Fast-forward switches rooms; unassigned devices appear under **Other**. Lights, switches, and input booleans show an On/Off switch and toggle directly on OK. Other devices retain configured actions; Play opens Dim/Brighten choices for supported lights.
- **Cameras:** up to nine Home Assistant cameras, with at most four visible and two-column arrow-key scrolling for larger selections. Authenticated snapshots refresh every five seconds while visible; the last successful image remains during refresh. Healthy previews show only the feed name beneath the image; loading and failure messages remain visible when needed. OK requests native HLS playback; unsupported or failed streams fall back to explicitly labeled, refreshed full-screen snapshots.
- **Settings:** room-filtered entity pickers with compact `[x]`/`[ ]` selection indicators, a selected-only view, and full focused entity ID and selection status. Pickers start in the Home/Controls room from which Settings was opened when available; All rooms remains accessible and is the fallback. Connection address/token, dark/light/automatic theme, Slate/Sand/Mist/no wallpaper, 12/24-hour clock, and refresh interval persist on the Roku.

This replaces the old four-page dashboard and Lovelace importer. It does not render Lovelace, launch Samsung apps, provide Jellyfin/music, or list Frigate recordings. Existing local credentials, entity aliases, and explicitly configured service actions remain usable. Legacy standalone camera/Frigate configuration is not used; select Home Assistant camera entities instead.

## Build and install

Requires Node.js 22+, npm, and a physical Roku on a network that can reach Home Assistant.

```sh
npm install
npm test
npm run build
```

The installable package is `out/ha-roku.zip`.

1. Enable Roku developer mode: **Home three times, Up twice, Right, Left, Right, Left, Right**. Enable the installer, set its password, and reboot when prompted.
2. Open `http://<roku-ip>` on your computer; sign in as `rokudev` with the developer password.
3. Upload `out/ha-roku.zip` and choose **Install**. This replaces the Roku's one sideloaded development channel.

An unconfigured installation opens Home Assistant setup guidance. Use **Settings** to enter the address and long-lived access token, then choose **Save connection**. Create the token in your Home Assistant user profile. Connection fields are drafts until saved; Back discards unsaved connection edits. Tokens are masked and are not logged.

Connection saving uses the same URL/token policy as camera requests. Preference and connection drafts remain open until registry persistence succeeds; failed writes or flushes leave active settings unchanged and restore the previous registry buffer. Duplicate preference submissions are blocked while saving. Save failures remain available through **Play: details**.

Alternatively, copy `config.example.json` to the ignored `config.json`, edit it, rebuild, and install. The example is never bundled automatically. A saved on-device connection overrides bundled credentials.

| Bootstrap field | Purpose |
| --- | --- |
| `homeAssistant.url` | Reachable HTTP(S) base URL, without credentials, query, or fragment. |
| `homeAssistant.token` | Home Assistant long-lived access token. |
| `homeAssistant.entities` | Optional initial Home selections. Suggested sensors are used only when this selection is empty, not to fill remaining slots. |
| `homeAssistant.entityNames` | Optional entity-ID-to-display-name map. |
| `homeAssistant.actions` | Optional explicit `{name, domain, service, entityId}` service permissions; these seed Controls. |
| `refreshSeconds` | Initial state refresh interval, 5–3600 seconds; default 30. |

Use Settings to customize selections afterward. Pickers begin with **Room** and **View** filters; OK cycles rooms or switches between all and selected devices. Filters never discard hidden selections. The focused device's full entity ID appears below the list. Picker changes require **Save selection**, pinned above the scrolling device list. Press **Right**, then **OK** to save from any row; **Left** returns to the devices, Rewind/Fast-forward pages through the list, and **Back** discards unsaved changes. Empty saved selections stay empty. Selecting a device for Controls authorizes its supported standard operation: light/switch/input-boolean toggle, scene activation, script execution, or button press. Other service operations require an explicit configured action. Complex service payloads belong in a Home Assistant script. Room grouping comes from Home Assistant area metadata; entities without a room use **Other**.

Selecting a light, switch, or input boolean in **Home tiles** also authorizes its toggle operation. These three domains always use a single toggle instead of configured command menus when selected on either page. The switch position, color, and On/Off text follow the reported state; unknown/unavailable devices show an unavailable label instead of a false Off switch. Non-toggle Home tiles remain read-only. Discovery alone never grants control permission.

Selected buttons and scenes can be activated before their first use, when Home Assistant reports `unknown`; missing and `unavailable` entities remain blocked. Settings uses the same availability policy. Configured nonstandard actions remain discoverable after deselection. Failed room discovery is retried on the next refresh; Replay invalidates the room cache even when queued behind another request.

## Interface

Shared dark/light colors, 132px-high Home/Controls tiles, and high-contrast focus distinguish navigation from device state. An underline identifies the active page independently of focus. On/Off switches use both text and thumb position; native Audio Guide descriptions include state and action. Automatic theme follows `sun.sun`.

The editable channel icon is `images/hearth-icon.svg`; `manifest` uses the HD/FHD PNG exports. The header uses separate frame/flame layers so the frame follows the theme while the centered flame retains [Home Assistant blue](https://github.com/OpenHomeFoundation/brand-assets/blob/main/home-assistant/logo/screen/logomark/HA-logomark-color.svg), `#18BCF2`. Wallpaper choices are Slate, Sand, Mist, and None; retired Forest/Dunes preferences fall back to Slate.

Camera tiles occupy a centered 656px viewport. Four or more cameras use 320px-wide tiles, stacked vertically in pairs before extending right. Left/Right scrolls columns; Up/Down moves within a stack. Feed names are centered with a 14px image gap.

## Remote

Remote help pairs button images from the supplied Roku remote photograph with action text. `HearthHint` wraps complete pairs, bounds oversized labels, and exposes full actions to Audio Guide. The bottom-aligned footer reserves space for the connection indicator; Settings and snapshot fallback allow two hint rows.

Home Assistant status sits at the bottom-right: a green check means valid settings and a successful fresh state fetch; a red X means unconfirmed or stale connectivity. Save errors remain separate from connection health. **Play opens error details before brightness controls** whenever the status banner offers details.

Routine state refreshes run silently without an “Updating Home Assistant” banner. Control/camera progress and actionable errors remain visible.

Home and Controls use the same bright, bold On/Off typography; combined brightness text remains smaller to fit beside the switch. Home/Controls ranges and camera counts are hidden when all selected items fit.

| Context | Buttons |
| --- | --- |
| Page toolbar | Left/Right selects a page; OK/Down enters it. |
| Home | Arrows move/scroll within a room; OK toggles lights/switches/input booleans or opens other entity details; Rewind/Fast-forward switches room subpages. |
| Controls | Arrows move/scroll within a room; Rewind/Fast-forward switches rooms; OK toggles or confirms an action; Play opens brightness adjustment for supported lights. |
| Cameras | Arrows choose a camera; OK opens it; Back closes playback/snapshots. |
| Navigation | Up from the top row or Back returns to the toolbar. Back on the toolbar returns Home, then exits. |
| Shortcuts | Star opens Settings; Replay refreshes states and room metadata; Play opens full error details when the status banner offers them. |

Actions are sent once, followed by a **one-second wait and state refresh**. The affected Home/Controls tile shows **Sending…** until completion; tiles then reflect Home Assistant's reported state, not optimistic guesses. Unavailable devices cannot be operated. Concurrent activations are rejected while a request is running; actions are never automatically retried. Routine state refresh pauses in Settings, dialogs, and full-screen playback. Failed refreshes identify potentially stale values; **Play: details** shows the complete error and last successful state-refresh time.

## Camera and security limits

Snapshots use Home Assistant's authenticated camera proxy, never arbitrary entity-picture hosts. HLS discovery uses a short-lived native WebSocket connection. Roku's native socket API does not provide TLS: **HTTPS/WSS and IPv6 connections use snapshots**, without downgrading HTTPS. HTTP IPv4/DNS connections can discover HLS directly. Use HTTP only on a trusted LAN; HTTPS requests otherwise keep certificate verification enabled.

For all cameras, Hearth selects Home Assistant's single-rendition `playlist.m3u8` rather than `master_playlist.m3u8`: the Roku can stall at 33% on the video-only master. Query parameters and same-origin checks are preserved. No external proxy is required. In Frigate, each camera's `live.streams` must reference an existing go2rtc stream; reload the Home Assistant integration after changing these mappings.

Roku can also raise a system-level **HDCP error 020** even while its media player reports playback. This is an HDMI/TV connection issue, not an HLS discovery failure. Reseat the HDMI cable or test another HDMI port/cable; the app cannot repair that connection or guarantee a software fallback for Roku's system overlay.

Playback requires Home Assistant's stream support and a codec supported by the Roku model. The app does not transcode RTSP, WebRTC, or MJPEG. HLS URLs must resolve to the configured Home Assistant origin. Expired URLs, unavailable cameras, unsupported codecs, and stream errors return to refreshed snapshots with an explanation.

Connection URLs are limited to 2048 characters; tokens must be printable ASCII without spaces, up to 8192 characters. REST, snapshots, and live-stream discovery share these input checks, while the live transport retains its HTTP/IPv4 limitation. Camera tab changes reuse the existing visual nodes, clear hidden image requests and bearer agents, and refresh images on re-entry.

Keep `config.json`, `.env` files, and built ZIPs private: bundled configuration can contain credentials. Roku registry persistence is local storage, not a secret vault. `localhost` means the Roku itself; use a reachable LAN address if `.local` resolution fails.

## Publishing safely

Publish source files and `config.example.json`, not your whole working folder. Exclude `config.json`, `config.local.json`, `.env` files, `out/` (including screenshots and device responses), `.hallmark/`, private keys, and `node_modules/`. These are ignored by Git; ignore rules do not protect manual uploads, force-added files, or previously committed history.

`npm run build` embeds `config.json` when present. Build public channel releases from a clean source checkout without that file, then configure the connection on-device. Before publishing, run `gitleaks dir . --redact`; scan Git history separately with `gitleaks git . --redact` if a repository already exists. Revoke and replace credentials exposed in commits, shared builds, screenshots, or chats; removing a file does not revoke its secrets.

## Verification

- `npm test`: authorization and availability, preference normalization, picker/save behavior, registry rollback, queued refreshes, error-details precedence, and page/Task regressions. Native boundaries use the existing desktop `brs` interpreter's doubles.
- `npm run check`: compiler diagnostics; `npm run build`: production packaging.
- Native WebSocket transactions (Python 3 stdlib; no real Home Assistant credentials):

  ```sh
  # Keep this running in one terminal; use your computer's Roku-reachable IPv4 address.
  python3 scripts/websocket_fixture.py --advertise-host <computer-LAN-IPv4>
  # In another terminal:
  npx bsc --project bsconfig.native-tests.json
  ```

  Sideload `out/native-tests.zip` and connect to the Roku debug console on TCP port 8085. Require both `HA_WEBSOCKET_TRANSACTIONS_PASSED` and `HA_WEBSOCKET_TESTS_PASSED`, plus `WEBSOCKET_FIXTURE_PASSED` in the fixture terminal. Cases cover authentication/discovery, split responses, ping/fragmentation, rejection, disconnect, deadline, and deterministic short sends. The fixture writes only its public address to ignored `out/websocket-fixture.json`; Ctrl-C removes it. Without that file, transaction tests explicitly report skipped; parser, cryptography, and URL tests still run. Reinstall production afterward.

Compilation and desktop tests do not verify SceneGraph layout, networking, or codecs. Check the actual Roku: navigate all pages, save/cancel a picker, restart to check saved settings, operate and restore a safe light, play a supported camera, and check Back/fallback behavior.

For picker persistence, change a selection beyond the first screen, save with Right then OK, and reopen it; restore the original selection afterward. Repeat with Back to verify cancellation. Review Home/Controls scrolling and focus, camera hide/re-entry, snapshot fallback, and room switching on the device.

Native hint layout checks: build with `npx bsc --project bsconfig.hint-tests.json`, sideload `out/hint-tests.zip`, and look for `HEARTH_HINT_TESTS_PASSED` on port 8085. Restore production after either native test package.

Audit remediation verification: all seven desktop suites, compiler checks, production packaging, and the native transaction fixture passed. Production was restored on Roku; brightness-dialog cancellation, repeated Replay, and camera scrolling were checked without sending household device commands. Desktop rendering tests substitute Font nodes because the interpreter cannot resolve Roku system-font URIs.

Verification limits: spoken Audio Guide output and physical-TV overscan require manual checks. Previous live-camera discovery produced advancing playback, but HDCP error 020 prevented visual playback verification. Hallmark's HTML/CSS tools and browser/mobile viewport checks do not apply to native SceneGraph. Historical `.hallmark` records are not evidence for the current implementation.

## Attribution

Hearth includes work by natureglass. The upstream copyright and MIT notice are retained in `LICENSE.hearth` and included in the channel package. The bundled minimalist wallpapers are original Hearth artwork.
