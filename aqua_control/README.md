# AquaControl

Smart water management app — Flutter client for monitoring and controlling pump/motor devices, paired with the [FourFold NestJS backend](../backend).

## Prerequisites

- Flutter SDK (3.2.0+) — verify with `flutter doctor`
- For iOS: Xcode + a configured signing setup
- For Android: Android Studio / SDK + a connected device or emulator
- The [FourFold backend](../backend) running locally (see that README) — the app talks to a real API by default, there is no user-facing mock-data toggle currently wired up

## Setup

```bash
cd aqua_control
flutter pub get
```

## Environment configuration

`lib/core/config/app_config.dart` selects one of three endpoint sets via the `APP_ENV` compile-time define:

```dart
static const String _envName = String.fromEnvironment('APP_ENV', defaultValue: 'local');
```

| `APP_ENV` | Base URL |
|---|---|
| `local` (default) | `http://192.168.1.3:3000/api/v1` — a LAN IP, **not** `localhost`, so a physical device on the same Wi-Fi can reach your dev machine. Update this to your machine's current LAN IP in `_LocalConfig.baseUrl` if it changes. |
| `dev` | `https://dev-api.aquacontrol.in/api/v1` |
| `prod` | `https://api.aquacontrol.in/api/v1` |

Run with a specific environment:
```bash
flutter run --dart-define=APP_ENV=dev
```

There's also `AppConfig.useMock`, which every repository checks before making a network call — but it's currently **hardcoded to `false`** (`static bool get useMock => false;`). To develop UI without a live backend, flip that literal to `true` temporarily; each repository's mock branch returns canned data (see e.g. `AuthRepository._mockUser`, `ModuleStatusModel.mock(serialNumber)`).

MSG91 OTP widget credentials (`msg91WidgetId`, `msg91AuthToken`) are also in `AppConfig` and initialized in `main.dart` via `OTPWidget.initializeWidget(...)`.

## Running the backend

```bash
cd ../backend
npm run start:dev
```

Backend runs on port 3000 with API prefix `/api/v1`. Make sure it's up and reachable at the base URL configured above before launching the app — auth, device, motor, and status calls all hit the real API.

## Running the app

List available devices:

```bash
flutter devices
```

Run on a specific target:

```bash
flutter run -d chrome              # web browser — fastest for UI iteration
flutter run -d <device-id>         # physical device or simulator/emulator
flutter run                        # prompts to pick a device if multiple are connected
```

### iOS physical device

Requires Xcode installed (`xcode-select --install` is not enough — install full Xcode from the App Store), then:

```bash
sudo xcode-select --switch /Applications/Xcode.app
flutter run -d <ios-device-id>
```

### Android

Connect a device with USB debugging enabled, or start an emulator from Android Studio, then:

```bash
flutter run -d <android-device-id>
```

---

## Feature tour

### Auth (`lib/features/auth/`)
- Splash screen → tries to restore a saved session (`AuthRepository.tryRestoreSession`) before routing to `/login` or the home shell.
- Two login paths: OTP via the MSG91 widget SDK, or phone + password (`POST /auth/user-login`).
- MSG91 SDK quirk: both `sendOTP` and `verifyOTP` responses carry their payload in a `message` field, not a dedicated one — `sendOTP` → `reqId`, `verifyOTP` → the access token, which is then exchanged with the backend at `POST /auth/verify-otp-token`.
- Registration collects society details (name, block/wing, member count, password) and posts to `POST /societies`.

### Home (`lib/features/home/`)
- **Dashboard** (`HomeScreen`) lists all modules linked to the user (`GET /device/user-modules/:userId`), with a crown badge for modules where the user has the `admin` role — gated **per device** (`DeviceModel.isAdmin`), not by the user's global society role.
- Tapping a module opens **`ModuleDetailScreen`**, which:
  - Polls `GET /module-status/:serialNumber` every 15s (`HomeBloc`, `Timer.periodic`) while the screen is open, so voltage/current/tank levels/motor state and any new overcurrent/undercurrent alert stay reasonably live without needing a full push-notification stack.
  - Shows a persistent red banner + one-time SnackBar the moment `ocBreached`/`ucBreached` flips true (rising-edge detection in a `BlocListener`).
  - Falls back to zeroed values (`PumpStatusModel.empty`) instead of an error screen if no status exists yet for that serial number, and neither the ON nor OFF button is highlighted in that case (`MotorStatus.unknown`).
  - **Pump control**: ON/OFF buttons dispatch `POST /motor/command` (`TURN_ON`/`TURN_OFF`) with optimistic UI + revert-on-failure.
  - **Threshold settings**: tapping the gear icon opens a bottom sheet pre-filled with the current overcurrent/undercurrent thresholds; Save fires `SET_OC` then `SET_UC` commands.
  - **Members panel**: shows society members for this module, with an "+ Add" button gated on the *freshly-fetched* member role for the current user (`_info.members`), not the possibly-stale `DeviceModel.isAdmin` passed in via navigation.
  - **Activity history**: the "Activity history" tile navigates to `ActivityHistoryScreen` (`GET /module-action-logs/:serialNumber`), listing every command/registration event for the module with a sensor snapshot at that moment.

### Devices (`lib/features/devices/`)
- Register a new module by serial number, or via the BLE Wi-Fi setup flow (see below) from Profile.

