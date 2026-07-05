# Vultr Mumbai + EMQX Setup Guide
## Complete Step-by-Step — Every Command Listed
### For AquaControl MQTT Broker (MQTT only, no NestJS here)

---

## What You Will Have at the End

```
Vultr Mumbai VPS (6$/month)
  └── EMQX Broker
        ├── Port 8883  — MQTT over TLS (ESP32 connects here)
        ├── Port 1883  — MQTT plain   (NestJS on AWS connects here)
        └── Port 18083 — Dashboard    (you access via browser)

Users created:
  backend_service     → NestJS backend
  esp32_{mac}         → each ESP32 device
  dev_tester          → local testing from laptop
```

---

# PART 1 — CREATE VULTR ACCOUNT AND SERVER

## Step 1 — Sign Up on Vultr

```
1. Go to https://vultr.com
2. Click "Sign Up"
3. Enter email and password
4. Verify email
5. Add payment method
   → Credit/debit card or PayPal
   → You get $100 free credit for 30 days automatically
```

## Step 2 — Deploy a New Server

```
1. After login, click "+ Deploy" (top right)
2. Select "Cloud Compute — Shared CPU"
```

### Choose Location:
```
Click: Mumbai
(Listed under Asia — "Mumbai, India")
```

### Choose Image:
```
Click: Ubuntu
Select: 22.04 LTS x64
```

### Choose Plan:
```
Click: "Regular Cloud Compute" tab

Select this plan:
  VC2-1C-2GB
  1 vCPU
  2 GB RAM
  55 GB SSD
  2 TB bandwidth
  $6/month

This is enough for EMQX with 1000+ devices.
```

### Add SSH Key:

First generate SSH key on your laptop if you don't have one:

```bash
# Run this on YOUR LAPTOP terminal
ssh-keygen -t rsa -b 4096 -C "aquacontrol@youremail.com"
# Press Enter 3 times (accept all defaults)

# Now copy your public key
cat ~/.ssh/id_rsa.pub
# Copy the entire output — starts with ssh-rsa ...
```

Back in Vultr:
```
Click "+ Add SSH Key"
Paste your public key
Name: my-laptop
Click "Add SSH Key"
```

### Server Hostname:
```
Hostname: aquacontrol-mqtt-1
```

### Click "Deploy Now"

Wait 60 seconds. Server status changes to "Running".

## Step 3 — Note Your Server IP

```
In Vultr dashboard → Servers list
You will see your server with an IP like:
  139.84.xxx.xxx

Copy this IP — you will use it everywhere below.
We will call it YOUR_SERVER_IP in all commands.
```

---

# PART 2 — FIRST LOGIN AND SYSTEM SETUP

## Step 4 — SSH Into Your Server

Open Terminal on your laptop:

```bash
ssh root@YOUR_SERVER_IP
```

First time you will see:
```
The authenticity of host 'xxx.xxx.xxx.xxx' can't be established.
RSA key fingerprint is SHA256:xxxxx
Are you sure you want to continue connecting (yes/no)? 
```

Type:
```bash
yes
```

You should now see:
```
root@aquacontrol-mqtt-1:~#
```

You are inside your server. ✅

## Step 5 — Update System Packages

```bash
apt update
```

```bash
apt upgrade -y
```

This takes 2-3 minutes. Wait for it to finish.

## Step 6 — Install Essential Tools

```bash
apt install -y curl wget nano ufw net-tools
```

## Step 7 — Set Up Firewall

```bash
ufw default deny incoming
```

```bash
ufw default allow outgoing
```

```bash
ufw allow 22/tcp
```

```bash
ufw allow 1883/tcp
```

```bash
ufw allow 8883/tcp
```

```bash
ufw allow 18083/tcp
```

```bash
ufw enable
```

When asked "Command may disrupt existing ssh sessions. Proceed with operation (y|n)?":
```bash
y
```

Verify firewall is active:
```bash
ufw status
```

