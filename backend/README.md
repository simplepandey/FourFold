# FourFold Backend API

NestJS + Prisma + PostgreSQL backend for FourFold — phone/OTP and society authentication, module/device registry, and live MQTT motor telemetry.

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

# MQTT broker (motor telemetry)
MQTT_HOST=65.20.84.166
MQTT_PORT=1883
MQTT_USERNAME=fourfold
MQTT_PASSWORD=fourfold@2026
MQTT_TELEMETRY_TOPIC=societies/+/motors/+/telemetry
```

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

This creates/updates all tables (`users`, `otps`, `societies`, `module_master`, `module_registration`) from `prisma/schema.prisma` and regenerates the typed Prisma client.

> Already have migrations and want to use them instead? `npx prisma migrate dev --name init` works too — but this project has been evolving the schema with `db push`, so that's the recommended path going forward.

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
[InstanceLoader] MqttModule dependencies initialized
[Bootstrap] Swagger UI: http://localhost:3000/api/docs
[PrismaService] Database connected successfully
[NestApplication] Nest application successfully started
[Bootstrap] Server running on http://localhost:3000
[MqttService] Connected to MQTT broker at 65.20.84.166:1883
[MqttService] Subscribed to topic 'societies/+/motors/+/telemetry'
```

The server watches for file changes and restarts automatically.

---

## Verify it's working

Open:
```
http://localhost:3000/api/docs
```

You should see Swagger UI grouped by tag: **Auth**, **Users**, **Societies**, **Module Master**, **Module Registration**.

---

## Test the API

### Auth — phone + OTP

```bash
curl -X POST http://localhost:3000/api/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+919876543210"}'
```
Returns `{ data: { otp, expiresIn } }` (OTP is only included in non-production responses).

```bash
curl -X POST http://localhost:3000/api/v1/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+919876543210", "otp": "482910"}'
```
Returns `{ data: { user, token } }` — copy `token` for protected routes.

### Auth — society login

```bash
curl -X POST http://localhost:3000/api/v1/auth/society-login \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+919876543210", "password": "yourpassword"}'
```

### Protected route example

```bash
curl http://localhost:3000/api/v1/users/me \
  -H "Authorization: Bearer <token>"
```

In Swagger UI: click **Authorize**, paste the token, and "Try it out" works on every secured endpoint without re-entering it.

---

## Testing MQTT telemetry locally

The `mqttx` CLI (or `mosquitto_pub`) can simulate a device publishing telemetry:

```bash
npx mqttx pub \
  --hostname 65.20.84.166 --port 1883 \
  --username fourfold --password "fourfold@2026" \
  --topic "societies/SOC001/motors/esp32_test/telemetry" \
  --message '{"voltage":230,"current":4.2,"status":"running"}'
```

Watch the server log for:
```
[MqttService] Telemetry received — society=SOC001 motor=esp32_test topic=... payload={...}
```

Currently telemetry is logged only (no DB persistence yet).

---

## Troubleshooting

### `npm ERR! EACCES ... .npm/_cacache`
Your npm cache has root-owned files. Run `sudo chown -R $(id -u):$(id -g) ~/.npm`, or pass `--cache /tmp/npm-cache` to bypass it for one install.

### `Database connection failed`
- Make sure PostgreSQL is running: `brew services start postgresql` (macOS)
- Check `DATABASE_URL` in `.env` matches your system username
- Confirm the database exists: `psql -U simplepandey -l`

### `relation "..." does not exist`
- Run `npx prisma db push` to sync the schema.

### `Cannot find module '@prisma/client'` or stale type errors
- Run `npx prisma generate`
- If VS Code still shows stale types: `rm -rf node_modules/.prisma && npx prisma generate`, then Cmd+Shift+P → "TypeScript: Restart TS Server"

### `Port 3000 already in use`
```bash
lsof -ti:3000 | xargs kill
```

