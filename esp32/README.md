# EM Pro V2 (2-Button) — Motor Protection Controller

`em_pro_v2_2button.ino` is ESP32 firmware for a single-phase motor/pump protection
unit. It drives a contactor relay through a soft-start stage, monitors load
current, and trips on overcurrent (OC) or undercurrent/dry-run (UC) faults. The
user interacts with it through a 2-button interface (mapped onto a 3x2 keypad
matrix) and a 4-digit TM1637 7-segment display.

No physical board required to explore the firmware's behavior — see
[SIMULATION.md](SIMULATION.md) for a ready-to-run Wokwi simulation
(`diagram.json` / `wokwi.toml` in this folder).

## Hardware

| Signal              | Pin | Purpose                                              |
|---------------------|-----|-------------------------------------------------------|
| `PIN_DISPLAY_CLK`   | 18  | TM1637 display clock                                   |
| `PIN_DISPLAY_DIO`   | 19  | TM1637 display data                                    |
| `PIN_RELAY_MAIN`    | 4   | Main contactor relay                                    |
| `PIN_RELAY_SOFT`    | 23  | Soft-start relay (energized only for the first ticks after turn-on) |
| `PIN_CURRENT_ADC`   | 33  | Analog current sense input                              |
| `PIN_VOLTAGE_ADC`   | 32  | Analog voltage sense input (read, currently unused in UI) |
| Keypad rows         | 5, 16, 17 | 3-row matrix                                       |
| Keypad cols         | 26, 21    | 2-column matrix                                     |

Only two logical buttons are used for navigation:
- `BTN_NEXT` (physical key `'1'`) — move cursor / next screen
- `BTN_UP` (physical key `'2'`) — increment digit / view

Keys `'5'`–`'8'` map directly to fixed functions: OC view, UC view, OFF, ON.

An 8-second hardware task watchdog (`esp_task_wdt`) is active; every blocking
loop in the firmware repeatedly calls `esp_task_wdt_reset()` and
`precesskey()` so it stays responsive and never triggers a watchdog panic.

## Startup

`setup()` drives both relay pins `LOW` **before** anything else initializes,
so the motor fails safe (off) on every boot/reset. It then loads calibration
from EEPROM, configures ADC pins, and arms the watchdog.

## Main state machine

`button_num` is the current UI/control state, dispatched every `loop()`
iteration:

| State            | Handler         | Meaning                                   |
|-------------------|----------------|--------------------------------------------|
| `BTN_OFF`          | `turn_off()`    | Relay off, idle display                    |
| `BTN_ON`           | `turn_on()`     | Relay on (with soft-start), current monitoring via `compare()` |
| `BTN_OC_VIEW`      | `OC_value()`    | Momentarily shows OC threshold; long-press enters settings |
| `BTN_UC_VIEW`      | `UC_value()`    | Momentarily shows UC threshold; long-press enters settings |
| `BTN_SETTINGS`     | `OC_setting()` / `UC_setting()` | Threshold editor / auto-calibration |
| `BTN_OC_FAULT`     | `Show_OC_Error()` | Latched overcurrent fault screen         |
| `BTN_UC_FAULT`     | `Show_UC_Error()` | Latched undercurrent/dry-run fault screen |

`PBN` remembers the previous "real" mode (ON/OFF) so that pressing `NEXT`/`UP`
outside of a settings/view context simply falls back to it.

## Current protection (`compare()`)

Called after every `turn_on()`. It skips checking during the soft-start grace
period (`l <= FAULT_GRACE_TICKS`, i.e. the first ~60 ticks after turn-on).
After that:

- **Overcurrent**: if `res > OC`, waits `OC_RECHECK_MS` (1.8s) while still
  sampling current, then re-checks. Only trips (`Relay(0)`,
  `button_num = BTN_OC_FAULT`) if still over threshold — this debounces
  transient spikes.
