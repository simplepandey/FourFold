# FourFold Backend API

NestJS + Prisma + PostgreSQL backend for FourFold — phone/OTP and society authentication, module/device registry, MQTT motor control (on/off + overcurrent/undercurrent threshold tuning), live telemetry ingestion, and a per-module live-status + action-history log.

---

## Prerequisites

| Tool | Version | Check |
|---|---|---|
| Node.js | >= 20 | `node -v` |
| npm | >= 9 | `npm -v` |
| PostgreSQL | >= 14 | `psql --version` |

---

## Step 1 — Install dependencies

```bash
cd FourFold/backend
npm install
```

> If you hit `npm ERR! code EACCES ... .npm/_cacache`, your npm cache has root-owned files from a previous `sudo npm` run. Fix permanently with:
> ```bash
> sudo chown -R $(id -u):$(id -g) ~/.npm
> ```
> Or work around it for one install: `npm install --cache /tmp/npm-cache`

---

## Step 2 — Set up environment variables

```bash
cp .env.example .env
```

Fill in `.env`:

```env
NODE_ENV=development
PORT=3000

# Format: postgresql://<username>@localhost:5432/<database_name>
DATABASE_URL=postgresql://simplepandey@localhost:5432/fourfold_db

JWT_SECRET=paste_your_generated_secret_here
JWT_EXPIRES_IN=7d

OTP_EXPIRY_MINUTES=5
OTP_LENGTH=6
SMS_PROVIDER=console

# --- MSG91 (OTP widget on the Flutter side + server-side token verification) ---
MSG91_AUTH_KEY=
MSG91_WIDGET_AUTH_KEY=

# --- Basic auth for the ESP32 self-registration endpoint ---
DEVICE_BASIC_AUTH_USERNAME=fourfold
DEVICE_BASIC_AUTH_PASSWORD=fourfold

# --- MQTT broker (motor telemetry + commands) ---
MQTT_HOST=65.20.84.166
MQTT_PORT=1883
MQTT_USERNAME=fourfold
MQTT_PASSWORD=fourfold@2026
MQTT_TELEMETRY_TOPIC=motors/+/telemetry
```

