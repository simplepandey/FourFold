# Vultr Managed Database Setup Guide
## Complete Step-by-Step — Every Command Listed
### For AquaControl / FourFold PostgreSQL Database

---

## What You Will Have at the End

```
Vultr Managed Database (PostgreSQL)
  ├── Database:  fourfold_db
  ├── User:      fourfold_app
  ├── Backups:   Automatic, daily, 7-day retention
  └── Network:   Attached to VPC "forfold-vpc" (10.46.96.0/20)
                   ├── Private IP reachable by any Vultr resource on
                   │     the same VPC, same region — no public exposure
                   └── Public hostname + Trusted Sources allowlist
                         as a fallback for anything off-Vultr (e.g. a
                         laptop, or a backend hosted on AWS)
```

---

# PART 1 — CREATE THE MANAGED DATABASE

## Step 1 — Open Vultr Console

```
1. Go to https://console.vultr.com
2. Left sidebar → "Databases" (under Products)
3. Click "+ Deploy Database"
```

## Step 2 — Choose Database Engine

```
Select: PostgreSQL
Version: 16 (or 15 to match local dev)
```

## Step 3 — Choose Location

```
Same region as your other Vultr resources (Mumbai, per the EMQX VPS
and the forfold-vpc network) — VPC-private networking only works
within a single region.
```

## Step 4 — Choose Plan

```
Database-1C-1GB
  1 vCPU, 1GB RAM, 15GB storage
  ~$15/month
Scale up later without downtime if needed.
```

## Step 5 — VPC Network

```
Select VPC Network: forfold-vpc
```

If `forfold-vpc` doesn't exist yet, create it first:
```
1. Left sidebar → "Network" → "VPC Network"
2. Click "+ Add VPC Network"
3. Region: same as the database (Mumbai)
4. Description: forfold-vpc
5. Click "Add VPC Network"
```

VPC networking on Vultr is **free** — no extra charge for creating or attaching to it, you only pay for the database/compute plans themselves.

## Step 6 — Automatic Backups

```
Toggle "Automatic Backups": ON
```

Included in the base price — no reason to turn it off. Default retention is 7 days.

## Step 7 — Database Label

```
Label: fourfold-db
```

Click **"Deploy Now"**. Wait 2–3 minutes for status to become "Running".

---

# PART 2 — GET CONNECTION DETAILS

## Step 8 — Open the Database

```
Products → Databases → fourfold-db
```

**Connection Details** panel shows:

```
Public Host:   fourfold-db-xxxxx.vultrdb.com
Public Port:   16751            (Vultr assigns a random port, not 5432)
Private Host:  10.46.96.x        (only reachable from forfold-vpc)
Private Port:  5432 (usually the standard port on the private side)
Username:      vultradmin
Password:      (click "Show" to reveal)
Database:      defaultdb
```

Copy the private host/port if your backend will live on `forfold-vpc`; copy the public host/port if it won't.

## Step 9 — Note the SSL Requirement

