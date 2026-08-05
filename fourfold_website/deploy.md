# Deploy the FourFold Website to the Existing API Server
## Complete Step-by-Step — Every Command Listed

This reuses the **same** Vultr VPS the backend already runs on (`fourfold-api-1`,
see `backend/deploy.md`) — no new server needed. Nginx there already
terminates TLS for `api.fourfoldsystem.com` via a single config file at
`/etc/nginx/sites-available/fourfold-api`. Rather than creating a second
file, we **append** two more `server {}` blocks to that same file for the
static marketing site, on the apex + `www` domain.

---

## What You Will Have at the End

```
Vultr Mumbai VPS — fourfold-api-1 (same box as the API)
  └── Nginx (80/443, Let's Encrypt TLS)
        ├── api.fourfoldsystem.com        → proxy_pass → fourfold-api container (unchanged)
        └── fourfoldsystem.com            → 301 redirect → https://www.fourfoldsystem.com
            www.fourfoldsystem.com        → static files at /opt/fourfold/fourfold_website
```

`www.fourfoldsystem.com` is the canonical URL because that's what's already
printed on the physical product manual and warranty card. The bare domain
just redirects there so both work.

---

# PART 1 — GET THE WEBSITE FILES ONTO THE SERVER

The site lives in this same repo at `fourfold_website/`, and the server
already has the repo cloned at `/opt/fourfold` (from the backend deploy).
So this is just a commit + pull.

## Step 1 — Commit and Push (from your laptop)

```bash
cd /Users/simplepandey/Documents/claude_project/FourFold
git add fourfold_website
git commit -m "Add FourFold marketing website"
git push
```

## Step 2 — Pull on the Server

```bash
ssh root@YOUR_API_SERVER_IP
cd /opt/fourfold
git pull
ls fourfold_website   # sanity check the files are there
```

No build step, no Docker container, no `npm install` — it's plain HTML/CSS/JS
served directly by Nginx.

---

# PART 2 — DNS

## Step 3 — Add A Records

In your domain registrar / DNS provider for `fourfoldsystem.com`:

```
Type   Name    Value
A      @       YOUR_API_SERVER_IP     (same IP api.fourfoldsystem.com already uses)
A      www     YOUR_API_SERVER_IP
```

Wait for propagation, then verify from your laptop:

```bash
nslookup fourfoldsystem.com
nslookup www.fourfoldsystem.com
```

Both should resolve to `YOUR_API_SERVER_IP`.

---

# PART 3 — NGINX SITE CONFIG

Firewall is already open on 80/443 from the backend deploy (`ufw allow 80/tcp`,
`ufw allow 443/tcp`) — nothing to change there.

## Step 4 — Append to the Existing Config File

This is the file you already have:

```bash
nano /etc/nginx/sites-available/fourfold-api
```

It currently has just the one block:

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

Leave that block exactly as-is, and **append** these two below it, in the
same file:

```nginx
# Canonical site — static files
server {
    listen 80;
    server_name www.fourfoldsystem.com;

    root /opt/fourfold/fourfold_website;
    index index.html;

    location / {
        try_files $uri $uri.html $uri/ =404;
    }

    location /assets/ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}

# Bare domain -> redirect to www
server {
    listen 80;
    server_name fourfoldsystem.com;
    return 301 https://www.fourfoldsystem.com$request_uri;
}
```

Save: `Ctrl+X` → `Y` → `Enter`. It's already symlinked into
`sites-enabled/` (that's how `api.fourfoldsystem.com` is live today), so
there's no new symlink step — just reload:

## Step 5 — Test and Reload

```bash
nginx -t
systemctl reload nginx
```

`nginx -t` re-parses the whole file, so it'll catch it immediately if a
brace got misplaced while editing — fix before reloading if it complains.

At this point `http://www.fourfoldsystem.com` should already serve the site
(no HTTPS yet), and `api.fourfoldsystem.com` keeps working untouched.

---

# PART 4 — HTTPS VIA CERTBOT

## Step 6 — Get the Certificate

Certbot's Nginx plugin edits both server blocks above automatically to add
`listen 443 ssl` and the HTTP→HTTPS redirect — same as it did for
`api.fourfoldsystem.com`.

```bash
certbot --nginx -d fourfoldsystem.com -d www.fourfoldsystem.com
```

```
Enter email address: your@email.com
Agree to terms: A
Share email with EFF: N
```

## Step 7 — Verify

```bash
curl -I https://www.fourfoldsystem.com
curl -I https://fourfoldsystem.com   # should show 301 -> https://www.fourfoldsystem.com
```

Or just open `https://fourfoldsystem.com` in a browser — it should land on
`https://www.fourfoldsystem.com` with a padlock.

Auto-renewal already runs via the systemd timer certbot installed for the API
cert — this second cert renews on the same schedule, nothing extra to set up.
Confirm both certs are covered:

```bash
certbot certificates
certbot renew --dry-run
```

---

# REDEPLOYING AFTER WEBSITE CHANGES

Since it's static files with no build step, this is the entire redeploy:

```bash
# on your laptop
git add fourfold_website && git commit -m "Update website" && git push

# on the server
ssh root@YOUR_API_SERVER_IP
cd /opt/fourfold && git pull
```

Changes are live immediately — no `nginx reload`, no container restart.
If you don't see the update in your browser, it's almost always the
`/assets/` 30-day cache header from Step 4 — hard-refresh
(Cmd+Shift+R) or bump the asset filenames.

---

# COMMON ERRORS AND FIXES

```
ERROR: 404 on every page except /
FIX:   server_name in the Nginx block doesn't match the domain you're
       requesting, or `root` path is wrong — confirm with
       `ls /opt/fourfold/fourfold_website/index.html` on the server.

ERROR: certbot "Challenge failed" for fourfoldsystem.com
FIX:   DNS hasn't propagated yet (Part 2), or port 80 isn't reachable —
       certbot needs plain HTTP first to issue the cert, same as the
       API server setup.

ERROR: www.fourfoldsystem.com works but fourfoldsystem.com doesn't
FIX:   The A record for the bare "@" host is missing or still
       propagating — re-check Step 3.

ERROR: Nginx won't reload, "nginx -t" fails
FIX:   Almost always a stray/missing brace from editing
       /etc/nginx/sites-available/fourfold-api by hand — all three
       server blocks (api, www, bare domain) live in this one file now,
       so a typo in any of them breaks the whole file, including the
       already-working api.fourfoldsystem.com block. Re-open it and
       check brace matching before reloading.

ERROR: Old content still showing after a redeploy
FIX:   Browser or Cloudflare-style CDN caching, not the server — see
       "Redeploying" note above about the /assets/ cache header.
```
