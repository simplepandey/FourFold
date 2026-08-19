// Final code 

//----------Include----------------
  #include "Keypad.h"
  #include <Arduino.h>
  #include <TM1637Display.h>
  #include <EEPROM.h>
  #include <esp_task_wdt.h>
  #include <string.h>
  #include <math.h>
  #include <WiFi.h>
  #include <WiFiClientSecure.h>
  #include <HTTPClient.h>
  #include <ArduinoJson.h>
  #include <BLEDevice.h>
  #include <BLEServer.h>
  #include <BLEUtils.h>
  #include <BLE2902.h>
  #include <PubSubClient.h>
//---------------------------------

//----------Definations------------
  #define PIN_DISPLAY_CLK   18
  #define PIN_DISPLAY_DIO   19

  #define PIN_RELAY_MAIN    4
  #define PIN_RELAY_SOFT    23

  #define PIN_CURRENT_ADC   33
  #define PIN_VOLTAGE_ADC   32

  #define KEYPAD_DEBOUNCE_MS       100
  #define INCREMENT_REPEAT_MS      300
  #define DISPLAY_REFRESH_MS       10
  #define BLINK_INTERVAL_MS        500
  #define SETTING_IDLE_TIMEOUT_MS  5000
  #define RELAY_SOFTSTART_TICKS    50
  #define FAULT_GRACE_TICKS        60
  #define OC_RECHECK_MS            1800
  #define UC_RECHECK_MS            1800
  #define UC_RECHECK_NO_LOAD_MS    4500
  #define CALIBRATION_WAIT_MS      3000
  #define CALIBRATION_STABLE_COUNT 5
  #define CALIBRATION_SAMPLE_MS    300
  #define CALIBRATION_TIMEOUT_MS   30000UL 

  #define WDT_TIMEOUT_S             8 

  #define OC_SAFE_DEFAULT   30
  #define UC_SAFE_DEFAULT   20

  #define EEPROM_SIZE 512
  #define EEPROM_CAL_ADDR 0
  #define EEPROM_NET_ADDR 16

  #define BTN_NEXT BTN_DIGIT1
  #define BTN_UP   BTN_DIGIT2

  // ---- WiFi / BLE provisioning ----
  #define BLE_PROVISION_TIMEOUT_MS  45000UL
  #define WIFI_CONNECT_TIMEOUT_MS   15000UL

  // Must match aqua_control's BLE WiFi provisioning service
  // (aqua_control/lib/core/services/ble_wifi_service.dart)
  #define BLE_SERVICE_UUID      "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
  #define BLE_SSID_CHAR_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a8"
  #define BLE_PASS_CHAR_UUID    "beb5483f-36e1-4688-b7f5-ea07361b26a9"
  #define BLE_STATUS_CHAR_UUID  "beb54840-36e1-4688-b7f5-ea07361b26aa"

  // ---- Backend device registration ----
  #define BACKEND_BASE_URL   "https://api.fourfoldsystem.com"
  #define BACKEND_AUTH_USER  "fourfold"
  #define BACKEND_AUTH_PASS  "fourfold"

  // ---- MQTT telemetry ----
  // Plain mqtt://, shared credentials - matches what the backend itself
  // connects with today (backend/.env, backend/README.md). Not the
  // TLS/per-device-credential setup described in vultr-emqx-complete-guide.md
  // - that isn't implemented on the backend side yet.
  #define MQTT_BROKER_HOST         "65.20.84.166"
  #define MQTT_BROKER_PORT         1883
  #define MQTT_USERNAME            "fourfold"
  #define MQTT_PASSWORD            "fourfold@2026"
  #define TELEMETRY_FIRST_SEND_MS  120000UL
  #define MQTT_RECONNECT_INTERVAL_MS 5000UL

  // Uncomment to skip BLE provisioning on boot and connect straight to
  // Wokwi's simulated open network, for bench-testing the WiFi/HTTP/EEPROM
  // path without a phone. Never enable this in a production build.
  // #define SIM_WIFI_TEST
  #ifdef SIM_WIFI_TEST
    #define SIM_WIFI_SSID "Wokwi-GUEST"
    #define SIM_WIFI_PASS ""
  #endif
//---------------------------------