Expected output:
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
1883/tcp                   ALLOW       Anywhere
8883/tcp                   ALLOW       Anywhere
18083/tcp                  ALLOW       Anywhere
22/tcp (v6)                ALLOW       Anywhere (v6)
1883/tcp (v6)              ALLOW       Anywhere (v6)
8883/tcp (v6)              ALLOW       Anywhere (v6)
18083/tcp (v6)             ALLOW       Anywhere (v6)
```

## Step 8 — Set Server Timezone to IST

```bash
timedatectl set-timezone Asia/Kolkata
```

Verify:
```bash
timedatectl
```

Expected:
```
Local time: Wed 2026-05-07 10:30:00 IST
Time zone: Asia/Kolkata (IST, +0530)
```

---

# PART 3 — INSTALL EMQX

## Step 9 — Add EMQX Repository

```bash
curl -s https://assets.emqx.com/scripts/install-emqx-deb.sh | bash
```

Wait for this to complete. You will see output about adding the repository.

## Step 10 — Install EMQX

```bash
apt-get install emqx -y
```

This takes 2-3 minutes to download and install.

## Step 11 — Start EMQX

```bash
systemctl start emqx
```

## Step 12 — Enable EMQX on Boot

```bash
systemctl enable emqx
```

Expected output:
```
Created symlink /etc/systemd/system/multi-user.target.wants/emqx.service
```

## Step 13 — Verify EMQX is Running

```bash
systemctl status emqx
```

Expected output:
```
● emqx.service - EMQX broker
     Loaded: loaded (/lib/systemd/system/emqx.service; enabled)
     Active: active (running) since ...
```

If not running, start it:
```bash
systemctl start emqx
```

## Step 14 — Verify EMQX Ports are Listening

```bash
ss -tlnp | grep emqx
```

Expected output (you should see these 4 ports):
```
LISTEN  0  1024  0.0.0.0:1883   ← MQTT plain
LISTEN  0  1024  0.0.0.0:8883   ← MQTT TLS
LISTEN  0  1024  0.0.0.0:8083   ← WebSocket
LISTEN  0  1024  0.0.0.0:18083  ← Dashboard
```

## Step 15 — Verify EMQX is Working

```bash
emqx ping
```

Expected:
```
pong
```

---

# PART 4 — ACCESS EMQX DASHBOARD

## Step 16 — Open Dashboard in Browser

On your laptop, open any browser:

```
http://YOUR_SERVER_IP:18083
```

Example:
```
http://139.84.142.88:18083
```

You should see the EMQX login page. ✅

## Step 17 — Login with Default Credentials

```
Username: admin
Password: public
```

Click "Login"

You will see the EMQX dashboard showing:
- Connected clients: 0
- Topics: 0
- Messages/sec: 0

---

# PART 5 — SECURE EMQX

## Step 18 — Change Admin Password

In the EMQX Dashboard:

```
1. Click "admin" at top right corner
2. Click "Change Password"
3. Old Password: public
4. New Password: Admin@AquaControl2026!
5. Confirm Password: Admin@AquaControl2026!
6. Click "Save"
```

You will be logged out. Log in again with your new password.

## Step 19 — Enable Username/Password Authentication

```
1. Left sidebar → "Access Control"
2. Click "Authentication"
3. Click "+ Create" button (top right)
4. Select "Password-Based"
5. Click "Next"
6. Select "Built-in Database"
7. Click "Next"
8. Password Hash Algorithm: "bcrypt"
9. Click "Create"
```

You should see "Built-in Database" authenticator created with status "Enabled".

## Step 20 — Create MQTT User: backend_service

```
1. Click on your "Built-in Database" authenticator
2. Click "Users" tab
3. Click "+ Add User"
4. Username: backend_service
5. Password: Backend@Aqua2026!
6. Click "Save"
```

## Step 21 — Create MQTT User: dev_tester

```
1. Still in Users tab
2. Click "+ Add User"
3. Username: dev_tester
4. Password: DevTest@2026!
5. Click "Save"
```

## Step 22 — Create MQTT User for ESP32 Device

```
1. Still in Users tab
2. Click "+ Add User"
3. Username: esp32_aabbccddeeff    ← use actual MAC address of your ESP32
4. Password: Device@Aqua2026!
5. Click "Save"
```

Note: Create one user per ESP32 device using its MAC address.

## Step 23 — Disable Anonymous Access

```
1. Go to "Access Control" → "Authentication"
2. Click on your "Built-in Database" authenticator
3. Find setting "Allow Anonymous Access"
4. Toggle it to OFF
5. Click "Update" or "Save"
```

## Step 24 — Verify All Users Are Created

```
Access Control → Authentication → Built-in Database → Users tab