- **Undercurrent / dry-run**: if `res < UC`, waits `UC_RECHECK_NO_LOAD_MS`
  (4.5s, if there's genuinely no load) or `UC_RECHECK_MS` (1.8s) otherwise,
  then re-checks before tripping to `BTN_UC_FAULT`.

A confirmed fault latches the display until the user manually cycles
OFF → ON.

## Current sensing (`Show_Current()`)

Averages 5 ADC samples, then applies a **piecewise-linear scale** to convert
the raw ADC average into a real-world current value (`res`). The scale
explicitly covers the 660–750 raw-value range, which a comment notes used to
fall through unmatched in an earlier version and leave `res` stale.

## Settings / calibration

Entered by long-pressing `OC_VIEW` or `UC_VIEW` while off (tracked via the
`M2` hold counter in `precesskey()`). Two flows:

1. **`OC_setting()` — manual threshold editor.** Lets the user step through
   digits of the OC then UC threshold using `NEXT` (move cursor, blinking)
   and `UP` (increment digit). A 5-second idle timeout reverts unsaved
   changes. Values are written to EEPROM once on exit, not per keystroke.
2. **`UC_setting()` — auto-calibration.** Turns the relay on directly, waits
   3s, then samples current every 300ms looking for 5 consecutive stable
   readings (within 2A of each other). Once stable it sets
   `OC = stableCurrent + 20` and `UC = stableCurrent - 15` (or 0 if there's
   no load), saves to EEPROM, and plays a confirmation display sequence.
   Times out after 30s with an error screen if the current never stabilizes.

## WiFi / BLE provisioning (`setupNetworking()`)

Runs once at the end of `setup()`, after the watchdog is armed, and never
blocks or interferes with the motor-protection loop afterward:

1. **Stored credentials first.** If EEPROM has a valid `NetworkData` record
   (`wifiValid == true`), it tries `WiFi.begin()` with a 15s timeout
   (`WIFI_CONNECT_TIMEOUT_MS`). If that succeeds, BLE is never turned on at
   all.
2. **BLE fallback (45s window).** If there are no stored credentials, or the
   stored ones fail to connect, the firmware advertises a BLE GATT service
   matching the [aqua_control](../aqua_control) app's WiFi provisioning flow
   (`aqua_control/lib/core/services/ble_wifi_service.dart`) for up to
   `BLE_PROVISION_TIMEOUT_MS` (45s):
   - Service UUID `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
   - SSID characteristic (write) `beb5483e-...-ea07361b26a8`
   - Password characteristic (write) `beb5483f-...-ea07361b26a9`
   - Status characteristic (notify) `beb54840-...-ea07361b26aa`

   The app writes raw UTF-8 bytes to the SSID and password characteristics
   (no JSON, no framing) and listens for human-readable strings on the
   status characteristic — it does not parse them for success/failure, so
   the firmware just needs to send something readable, not a specific
   keyword.
3. **Credentials arrive → save → connect.** On receiving both writes, the
   firmware saves them to EEPROM immediately (so a later failure doesn't
   lose them), sends a status notification, tears down BLE completely
   (`BLEDevice::deinit(true)` — BLE and WiFi share the same radio on
   classic ESP32, so BLE is always fully stopped *before* `WiFi.begin()` is
   called, never concurrently), then attempts to connect.
4. **No connection either way → fall through.** If the 45s window expires
   with no credentials, or the post-BLE connection attempt fails, the
   firmware just continues with no network at all — everything above this
   point in `setup()` (relay fail-safe, calibration, watchdog) and all of
   `loop()` behave exactly as they did before this feature existed.
5. **Backend registration.** Once WiFi is up (either path), it `POST`s to
   `{BACKEND_BASE_URL}/api/v1/device/register/{serial}?type=esp32` with
   HTTP Basic Auth, using a serial number derived from the ESP32's efuse
   MAC (`getDeviceSerial()`, format `SR<12 hex chars>` — not stored, just
   recomputed each boot since the MAC is fixed in hardware). On success,
   the returned `topics` object (commands/telemetry/alert/heartbeat MQTT
   topic strings) is saved to EEPROM. This call is idempotent server-side
   (200 if already registered, 201 if new) and is safe to repeat on every
   boot that has WiFi.

## Telemetry (`sendTelemetry()`)

A one-shot telemetry publish fires from `loop()` once `millis() >=
TELEMETRY_FIRST_SEND_MS` (2 minutes after boot) — a cheap flag+time check
every cycle, with the actual MQTT work happening exactly once, so it never
turns into a recurring poll or blocks the motor-protection loop. It's a
no-op if WiFi isn't up or no topics are stored yet at that point (no retry
is attempted — see rough edges below).

When it fires: forces a fresh burst of current/voltage samples
(`sampleElectricalReadings()`, since `Show_Current()`/`Show_Voltage()` only
average once every 5+ calls, so the last-computed value could be stale or
zero), builds a JSON payload matching the backend's `telemetry.service.ts`
schema exactly —

```json
{"v": <voltage>, "i": <current>, "oc": <OC threshold>, "uc": <UC threshold>, "motor": <relay state>, "sn": "<serial>"}
```

— then does an ephemeral connect → publish → disconnect to
`{MQTT_BROKER_HOST}:{MQTT_BROKER_PORT}` (plain `mqtt://`, shared
`fourfold`/`fourfold@2026` credentials — see security notes) and publishes
to `netData.topicTelemetry` (e.g. `motors/FF00114/telemetry`, as returned
by registration). `gt`/`oh` (tank level fields) are omitted — this hardware
has no tank-level sensors, and the backend treats them as optional.

`sn` is sent as the same `SR<hex>` string used for backend registration,
not a bare number — the backend's example payloads show a numeric `sn`,
but it's only read as a fallback when the MQTT topic itself doesn't
resolve to a registered device, which won't happen here since we already
registered under this exact topic. `.toString()` on a JS string is a
no-op, so this is harmless either way.