//----------Variable---------------
  const byte KEYPAD_ROWS = 3;
  const byte KEYPAD_COLS = 2;
  byte rowPins[KEYPAD_ROWS] = {5, 16, 17};
  byte colPins[KEYPAD_COLS] = {26, 21};

  char keys[KEYPAD_ROWS][KEYPAD_COLS] = {
    {'2', '1'},
    {'5', '6'},
    {'7', '8'}
  };
  
  struct CalibrationData {
    uint16_t ocValue;
    uint16_t ucValue;
    uint16_t crc;
  };
  CalibrationData calib;

  struct NetworkData {
    char ssid[33];
    char password[65];
    char topicCommands[64];
    char topicTelemetry[64];
    char topicAlert[64];
    char topicHeartbeat[64];
    bool wifiValid;
    bool topicsValid;
    uint16_t crc;
  };
  NetworkData netData;

  BLECharacteristic* bleStatusChar = nullptr;
  volatile bool bleSsidReceived = false;
  volatile bool blePassReceived = false;
  volatile bool bleClientConnected = false;
  char bleSsidBuf[33];
  char blePassBuf[65];

  bool telemetrySent = false;

  // Persistent MQTT client - subscribed to the commands topic and reused
  // for telemetry/heartbeat publishes, instead of the old connect-per-publish
  // approach. Kept alive from loop() via maintainMqtt().
  WiFiClient mqttNetClient;
  PubSubClient mqttClient(mqttNetClient);
  unsigned long lastMqttReconnectAttempt = 0;

  enum ButtonCode {
    BTN_DIGIT1 = 1, BTN_DIGIT2 = 2, BTN_DIGIT3 = 3, BTN_DIGIT4 = 4,
    BTN_OC_VIEW = 5, BTN_UC_VIEW = 6,
    BTN_OFF = 7, BTN_ON = 8,
    BTN_HOLD_A = 10, BTN_SETTINGS = 11,
    BTN_OC_FAULT = 12, BTN_UC_FAULT = 13
  };

  TM1637Display Display(PIN_DISPLAY_CLK, PIN_DISPLAY_DIO);
  Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, KEYPAD_ROWS, KEYPAD_COLS);

  int button_num = BTN_OFF;
  int PBN = BTN_OFF;
  int Set_mode = 0;

  int D1, D2, D3, D4;

  int OC = OC_SAFE_DEFAULT; 
  int UC = UC_SAFE_DEFAULT; 
  int SC = 0; 

  uint8_t data[4];
  int M1 = 0, M2 = 0, l = 0;

  unsigned long lastIncrementTime = 0;
  unsigned long lastDisplayRefresh = 0;
  uint8_t lastD1 = 0, lastD2 = 0, lastD3 = 0, lastD4 = 0;

  int res = 0;
  int res3 = 0;
  // Sub-decigap-resolution current. res/OC/UC/calib.ocValue/calib.ucValue are
  // all real amps x10 internally (confirmed by the display: Show_Current()'s
  // print(D2, D3+10, D4, 25) ORs the decimal-point segment onto D3, rendering
  // res as "D2 D3.D4" i.e. res/10). resPrecise carries that same x10 scale
  // without the truncation res's int cast applies.
  float resPrecise = 0;

  // Event-driven telemetry tracking - see reportMotorState()/reportCurrentIfChanged().
  // Stored in true amps (not the internal x10 scale) since that's the unit
  // CURRENT_TELEMETRY_DELTA_A is expressed in, and what MQTT payloads use.
  int lastReportedMotorState = -1;       // -1 = not yet reported, 0 = off, 1 = on
  float lastReportedCurrentAmps = -1.0f; // negative = not yet reported (real current is never negative)
  unsigned long lastCurrentTelemetryMs = 0;
  #define CURRENT_TELEMETRY_DELTA_A         0.5f
  #define CURRENT_TELEMETRY_MIN_INTERVAL_MS 2000UL

  int  currentDigit       = 1; 
  bool digitBlinkVisible  = true;
  unsigned long lastDigitBlinkMs = 0;

  bool nextWasHeld = false;

  bool upWasHeld = false;
//---------------------------------

//----------Setup------------------
  void setup() {
    Serial.begin(115200);

    // Relay OFF as early as possible - fail-safe default before
    // anything else initialises.
    pinMode(PIN_RELAY_MAIN, OUTPUT);
    pinMode(PIN_RELAY_SOFT, OUTPUT);
    digitalWrite(PIN_RELAY_MAIN, LOW);
    digitalWrite(PIN_RELAY_SOFT, LOW);

    Display.setBrightness(0x0f);
    EEPROM.begin(EEPROM_SIZE);
    Data_read();

    pinMode(PIN_CURRENT_ADC, INPUT);
    pinMode(PIN_VOLTAGE_ADC, INPUT);

    // esp_task_wdt_init(uint32_t timeout_s, bool panic) - the older,
    // pre-ESP-IDF-5 signature (esp32 Arduino core <3.0, e.g. 2.0.7). The
    // esp_task_wdt_config_t struct-based overload only exists in core 3.x.
    esp_task_wdt_init(WDT_TIMEOUT_S, true);
    esp_task_wdt_add(NULL);

    setupNetworking();
  }
//---------------------------------

//----------loop-------------------
  void loop() {
    esp_task_wdt_reset();

    // One-shot telemetry publish, 2 minutes after boot. Cheap flag+time
    // check every cycle; the actual MQTT work only ever runs once.
    if (!telemetrySent && millis() >= TELEMETRY_FIRST_SEND_MS) {
      telemetrySent = true;
      sendTelemetry();
    }

    maintainMqtt();

    keypad.setDebounceTime(KEYPAD_DEBOUNCE_MS);
    precesskey();

    switch (button_num) {
      
      case BTN_NEXT: if (PBN != BTN_SETTINGS) button_num = PBN; break;
      case BTN_UP:   if (PBN != BTN_SETTINGS) button_num = PBN; break;

      case BTN_OC_VIEW: OC_value(); break;
      case BTN_UC_VIEW: UC_value(); break;

      case BTN_OFF: turn_off(); break;
      case BTN_ON:  turn_on();  break;

      case BTN_SETTINGS:
        if (Set_mode == 0) OC_setting();
        if (Set_mode == 1) UC_setting();
        break;

      case BTN_OC_FAULT: Show_OC_Error(); break;
      case BTN_UC_FAULT: Show_UC_Error(); break;
    }
  }
//---------------------------------

//----------Control Function-------
  void turn_off() {
    precesskey();
    Relay(0);
    print(20, 21, 22, 22);
    M1 = M2 = 0;
    PBN = BTN_OFF;
    reportMotorState(false);
  }

  void turn_on() {
    precesskey();
    Show_Current();
    Relay(1);
    M1 = M2 = 0;
    PBN = BTN_ON;
    reportMotorState(true);
    reportCurrentIfChanged();
    compare();
  }

  // Sends telemetry exactly once per motor on/off transition, not on every
  // loop() tick - turn_on()/turn_off() run every tick while in that state,
  // so without this dedupe they'd spam a telemetry publish every cycle.
  void reportMotorState(bool isOn) {
    int state = isOn ? 1 : 0;
    if (state == lastReportedMotorState) return;
    lastReportedMotorState = state;
    if (!isOn) lastReportedCurrentAmps = -1.0f; // fresh baseline for the next run
    sendTelemetry();
  }

  // Sends telemetry when load current has moved by CURRENT_TELEMETRY_DELTA_A
  // (0.5A) or more since the last report, rate-limited so noisy/fluctuating
  // current can't flood MQTT with a publish every ~25ms sample cycle.
  void reportCurrentIfChanged() {
    float trueAmps = resPrecise / 10.0f; // resPrecise is on the internal x10 scale
    if (fabs(trueAmps - lastReportedCurrentAmps) < CURRENT_TELEMETRY_DELTA_A) return;

    unsigned long now = millis();
    if (now - lastCurrentTelemetryMs < CURRENT_TELEMETRY_MIN_INTERVAL_MS) return;
    lastCurrentTelemetryMs = now;
    lastReportedCurrentAmps = trueAmps;
    sendTelemetry();
  }