You should see:
  backend_service
  dev_tester
  esp32_aabbccddeeff
```

---

# PART 6 — TEST AUTHENTICATION FROM LAPTOP

Install MQTTX CLI on your laptop (NOT on VPS):

## Step 25 — Install MQTTX on Laptop

Mac:
```bash
brew install mqttx
```

Linux:
```bash
npm install -g mqttx
```

Windows:
```
Download installer from: https://mqttx.app/cli
```

## Step 26 — Test Connection WITH Credentials (should work)

Run this on YOUR LAPTOP:

```bash
mqttx conn \
  --hostname YOUR_SERVER_IP \
  --port 1883 \
  --username dev_tester \
  --password "DevTest@2026!"
```

Expected:
```
✔ Connected
```

Press Ctrl+C to disconnect.

## Step 27 — Test Connection WITHOUT Credentials (should fail)

```bash
mqttx conn \
  --hostname YOUR_SERVER_IP \
  --port 1883
```

Expected:
```
✗ Connection refused: Not authorized
```

Authentication is working correctly. ✅

---

# PART 7 — INSTALL SSL CERTIFICATE FOR TLS

ESP32 needs TLS on port 8883. We use Let's Encrypt.

## Step 28 — Point a Domain to Your Vultr IP

Before this step you need a domain name.
If you have one, add a DNS A record:

```
Type:  A
Name:  mqtt
Value: YOUR_SERVER_IP

Full domain: mqtt.yourdomain.com → YOUR_SERVER_IP
```

Wait 5-10 minutes for DNS to propagate.

Verify DNS is working:
```bash
nslookup mqtt.yourdomain.com
```

Expected — it should show your server IP.

## Step 29 — Install Certbot

Run on VPS:

```bash
apt install certbot -y
```

## Step 30 — Get SSL Certificate

```bash
certbot certonly --standalone -d mqtt.yourdomain.com
```

When asked:
```
Enter email address: your@email.com
Agree to terms: A
Share email with EFF: N
```

Expected output:
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/mqtt.yourdomain.com/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/mqtt.yourdomain.com/privkey.pem
```

## Step 31 — Copy Certificates to EMQX

```bash
mkdir -p /etc/emqx/certs
```

```bash
cp /etc/letsencrypt/live/mqtt.yourdomain.com/fullchain.pem /etc/emqx/certs/
```

```bash
cp /etc/letsencrypt/live/mqtt.yourdomain.com/privkey.pem /etc/emqx/certs/
```

```bash
chown -R emqx:emqx /etc/emqx/certs
```

```bash
chmod 600 /etc/emqx/certs/privkey.pem
```

Verify files are there:
```bash
ls -la /etc/emqx/certs/
```

Expected:
```
-rw-r--r-- emqx emqx fullchain.pem
-rw------- emqx emqx privkey.pem
```

## Step 32 — Configure TLS in EMQX

```bash
nano /etc/emqx/emqx.conf
```

Add these lines at the bottom of the file:

```hocon
listeners.ssl.default {
  bind = "0.0.0.0:8883"
  ssl_options {
    certfile = "/etc/emqx/certs/fullchain.pem"
    keyfile  = "/etc/emqx/certs/privkey.pem"
    verify   = verify_none
  }
}
```

Save and exit:
```
Press Ctrl+X
Press Y
Press Enter
```

## Step 33 — Restart EMQX to Apply TLS

```bash
systemctl restart emqx
```

Wait 5 seconds then check status:

```bash
systemctl status emqx
```

Expected:
```
Active: active (running)
```

## Step 34 — Set Up Auto Certificate Renewal

Create renewal hook script:

```bash
nano /etc/letsencrypt/renewal-hooks/deploy/emqx-reload.sh
```

Paste exactly:

```bash
#!/bin/bash
cp /etc/letsencrypt/live/mqtt.yourdomain.com/fullchain.pem /etc/emqx/certs/
cp /etc/letsencrypt/live/mqtt.yourdomain.com/privkey.pem /etc/emqx/certs/
chown emqx:emqx /etc/emqx/certs/*.pem
chmod 600 /etc/emqx/certs/privkey.pem
systemctl reload emqx
echo "EMQX certs renewed at $(date)" >> /var/log/emqx-cert-renewal.log
```