Vultr Managed Databases require SSL (`?sslmode=require`) on the **public** connection. The private VPC connection does not require it (traffic never leaves Vultr's internal network), but it's still safe to include.

---

# PART 3 — CREATE YOUR OWN DATABASE AND USER

## Step 10 — Create `fourfold_db`

```
1. Inside the database instance page, click the "Databases" tab
2. Click "+ Create Database"
3. Name: fourfold_db
4. Click "Create"
```

## Step 11 — Create a Dedicated App User

```
1. Click the "Users" tab
2. Click "+ Create User"
3. Username: fourfold_app
4. Click "Create" — click "Show" to copy the generated password
```

---

# PART 4 — NETWORK ACCESS

## Step 12 — Attach Your Backend to `forfold-vpc` (if it's on Vultr)

If your NestJS backend runs (or will run) on a Vultr Compute instance in the same region:

```
1. Products → Compute → select the backend instance
2. Settings → Network → "Attach VPC Network"
3. Select: forfold-vpc
```

The instance gets a private IP in the `10.46.96.0/20` range. It can now reach the database's **private host** directly — no public internet, no firewall rule needed for this leg.

## Step 13 — Trusted Sources (only needed for non-VPC access)

For anything reaching the database over the **public** hostname — your laptop for `psql`/`prisma studio`, or a backend hosted off-Vultr (e.g. AWS):

```
1. Database page → "Settings" tab
2. Scroll to "Trusted Sources"
3. Click "+ Add Trusted Source"
4. Add the public IP of each machine that needs access
   (curl ifconfig.me on that machine to find it)
5. Click "Add"
```

> A laptop on a home ISP without a static IP will need re-adding here whenever its IP changes.

---

# PART 5 — POINT THE BACKEND AT IT

## Step 14 — Build the Connection String

**If backend is on `forfold-vpc` (private, recommended):**
```
postgresql://fourfold_app:<PASSWORD>@10.46.96.x:5432/fourfold_db
```

**If backend is off-Vultr (public + Trusted Sources):**
```
postgresql://fourfold_app:<PASSWORD>@fourfold-db-xxxxx.vultrdb.com:16751/fourfold_db?sslmode=require
```

## Step 15 — Update `.env`

```bash
nano backend/.env
```

```env
DATABASE_URL=postgresql://fourfold_app:YOUR_PASSWORD@<HOST>:<PORT>/fourfold_db[?sslmode=require]
```

## Step 16 — Push the Schema

```bash
cd backend
npx prisma db push
npx prisma generate
```

Expected:
```
🚀  Your database is now in sync with your Prisma schema.
```

Creates every table (`users`, `societies`, `module_status`, `module_action_logs`, `topic_pattern_to_subscribe`, etc.) on the Vultr database.

## Step 17 — Verify

```bash
psql "$DATABASE_URL" -c "\dt"
```

Expected: full table list.

Start the backend and confirm:
```bash
npm run start:dev
```
```
[PrismaService] Database connected successfully
```

---

# PART 6 — BACKUPS

Automatic daily backups are already enabled (Step 6).

## Step 18 — Confirm / Adjust Retention

```
Database page → "Backups" tab
Confirm "Automatic Backups" is ON
Retention: 7 days (default) — increase in Settings if you want longer
```

## Step 19 — Manual Snapshot (before risky changes, e.g. a big migration)

```
Backups tab → "Take Snapshot Now"
```

---

# QUICK REFERENCE CARD

```
═══════════════════════════════════════════════════════
  DATABASE
  Label:         fourfold-db
  Database:      fourfold_db
  User:          fourfold_app
═══════════════════════════════════════════════════════
  NETWORK
  VPC:           forfold-vpc
  VPC Subnet:    10.46.96.0/20
  Private conn:  10.46.96.x:5432   (Vultr resources on forfold-vpc)
  Public conn:   fourfold-db-xxxxx.vultrdb.com:16751  (+ sslmode=require,
                   requires Trusted Sources allowlist)
═══════════════════════════════════════════════════════
  BACKUPS
  Automatic:     ON, 7-day retention
═══════════════════════════════════════════════════════
```

---

# COMMON ERRORS AND FIXES

```
ERROR: connection refused / timeout (private IP)
FIX:   Backend instance isn't attached to forfold-vpc, or the DB
       isn't attached to the same VPC. Check both under
       Settings → Network on each resource.

ERROR: connection refused / timeout (public hostname)
FIX:   Your IP isn't in Trusted Sources (Part 4, Step 13).

ERROR: no pg_hba.conf entry for host, no encryption
FIX:   You forgot ?sslmode=require on the public connection string.
       Not needed on the private VPC connection.

ERROR: password authentication failed
FIX:   Re-copy the password from the dashboard — it's masked by
       default, click "Show" and copy exactly, no trailing space.

ERROR: prisma db push hangs / times out
FIX:   Usually a network-path issue — confirm you're using the
       right host/port for how you're actually connecting
       (private vs public), and that path is allowed through.
```
