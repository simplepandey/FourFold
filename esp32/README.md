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
the raw ADC average into a current value (`res`). The scale explicitly
covers the 660–750 raw-value range, which a comment notes used to fall
through unmatched in an earlier version and leave `res` stale.

**Units: `res`/`OC`/`UC`/`calib.ocValue`/`calib.ucValue` are real amps × 10,
not whole amps.** Confirmed by the display: `print(D2, D3 + 10, D4, 25)`
ORs the decimal-point segment onto `D3` (`TM1637Display.cpp`'s
`digitToSegment[10..19]` = digits 0–9 with the DP bit set), rendering `res`
as `D2 D3.D4` — i.e. `res / 10`. `OC_SAFE_DEFAULT = 30` therefore displays
as "3.0", not "30". Comparisons/EEPROM storage/calibration all stay in this
×10 scale internally (unchanged); the conversion to/from true amps happens
only at the MQTT boundary — see Telemetry/Alerts/Commands below.

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
2. **BLE fallback, with in-session retry (45s total budget).** If there are
   no stored credentials, or the stored ones fail to connect, the firmware
   advertises a BLE GATT service matching the
   [aqua_control](../aqua_control) app's WiFi provisioning flow
   (`aqua_control/lib/core/services/ble_wifi_service.dart`), for up to
   `BLE_PROVISION_TIMEOUT_MS` (45s) total across as many attempts as fit in
   that window:
   - Service UUID `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
   - SSID characteristic (write) `beb5483e-...-ea07361b26a8`
   - Password characteristic (write) `beb5483f-...-ea07361b26a9`
   - Status characteristic (notify) `beb54840-...-ea07361b26aa`

   The app writes raw UTF-8 bytes to the SSID and password characteristics
   (no JSON, no framing) and listens for human-readable strings on the
   status characteristic. The firmware sends three kinds of message:
   `"Credentials received, connecting to WiFi..."` right after both are
   written, then either `"WiFi connected successfully!"` or `"WiFi
   connection failed. Check the password and try again."` once
   `connectToWifi()` resolves — the app matches on `"successfully"` /
   `"failed"` substrings (`wifi_ble_setup_sheet.dart`) to decide the
   outcome, rather than assuming the BLE stream ending means success.
3. **BLE stays connected through the WiFi attempt.** ESP32 supports
   WiFi/BLE running concurrently (the radio is time-shared via ESP-IDF's
   coexistence support — the same pattern Espressif's own BLE
   provisioning example uses), so `runBleProvisioning()` does *not* tear
   BLE down before calling `connectToWifi()`. This means the phone hears
   the outcome over the same session it's already connected to, and on
   failure the firmware just clears the received-credentials flags and
   loops back to waiting — the phone can write a new SSID/password without
   reconnecting. `netData.ssid`/`password`/`wifiValid` are saved to EEPROM
   only once a `connectToWifi()` attempt actually succeeds (a failed
   attempt is never persisted).
4. **Retry loop exits on: success, the phone disconnecting, or the 45s
   budget running out** — whichever comes first. In every non-success
   case, the firmware falls through to no network at all — everything
   above this point in `setup()` (relay fail-safe, calibration, watchdog)
   and all of `loop()` behave exactly as they did before this feature
   existed. `stopBleProvisioning()` (`BLEDevice::deinit(true)`) always
   runs once the retry loop exits, whatever the outcome.
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

Builds a JSON payload matching the backend's `telemetry.service.ts` schema
exactly —

```json
{"v": <voltage>, "i": <current, true amps>, "oc": <OC threshold, true amps>, "uc": <UC threshold, true amps>, "motor": <relay state>, "sn": "<serial>"}
```

— and publishes it to `netData.topicTelemetry` (e.g. `motors/FF00114/telemetry`)
over the persistent `mqttClient` (connecting it first via `ensureMqttConnected()`
if needed). `gt`/`oh` (tank level fields) are omitted — this hardware has no
tank-level sensors, and the backend treats them as optional.

`i`/`oc`/`uc` are `res`/`OC`/`UC` divided by 10 before being written into
the JSON — see the units note under Current sensing above. `v` (`res3`)
is sent as-is; voltage was never on that ×10 scale.

`sn` is sent as the same `SR<hex>` string used for backend registration,
not a bare number — the backend's example payloads show a numeric `sn`,
but it's only read as a fallback when the MQTT topic itself doesn't
resolve to a registered device, which won't happen here since we already
registered under this exact topic. `.toString()` on a JS string is a
no-op, so this is harmless either way.

