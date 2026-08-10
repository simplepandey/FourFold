# Deploy Backend to a Vultr Compute Instance
## Complete Step-by-Step — Every Command Listed
### For FourFold NestJS API (fourfold-api-1)

Ties together the other two Vultr pieces already set up:
- MQTT broker → `vultr-emqx-complete-guide.md` (repo root)
- Database → `dbserver.md` (repo root, Managed DB) or `steps.txt` (self-hosted Docker Postgres)

---

## What You Will Have at the End

```
Vultr Mumbai VPS — fourfold-api-1 ($6/month)
  └── Nginx (80/443, Let's Encrypt TLS)
        └── fourfold-api container (127.0.0.1:3000, not public)
              ├── connects to → Postgres on fourfold-api-1 (or Managed DB)
              └── connects to → EMQX broker on aquacontrol-mqtt-1

Public URL:  https://api.fourfoldsystem.com  (already hardcoded in
             the Flutter app's AppConfig._DevConfig.baseUrl)
```

---

# PART 1 — CREATE THE API SERVER

## Step 1 — Deploy a New Server

```
1. Go to https://console.vultr.com
2. Click "+ Deploy" → "Cloud Compute — Shared CPU"
3. Location: Mumbai (same region as your EMQX and DB VPSs)
4. Image: Ubuntu 22.04 LTS x64
5. Plan: VC2-1C-2GB ($6/month) — bump to VC2-2C-4GB if you see memory pressure under load
6. SSH Key: reuse "my-laptop" from your other VPSs
7. Hostname: fourfold-api-1
8. Click "Deploy Now"
```

## Step 2 — Note the IP

```
Servers list → copy the IP, e.g. 45.63.xxx.xxx
We'll call it YOUR_API_SERVER_IP below.
```

---

# PART 2 — SYSTEM SETUP + DOCKER

## Step 3 — SSH In and Update

```bash
ssh root@YOUR_API_SERVER_IP
apt update && apt upgrade -y
apt install -y curl wget nano ufw git
timedatectl set-timezone Asia/Kolkata
```

## Step 4 — Install Docker

```bash
curl -fsSL https://get.docker.com | sh
systemctl enable docker
docker --version && docker compose version
```

---

# PART 3 — FIREWALL

## Step 5 — Base Rules + HTTPS

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

Notice **3000 is not opened publicly** — the app listens on `localhost:3000` only, Nginx (Part 6) is the sole public entry point on 80/443. This matches how the Flutter app is already configured to talk to `https://...` domains, not raw `:3000`.

## Step 6 — Allow This Server to Reach Your Database

On the **database VPS** (`fourfold-api-1`, from `steps.txt`), add this server's IP:

```bash
ssh root@YOUR_DB_SERVER_IP
ufw allow from YOUR_API_SERVER_IP to any port 5432 proto tcp
ufw status   # confirm it's listed
exit
```

This is the "YOUR_BACKEND_IP" placeholder from `steps.txt` Step 11 — now you have the real value.

> If you're using the Vultr Managed Database (`dbserver.md`) instead, add `YOUR_API_SERVER_IP` to its **Trusted Sources** list in the Vultr console instead of `ufw` — same idea, different mechanism. If the API server is attached to `forfold-vpc`, you can skip this entirely and use the DB's private VPC IP.

---

# PART 4 — GET THE CODE ONTO THE SERVER

## Step 7 — Clone the Repo

If the repo is private, add a deploy key first: generate one on the server, add its public half to GitHub (repo → Settings → Deploy keys → read-only is enough).

```bash
ssh-keygen -t ed25519 -C "fourfold-api-1" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```
Paste that into GitHub → your repo → Settings → Deploy keys → "Add deploy key" (read-only).

```bash
mkdir -p /opt/fourfold
cd /opt/fourfold
git clone git@github.com:<your-org>/<your-repo>.git .
cd backend
```

---