Save and exit (Ctrl+X → Y → Enter).

Make it executable:

```bash
chmod +x /etc/letsencrypt/renewal-hooks/deploy/emqx-reload.sh
```

Test auto renewal works:

```bash
certbot renew --dry-run
```

Expected:
```
Congratulations, all simulated renewals succeeded
```

---

# PART 8 — TEST TLS CONNECTION

## Step 35 — Test TLS From Laptop

```bash
mqttx conn \
  --hostname mqtt.yourdomain.com \
  --port 8883 \
  --username dev_tester \
  --password "DevTest@2026!" \
  --tls
```

Expected:
```
✔ Connected
```

TLS is working. ✅

---

# PART 9 — TEST FULL PUB/SUB FLOW

## Step 36 — Open Two Terminal Windows on Laptop

**Terminal 1 — Subscribe (listener):**

```bash
mqttx sub \
  --hostname YOUR_SERVER_IP \
  --port 1883 \
  --username dev_tester \
  --password "DevTest@2026!" \
  --topic "societies/+/motors/+/alerts" \
  --verbose
```

Expected:
```
✔ Connected
✔ Subscribed to societies/+/motors/+/alerts
```

Keep this terminal open and waiting.

**Terminal 2 — Publish (sender):**

```bash
mqttx pub \
  --hostname YOUR_SERVER_IP \
  --port 1883 \
  --username dev_tester \
  --password "DevTest@2026!" \
  --topic "societies/SOC001/motors/esp32_aabbccddeeff/alerts" \
  --message '{"alert":"OC","value":8.6,"threshold":8.0,"ts":1746123456}' \
  --qos 1
```

Expected in Terminal 1:
```
societies/SOC001/motors/esp32_aabbccddeeff/alerts
{"alert":"OC","value":8.6,"threshold":8.0,"ts":1746123456}
```

## Step 37 — Test All 4 Topics

**Telemetry (QoS 0):**
```bash
mqttx pub \
  --hostname YOUR_SERVER_IP \
  --port 1883 \
  --username dev_tester \
  --password "DevTest@2026!" \
  --topic "societies/SOC001/motors/esp32_aabbccddeeff/telemetry" \
  --message '{"v":232,"i":4.2,"oh":68,"ug":45,"motor":true,"ts":1746123456}' \
  --qos 0
```

**Command (QoS 1):**
```bash
mqttx pub \
  --hostname YOUR_SERVER_IP \
  --port 1883 \
  --username backend_service \
  --password "Backend@Aqua2026!" \
  --topic "societies/SOC001/motors/esp32_aabbccddeeff/commands" \
  --message '{"cmd":"TURN_ON","cmd_id":"abc-123","issued_by":"user_001","ts":1746123456}' \
  --qos 1
```

**Heartbeat (QoS 0):**
```bash
mqttx pub \
  --hostname YOUR_SERVER_IP \
  --port 1883 \
  --username dev_tester \
  --password "DevTest@2026!" \
  --topic "societies/SOC001/motors/esp32_aabbccddeeff/heartbeat" \
  --message '{"fw":"1.0.0","rssi":-62,"uptime":3600,"oc_set":8.0,"uc_set":0.5,"ts":1746123456}' \
  --qos 0
```

---

# PART 10 — MONITOR IN DASHBOARD

## Step 38 — Check Dashboard

Open browser: `http://YOUR_SERVER_IP:18083`

```
Home → Overview
  Shows: connected clients, messages/sec

Monitoring → Clients
  Shows: each connected MQTTX client
  Click any client to see its subscriptions

Monitoring → Topics
  Shows: active topics after first message

Access Control → Authentication → Users
  Verify your 3 users are listed
```

---

# PART 11 — USEFUL COMMANDS REFERENCE

## EMQX Service Commands

Check status:
```bash
systemctl status emqx
```

Start EMQX:
```bash
systemctl start emqx
```

Stop EMQX:
```bash
systemctl stop emqx
```

Restart EMQX:
```bash
systemctl restart emqx
```