### MQTT not connecting
- Confirm `MQTT_HOST`/`MQTT_PORT`/`MQTT_USERNAME`/`MQTT_PASSWORD` in `.env` are correct
- The client auto-reconnects every 5s — check logs for `[MqttService] Reconnecting to MQTT broker...`

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
| `npx prisma migrate dev --name <name>` | Create and apply a new migration |
| `npx prisma migrate deploy` | Apply migrations (production) |
| `npx prisma studio` | Open database GUI in browser |
| `npm run prisma:seed` | Insert test data |

---

## Project Structure

```
backend/
├── .env                          ← local environment variables (never commit)
├── .env.example                  ← template to copy from
├── Dockerfile / docker-compose.yml
├── prisma/
│   ├── schema.prisma              ← all DB models
│   ├── seed.ts                    ← test data seeder
│   └── migrations/
└── src/
    ├── main.ts                    ← app entry point, global pipes/guards/Swagger
    ├── app.module.ts               ← root module
    ├── config/configuration.ts     ← typed env config (db, jwt, otp, sms, mqtt)
    ├── prisma/prisma.service.ts    ← database connection
    ├── modules/
    │   ├── auth/                   ← send-otp, verify-otp, society-login, JWT strategy
    │   ├── users/                  ← user profile endpoints
    │   ├── otp/                    ← OTP generation, validation, expiry
    │   ├── societies/              ← society registration + auth
    │   ├── module-master/          ← device/module registry (CRUD, soft delete)
    │   ├── module-registration/    ← links a module to a user (1 module → 1 user)
    │   └── mqtt/                   ← MQTT client, subscribes to motor telemetry
    └── common/
        ├── guards/                 ← JwtAuthGuard (all routes protected by default)
        ├── decorators/             ← @Public() to skip auth, @CurrentUser()
        ├── filters/                ← global error handler
        ├── interceptors/           ← logging + response envelope
        └── providers/sms/          ← SMS abstraction (console active, Twilio/MSG91/SNS ready)
```

---

## API Endpoints

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/api/v1/auth/send-otp` | No | Send OTP to phone number |
| POST | `/api/v1/auth/verify-otp` | No | Verify OTP, get JWT token |
| POST | `/api/v1/auth/society-login` | No | Society login (phone + password) |
| GET | `/api/v1/users/me` | Yes | Get current user profile |
| GET | `/api/v1/users/:id` | Yes | Get user by ID |
| POST | `/api/v1/societies` | Yes | Register a society |
| GET | `/api/v1/societies` | Yes | List societies |
| GET | `/api/v1/societies/:id` | Yes | Get society by ID |
| POST | `/api/v1/module-master` | Yes | Create a module |
| GET | `/api/v1/module-master` | Yes | List active modules |
| GET | `/api/v1/module-master/serial-number/:serialNumber` | Yes | Get module by serial number |
| GET | `/api/v1/module-master/:id` | Yes | Get module by ID |
| PUT | `/api/v1/module-master/:id` | Yes | Update a module |
| DELETE | `/api/v1/module-master/:id?deletedBy=` | Yes | Soft-delete a module |
| POST | `/api/v1/module-registration` | Yes | Register a module to a user |
| GET | `/api/v1/module-registration` | Yes | List active registrations |
| GET | `/api/v1/module-registration/module/user/:id` | Yes | List a user's registered modules |
| GET | `/api/v1/module-registration/:id` | Yes | Get registration by ID |
| PUT | `/api/v1/module-registration/:id` | Yes | Update a registration |
| DELETE | `/api/v1/module-registration/:id?deletedBy=` | Yes | Soft-delete (unregister) a module |

**Swagger UI:** `http://localhost:3000/api/docs`

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | NestJS 10 (TypeScript) |
| Database | PostgreSQL |
| ORM | Prisma 5 |
| Auth | JWT + Passport |
| Validation | class-validator |
| Documentation | Swagger / OpenAPI |
| Realtime | MQTT (motor telemetry) |
| Containerization | Docker + Docker Compose |