# PART 5 — CONFIGURE THE APP

## Step 8 — Generate a JWT Secret

```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```
(No Node yet? Skip this — you'll run it in Part 6 via Docker instead, or just `openssl rand -hex 64`.)

## Step 9 — Create `.env`

```bash
nano .env
```

```env
NODE_ENV=production
PORT=3000

# Points at fourfold-api-1 from steps.txt — swap for the Vultr Managed
# Database connection string instead if you went that route (dbserver.md)
DATABASE_URL=postgresql://fourfold_app:YOUR_DB_PASSWORD@YOUR_DB_SERVER_IP:5432/fourfold_db

JWT_SECRET=PASTE_GENERATED_SECRET_HERE
JWT_EXPIRES_IN=7d

OTP_EXPIRY_MINUTES=5
OTP_LENGTH=6
SMS_PROVIDER=console

MSG91_AUTH_KEY=your_msg91_auth_key
MSG91_WIDGET_AUTH_KEY=your_msg91_widget_auth_key

DEVICE_BASIC_AUTH_USERNAME=fourfold
DEVICE_BASIC_AUTH_PASSWORD=set_a_real_password_here

# Points at your EMQX VPS from vultr-emqx-complete-guide.md
MQTT_HOST=YOUR_EMQX_SERVER_IP
MQTT_PORT=1883
MQTT_USERNAME=backend_service
MQTT_PASSWORD=Backend@Aqua2026!
MQTT_TELEMETRY_TOPIC=motors/+/telemetry
```

Save: `Ctrl+X` → `Y` → `Enter`.

---

# PART 6 — BUILD, RUN, AND EXPOSE

## Step 10 — Create a Deploy Compose File

The repo's own `backend/docker-compose.yml` also spins up its *own* Postgres + pgAdmin — you don't want that here since Postgres already lives on a separate VPS. Create a deploy-only override instead:

```bash
nano docker-compose.prod.yml
```

```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: fourfold-api
    restart: unless-stopped
    ports:
      - '127.0.0.1:3000:3000'   # only reachable via Nginx, not directly from outside
    env_file:
      - .env
    volumes:
      - ./logs:/usr/src/app/logs   # persists app-YYYY-MM-DD.log / error-YYYY-MM-DD.log on the host
```

## Step 11 — Build and Start

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

Expected:
```
[+] Running 2/2
 ✔ Container fourfold-api  Started
```

## Step 12 — Check Logs

```bash
docker compose -f docker-compose.prod.yml logs -f api
```

Expected:
```
[Bootstrap] Swagger UI: http://localhost:3000/api/docs
[PrismaService] Database connected successfully
[EspTopicCacheService] Cached MQTT topics for N device(s)
[Bootstrap] Server running on http://localhost:3000
[MqttService] Connected to MQTT broker at YOUR_EMQX_SERVER_IP:1883
```

If `PrismaService` fails to connect: re-check Part 3 Step 6 (firewall) and the `DATABASE_URL` in `.env`.

## Step 12b — File Logs + 6-Month Retention Cron

The app writes structured logs to disk (via `winston`/`nest-winston`, `src/common/logger/winston.config.ts`) in addition to the console output `docker compose logs` already shows — console output disappears once a container is removed/rebuilt, these files don't:

```
backend/logs/app-2026-08-05.log     # all levels
backend/logs/error-2026-08-05.log   # errors only
```

One file per day, new files start automatically at midnight — no manual rotation step needed. The app itself never deletes old files (no `maxFiles` set on the transport), so retention is handled entirely by a cron:

```bash
# Runs daily at 3:15am — deletes any log file untouched for 180+ days
(crontab -l 2>/dev/null; echo "15 3 * * * find /opt/fourfold/backend/logs -type f -mtime +180 -delete") | crontab -

# Verify it's installed
crontab -l
```

## Step 13 — Push the Schema

Do this from wherever `DATABASE_URL` is already reachable and trusted (your laptop, matching how you've done it in `dbserver.md`/`steps.txt`) — the production container's image was built with `npm install --omit=dev`, so the `prisma` CLI isn't inside it, only the generated client is.

```bash
# on your laptop
cd backend
DATABASE_URL="postgresql://fourfold_app:YOUR_DB_PASSWORD@YOUR_DB_SERVER_IP:5432/fourfold_db" npx prisma db push
```

---

# PART 7 — HTTPS VIA NGINX + LET'S ENCRYPT

Your Flutter app's `AppConfig` already expects `https://api.fourfoldsystem.com` and `https://api.aquacontrol.in` — point one of those at this server.

## Step 14 — DNS

```
Add an A record:
  Name:  dev-api  (or api, for prod)
  Value: YOUR_API_SERVER_IP

Full domain: api.fourfoldsystem.com → YOUR_API_SERVER_IP
```

Wait for propagation, verify:
```bash
nslookup api.fourfoldsystem.com
```

## Step 15 — Install Nginx + Certbot

```bash
apt install -y nginx certbot python3-certbot-nginx
```

## Step 16 — Configure the Reverse Proxy

```bash
nano /etc/nginx/sites-available/fourfold-api
```

```nginx
server {
    listen 80;
    server_name api.fourfoldsystem.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
ln -s /etc/nginx/sites-available/fourfold-api /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

## Step 17 — Get the Certificate

```bash
certbot --nginx -d api.fourfoldsystem.com
```
```
Enter email address: your@email.com
Agree to terms: A
Share email with EFF: N
```

Certbot edits the Nginx config automatically to add the `listen 443 ssl` block and redirect HTTP → HTTPS.

## Step 18 — Verify

```bash
curl https://api.fourfoldsystem.com/api/docs
```

Or just open `https://api.fourfoldsystem.com/api/docs` in a browser — should show Swagger UI over HTTPS.

Auto-renewal is set up by certbot's own systemd timer; confirm it:
```bash
certbot renew --dry-run
```

---

# PART 8 — CONNECT THE FLUTTER APP

Your `_DevConfig.baseUrl` in `app_config.dart` should already be `https://api.fourfoldsystem.com/api/v1` — no code change needed, just run:

```bash
flutter run --dart-define=APP_ENV=dev
```

---

# REDEPLOYING AFTER CODE CHANGES

```bash
cd /opt/fourfold
git pull
cd backend
docker compose -f docker-compose.prod.yml up -d --build
```

If the schema only *added* something (a new nullable column, a new table with
no data to move), re-running Step 13 (`prisma db push`) from your laptop is
still fine. **If the schema change moves or drops existing columns — like the
`topics` table extraction — do NOT use `db push`.** `db push` just diffs and
applies directly; for that kind of change it means an instant `DROP COLUMN`
with no backfill, so whatever data was in those columns is gone. Use the
migration procedure below instead.

---

# DEPLOYING A DATA-MIGRATING SCHEMA CHANGE (e.g. the `topics` table)

This applies whenever a migration under `backend/prisma/migrations/` does more
than add a column — anything that moves data between tables (like extracting
`commandTopic`/`telemetryTopic`/`alertTopic`/`heartbeatTopic` off
`EspRegistration` into a new `topics` table) needs this procedure, not `db
push`, so existing rows keep their data.

## Step 1 — Back Up the Database First

Non-negotiable before touching a production schema. From your laptop (wherever
`DATABASE_URL` is already reachable, same place Step 13 works from):

```bash
pg_dump "postgresql://fourfold_app:YOUR_DB_PASSWORD@YOUR_DB_SERVER_IP:5432/fourfold_db" \
  -F c -f fourfold_db_backup_$(date +%Y%m%d%H%M%S).dump
```

If this fails because `pg_dump` isn't installed locally: `brew install postgresql@16` (macOS) gets you the client tools without a full server install.

## Step 2 — Push the Code (from your laptop)

```bash
cd /Users/simplepandey/Documents/claude_project/FourFold
git add backend/prisma backend/src backend/.gitignore
git commit -m "Extract ESP MQTT topics into their own table"
git push
```

## Step 3 — Pull and Pre-Build on the Server (don't cut over yet)

```bash
ssh root@YOUR_API_SERVER_IP
cd /opt/fourfold/FourFold/backend
git pull
docker compose -f docker-compose.prod.yml build   # build only — old container keeps serving traffic
```

## Step 4 — Baseline the Existing Migrations (one-time only)

Production has only ever used `db push`, so — same as the local dev DB before
this change — there's no `_prisma_migrations` history table yet. Skip this
step on any future migration once this has been done once.

From your laptop:

```bash
cd backend
DATABASE_URL="postgresql://fourfold_app:YOUR_DB_PASSWORD@YOUR_DB_SERVER_IP:5432/fourfold_db" \
  npx prisma migrate resolve --applied 20260520161135_init

DATABASE_URL="postgresql://fourfold_app:YOUR_DB_PASSWORD@YOUR_DB_SERVER_IP:5432/fourfold_db" \
  npx prisma migrate resolve --applied 20260520164822_add_societies
```

(If your laptop can't reach the DB port directly, run these same two commands
over SSH on the API server instead, using a container built from the
`development` Dockerfile stage — that stage has the full `prisma` CLI that
the slim production image intentionally omits.)

## Step 5 — Apply the Migration

```bash
DATABASE_URL="postgresql://fourfold_app:YOUR_DB_PASSWORD@YOUR_DB_SERVER_IP:5432/fourfold_db" \
  npx prisma migrate deploy
```

Expected: `Applying migration 20260810191857_add_topics_table` → `All
migrations have been successfully applied.` This is the same
backfill-then-drop SQL already verified against the local dev DB — it copies
each existing row's 4 topic values into the new `topics` table (reusing the
`esp_registrations` row's own `id` as the topic's `id`) before dropping the
old columns, so nothing is lost.

## Step 6 — Cut Over Immediately

The old container is still running against the now-migrated DB at this point
— its bundled Prisma Client doesn't know the old columns are gone, so any
device/topic query will error until this step finishes. Since the image was
already built in Step 3, this is just a fast restart, not a rebuild:

```bash
# back on the server
docker compose -f docker-compose.prod.yml up -d
```

## Step 7 — Verify

```bash
docker compose -f docker-compose.prod.yml logs -f api   # no Prisma errors on boot
curl https://api.fourfoldsystem.com/api/v1/device/register/<a real serial number>
```

Confirm the response still has the same `topics: { commands, telemetry,
alert, heartbeat }` shape as before — the API payload was deliberately kept
unchanged even though the DB structure moved.

---

# COMMON ERRORS AND FIXES

```
ERROR: 502 Bad Gateway from Nginx
FIX:   Container isn't running / crashed. Check:
       docker compose -f docker-compose.prod.yml logs api

ERROR: PrismaService fails to connect on boot
FIX:   DB VPS firewall doesn't have this server's IP allowed yet
       (Part 3, Step 6), or DATABASE_URL in .env is wrong.

ERROR: certbot fails "Challenge failed"
FIX:   DNS hasn't propagated yet, or port 80 isn't open
       (ufw allow 80/tcp) — certbot needs HTTP first to issue the cert.

ERROR: MqttService stuck "Reconnecting..."
FIX:   Check MQTT_HOST/USERNAME/PASSWORD in .env match what's set up
       on the EMQX VPS, and that EMQX's firewall allows this
       server's IP on 1883 if you locked that down too.

ERROR: git clone permission denied (publickey)
FIX:   The deploy key (Step 7) wasn't added to GitHub, or was added
       as write-only when your workflow needs read (should be fine
       either way for cloning — check it was added at all).
```