### Profile (`lib/features/profile/`)
- Society info, dark-mode toggle, biometric/notification switches (local-only, not yet persisted to a backend), logout.
- `MembersScreen` (`GET/PUT/DELETE /societies/:id/members`) exists as a route (`/profile/members`) but nothing in `ProfileScreen` currently links to it — reachable only via manual navigation.
- **Bluetooth (BLE) Wi-Fi setup** — see dedicated section below.

### Motor Settings (`lib/features/motor_settings/`)
- `MotorSettingsScreen` and its widgets exist and are wired into the router at `/home/motor-settings`, but nothing currently navigates to that route — it's unreachable from the UI as of this writing.

---

## Bluetooth (BLE) Wi-Fi setup

The **Profile → Connect via Bluetooth** button scans for an ESP32/Arduino device advertising as `AquaControl-Setup`, connects over BLE, and sends your Wi-Fi SSID and password as UTF-8 strings to the firmware characteristics below:

| Purpose | UUID |
|---|---|
| Service | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| SSID write | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| Password write | `beb5483f-36e1-4688-b7f5-ea07361b26a9` |
| Status notify | `beb54840-36e1-4688-b7f5-ea07361b26aa` |

### Required permissions

**Android** — add to `android/app/src/main/AndroidManifest.xml` (inside `<manifest>`):

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

**iOS** — add to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>AquaControl uses Bluetooth to configure your water controller's Wi-Fi connection.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>AquaControl uses Bluetooth to send Wi-Fi credentials to the controller.</string>
```

> Platform folders (`android/`, `ios/`) are generated by `flutter create .`. Run that first if they don't exist.

---

## Project structure

```
lib/
├── main.dart                       ← entry point, MSG91 init, repo/bloc providers
├── app.dart                        ← MaterialApp.router + theme wiring
├── core/
│   ├── config/app_config.dart       ← APP_ENV-based endpoint config, MSG91 keys, useMock
│   ├── router/app_router.dart       ← go_router routes (StatefulShellRoute for the 3-tab shell)
│   ├── services/ble_wifi_service.dart
│   ├── theme/, constants/, widgets/
└── features/
    ├── auth/                        ← splash, login, register, OTP + password auth
    ├── home/                        ← dashboard, module detail, pump control, thresholds, activity history
    │   ├── data/models/              ← DeviceModel-adjacent: PumpStatusModel, ModuleStatusModel, ModuleActionLogModel
    │   ├── data/repositories/         ← MotorRepository (status/commands/action logs), motor_repository.dart
    │   └── presentation/bloc/         ← HomeBloc (polling, optimistic commands, threshold updates)
    ├── devices/                      ← device list, add-device (serial number registration)
    ├── profile/                      ← society info, members, appearance, BLE Wi-Fi setup
    ├── motor_settings/                ← screen + widgets exist, currently unreachable from the UI (see above)
    ├── history/                       ← ⚠ legacy/orphaned — HistoryScreen + ActivityModel, not referenced by the
    │                                     router or any screen. Superseded by home/.../activity_history_screen.dart.
    └── main/                          ← bottom-nav shell (MainScreen)
```

> **Known cruft, not yet cleaned up:** `lib/features/history/` is dead code from an earlier iteration — the router uses `ActivityHistoryScreen` in `features/home/` instead. There are also two malformed empty directories under `lib/features/profile/` (`{presentation` and `{presentation/screens}`, `{presentation/widgets}`), almost certainly leftover from a `mkdir -p` brace-expansion typo. Neither affects the build; flagging them here so they don't cause confusion later.

---

## Building release artifacts

```bash
flutter build apk          # Android APK
flutter build appbundle    # Android App Bundle (Play Store)
flutter build ios          # iOS (requires Xcode + signing)
```

---

## Known stubs / not yet implemented

- `EditSocietySheet` "Save Changes" → just closes the sheet, no actual save.
- `_AddMemberSheet`'s "Copy invite link" and "Share via WhatsApp" buttons → no-op.
- `ProfileScreen`'s edit-profile icon and "Change Password" tile → no-op.
- Biometric login and notification toggles in Profile → local state only, not persisted or wired to any backend/OS capability.
- `MotorSettingsScreen` → built but unreachable (no navigation entry point).
- In-app alerts are polling-based while `ModuleDetailScreen` is open only — there's no background/OS-level push notification (would require a Firebase project + FCM wiring on both ends, not currently set up).

---

## Troubleshooting

- **"No pubspec.yaml file found"** — you're not in the `aqua_control/` directory. `cd` into it first.
- **"No supported devices connected"** — run `flutter create .` to regenerate missing `ios/`/`android/` platform folders.
- **Flutter not found in VS Code** — ensure `flutter/bin` is on your `PATH` (check `~/.zshrc` or `~/.bashrc`) and that `dart.flutterSdkPath` in VS Code settings points to your Flutter SDK install.
- **API calls failing** — confirm the backend is running and reachable at the `baseUrl` configured for your `APP_ENV` (default `local` points at a LAN IP, not `localhost` — a simulator/emulator on the same machine may need this changed to `http://localhost:3000/api/v1`, or `10.0.2.2` for the Android emulator).
- **`GoException: no routes for location: ...`** — a route is nested incorrectly in `app_router.dart`; `GoRoute.routes` paths are relative to their *immediate* parent, not the top-level shell branch.
- **Motor command returns 404** — the target `serialNumber` was never registered via `POST /device/register/:serialNo` on the backend (module *registration* and ESP *device* registration are separate steps).