`sendTelemetry()` fires from three places, all event-driven rather than
polled — the backend's `moduleStatusService.upsert()` merges whatever
fields a given publish includes, so any of these keeps `module_status`
current without needing every field every time:

- **A one-shot publish 2 minutes after boot** (`TELEMETRY_FIRST_SEND_MS`,
  a cheap flag+time check every `loop()` cycle) — a fallback baseline in
  case nothing else has triggered a send yet.
- **On every ON/OFF transition**, via `reportMotorState()`. `turn_on()`/
  `turn_off()` run on *every* `loop()` tick while in that state, not just
  on the keypress — `reportMotorState()` compares against
  `lastReportedMotorState` and only actually calls `sendTelemetry()` on a
  real transition, so holding OFF (or ON) doesn't republish every tick.
  Also called from `compare()`'s fault-trip points, since a breach turns
  the relay off outside of `turn_off()`.
- **On a ≥0.5A swing in load current**, via `reportCurrentIfChanged()`
  (called every tick from `turn_on()`). Compares the sub-amp-resolution
  `resPrecise` against `lastReportedCurrentAmps`, rate-limited to at most
  once per `CURRENT_TELEMETRY_MIN_INTERVAL_MS` (2s) so noisy/fluctuating
  current can't flood MQTT with a publish every ~25ms sample cycle.

All three paths call `sampleElectricalReadings()`, which forces a fresh
burst of current/voltage samples with `updateDisplay=false` — it must
never flicker whatever screen is currently showing (e.g. the OFF screen)
just because telemetry fired in the background.

## Alerts (`sendAlert()`)

On a confirmed OC or UC breach in `compare()` (relay already off, fault
screen latched), `sendAlert(ocBreached, ucBreached)` publishes to
`netData.topicAlert` matching `telemetry.service.ts`'s `processAlert()`:

```json
{"overcurrent_breached": <current, true amps>}   // or "undercurrent_breached", whichever tripped
```

The backend only checks whether the field is present, not its value, but
the last current reading (also divided by 10 to true amps, same as
telemetry) is included since it's available. The
accompanying motor-state change (relay now off) is reported separately —
`compare()` also calls `reportMotorState(false)`, which publishes a
telemetry message with `"motor": false`, since the alert payload itself
has no motor field.

## Commands (`mqttCommandCallback()`)

A persistent `PubSubClient` (`mqttClient`) is kept alive from `loop()` via
`maintainMqtt()`, reconnecting at most once every
`MQTT_RECONNECT_INTERVAL_MS` (5s) and subscribing to `netData.topicCommands`
on connect. `sendTelemetry()` now publishes over this same persistent client
instead of an ephemeral connect/publish/disconnect.

Incoming messages on the commands topic are parsed as
`{"cmd":"...","value":<num|null>,"cmd_id":"<uuid>"}`, matching
`create-motor-command.dto.ts` / `module-status.service.ts`:

| `cmd`            | Effect                                                              |
|------------------|----------------------------------------------------------------------|
| `TURN_ON`        | `button_num = BTN_ON` — dispatched to `turn_on()` on the same loop tick, same as pressing the physical ON key |
| `TURN_OFF`       | `button_num = BTN_OFF` — same, via `turn_off()`                     |
| `SET_OC`         | `value` is true amps (DTO example: `8.5`) — converted to the device's internal ×10 scale and rounded: `calib.ocValue = constrain(round(value * 10), 0, 999)`, saved to EEPROM, `OC` updated live |
| `SET_UC`         | Same for `calib.ucValue` / `UC`                                     |
| `SEND_HEARTBEAT` | Replies on `netData.topicHeartbeat` with `{"id":"<cmd_id>","v":..,"i":..,"oc":..,"uc":..}` (`i`/`oc`/`uc` converted to true amps, same as telemetry), echoing the request's `cmd_id` under the key `id` so the backend's `HeartbeatRegistryService` can correlate it |

**Not yet implemented**: recurring telemetry beyond the event-driven sends above.

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
- **Telemetry sends aren't retried on failure.** `reportMotorState()` and
  `reportCurrentIfChanged()` update their tracking variables
  (`lastReportedMotorState`/`lastReportedCurrentAmps`) *before* checking
  whether `sendTelemetry()` actually succeeded — so if the broker is
  briefly unreachable when an ON/OFF transition or a current swing occurs,
  that event is marked "reported" and never resent, even though the
  backend never saw it. The 2-minute boot publish has the same gap
  (`telemetrySent` is set unconditionally before the attempt). In practice
  a later event (the next transition, or a further ≥0.5A swing) usually
  produces a fresh publish anyway, but a device that's briefly offline
  right at a transition can leave the backend's `module_status` stale
  until something else triggers a send.