Reload config (without dropping connections):
```bash
systemctl reload emqx
```

## EMQX CLI Commands

Check EMQX is alive:
```bash
emqx ping
```

Check EMQX version:
```bash
emqx version
```

List all connected clients:
```bash
emqx ctl clients list
```

List all active subscriptions:
```bash
emqx ctl subscriptions list
```

Show EMQX broker info:
```bash
emqx ctl broker
```

## View EMQX Logs

Live log stream:
```bash
tail -f /var/log/emqx/emqx.log
```

Last 100 lines:
```bash
tail -100 /var/log/emqx/emqx.log
```

Search for errors:
```bash
grep -i error /var/log/emqx/emqx.log
```

Search for specific client:
```bash
grep "esp32_aabbccddeeff" /var/log/emqx/emqx.log
```

## Server Health Commands

Check RAM usage:
```bash
free -h
```

Check CPU usage:
```bash
top
```

Check disk usage:
```bash
df -h
```

Check open ports:
```bash
ss -tlnp
```

Check firewall status:
```bash
ufw status
```

---

# PART 12 — ADD MORE ESP32 DEVICES

Every time you add a new ESP32 device:

## Step 39 — Add New Device User via Dashboard

```
Access Control → Authentication → Built-in Database → Users
→ Add User
→ Username: esp32_{MAC_OF_NEW_DEVICE}
→ Password: unique strong password for this device
→ Save
```

Or via CLI on VPS:

```bash
emqx ctl authentication user_management add \
  --user-id esp32_newdevicemac \
  --password "NewDevice@2026!"
```

That is it. No other config needed.
EMQX automatically routes topics for new devices.

---

# QUICK REFERENCE CARD

```
═══════════════════════════════════════════════════════
  EMQX DASHBOARD
  URL:       http://YOUR_SERVER_IP:18083
  Username:  admin
  Password:  Admin@AquaControl2026!
═══════════════════════════════════════════════════════
  MQTT CONNECTION DETAILS
  Host:      YOUR_SERVER_IP  (or mqtt.yourdomain.com)
  Port:      1883  → NestJS backend (plain)
  Port:      8883  → ESP32 devices (TLS)
═══════════════════════════════════════════════════════
  MQTT USERS
  backend_service  /  Backend@Aqua2026!   → NestJS
  esp32_MACADDR    /  Device@Aqua2026!    → ESP32
  dev_tester       /  DevTest@2026!       → Testing
═══════════════════════════════════════════════════════
  TOPICS
  societies/{id}/motors/{device}/commands   QoS 1
  societies/{id}/motors/{device}/telemetry  QoS 0
  societies/{id}/motors/{device}/alerts     QoS 1
  societies/{id}/motors/{device}/heartbeat  QoS 0
═══════════════════════════════════════════════════════
  KEY COMMANDS
  systemctl status emqx    → check if running
  emqx ping                → quick health check
  tail -f /var/log/emqx/emqx.log → live logs
  ufw status               → check firewall
═══════════════════════════════════════════════════════
```

---

# COMMON ERRORS AND FIXES

```
ERROR: ssh: connect to host xxx port 22: Connection refused
FIX:   Wait 60 seconds after server creation then try again

ERROR: Connection refused on port 1883
FIX:   sudo systemctl start emqx
       sudo ufw allow 1883/tcp

ERROR: Not authorized (MQTT connection rejected)
FIX:   Check username and password exactly match what you
       created in Step 20-22
       Anonymous access must be disabled after creating users

ERROR: systemctl status emqx shows "failed"
FIX:   Check logs: tail -50 /var/log/emqx/emqx.log
       Usually a config syntax error: nano /etc/emqx/emqx.conf

ERROR: TLS connection refused on port 8883
FIX:   Check cert files exist: ls -la /etc/emqx/certs/
       Check EMQX config: nano /etc/emqx/emqx.conf
       Restart: systemctl restart emqx

ERROR: Certificate not found
FIX:   Run certbot again: certbot certonly --standalone -d mqtt.yourdomain.com
       Make sure DNS points to your server IP first

ERROR: Dashboard not loading on port 18083
FIX:   Check firewall: ufw allow 18083/tcp
       Check EMQX running: systemctl status emqx
       Try: http:// not https://
```