> `MQTT_TELEMETRY_TOPIC` is read into config but the MQTT client currently subscribes to a **hardcoded** `['motors/+/telemetry', 'motors/+/alert']` in `mqtt.service.ts` regardless of this value — see [MQTT Topics](#mqtt-topics) below.

### Generate a JWT secret (run once):

```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

Paste the output as `JWT_SECRET`.

---

## Step 3 — Create the PostgreSQL database

```bash
psql -U simplepandey -c "CREATE DATABASE fourfold_db;"
psql -U simplepandey -l   # verify it's listed
```

---

## Step 4 — Sync the database schema

```bash
npx prisma db push
npx prisma generate
```

This project uses `prisma db push` as its working schema-sync flow (not tracked `prisma migrate` migrations — the `prisma/migrations/` folder exists but is not kept in sync with the schema). Creates/updates all tables from `prisma/schema.prisma` and regenerates the typed Prisma client:

| Table | Description |
|---|---|
| `users` | Registered app users |
| `otps` | OTP codes for phone auth |
| `societies` | Registered housing societies |
| `society_members` | Members of each society (admin / member roles), optionally linked to a `serialNumber` |
| `module_master` | Physical ESP32 devices by serial number |
| `module_registration` | Links a module serial number to a society (pump config, address) |
| `esp_registrations` | ESP32 device self-registration with assigned MQTT topics |
| `motor_commands` | Log of TURN_ON / TURN_OFF / SET_OC / SET_UC commands sent to motors |
| `motor_telemetry` | Raw telemetry readings as received (voltage, current, oc/uc, tank levels, motor state) |
| `motor_alerts` | Overcurrent / undercurrent breach events as received |
| `module_status` | **Current** live state per module (one row per `serialNumber`, upserted in place) |
| `module_action_logs` | **Append-only** history of every status-changing event per module (registration, commands, threshold changes) |

`module_status` vs `motor_telemetry`/`motor_alerts`: the latter two are raw append-only logs of everything the ESP32 reports; `module_status` is the derived "what does this module look like right now" snapshot the app actually polls, kept live by telemetry/alert ingestion and by commands. `module_action_logs` is the human-facing activity trail (`GET /module-action-logs/:serialNumber`, surfaced in the app's "Activity history" screen) — one row per command/registration event, not per raw telemetry tick.

---

## Step 5 — (Optional) Seed test data

```bash
npm run prisma:seed
```

---

## Step 6 — Start the server

```bash
npm run start:dev
```

Expected output:
```
[Bootstrap] Swagger UI: http://localhost:3000/api/docs
[PrismaService] Database connected successfully
[EspTopicCacheService] Cached MQTT topics for N device(s)
[NestApplication] Nest application successfully started
[Bootstrap] Server running on http://localhost:3000
[MqttService] Connected to MQTT broker at 65.20.84.166:1883
[MqttService] Subscribed to: motors/+/telemetry, motors/+/alert
```

The server watches for file changes and restarts automatically.

---

## Verify it's working

Open:
```
http://localhost:3000/api/docs
```

You should see Swagger UI grouped by tag: **Auth**, **Users**, **Societies**, **Module Master**, **Module Registration**, **Device Registration**, **Motor Commands**, **Module Status**, **Module Action Logs**.

---

## API Endpoints

All routes are versioned under `/api/v1`. Unless noted **No**, `Authorization: Bearer <jwt>` is required (enforced globally by `JwtAuthGuard`; routes opt out with `@Public()`).

### Auth
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/auth/send-otp` | No | Send OTP to phone number (legacy own-OTP flow; dev mode returns the OTP in the response) |
| POST | `/auth/verify-otp` | No | Verify OTP from `send-otp`, returns JWT |
| POST | `/auth/verify-otp-token` | No | Verify an MSG91 widget access token (the flow the Flutter app actually uses), returns JWT — body: `{ accessToken, phoneNumber }` |
| POST | `/auth/user-login` | No | Society login with phone number + password, returns JWT |

### Users
| Method | Endpoint | Description |
|---|---|---|
| GET | `/users/me` | Get current user profile |
| GET | `/users/:id` | Get user by ID |

### Societies
| Method | Endpoint | Description |
|---|---|---|
| POST | `/societies` | Register a society (generates unique `societyCode`) |
| GET | `/societies` | List all societies |
| GET | `/societies/:id` | Get society by ID |
| POST | `/societies/:societyId/members` | Add member by phone number — body accepts optional `name`, `serialNumber` (which module they were added from) |
| GET | `/societies/:societyId/members` | List all members of a society |
| PUT | `/societies/:societyId/members/:memberId` | Update member role (admin only) |
| DELETE | `/societies/:societyId/members/:memberId` | Remove member from society (admin only) |

### Module Master
| Method | Endpoint | Description |
|---|---|---|
| POST | `/module-master` | Create a module |
| GET | `/module-master` | List active modules |
| GET | `/module-master/serial-number/:serialNumber` | Get module by serial number |
| GET | `/module-master/:id` | Get module by ID |
| PUT | `/module-master/:id` | Update a module |
| DELETE | `/module-master/:id?deletedBy=` | Soft-delete a module |

### Module Registration
| Method | Endpoint | Description |
|---|---|---|
| POST | `/module-registration` | Register a module to a society. Verifies the ESP is registered, prevents duplicate active registration, and **seeds an initial `module_status` row** (all-zero, `motorStatus: 'OFF'`) for the serial number |
| GET | `/module-registration` | List active registrations |
| GET | `/module-registration/module/user/:id` | List a user's registered modules |
| GET | `/module-registration/:id` | Get registration by ID |
| PUT | `/module-registration/:id` | Update a registration |
| DELETE | `/module-registration/:id?deletedBy=` | Soft-delete (unregister) a module |

### Device Registration (ESP32)
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/device/register/:serialNo` | Basic auth | ESP32 registers itself on first boot, receives assigned MQTT topics. 201 if new, 200 if already registered (same payload either way). Also warms the in-memory topic cache. |
| GET | `/device/register/:serialNo` | No | Get all registrations for a serial number |
| GET | `/device/user/:userId` | No | Get all devices registered to a user |
| GET | `/device/user-modules/:userId` | No | Get all modules linked to a user via `society_members.serialNumber`, each with ESP registration details |
| GET | `/device/info/:serialNo` | No | Combined view: ESP registration (topics) + module registration (pump config/address) + all society members with role |

### Motor Commands
| Method | Endpoint | Description |
|---|---|---|
| POST | `/motor/command` | Send a command to a motor over MQTT and log it. `command` ∈ `TURN_ON \| TURN_OFF \| SET_OC \| SET_UC`. Body: `{ societyCode, motorId, serialNumber, command, value?, commandBy }` — `value` (amps) is **required** when `command` is `SET_OC`/`SET_UC`. Requires `commandBy` to be a member of `societyCode`. Publishes to the module's real command topic looked up from `esp_registrations` (see [MQTT Topics](#mqtt-topics)), writes a `motor_commands` row, appends a `module_action_logs` entry, and upserts `module_status`. |
| GET | `/motor/commands` | List all motor commands |
| GET | `/motor/commands/:societyCode/:motorId` | List commands for a specific motor |

### Module Status
| Method | Endpoint | Description |
|---|---|---|
| GET | `/module-status/:serialNumber` | Current live state for a module: `voltage`, `current`, `overcurrent`/`undercurrent` (configured thresholds), `overheadTankLevel`, `undergroundTankLevel`, `motorStatus` (`ON`/`OFF`), `ocBreached`, `ucBreached`, `updatedAt`, `updatedBy`. 404 if the module has never been registered/reported in. |

### Module Action Logs
| Method | Endpoint | Description |
|---|---|---|
| GET | `/module-action-logs/:serialNumber` | Up to the 100 most recent action-log entries for a module, newest first — one entry per command (TURN_ON/OFF, SET_OC, SET_UC), each a snapshot of the module's sensor state at that moment plus who triggered it (`createdBy`). |

**Swagger UI:** `http://localhost:3000/api/docs`

---

## MQTT Topics

Per-device topics are assigned once, at ESP32 self-registration (`POST /device/register/:serialNo`), and stored on the `esp_registrations` row. The server derives a 12-character SHA-256 `serialHash` from the serial number and builds:

| Topic | Direction | Purpose |
|---|---|---|
| `motors/{serialHash}/commands` | Server → ESP32 | Motor commands (`TURN_ON`/`TURN_OFF`/`SET_OC`/`SET_UC`) |
| `motors/{serialHash}/telemetry` | ESP32 → Server | Voltage, current, thresholds, tank levels, motor state |
| `motors/{serialHash}/alert` | ESP32 → Server | Overcurrent / undercurrent breach |
| `motors/{serialHash}/heartbeat` | ESP32 → Server | Device alive ping (not currently consumed by any handler) |

The server subscribes to `motors/+/telemetry` and `motors/+/alert` (hardcoded in `mqtt.service.ts`), and publishes to a device's specific `.../commands` topic.

### `EspTopicCacheService` — command topic lookup

`POST /motor/command` doesn't rebuild the topic string from `societyCode`/`motorId` — it looks up the module's real `commandTopic` via `EspTopicCacheService` (`src/modules/device/esp-topic-cache.service.ts`):
- On app startup, every `esp_registrations` row is preloaded into an in-memory `Map<serialNumber, topics>`.
- On a cache miss (a device registered after boot but before this instance's next restart), it falls back to a DB lookup by `serialNumber` and backfills the cache — throws `404 Not Found` if the serial number was never registered as an ESP device.
- `DeviceService.register()` also proactively warms the cache on both the "already registered" and "newly created" paths.

`societyCode`/`motorId` are still stored on the `motor_commands` row and used for the society-membership permission check — only the MQTT publish target is resolved from `esp_registrations`.

---

## MQTT Payload Formats

### Telemetry payload (ESP32 → Server, topic `motors/{serialHash}/telemetry`)

```json
{
  "v":     232,       // voltage (V)
  "i":     4.2,        // current reading (A)
  "oc":    8.5,         // configured overcurrent threshold (A)
  "uc":    1.0,          // configured undercurrent threshold (A)
  "gt":    45,           // ground/underground tank level (%) — optional
  "oh":    68,           // overhead tank level (%) — optional
  "motor": true,          // motor relay state: true = running, false = stopped
  "sn":    123456           // ESP32 serial number, used only as a fallback if serialHash doesn't resolve to a registration
}
```

Every telemetry message upserts `module_status` (`voltage`, `current`, `overcurrent`, `undercurrent`, `overheadTankLevel`, `undergroundTankLevel`, `motorStatus`) and also appends a raw row to `motor_telemetry`.

### Alert payload (ESP32 → Server, topic `motors/{serialHash}/alert`)

```json
{ "overcurrent_breached": 5.8 }
```
```json
{ "undercurrent_breached": 0.3 }
```
```json
{ "overcurrent_breached": 5.8, "undercurrent_breached": 0.3 }
```

Sets `module_status.ocBreached` / `ucBreached` to `true` when the corresponding field is present (any non-null value counts as breached), and appends a raw row to `motor_alerts` with the actual breach value.

### Command payload (Server → ESP32, topic `motors/{serialHash}/commands`)

```json
{
  "cmd":    "TURN_ON",                                // TURN_ON | TURN_OFF | SET_OC | SET_UC
  "value":  null,                                      // amps, only set for SET_OC / SET_UC
  "cmd_id": "11111111-1111-1111-1111-111111111111",     // unique command UUID
  "ts":     1751808000                                   // unix epoch
}
```

---

## Testing MQTT locally

Subscribe and watch incoming messages:
```bash
mqttx sub \
  --hostname 65.20.84.166 --port 1883 \
  --username fourfold --password "fourfold@2026" \
  --topic "motors/+/#" --verbose
```

Simulate ESP32 telemetry (replace `a1b2c3d4e5f6` with the real `serialHash` from that device's `esp_registrations` row):
```bash
mqttx pub \
  --hostname 65.20.84.166 --port 1883 \
  --username fourfold --password "fourfold@2026" \
  --topic "motors/a1b2c3d4e5f6/telemetry" \
  --message '{"v":232,"i":4.2,"oc":8.5,"uc":1.0,"gt":45,"oh":68,"motor":true,"sn":123456}'
```

Simulate an alert:
```bash
mqttx pub \
  --hostname 65.20.84.166 --port 1883 \
  --username fourfold --password "fourfold@2026" \
  --topic "motors/a1b2c3d4e5f6/alert" \
  --message '{"overcurrent_breached":5.8}'
```

Send a TURN_ON command via the API (saves to DB + publishes MQTT + logs + updates status):
```bash
curl -X POST http://localhost:3000/api/v1/motor/command \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"societyCode":"SOC001","motorId":"SN-2024-001","serialNumber":"SN-2024-001","command":"TURN_ON","commandBy":"user-uuid"}'
```

Set an overcurrent threshold:
```bash
curl -X POST http://localhost:3000/api/v1/motor/command \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"societyCode":"SOC001","motorId":"SN-2024-001","serialNumber":"SN-2024-001","command":"SET_OC","value":8.5,"commandBy":"user-uuid"}'
```

---

## Troubleshooting

### `npm ERR! EACCES ... .npm/_cacache`
Your npm cache has root-owned files. Run `sudo chown -R $(id -u):$(id -g) ~/.npm`, or pass `--cache /tmp/npm-cache` to bypass it for one install.

### `Database connection failed`
- Make sure PostgreSQL is running: `brew services start postgresql` (macOS)
- Check `DATABASE_URL` in `.env` matches your system username
- Confirm the database exists: `psql -U simplepandey -l`

### `relation "..." does not exist`
Run `npx prisma db push` to sync the schema.

### `Cannot find module '@prisma/client'` or stale type errors
Run `npx prisma generate`. If VS Code still shows stale types: `rm -rf node_modules/.prisma && npx prisma generate`, then `Cmd+Shift+P` → "TypeScript: Restart TS Server".

### `Port 3000 already in use`
```bash
lsof -ti:3000 | xargs kill
```

### MQTT not connecting
- Confirm `MQTT_HOST`/`MQTT_PORT`/`MQTT_USERNAME`/`MQTT_PASSWORD` in `.env` are correct
- The client auto-reconnects every 5s — check logs for `[MqttService] Reconnecting to MQTT broker...`

### `403 Forbidden` on motor command
The `commandBy` user ID is not a member of the society. Add them via `POST /societies/:societyId/members` first.

### `404 Not Found` on motor command ("No ESP registration found for serial number ...")
The `serialNumber` sent has never called `POST /device/register/:serialNo`. Register the ESP device first — `module-registration` alone doesn't create an `esp_registrations` row.

### `400 Bad Request` on `SET_OC`/`SET_UC`
`value` is required (a number) whenever `command` is `SET_OC` or `SET_UC` — validated via `class-validator`'s `@ValidateIf`.

### `403 Forbidden` on update/delete member
Only users with `role: admin` in `society_members` can update or remove members.

---

## Available Scripts

| Command | Description |
|---|---|
| `npm run start:dev` | Start in watch mode (auto-restart on changes) |
| `npm run start` | Start normally |
| `npm run build` | Compile TypeScript to `dist/` |
| `npm run lint` | Run ESLint with auto-fix |
| `npm run format` | Run Prettier |
| `npm run test` | Run unit tests |
| `npm run test:cov` | Run tests with coverage report |
| `npx prisma db push` | Sync schema to the database (current workflow) |
| `npx prisma migrate dev --name <name>` | Create and apply a new migration (not currently used — see Step 4) |
| `npx prisma migrate deploy` | Apply migrations (production) |
| `npx prisma studio` | Open database GUI in browser |
| `npm run prisma:seed` | Insert test data |

---

## Project Structure

```
backend/
├── .env                          ← local environment variables (never commit)
├── .env.example                  ← template to copy from
├── prisma/
│   ├── schema.prisma              ← all DB models
│   └── seed.ts                    ← test data seeder
└── src/
    ├── main.ts                    ← app entry point, global pipes/guards/Swagger
    ├── app.module.ts               ← root module
    ├── config/configuration.ts     ← typed env config (db, jwt, otp, sms, device basic auth, mqtt)
    ├── prisma/prisma.service.ts    ← database connection
    ├── modules/
    │   ├── auth/                   ← send-otp, verify-otp, verify-otp-token (MSG91), user-login, JWT strategy
    │   ├── users/                  ← user profile endpoints
    │   ├── otp/                    ← OTP generation, validation, expiry
    │   ├── societies/              ← society CRUD + member management
    │   ├── module-master/          ← ESP32 device registry (CRUD, soft delete)
    │   ├── module-registration/    ← links a module to a society; seeds initial module_status
    │   ├── device/                 ← ESP32 self-registration, topic assignment, EspTopicCacheService
    │   ├── motor/                  ← motor command endpoint (TURN_ON/OFF, SET_OC/UC) + command log
    │   ├── module-status/          ← current live per-module state (upsert + GET)
    │   ├── module-action-log/      ← append-only per-module activity history (create + GET)
    │   ├── telemetry/               ← telemetry + alert ingestion, upserts module_status
    │   └── mqtt/                   ← MQTT client (subscribes + publishes)
    └── common/
        ├── guards/                 ← JwtAuthGuard (all routes protected by default)
        ├── decorators/             ← @Public() to skip auth, @CurrentUser()
        ├── filters/                ← global error handler
        ├── interceptors/           ← logging + response envelope
        └── providers/sms/          ← SMS abstraction (console active, Twilio/MSG91/SNS ready)
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | NestJS 10 (TypeScript) |
| Database | PostgreSQL |
| ORM | Prisma 5 |
| Auth | JWT + Passport, plus MSG91 OTP widget token verification |
| Validation | class-validator |
| Documentation | Swagger / OpenAPI |
| Realtime | MQTT (motor commands + telemetry + alerts) |
