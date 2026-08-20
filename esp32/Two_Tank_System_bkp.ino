// Final code 

//----------Include----------------
  #include "Keypad.h"
  #include <Arduino.h>
  #include <TM1637Display.h>
  #include <EEPROM.h>
  #include <esp_task_wdt.h>
//---------------------------------

//----------Definations------------
  #define PIN_DISPLAY_CLK   18
  #define PIN_DISPLAY_DIO   19

  #define PIN_RELAY_MAIN    25
  #define PIN_RELAY_SOFT    27

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

  #define EEPROM_SIZE 200
  #define EEPROM_CAL_ADDR 0

  #define BTN_NEXT BTN_DIGIT1
  #define BTN_UP   BTN_DIGIT2
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
  enum ButtonCode {
    BTN_DIGIT1 = 1, BTN_DIGIT2 = 2, BTN_DIGIT3 = 3, BTN_DIGIT4 = 4,
    BTN_OC_VIEW = 5, BTN_UC_VIEW = 6,
    BTN_OFF = 7, BTN_ON = 8,
    BTN_HOLD_A = 10, BTN_SETTINGS = 11,
    BTN_OC_FAULT = 12, BTN_UC_FAULT = 13
  };

  TM1637Display Display(PIN_DISPLAY_CLK, PIN_DISPLAY_DIO);
  Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, KEYPAD_ROWS, KEYPAD_COLS);

  int button_num;
  int PBN;
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

  int  currentDigit       = 1; 
  bool digitBlinkVisible  = true;
  unsigned long lastDigitBlinkMs = 0;

  bool nextWasHeld = false;

  bool upWasHeld = false;

  bool UF_Flag = 0;
  bool LF_Flag = 0;
  bool UE_Flag = 0;
  bool LE_Flag = 0;
  bool prevUF, prevUE, prevLF, prevLE;

  int UF; // Upper tank FULL
  int UE; // Upper tank EMPTY
  int LF; // Lower tank FULL
  int LE;
  bool P_On = 1;
  bool key8_latched = false;
  bool key7_latched = false;

  int mode = 0;
  int AM ;
  int i;
//---------------------------------

//----------Setup------------------
  void setup() {
    Serial.begin(115200);

    pinMode(PIN_RELAY_MAIN, OUTPUT);
    pinMode(PIN_RELAY_SOFT, OUTPUT);
    digitalWrite(PIN_RELAY_MAIN, LOW);
    digitalWrite(PIN_RELAY_SOFT, LOW);

    Display.setBrightness(0x0f);
    EEPROM.begin(EEPROM_SIZE);
    Data_read();

    pinMode(PIN_CURRENT_ADC, INPUT);
    pinMode(PIN_VOLTAGE_ADC, INPUT);
    pinMode(4,  INPUT);
    pinMode(2,  INPUT);
    pinMode(15, INPUT);
    pinMode(12, INPUT);


    esp_task_wdt_config_t wdtConfig = {
      .timeout_ms = WDT_TIMEOUT_S * 1000,
      .idle_core_mask = 0,
      .trigger_panic = true
    };
    esp_task_wdt_init(&wdtConfig);
    esp_task_wdt_add(NULL);

    button_num = AM;
    PBN = AM;
  }
//---------------------------------

//----------loop-------------------
  void loop() {
    esp_task_wdt_reset();
    keypad.setDebounceTime(KEYPAD_DEBOUNCE_MS);
    precesskey();

    UF = digitalRead(12);
    UE = digitalRead(15);
    LF = digitalRead(2);
    LE = digitalRead(4);

    switch (button_num) {
      
      case BTN_NEXT: if (PBN != BTN_SETTINGS) button_num = AM; break;
      case BTN_UP:   if (PBN != BTN_SETTINGS) button_num = AM; break;

      case BTN_OC_VIEW: OC_value(); break;
      case BTN_UC_VIEW: UC_value(); break;

      case 9:  Manual();  break;
      case 10: Auto(); break;

      case BTN_SETTINGS:
        if (Set_mode == 0) OC_setting();
        if (Set_mode == 1) UC_setting();
        break;

      case BTN_OC_FAULT: Show_OC_Error(); break;
      case BTN_UC_FAULT: Show_UC_Error(); break;

      case 14: turn_off(); break;
      case 15: turn_on();  break;
    }
  }