**Not yet implemented**: recurring telemetry (only a single 2-minute
publish exists today), heartbeat replies (per `module-status.service.ts`,
heartbeat is a request/reply protocol — the backend publishes
`{"cmd":"SEND_HEARTBEAT","cmd_id":...}` to the device's *commands* topic
and expects a reply on the heartbeat topic echoing that `cmd_id`, not
something publishable on a timer), and alert publishing. A persistent MQTT
client (subscribed to the commands topic, `client.loop()`'d from the main
loop) would be the natural upgrade path if any of those are needed later.

## EEPROM persistence

`CalibrationData { ocValue, ucValue, crc }` is stored at address 0 with a
CRC16 checksum. `loadCalibration()` validates the CRC and bounds; if
corrupt or never written, `Data_read()` self-heals by writing safe defaults
(`OC_SAFE_DEFAULT = 30`, `UC_SAFE_DEFAULT = 20`).

`NetworkData` (WiFi SSID/password + the four MQTT topic strings) is stored
separately at address 16, also CRC16-checked, using the same
load-validate-or-reset pattern (`loadNetworkData()`/`saveNetworkData()`).
`EEPROM_SIZE` was bumped from 200 to 512 bytes to fit both records.

## Display

`TM1637Display.encodeDigit()` is fed out-of-range codes as a trick to render
non-digit glyphs (letters/blank) for status text — e.g. `20` renders blank.
These appear throughout fault screens and calibration prompts as
undocumented magic numbers.

## Security notes

- **TLS certificate validation is disabled.** `registerDeviceWithBackend()`
  calls `WiFiClientSecure::setInsecure()`, so the HTTPS connection to the
  backend is encrypted but the server's certificate is never verified —
  this is vulnerable to a MITM on the local network substituting its own
  cert. Embedding the actual root CA (e.g. ISRG Root X1, if
  `api.fourfoldsystem.com` uses Let's Encrypt) and using
  `setCACert()` instead is the hardened alternative, at the cost of needing
  to update the firmware if the CA ever changes.
- **Backend Basic Auth credentials are hardcoded in firmware**
  (`fourfold`/`fourfold`, matching the backend's default — see
  `backend/src/common/guards/basic-auth.guard.ts`). Anyone who dumps the
  firmware gets these credentials; they're shared across every device
  rather than per-device.
- **WiFi credentials are stored in plaintext in EEPROM**, unencrypted (same
  as most consumer IoT devices, but worth noting explicitly).
- **MQTT connection is plaintext, shared-credential.** `MQTT_USERNAME`/
  `MQTT_PASSWORD` (`fourfold`/`fourfold@2026`) are hardcoded and shared
  across every device — same tradeoff as the backend Basic Auth
  credentials above. There's also a separate, more hardened design
  documented in `vultr-emqx-complete-guide.md` (TLS on 8883, per-device
  `esp32_{MAC}` credentials) that isn't implemented on the backend yet;
  this firmware targets the plain setup that's actually running today.

## Known rough edges

These were identified while reviewing the code and are not yet fixed:

- **BLE provisioning isn't exercisable in the Wokwi simulation** (see
  [SIMULATION.md](SIMULATION.md)) — Wokwi doesn't model a BLE central/phone
  to pair with, so the 45s BLE window will always time out there. Use
  `#define SIM_WIFI_TEST` to bypass it and test the WiFi/HTTP/EEPROM path
  directly against Wokwi's simulated network instead.
- **Settings entry can get stuck.** `OC_setting()` only runs its editor body
  when `D1..D4 == 0`, but those are the same globals `Show_Current()` uses to
  hold the live current reading. Once the motor has drawn any non-zero
  current, that gate stays false until reboot, silently blocking entry to
  the settings menu.
- **OFF is ignored during a fault recheck window.** The blocking wait in
  `compare()` (1.8–4.5s) never checks for `button_num == BTN_OFF` to exit
  early, unlike every other blocking loop in the file — the relay stays
  energized and a pending trip decision can overwrite the user's OFF
  request.
- **Manual threshold entry caps at 199** (`handleDigitEntry`'s `maxDigit1 =
  2`) while auto-calibration and EEPROM storage support up to 999.
- **Calibration bypasses soft-start** — `UC_setting()` drives the main relay
  pin directly instead of going through `Relay()`.
- `BTN_DIGIT3` / `BTN_DIGIT4` are defined but have no corresponding physical
  key in the keypad matrix.
- **Telemetry send isn't retried.** If WiFi/topics aren't ready at exactly
  the 2-minute mark (e.g. BLE provisioning ate into that window, or the
  broker is briefly unreachable), `sendTelemetry()` just returns `false`
  and nothing else ever tries again — `telemetrySent` is set unconditionally
  before the attempt, regardless of outcome.