//---------------------------------

//----------Relay------------------
  void Relay(int status) {
    switch (status) {
      case 0:
        digitalWrite(PIN_RELAY_MAIN, LOW);
        digitalWrite(PIN_RELAY_SOFT, LOW);
        l = 0;
        break;
      case 1:
        digitalWrite(PIN_RELAY_MAIN, HIGH);
        if (l < RELAY_SOFTSTART_TICKS) digitalWrite(PIN_RELAY_SOFT, HIGH);
        else                           digitalWrite(PIN_RELAY_SOFT, LOW);
        l++;
        break;
    }
  }
//---------------------------------

//----------Setting----------------
  void OC_setting() {
    PBN = BTN_SETTINGS;
    print(D1, D2, D3, D4);

    if (D1 == 0 && D2 == 0 && D3 == 0 && D4 == 0) {
      unsigned long lastKeyTime = millis();

      while (true) {
        print(D1, D2, D3, D4);
        precesskey();
        refreshDisplay();
        esp_task_wdt_reset();

        if (button_num != BTN_SETTINGS) lastKeyTime = millis();
        if (millis() - lastKeyTime > SETTING_IDLE_TIMEOUT_MS) { Data_read(); button_num = BTN_OFF; break; }
        if (button_num == BTN_OFF) break;

        // ---- OC threshold ----
        if (button_num == BTN_OC_VIEW) {
          uint8_t h, t, u;
          splitDigits3(calib.ocValue, h, t, u);
          D1 = h; D2 = t; D3 = u;
          lastKeyTime = millis();
          resetDigitEntry();

          while (true) {
            precesskey();
            refreshDisplay();
            esp_task_wdt_reset();

            if (button_num != BTN_SETTINGS) lastKeyTime = millis();
            if (millis() - lastKeyTime > SETTING_IDLE_TIMEOUT_MS) { Data_read(); button_num = BTN_OFF; break; }
            if (button_num == BTN_UC_VIEW || button_num == BTN_OFF) break;
            else if (button_num == BTN_NEXT || button_num == BTN_UP) handleDigitEntry(2, 3);
            printBlinkDigit(D1, D2 + 10, D3, 25, currentDigit);
          }

          // Single batched write on exit instead of one per keypress.
          uint16_t newOC = D1 * 100 + D2 * 10 + D3;
          if (newOC != calib.ocValue) {
            calib.ocValue = constrain(newOC, 0, 999);
            saveCalibration();
          }
          if (button_num == BTN_OFF) break;
        }

        // ---- UC threshold ----
        if (button_num == BTN_UC_VIEW) {
          uint8_t h, t, u;
          splitDigits3(calib.ucValue, h, t, u);
          D1 = h; D2 = t; D3 = u;
          lastKeyTime = millis();
          resetDigitEntry();

          while (true) {
            precesskey();
            refreshDisplay();
            esp_task_wdt_reset();

            if (button_num != BTN_SETTINGS) lastKeyTime = millis();
            if (millis() - lastKeyTime > SETTING_IDLE_TIMEOUT_MS) { Data_read(); button_num = BTN_OFF; break; }
            if (button_num == BTN_OC_VIEW || button_num == BTN_OFF) break;
            else if (button_num == BTN_NEXT || button_num == BTN_UP) handleDigitEntry(2, 3);
            printBlinkDigit(D1, D2 + 10, D3, 25, currentDigit);
          }

          uint16_t newUC = D1 * 100 + D2 * 10 + D3;
          if (newUC != calib.ucValue) {
            calib.ucValue = constrain(newUC, 0, 999);
            saveCalibration();
          }
          if (button_num == BTN_OFF) break;
        }
      }
      Data_read(); // refresh OC/UC actives from whatever was just saved
    }
  }

  void UC_setting() {

    PBN = BTN_SETTINGS;
    digitalWrite(PIN_RELAY_MAIN, HIGH);

    unsigned long startWait = millis();
    while (millis() - startWait < CALIBRATION_WAIT_MS) {
      precesskey();
      refreshDisplay();
      esp_task_wdt_reset();
      if (button_num == BTN_OFF) return;
    }

    float previousRes = 0;
    int stableCount = 0;
    unsigned long lastSample = 0;
    unsigned long calibStart = millis();
    bool timedOut = false;

    while (stableCount < CALIBRATION_STABLE_COUNT) {
      precesskey();
      refreshDisplay();
      esp_task_wdt_reset();
      if (button_num == BTN_OFF) return;

      if (millis() - calibStart > CALIBRATION_TIMEOUT_MS) {
        timedOut = true;
        break;
      }

      if (millis() - lastSample >= CALIBRATION_SAMPLE_MS) {
        lastSample = millis();
        Show_Current();
        float currentRes = res;

        if (abs(currentRes - previousRes) < 2.0) stableCount++;
        else                                     stableCount = 0;

        previousRes = currentRes;
      }
    }

    if (timedOut) {
      Relay(0);
      print(29, 38, 55, 20);
      delay(1500);
      button_num = BTN_OFF;
      return;
    }

    float stableRes = previousRes;
    int oc = constrain((int)(stableRes + 20), 0, 999);
    int uc = (stableRes != 0) ? constrain((int)(stableRes - 15), 0, 999) : 0;

    calib.ocValue = oc;
    calib.ucValue = uc;
    saveCalibration();

    OC = oc;
    UC = uc;
    Relay(0);
    Data_read();

    uint8_t ocH, ocT, ocU, ucH, ucT, ucU;
    splitDigits3(oc, ocH, ocT, ocU);
    splitDigits3(uc, ucH, ucT, ucU);

    struct { uint8_t a, b, c, d; unsigned long duration; } sequence[] = {
      {52, 26, 29, 28, 2000},
      {20, 39, 42, 20, 2000},
      {ocH, (uint8_t)(ocT + 10), ocU, 25, 2000},
      {20, 48, 42, 20, 2000},
      {ucH, (uint8_t)(ucT + 10), ucU, 25, 2000},
    };

    for (auto &s : sequence) {
      print(s.a, s.b, s.c, s.d);
      unsigned long t = millis();
      while (millis() - t < s.duration) {
        precesskey();
        refreshDisplay();
        esp_task_wdt_reset();
        if (button_num == BTN_OFF) return;
      }
    }

    button_num = BTN_OFF;
  }