//---------------------------------

//----------Control Function-------
  void turn_off() {
    precesskey();
    Relay(0);
    if (AM == 9){blink_print(20, 21, 22, 22);}
    M1 = M2 = 0;
    PBN = BTN_OFF;
  }

  void turn_on() {
    precesskey();
    Show_Current();
    Relay(1);
    M1 = M2 = 0;
    PBN = BTN_ON;
    compare();
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

  #define PASSWORD_D1 1
  #define PASSWORD_D2 0
  #define PASSWORD_D3 0
  #define PASSWORD_D4 1

  void PasswordEntry() {
    D1 = D2 = D3 = D4 = 0;
    resetDigitEntry();
    unsigned long lastKeyTime = millis();

    while (true) {
      printBlinkDigit(D1, D2, D3, D4, currentDigit);
      precesskey();
      refreshDisplay();
      esp_task_wdt_reset();

      if (button_num == BTN_NEXT || button_num == BTN_UP) {
        handleDigitEntry(10, 4);
        lastKeyTime = millis();
      }

      if (button_num == BTN_OFF) return;

      if (millis() - lastKeyTime > SETTING_IDLE_TIMEOUT_MS) {
        button_num = BTN_OFF;
        return;
      }

      if (D1 == PASSWORD_D1 && D2 == PASSWORD_D2 && D3 == PASSWORD_D3 && D4 == PASSWORD_D4) {
        return;
      }
    }
  }

  void OC_setting() {
    PBN = BTN_SETTINGS;

    PasswordEntry();
    if (button_num == BTN_OFF) return;

    print(D1, D2, D3, D4);

    {
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
            if (millis() - lastKeyTime > SETTING_IDLE_TIMEOUT_MS) { Data_read(); button_num = AM; break; }
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
          if (button_num == AM) break;
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
            if (millis() - lastKeyTime > SETTING_IDLE_TIMEOUT_MS) { Data_read(); button_num = AM; break; }
            if (button_num == BTN_OC_VIEW || button_num == BTN_OFF) break;
            else if (button_num == BTN_NEXT || button_num == BTN_UP) handleDigitEntry(2, 3);
            printBlinkDigit(D1, D2 + 10, D3, 25, currentDigit);
          }

          uint16_t newUC = D1 * 100 + D2 * 10 + D3;
          if (newUC != calib.ucValue) {
            calib.ucValue = constrain(newUC, 0, 999);
            saveCalibration();
          }
          if (button_num == AM) break;
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

    button_num = AM;
  }
//---------------------------------

//----------Compare----------------
  void compare() {
      if (l <= FAULT_GRACE_TICKS) return; // still in soft-start grace period

      int enteredAs = button_num;  // whatever called us (15 = Manual ON, or 10 = Auto)

      if (res > OC) {
        unsigned long waitStart = millis();
        while (millis() - waitStart < OC_RECHECK_MS) {
          if (button_num != enteredAs) return;  // user pressed 7 or 8 - bail out immediately
          Show_Current();
          precesskey();
          refreshDisplay();
          esp_task_wdt_reset();
        }
        if (res > OC) {
          Relay(0);
          delay(20);
          button_num = BTN_OC_FAULT;
        }
      } 
      else if (res < UC) {
        unsigned long waitTime = (res == 0) ? UC_RECHECK_NO_LOAD_MS : UC_RECHECK_MS;
        unsigned long waitStart = millis();
        while (millis() - waitStart < waitTime) {
          if (button_num != enteredAs) return;
          Show_Current();
          precesskey();
          refreshDisplay();
          esp_task_wdt_reset();
        }
        if (res < UC) {
          Relay(0);
          delay(20);
          button_num = BTN_UC_FAULT;
        }
      }
  }
//---------------------------------

//----------Show Functions---------
  void Show_Current() {
    static unsigned long lastSampleTime = 0;
    static long sum = 0;
    static int sampleCount = 0;

    if (millis() - lastSampleTime >= 5) {
      lastSampleTime = millis();
      sum += analogRead(PIN_CURRENT_ADC);
      sampleCount++;
    }

    if (sampleCount >= 30) {
      int averaged_value = sum / sampleCount;
      sum = 0;
      sampleCount = 0;

           if (averaged_value <= 15)       res = averaged_value * 1;
      else if (averaged_value <= 300)      res = averaged_value * 0.106;
      else if (averaged_value <= 900)      res = averaged_value * 0.056;
      else if (averaged_value <= 1920)     res = averaged_value * 0.047;
      else                                 res = averaged_value * 0.05;

      D1 = res / 1000 % 10;
      D2 = res / 100  % 10;
      D3 = res / 10   % 10;
      D4 = res        % 10;

      SC = (res >= 200) ? 1 : 0;
    }

    if(AM == 9){blink_print(D2, D3 + 10, D4, 25);}
    else{print(D2, D3 + 10, D4, 25);}
    //print(D2, D3 + 10, D4, 25);
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
        button_num = AM;
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
        button_num = AM;
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

    if (SC == 0) blink_print(31, 39, 45, 31);
    if (SC == 1) blink_print(31, 44, 42, 31);

    precesskey();
  }

  void Show_UC_Error() {
    Relay(0);
    PBN = BTN_UC_FAULT;
    button_num = BTN_UC_FAULT;

    blink_print(31, 52, 55, 31);
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

        if (isNextKey) {
          bool rawHeld = (state == PRESSED || state == HOLD);

          if (state == PRESSED && !nextWasHeld) {
            button_num = BTN_NEXT;
          }

          nextWasHeld = rawHeld;
        }

        if (isUpKey) {
          bool rawHeld = (state == PRESSED || state == HOLD);

          if (rawHeld) {
            unsigned long now = millis();

            if (!upWasHeld) {
              upWasHeld = true;
              lastIncrementTime = now;
              button_num = BTN_UP;
            }
            else if (now - lastIncrementTime >= INCREMENT_REPEAT_MS) {
              lastIncrementTime = now;
              button_num = BTN_UP;
            }
          }
          else {
            upWasHeld = false;
          }
        }


        // =====================================================
        // KEYS 5 - 8
        // ORIGINAL CODE + KEY 7/8 SPECIAL FUNCTIONS
        // =====================================================
        if (d >= '5' && d <= '8') {

            // ---- Button 8: alternate between Manual (9) and Auto (10) ----
            if (d == '8') {
              if (state == PRESSED && key8_latched == false) {
                key8_latched = true;

                Serial.print("KEY8 PRESSED  AM=");
                Serial.print(AM);
                Serial.print(" mode=");
                Serial.println(mode);

                if (AM == 9) {
                  button_num = 10;   // was in Manual -> switch to Auto
                } else {
                  button_num = 9;    // was in Auto (or anything else) -> switch to Manual
                  mode = 0;
                }

                Serial.print("  -> button_num set to ");
                Serial.println(button_num);
              }
              else if (state == RELEASED) {
                key8_latched = false;   // <-- moved here, now always reached
              }
              continue;
            }

            // ---- Button 7: only toggles ON/OFF while in Manual mode ----
            if (d == '7') {
              if (state == PRESSED && key7_latched == false) {
                key7_latched = true;

                Serial.print("KEY7 PRESSED  AM=");
                Serial.print(AM);
                Serial.print(" mode=");
                Serial.println(mode);

                if (AM == 9) {
                  mode = (mode == 0) ? 1 : 0;
                  button_num = 9;
                  Serial.print("  -> mode toggled to ");
                  Serial.println(mode);
                } else {
                  Serial.println("  -> ignored, not in Manual mode");
                }
              }
              else if (state == RELEASED) {
                  key7_latched = false;   // <-- moved here, now always reached
                }
              continue;
            }

            else if (state == PRESSED || state == HOLD) {
              button_num = d - '0';

              if (state == PRESSED && button_num == BTN_OC_VIEW) {
                M2++;
                M1 = 0;
              }

              if (state == HOLD &&
                  (button_num == BTN_OC_VIEW ||
                  button_num == BTN_UC_VIEW)) {
                M2++;
                M1 = 0;
              }
            }
        }


      }
    }

    //Serial.println(AM);
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

      uint8_t out0, out1, out2, out3;
      if (visible) {
        out0 = d1; out1 = d2; out2 = d3; out3 = d4;
      } else {
        out0 = out1 = out2 = out3 = 20;   // blank glyph
      }

      lastD1 = out0; lastD2 = out1; lastD3 = out2; lastD4 = out3;   // <-- the missing piece

      if (now - lastDisplayRefresh < DISPLAY_REFRESH_MS) return;
      lastDisplayRefresh = now;

      data[0] = Display.encodeDigit(out0);
      data[1] = Display.encodeDigit(out1);
      data[2] = Display.encodeDigit(out2);
      data[3] = Display.encodeDigit(out3);
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

    // ---- Restore last mode (Manual/Auto) from EEPROM ----
    uint8_t storedAM = EEPROM.read(6);
    if (storedAM == 9 || storedAM == 10) {
      AM = storedAM;
    } else {
      AM = 9;   // brand-new chip / never written -> default idle
    }
  }
