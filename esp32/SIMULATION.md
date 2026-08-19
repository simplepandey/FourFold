# Simulating em_pro_v2_2button.ino

There's no motor to attach in a simulator, but every peripheral this firmware
actually talks to (ESP32, TM1637 display, the 2-button keypad matrix, and the
two ADC inputs) is supported by [Wokwi](https://wokwi.com), so the full state
machine — display output, keypad handling, threshold settings, calibration,
and OC/UC fault tripping — can be exercised without hardware. Current and
voltage are faked with potentiometers standing in for the sense circuitry.

`diagram.json` and `wokwi.toml` in this folder are already wired up for this
sketch, entirely on Wokwi's free tier — see the library note below, the
"paid" wall people sometimes hit is a red herring for this project.

## Recommended: VS Code + Wokwi extension (free, stays local)

Everything (sketch, diagram, config) stays in this repo — nothing gets
published anywhere. Requires a free personal Wokwi license, no payment.

1. Install the [Wokwi Simulator VS Code extension](https://marketplace.visualstudio.com/items?itemName=wokwi.wokwi-vscode).
   On first use it'll prompt you to run **Wokwi: Request a new License** —
   this issues a free license tied to your (free) Wokwi account, no card
   needed for personal/hobby use.
2. Install `arduino-cli` and the ESP32 core:
   ```
   arduino-cli core install esp32:esp32
   ```
3. Install the libraries the sketch needs beyond the ESP32 core (`WiFi`,
   `WiFiClientSecure`, `HTTPClient`, and the BLE headers are all bundled
   with `esp32:esp32`, no install needed):
   ```
   arduino-cli lib install Keypad
   arduino-cli lib install ArduinoJson
   arduino-cli lib install PubSubClient
   ```
   `TM1637Display.h`/`.cpp` are already bundled directly in this folder
   (avishorp/TM1637 v1.2.0 source) — arduino-cli/Wokwi will pick them up
   automatically since they sit next to the sketch, so no library install
   is needed for the display. Don't also `arduino-cli lib install TM1637`
   — that would install a second copy globally and risks a duplicate-class
   conflict with the local one.
4. Compile the sketch so the binary paths in `wokwi.toml` exist. WiFi + BLE
   + TLS + JSON together are large enough that the default partition table
   can be tight, so request a bigger app partition explicitly:
   ```
   arduino-cli compile --fqbn esp32:esp32:esp32doit-devkit-v1 \
     --build-property build.partitions=huge_app \
     --output-dir esp32/build esp32/em_pro_v2_2button.ino
   ```
   (adjust `--output-dir` to match the `firmware`/`elf` paths in
   `wokwi.toml` if you change it)
5. Open this folder in VS Code and run **Wokwi: Start Simulator**.

### Testing the WiFi/registration path without a phone

BLE provisioning can't be exercised in Wokwi (see the note below), but the
WiFi → HTTPS registration → EEPROM path can, against Wokwi's simulated
open network. Uncomment `#define SIM_WIFI_TEST` near the top of
`em_pro_v2_2button.ino` before compiling — this makes `setupNetworking()`
skip straight to `WiFi.begin("Wokwi-GUEST", "")` on first boot with no
stored credentials, bypassing the 45s BLE window entirely. Remember to
comment it back out before flashing real hardware.

With `SIM_WIFI_TEST` enabled, the whole chain is actually testable in
Wokwi end to end: WiFi connects → registers against the real
`api.fourfoldsystem.com` backend → 2 minutes after boot, publishes a real
telemetry message to the real MQTT broker (`65.20.84.166:1883`) — Wokwi's
simulated network has genuine internet access, so this isn't mocked.

## Alternative: wokwi.com web editor

Quicker to start, no local install — but free-tier projects on wokwi.com
are public (anyone with the link can view/fork them), which may not suit
firmware for a real product. Use this only if that's acceptable to you.

1. Go to [wokwi.com](https://wokwi.com), create a new **ESP32** project.
2. Replace the generated `sketch.ino` with the contents of
   `em_pro_v2_2button.ino`.
3. Open the "diagram.json" tab and replace its contents with this folder's
   `diagram.json`.
4. Add the `Keypad`, `ArduinoJson`, and `PubSubClient` libraries via the
   Library Manager tab's search + **+** button (or this folder's
   `libraries.txt`).
5. Also create `TM1637Display.h` and `TM1637Display.cpp` as new files in the
   project (paste in the contents of this folder's copies) — this sidesteps
   the display library entirely rather than searching for it, since it's
   registered upstream as `TM1637`, not `TM1637Display`.
6. Press the green ▶ Simulate button.

## What's wired up

| Sketch pin | Simulated as |
|---|---|
| `PIN_DISPLAY_CLK`/`DIO` (18/19) | TM1637 4-digit display |
| Keypad rows 5, 16, 17 / cols 26, 21 | 6 pushbuttons bridging row↔col, one per key (`1`,`2`,`5`,`6`,`7`,`8`) |
| `PIN_CURRENT_ADC` (33) | Potentiometer — stands in for the current sense signal |
| `PIN_VOLTAGE_ADC` (32) | Potentiometer — stands in for the voltage sense signal |
| `PIN_RELAY_MAIN` (4) | LED — lights when the main contactor would energize |
| `PIN_RELAY_SOFT` (23) | LED — lights during the soft-start window after turn-on |

Note board pin naming: on the `wokwi-esp32-devkit-v1` part, GPIO16/17 are
labeled `RX2`/`TX2` (not `D16`/`D17`) — already accounted for in
`diagram.json`.

## Button → key mapping

| Physical button in the diagram | Key char | Function |
|---|---|---|
| `btn_next`   | `'1'` | `BTN_NEXT` — move cursor / next screen |
| `btn_up`     | `'2'` | `BTN_UP` — increment digit (auto-repeats while held) |
| `btn_ocview` | `'5'` | `BTN_OC_VIEW` — view OC threshold; long-press enters settings |
| `btn_ucview` | `'6'` | `BTN_UC_VIEW` — view UC threshold; long-press enters settings |
| `btn_off`    | `'7'` | `BTN_OFF` |
| `btn_on`     | `'8'` | `BTN_ON` |

## Exercising the fault logic

Defaults are `OC = 30`, `UC = 20` (in the firmware's scaled current units).
`Show_Current()` maps the raw ADC reading through a piecewise curve, so as a
rough guide with `pot_current` on `D33`:

- **Left at minimum (0V → `res = 0`)**: after turn-on and the soft-start
  grace period, this reads as undercurrent/dry-run — a good way to trigger
  `BTN_UC_FAULT` without touching anything.
- **~10% of the pot's travel** (roughly 0.35V, ADC ≈ 440) crosses `res ≈ 30`
  and should trigger `BTN_OC_FAULT` after the recheck window.
- Somewhere between those two points keeps `res` inside `UC..OC` and the
  relay stays on indefinitely.

Turn the pot slowly — the fault recheck logic (1.8–4.5s) waits for a
sustained reading before tripping, so a single fast sweep through the
threshold may not trip it (this is the debounce behavior described in
[README.md](README.md)).

To exercise settings/calibration, hold `btn_ocview` or `btn_ucview` while
off; note the known bug in [README.md](README.md) where the settings menu
can become permanently inaccessible after the pump has shown any non-zero
current — reset the simulation (or fix that gate) if you hit it.

## Heads-up: the status-screen glyph codes may not render as intended

While tracking down the `TM1637`/`TM1637Display` naming issue, I read the
actual upstream `TM1637Display::encodeDigit()` (avishorp/TM1637 v1.2.0, the
release the Arduino index installs):

```cpp
uint8_t TM1637Display::encodeDigit(uint8_t digit) {
    return digitToSegment[digit & 0x0f];
}
```

It masks the input with `& 0x0f` against a 16-entry table (`0`-`9`, `A`-`F`
only). This sketch calls `encodeDigit()`/`print()`/`blink_print()` with
values like `20`, `25`, `26`, `29`, `31`, `38`, `42`, `48`, `52` — e.g. the
comment at [em_pro_v2_2button.ino:673](em_pro_v2_2button.ino#L673) says
`20 = blank glyph`. With the stock library, `20 & 0x0f == 4`, so that call
actually renders digit `4`, not blank — and the other codes wrap the same
way, landing on arbitrary hex digits rather than the intended
letters/blank.

If the real hardware currently uses this same stock library, the fault and
calibration screens are almost certainly showing wrapped hex digits instead
of the intended message — worth checking on real hardware. If they display
correctly on real hardware, the production build must be linking against a
different/patched `TM1637Display.h` with an extended glyph table that isn't
present anywhere in this repo, and the simulation (using the stock library)
will show those screens differently than real hardware until that variant
is tracked down and used instead.