//---------------------------------

//----------Compare----------------
  void compare() {
    if (l <= FAULT_GRACE_TICKS) return; // still in soft-start grace period

    if (res > OC) {
      unsigned long waitStart = millis();
      while (millis() - waitStart < OC_RECHECK_MS) {
        Show_Current();
        precesskey();
        refreshDisplay();
        esp_task_wdt_reset();
      }
      if (res > OC) {
        Relay(0);
        delay(20);
        button_num = BTN_OC_FAULT;
        sendAlert(true, false);
        reportMotorState(false); // relay tripped outside turn_off(), so report it here
      }
    } else if (res < UC) {
      unsigned long waitTime = (res == 0) ? UC_RECHECK_NO_LOAD_MS : UC_RECHECK_MS;
      unsigned long waitStart = millis();
      while (millis() - waitStart < waitTime) {
        Show_Current();
        precesskey();
        refreshDisplay();
        esp_task_wdt_reset();
      }
      if (res < UC) {
        Relay(0);
        delay(20);
        button_num = BTN_UC_FAULT;
        sendAlert(false, true);
        reportMotorState(false);
      }
    }
  }
//---------------------------------

//----------Show Functions---------
  // Overload (not a default arg - Arduino's auto-generated prototype would
  // duplicate a default value onto both the prototype and the definition,
  // which G++ rejects as a redefinition) so existing no-arg call sites are
  // untouched.
  void Show_Current() { Show_Current(true); }

  // updateDisplay=false lets background sampling (telemetry/heartbeat) read
  // a fresh current value without flickering the display over whatever
  // screen is currently showing - see sampleElectricalReadings().
  void Show_Current(bool updateDisplay) {
    static unsigned long lastSampleTime = 0;
    static long sum = 0;
    static int sampleCount = 0;

    if (millis() - lastSampleTime >= 5) {
      lastSampleTime = millis();
      sum += analogRead(PIN_CURRENT_ADC);
      sampleCount++;
    }

    if (sampleCount >= 5) {
      int averaged_value = sum / sampleCount;
      sum = 0;
      sampleCount = 0;

      // Piecewise scaling to real-world current. Gap between 660-750
      // in v1.0 fell through with no match, leaving res stale - fixed
      // by covering the full range explicitly.
      float scaled;
          if (averaged_value <= 45)                             scaled = averaged_value * 0.30;
      else if (averaged_value <= 120)                             scaled = averaged_value * 0.16;
      else if (averaged_value <= 230)                             scaled = averaged_value * 0.10;
      else if (averaged_value <= 390)                             scaled = averaged_value * 0.076;
      else if (averaged_value <= 510)                             scaled = averaged_value * 0.068;
      else if (averaged_value <= 660)                             scaled = averaged_value * 0.06;
      else if (averaged_value <= 750)                             scaled = averaged_value * 0.058; // fills the gap
      else if (averaged_value <= 1300)                            scaled = averaged_value * 0.054;
      else if (averaged_value <= 2750)                            scaled = averaged_value * 0.048;
      else                                                        scaled = averaged_value * 0.05;

      resPrecise = scaled;
      res = (int)scaled;

      D1 = res / 1000 % 10;
      D2 = res / 100  % 10;
      D3 = res / 10   % 10;
      D4 = res        % 10;

      SC = (res >= 200) ? 1 : 0;
    }

    if (updateDisplay) print(D2, D3 + 10, D4, 25);
  }

  void Show_Voltage(int show) {
    static unsigned long lastSampleTime = 0;
    static long sum = 0;
    static int sampleCount = 0;

    if (millis() - lastSampleTime >= 5) {
      lastSampleTime = millis();
      sum += analogRead(PIN_VOLTAGE_ADC);
      sampleCount++;
    }

    if (sampleCount >= 5) {
      int averaged_value = sum / sampleCount;
      sum = 0;
      sampleCount = 0;

      if (averaged_value > 4000) averaged_value = 4095; // clamp ADC ceiling

      res3 = averaged_value * 0.056;

      D1 = res3 / 1000 % 10;
      D2 = res3 / 100  % 10;
      D3 = res3 / 10   % 10;
      D4 = res3        % 10;
    }

    if (show == 1) print(20, D2, D3, D4);
  }

  void OC_value() {
    if (button_num != BTN_SETTINGS) {
      if (M2 >= 100) {
        D1 = D2 = D3 = D4 = 0;
        print(D1, D2, D3, D4);
        Set_mode = 0;
        button_num = BTN_SETTINGS;
      } else if (M1 <= 50) {
        uint8_t h, t, u;
        splitDigits3(calib.ocValue, h, t, u);
        print(h, t + 10, u, 25);
      } else {
        button_num = PBN;
      }
      M1++;
    }
  }

  void UC_value() {
    if (button_num != BTN_SETTINGS) {
      if (M2 >= 100) {
        print(25, 30, 28, 21);
        Set_mode = 1;
        button_num = BTN_SETTINGS;
      } else if (M1 <= 50) {
        uint8_t h, t, u;
        splitDigits3(calib.ucValue, h, t, u);
        print(h, t + 10, u, 25);
      } else {
        button_num = PBN;
      }
      M1++;
    }
  }
//---------------------------------