//----------------------------------

//---------------------Manual------------------------------
  void Manual()
  {  
    Serial.println("Manual() called");
    if(AM != 9){EEPROM.write(6, 9);EEPROM.commit();delay(20);}
    AM = 9;
    if(PBN != 9){PBN = 9;}
           if(mode == 0){button_num = 14;}
      else if(mode == 1){button_num = 15;}
  }
//---------------------------------------------------------

//---------------------Auto--------------------------------
  void Auto() 
  {
      //Serial.println("Auto() called");
      if(AM != 10){EEPROM.write(6, 10);EEPROM.commit();delay(20);}
      AM = 10;
      if(PBN != 10){PBN = 10;} 
      if(LE == 0 && LF == 0)
      {
        button_num = 10;
        M1 = M2 = i = 0;
        //delay(700);
        turn_off();
        print(31,48,51,47); // UGE
        LF_Flag = 0;
      }
      if(LE == 1 && LF == 0 && LF_Flag == 0)
      {
        turn_off();
        print(31,48,51,47); // UGE
      }

      if(LF == 1){LF_Flag = 1;}
      if(LE == 1 && P_On == 1)
      {
        LF_Flag = 1; P_On = 0;
      }


      if(LF_Flag == 1)
      {
          if(UF == 1){UF_Flag = 1;}

          if(UF == 1 && UF_Flag == 1)
          {
            M1 = M2 =  0;
            //delay(700);
            Relay(0);
              
            print(31,39,28,22); // OTF
            UF_Flag = 1;
          }

          if(UF == 0 && UF_Flag == 1 && UE == 1)
          {
            M1 = M2 = i = 0;
            Relay(0);
            print(31,39,28,22); //OTF
          }

        if(UF != 1)
          {
            if(UE == 0){UF_Flag = 0;}
            if(UF_Flag == 0)
            { 
              turn_on();
              //if(autosent == 0)
                //{
                  //type = "upd";
                  //sendStatus();
                  //autosent = 1;
                //}
            }
            else
            {
              //delay(700);
              UF_Flag  = 1;
              //autosent = 0;
              //Switch_Off();
              //button_num = 8;
            }
          }

      }

  }
//---------------------------------------------------------