//----------Errors-----------------
  void Show_OC_Error() {
    Relay(0);
    PBN = BTN_OC_FAULT;
    button_num = BTN_OC_FAULT;

    if (SC == 0) blink_print(31, 0,  24, 31);
    if (SC == 1) blink_print(31, 26, 24, 31);

    precesskey();
  }

  void Show_UC_Error() {
    Relay(0);
    PBN = BTN_UC_FAULT;
    button_num = BTN_UC_FAULT;

    blink_print(31, 30, 24, 31);
    precesskey();
  }
//---------------------------------

//----------Keypad-----------------
  void precesskey() {
    keypad.getKey(); // refresh internal state

    for (byte r = 0; r < KEYPAD_ROWS; r++) {
      for (byte c = 0; c < KEYPAD_COLS; c++) {
        KeyState state = keypad.key[r * KEYPAD_COLS + c].kstate;
        char d = keypad.key[r * KEYPAD_COLS + c].kchar;

        bool isNextKey = (d == '1');
        bool isUpKey   = (d == '2');

        // ---- NEXT: fire on the PRESSED edge only. This is the fix for
        //      the old auto-repeat bug - HOLD stays true every scan while
        //      the button is down, so treating HOLD as a trigger fires
        //      continuously. We now explicitly track the previous state
        //      and only act on the transition into PRESSED. ----
        if (isNextKey) {
          bool rawHeld = (state == PRESSED || state == HOLD);
          if (state == PRESSED && !nextWasHeld) {
            button_num = BTN_NEXT;
          }
          nextWasHeld = rawHeld;
        }

        // ---- UP: allowed to auto-repeat while held, but gated by
        //      INCREMENT_REPEAT_MS so it doesn't spam every scan. ----
        if (isUpKey) {
          bool rawHeld = (state == PRESSED || state == HOLD);
          if (rawHeld) {
            unsigned long now = millis();
            if (!upWasHeld) {
              upWasHeld = true;
              lastIncrementTime = now;
              button_num = BTN_UP;
            } else if (now - lastIncrementTime >= INCREMENT_REPEAT_MS) {
              lastIncrementTime = now;
              button_num = BTN_UP;
            }
          } else {
            upWasHeld = false;
          }
        }

        if (d >= '5' && d <= '8') {
          if (state == PRESSED || state == HOLD) {
            button_num = d - '0';
            if (state == PRESSED && button_num == BTN_OC_VIEW) { M2++; M1 = 0; }
            if (state == HOLD && (button_num == BTN_OC_VIEW || button_num == BTN_UC_VIEW)) { M2++; M1 = 0; }
          }
        }
      }
    }
  }
  
//---------------------------------

//----------Display----------------
  void print(uint8_t d1, uint8_t d2, uint8_t d3, uint8_t d4) {
    lastD1 = d1; lastD2 = d2; lastD3 = d3; lastD4 = d4;

    unsigned long now = millis();
    if (now - lastDisplayRefresh < DISPLAY_REFRESH_MS) return;
    lastDisplayRefresh = now;

    data[0] = Display.encodeDigit(d1);
    data[1] = Display.encodeDigit(d2);
    data[2] = Display.encodeDigit(d3);
    data[3] = Display.encodeDigit(d4);
    Display.setSegments(data);
  }

  void blink_print(uint8_t d1, uint8_t d2, uint8_t d3, uint8_t d4) {
    static unsigned long previousMillis = 0;
    static bool visible = true;

    unsigned long now = millis();
    if (now - previousMillis >= BLINK_INTERVAL_MS) {
      previousMillis = now;
      visible = !visible;
    }

    if (visible) {
      data[0] = Display.encodeDigit(d1);
      data[1] = Display.encodeDigit(d2);
      data[2] = Display.encodeDigit(d3);
      data[3] = Display.encodeDigit(d4);
    } else {
      for (int i = 0; i < 4; i++) data[i] = Display.encodeDigit(20);
    }

    Display.setSegments(data);
  }

  void refreshDisplay() {
    unsigned long now = millis();
    if (now - lastDisplayRefresh < DISPLAY_REFRESH_MS) return;
    lastDisplayRefresh = now;

    data[0] = Display.encodeDigit(lastD1);
    data[1] = Display.encodeDigit(lastD2);
    data[2] = Display.encodeDigit(lastD3);
    data[3] = Display.encodeDigit(lastD4);
    Display.setSegments(data);
  }

  void resetDigitEntry() {
    currentDigit = 1;
    digitBlinkVisible = true;
    lastDigitBlinkMs = millis();
  }

  void handleDigitEntry(int maxDigit1, int numDigits) {
    if (button_num == BTN_NEXT) {
      currentDigit++;
      if (currentDigit > numDigits) currentDigit = 1;
      digitBlinkVisible = true;
      lastDigitBlinkMs  = millis();
    } else if (button_num == BTN_UP) {
      switch (currentDigit) {
        case 1: D1++; if (D1 >= maxDigit1) D1 = 0; break;
        case 2: D2++; if (D2 >= 10)        D2 = 0; break;
        case 3: D3++; if (D3 >= 10)        D3 = 0; break;
        case 4: D4++; if (D4 >= 10)        D4 = 0; break;
      }
    }

    button_num = BTN_SETTINGS; // stay in the settings screen after handling
  }

  void printBlinkDigit(uint8_t d1, uint8_t d2, uint8_t d3, uint8_t d4, int cursorPos) {
    unsigned long now = millis();
    if (now - lastDigitBlinkMs >= BLINK_INTERVAL_MS) {
      lastDigitBlinkMs = now;
      digitBlinkVisible = !digitBlinkVisible;
    }

    uint8_t vals[4] = {d1, d2, d3, d4};
    uint8_t out[4];
    for (int i = 0; i < 4; i++) {
      bool selected = (cursorPos != 0) && (i == cursorPos - 1);
      out[i] = (selected && !digitBlinkVisible) ? 20 : vals[i]; // 20 = blank glyph
    }
    lastD1 = out[0]; lastD2 = out[1]; lastD3 = out[2]; lastD4 = out[3];

    if (now - lastDisplayRefresh < DISPLAY_REFRESH_MS) return;
    lastDisplayRefresh = now;

    data[0] = Display.encodeDigit(out[0]);
    data[1] = Display.encodeDigit(out[1]);
    data[2] = Display.encodeDigit(out[2]);
    data[3] = Display.encodeDigit(out[3]);
    Display.setSegments(data);
  }
//---------------------------------

//----------Other-------------------
  uint16_t crc16(const uint8_t *data, size_t len) {
    uint16_t crc = 0xFFFF;
    for (size_t i = 0; i < len; i++) {
      crc ^= data[i];
      for (uint8_t b = 0; b < 8; b++) {
        if (crc & 1) crc = (crc >> 1) ^ 0xA001;
        else         crc >>= 1;
      }
    }
    return crc;
  }

  void splitDigits3(uint16_t value, uint8_t &h, uint8_t &t, uint8_t &u) {
    value = constrain(value, 0, 999);
    h = (value / 100) % 10;
    t = (value / 10)  % 10;
    u =  value        % 10;
  }

  bool loadCalibration() {
    EEPROM.get(EEPROM_CAL_ADDR, calib);
    uint16_t expected = crc16((uint8_t*)&calib, sizeof(calib) - sizeof(calib.crc));
    if (calib.crc != expected || calib.ocValue > 999 || calib.ucValue > 999) {
      return false; // corrupt or never written
    }
    return true;
  }

  void saveCalibration() {
    calib.crc = crc16((uint8_t*)&calib, sizeof(calib) - sizeof(calib.crc));
    EEPROM.put(EEPROM_CAL_ADDR, calib);
    EEPROM.commit();
  }

  void Data_read() {
    if (!loadCalibration()) {
      calib.ocValue = OC_SAFE_DEFAULT;
      calib.ucValue = UC_SAFE_DEFAULT;
      saveCalibration();   // self-heal so next boot is valid too
    }
    OC = calib.ocValue;
    UC = calib.ucValue;
  }
//----------------------------------

//----------Networking--------------
  // Derived from the efuse MAC, not stored - stable across reboots without
  // needing its own EEPROM slot.
  String getDeviceSerial() {
    uint64_t mac = ESP.getEfuseMac();
    char buf[13];
    snprintf(buf, sizeof(buf), "%012llX", mac);
    return "SR" + String(buf);
  }

  bool loadNetworkData() {
    EEPROM.get(EEPROM_NET_ADDR, netData);
    uint16_t expected = crc16((uint8_t*)&netData, sizeof(netData) - sizeof(netData.crc));
    if (netData.crc != expected) {
      memset(&netData, 0, sizeof(netData));
      return false; // no valid stored network config yet
    }
    return true;
  }

  void saveNetworkData() {
    netData.crc = crc16((uint8_t*)&netData, sizeof(netData) - sizeof(netData.crc));
    EEPROM.put(EEPROM_NET_ADDR, netData);
    EEPROM.commit();
  }

  bool connectToWifi(const char* ssid, const char* pass, unsigned long timeoutMs) {
    if (ssid == nullptr || ssid[0] == '\0') return false;

    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, pass);

    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
      esp_task_wdt_reset();
      delay(200);
    }
    return WiFi.status() == WL_CONNECTED;
  }

  void bleNotifyStatus(const char* msg) {
    if (bleStatusChar == nullptr) return;
    bleStatusChar->setValue(msg);
    bleStatusChar->notify();
  }

  class BleSsidCallback : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* c) override {
      strlcpy(bleSsidBuf, c->getValue().c_str(), sizeof(bleSsidBuf));
      bleSsidReceived = true;
    }
  };

  class BlePassCallback : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* c) override {
      strlcpy(blePassBuf, c->getValue().c_str(), sizeof(blePassBuf));
      blePassReceived = true;
    }
  };

  // Tracks whether a phone is currently connected to the GATT server, so
  // runBleProvisioning() can tell "nobody's connected yet" (keep waiting)
  // apart from "was connected, now isn't" (the phone gave up - stop).
  class BleServerConnectionCallback : public BLEServerCallbacks {
    void onConnect(BLEServer* server) override { bleClientConnected = true; }
    void onDisconnect(BLEServer* server) override { bleClientConnected = false; }
  };

  // Advertises the BLE GATT service aqua_control's WiFi provisioning flow
  // expects, and retries WiFi connection attempts as credentials arrive,
  // all within a single timeoutMs budget. ESP32 supports WiFi/BLE running
  // concurrently (the radio is time-shared via ESP-IDF's coexistence
  // support - the same pattern Espressif's own BLE provisioning example
  // uses), so BLE is left connected through each connectToWifi() attempt:
  // the phone hears "connecting...", then "connected"/"failed" over the
  // same session, and on failure can just write a new SSID/password
  // without reconnecting. Returns true (with netData.ssid/password/
  // wifiValid already saved) only once a connectToWifi() attempt actually
  // succeeds; false if the budget runs out or the phone disconnects
  // without ever succeeding.
  bool runBleProvisioning(unsigned long timeoutMs) {
    bleSsidReceived = false;
    blePassReceived = false;
    bleClientConnected = false;
    memset(bleSsidBuf, 0, sizeof(bleSsidBuf));
    memset(blePassBuf, 0, sizeof(blePassBuf));

    String serial = getDeviceSerial();
    String bleName = "fourfold-bluetooth";
    BLEDevice::init(bleName.c_str());

    BLEServer* server = BLEDevice::createServer();
    server->setCallbacks(new BleServerConnectionCallback());
    BLEService* service = server->createService(BLE_SERVICE_UUID);

    BLECharacteristic* ssidChar = service->createCharacteristic(
      BLE_SSID_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE);
    ssidChar->setCallbacks(new BleSsidCallback());

    BLECharacteristic* passChar = service->createCharacteristic(
      BLE_PASS_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE);
    passChar->setCallbacks(new BlePassCallback());

    bleStatusChar = service->createCharacteristic(
      BLE_STATUS_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY);
    bleStatusChar->addDescriptor(new BLE2902());

    service->start();
    BLEAdvertising* advertising = BLEDevice::getAdvertising();
    advertising->addServiceUUID(BLE_SERVICE_UUID);
    advertising->setScanResponse(true);
    BLEDevice::startAdvertising();

    unsigned long deadline = millis() + timeoutMs;
    bool everConnected = false;
    bool wifiUp = false;

    while ((long)(deadline - millis()) > 0) {
      esp_task_wdt_reset();

      if (bleClientConnected) everConnected = true;
      if (everConnected && !bleClientConnected) break; // phone disconnected without a successful attempt

      if (bleSsidReceived && blePassReceived) {
        strlcpy(netData.ssid, bleSsidBuf, sizeof(netData.ssid));
        strlcpy(netData.password, blePassBuf, sizeof(netData.password));
        bleNotifyStatus("Credentials received, connecting to WiFi...");

        long remainingMs = (long)(deadline - millis());
        unsigned long attemptTimeout = min((unsigned long)WIFI_CONNECT_TIMEOUT_MS,
                                            (unsigned long)max(remainingMs, 0L));
        wifiUp = connectToWifi(netData.ssid, netData.password, attemptTimeout);

        if (wifiUp) {
          netData.wifiValid = true;
          saveNetworkData();
          bleNotifyStatus("WiFi connected successfully!");
          delay(300); // let the notification go out before tearing down BLE
          break;
        }

        bleNotifyStatus("WiFi connection failed. Check the password and try again.");
        WiFi.disconnect(true); // release the STA attempt before the next retry
        bleSsidReceived = false;
        blePassReceived = false;
        memset(bleSsidBuf, 0, sizeof(bleSsidBuf));
        memset(blePassBuf, 0, sizeof(blePassBuf));
      }

      delay(50);
    }

    return wifiUp;
  }

  // Frees the BLE radio/stack once provisioning is done (success, timeout,
  // or the phone disconnected) - always call this after runBleProvisioning()
  // returns.
  void stopBleProvisioning() {
    BLEDevice::stopAdvertising();
    bleStatusChar = nullptr;
    BLEDevice::deinit(true);
  }

  // POSTs to the backend registration endpoint and stores the returned MQTT
  // topics into netData on success. Idempotent - safe to call on every boot.
  bool registerDeviceWithBackend() {
    String url = String(BACKEND_BASE_URL) + "/api/v1/device/register/" +
                 getDeviceSerial() + "?type=esp32";

    WiFiClientSecure client;
    client.setInsecure(); // no CA pinned - see esp32/README.md security note

    HTTPClient http;
    if (!http.begin(client, url)) return false;

    http.setAuthorization(BACKEND_AUTH_USER, BACKEND_AUTH_PASS);
    http.addHeader("accept", "application/json");
    int httpCode = http.POST("");

    bool ok = false;
    if (httpCode == 200 || httpCode == 201) {
      JsonDocument doc; // requires ArduinoJson v7+
      if (deserializeJson(doc, http.getString()) == DeserializationError::Ok &&
          doc["success"] == true) {
        JsonObject topics = doc["data"]["topics"].as<JsonObject>();
        strlcpy(netData.topicCommands,  topics["commands"]  | "", sizeof(netData.topicCommands));
        strlcpy(netData.topicTelemetry, topics["telemetry"] | "", sizeof(netData.topicTelemetry));
        strlcpy(netData.topicAlert,     topics["alert"]     | "", sizeof(netData.topicAlert));
        strlcpy(netData.topicHeartbeat, topics["heartbeat"] | "", sizeof(netData.topicHeartbeat));
        netData.topicsValid = true;
        ok = true;
      }
    }

    http.end();
    return ok;
  }

  // Forces a handful of fresh current/voltage samples so res/res3 reflect
  // "now" rather than whatever stale value was last computed - relevant
  // because Show_Current()/Show_Voltage() only average once every 5+ calls.
  // Both calls pass updateDisplay=false so this background sampling never
  // touches the display - it must not flicker whatever screen is currently
  // showing (e.g. the OFF screen) just because telemetry/heartbeat fired.
  void sampleElectricalReadings() {
    for (int i = 0; i < 6; i++) {
      Show_Current(false);
      Show_Voltage(0);
      delay(6);
    }
  }

  // Publishes one telemetry snapshot over the persistent mqttClient
  // (connecting it first if needed). Still only fires once, 2 minutes
  // after boot (see loop()) - just no longer tears the connection back
  // down afterward, since mqttClient now stays alive for commands too.
  bool sendTelemetry() {
    if (WiFi.status() != WL_CONNECTED || !netData.topicsValid) return false;

    sampleElectricalReadings();

    // res/OC/UC are internally real-amps x10 (see resPrecise's comment) -
    // the backend/app expect true amps, so divide before sending. Voltage
    // (res3) has no such scaling - Show_Voltage() never sets the DP segment.
    JsonDocument doc;
    doc["v"] = res3;
    doc["i"] = res / 10.0;
    doc["oc"] = OC / 10.0;
    doc["uc"] = UC / 10.0;
    doc["motor"] = (digitalRead(PIN_RELAY_MAIN) == HIGH);
    doc["sn"] = getDeviceSerial();

    char payload[192];
    size_t len = serializeJson(doc, payload, sizeof(payload));

    esp_task_wdt_reset();
    ensureMqttConnected();
    if (!mqttClient.connected()) return false;

    bool ok = mqttClient.publish(netData.topicTelemetry, (const uint8_t*)payload, len);
    esp_task_wdt_reset();
    return ok;
  }

  // Keeps mqttClient connected and subscribed to the commands topic,
  // reconnecting at most once every MQTT_RECONNECT_INTERVAL_MS so an
  // unreachable broker doesn't turn into a connect() attempt (up to the
  // 3s socket timeout) on every single loop() tick.
  void ensureMqttConnected() {
    if (mqttClient.connected()) return;

    unsigned long now = millis();
    if (now - lastMqttReconnectAttempt < MQTT_RECONNECT_INTERVAL_MS) return;
    lastMqttReconnectAttempt = now;

    String clientId = "esp32-" + getDeviceSerial();
    esp_task_wdt_reset();
    if (mqttClient.connect(clientId.c_str(), MQTT_USERNAME, MQTT_PASSWORD)) {
      mqttClient.subscribe(netData.topicCommands);
    }
    esp_task_wdt_reset();
  }

  // Services the persistent MQTT connection (reconnect + incoming message
  // dispatch) every loop() tick. No-op until WiFi and topics are ready.
  void maintainMqtt() {
    if (WiFi.status() != WL_CONNECTED || !netData.topicsValid) return;
    ensureMqttConnected();
    mqttClient.loop();
  }

  // Replies to a SEND_HEARTBEAT command on the heartbeat topic, echoing
  // the request's cmd_id back under the key "id" - that's how the backend
  // (module-status.service.ts) correlates the reply to its pending request.
  void sendHeartbeatReply(const char* cmdId) {
    sampleElectricalReadings();

    // Same x10 -> true-amp conversion as sendTelemetry() - see its comment.
    JsonDocument doc;
    doc["id"] = cmdId;
    doc["v"] = res3;
    doc["i"] = res / 10.0;
    doc["oc"] = OC / 10.0;
    doc["uc"] = UC / 10.0;

    char payload[192];
    size_t len = serializeJson(doc, payload, sizeof(payload));
    mqttClient.publish(netData.topicHeartbeat, (const uint8_t*)payload, len);
  }

  // Publishes an OC/UC breach notice on the alert topic. Matches
  // telemetry.service.ts's processAlert(): the value's presence (not its
  // magnitude) is what flags overcurrent_breached/undercurrent_breached, so
  // any non-null number works - the last current reading is the most useful
  // one to include. Motor state itself is reported separately via the
  // reportMotorState(false) telemetry publish the caller also triggers.
  void sendAlert(bool ocBreached, bool ucBreached) {
    if (WiFi.status() != WL_CONNECTED || !netData.topicsValid) return;

    float trueAmps = res / 10.0; // same x10 -> true-amp conversion as sendTelemetry()
    JsonDocument doc;
    if (ocBreached) doc["overcurrent_breached"] = trueAmps;
    if (ucBreached) doc["undercurrent_breached"] = trueAmps;

    char payload[128];
    size_t len = serializeJson(doc, payload, sizeof(payload));

    esp_task_wdt_reset();
    ensureMqttConnected();
    if (!mqttClient.connected()) return;
    mqttClient.publish(netData.topicAlert, (const uint8_t*)payload, len);
    esp_task_wdt_reset();
  }

  // Handles commands published by the backend on netData.topicCommands:
  // {"cmd":"TURN_ON"|"TURN_OFF"|"SET_OC"|"SET_UC"|"SEND_HEARTBEAT","value":<num|null>,"cmd_id":"<uuid>","ts":<unix>}
  void mqttCommandCallback(char* topic, byte* payload, unsigned int length) {
    char buf[192];
    size_t n = min((size_t)length, sizeof(buf) - 1);
    memcpy(buf, payload, n);
    buf[n] = '\0';

    JsonDocument doc;
    if (deserializeJson(doc, buf) != DeserializationError::Ok) return;

    const char* cmd = doc["cmd"] | "";
    const char* cmdId = doc["cmd_id"] | "";

    if (strcmp(cmd, "TURN_ON") == 0) {
      button_num = BTN_ON;
    } else if (strcmp(cmd, "TURN_OFF") == 0) {
      button_num = BTN_OFF;
    } else if (strcmp(cmd, "SET_OC") == 0 && !doc["value"].isNull()) {
      // Backend/app send true amps (e.g. 8.5) - the device stores/compares
      // real-amps x10 internally (see resPrecise's comment), so convert
      // and round rather than truncate: 8.5A -> 85, not 8 (which would
      // display/trip as 0.8A).
      calib.ocValue = constrain((int)round((float)doc["value"] * 10.0f), 0, 999);
      saveCalibration();
      OC = calib.ocValue;
    } else if (strcmp(cmd, "SET_UC") == 0 && !doc["value"].isNull()) {
      calib.ucValue = constrain((int)round((float)doc["value"] * 10.0f), 0, 999);
      saveCalibration();
      UC = calib.ucValue;
    } else if (strcmp(cmd, "SEND_HEARTBEAT") == 0) {
      sendHeartbeatReply(cmdId);
    }
  }

  // Runs once at boot, after the watchdog is armed. Tries stored WiFi
  // credentials first; only falls back to BLE provisioning (45s window) if
  // there are none, or if the stored ones fail to connect. If BLE
  // provisioning doesn't yield a connection either, this just returns with
  // no network - the rest of the firmware behaves exactly as it did before
  // this feature existed, since motor protection never depends on network
  // state.
  void setupNetworking() {
    loadNetworkData();

    mqttClient.setServer(MQTT_BROKER_HOST, MQTT_BROKER_PORT);
    mqttClient.setCallback(mqttCommandCallback);
    mqttClient.setSocketTimeout(3); // keep well under WDT_TIMEOUT_S

    #ifdef SIM_WIFI_TEST
      if (!netData.wifiValid) {
        strlcpy(netData.ssid, SIM_WIFI_SSID, sizeof(netData.ssid));
        strlcpy(netData.password, SIM_WIFI_PASS, sizeof(netData.password));
        netData.wifiValid = true;
      }
    #endif

    bool wifiUp = netData.wifiValid &&
                  connectToWifi(netData.ssid, netData.password, WIFI_CONNECT_TIMEOUT_MS);

    if (!wifiUp) {
      // Advertises, waits for credentials, and retries failed attempts
      // in-place (BLE stays connected throughout) until success, the
      // phone disconnects, or BLE_PROVISION_TIMEOUT_MS runs out - see
      // runBleProvisioning()'s comment. netData is already saved on success.
      wifiUp = runBleProvisioning(BLE_PROVISION_TIMEOUT_MS);
      stopBleProvisioning();
    }

    if (wifiUp && registerDeviceWithBackend()) {
      saveNetworkData();
    }
  }
//----------------------------------
