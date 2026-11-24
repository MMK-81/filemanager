# Team File Manager (FileBrowser Quantum + Caddy)

A lightweight self-hosted file manager with per-user folders, shared space, public share links and WebDAV, served over automatic HTTPS. It is designed to run on a small VPS (~512 MB RAM) as a simpler alternative to Nextcloud for file management only.

[راهنمای فارسی / Persian README](README.fa.md) · [Persian installation guide](INSTALL.fa.md)

## Features

- Web UI for upload (drag & drop, multi-file, folder upload), download, preview and text editing
- Images, video, PDF and Office previews
- Personal folder per user (`files/users/<username>`) plus a shared folder (`files/shared`)
- Public share links with password, expiry, permissions (view/download/upload/edit) and guest access
- Upload-only "inbox" shares for receiving files from people without accounts
- WebDAV endpoint at `/dav`
- Automatic Let's Encrypt certificates via Caddy (HTTP/1.1, HTTP/2, HTTP/3)
- Admin-managed users; open sign-up disabled by default

## Architecture

| Component | Technology | Exposure |
|---|---|---|
| File manager | `ghcr.io/gtsteffaniak/filebrowser:stable` (FileBrowser Quantum) | container port 80 only, no host port |
| Reverse proxy / TLS | `caddy:2-alpine` | host ports 80, 443, 443/udp |
| State | SQLite (`data/database.sqlite`) + `data/config.yaml` | bind-mounted `./data` |
| User files | `./files` mounted at `/data` inside FileBrowser | `users/` and `shared/` sources |

Running container names: `filemanager-filebrowser-1` and `filemanager-caddy-1`.

The Caddy container in this stack is also the shared reverse proxy for the sibling projects in this collection (Mattermost and WatchSync join the `filemanager_default` network).

## Requirements

- Linux server (Ubuntu 22.04/24.04 or Debian 12 recommended), 1 CPU, 512 MB+ RAM, 10 GB+ disk
- Docker Engine and Docker Compose **v2**
- A DNS A record pointing to the server; no stale AAAA records; ports 80/443 reachable
- If using Cloudflare, keep the record DNS-only while certificates are issued

## Quick start

```bash
# On the server
cd /opt/filemanager
cp .env.example .env
nano .env                 # DOMAIN, ACME_EMAIL, ADMIN_PASSWORD
chmod 600 .env
chmod +x *.sh
./setup.sh
```

`setup.sh` checks Docker/Compose, validates `.env`, creates `data/`, `files/users/` and `files/shared/`, rewrites `externalUrl` in `data/config.yaml`, generates a stable `JWT_SECRET` (only when it is still `__GENERATE__`), fixes ownership to `1000:1000`, then pulls images and starts the stack.

Open `https://<DOMAIN>` after 30–90 seconds. Log in with user `admin` and the `ADMIN_PASSWORD` from `.env`.

If no admin password is configured, a random one is printed once:

```bash
docker compose logs filebrowser 2>&1 | grep -i "initial admin password"
docker compose logs --tail=40 caddy     # "certificate obtained successfully"
```

## Configuration

Environment variables (see `.env.example`; **never commit `.env`**):

| Variable | Meaning |
|---|---|
| `DOMAIN` | Hostname without scheme, e.g. `files.example.com` |
| `ACME_EMAIL` | Let's Encrypt notification email |
| `ADMIN_PASSWORD` | Initial admin password (12+ characters) |
| `JWT_SECRET` | Generated once by `setup.sh`; changing it logs everyone out |
| `TOTP_SECRET` | Optional 2FA secret (`openssl rand -base64 32`) |

`data/config.yaml` defines two sources: `/data/users` ("پوشه من" / My folder, `createUserDir: true`) and `/data/shared` ("مشترک" / Shared). A commented third source gives the admin a view of everything, at the cost of duplicate indexing.

Caddy handles `/public/*` as unauthenticated share links and everything else (including `/dav`) through the authenticated handler. `request_body.max_size` is 1100 MB.

## Everyday use

```bash
# Users
./add-user.sh ali                       # interactive password prompt (recommended)
# ./add-user.sh ali '<password>'        # also works, but password stays in shell history

# Operations
docker compose ps
docker compose logs -f filebrowser
docker compose logs -f caddy
docker compose restart filebrowser
docker compose down
docker compose up -d
```

Sharing: select a file/folder → `⋯` → **Share** → set password, expiry, permissions and audience → copy the `/public/share/...` URL. Revoke it from the Shares list. Deleting the file also removes the link.

WebDAV clients:

- Windows: Map network drive → `https://<DOMAIN>/dav`
- macOS: Go → Connect to Server → same URL
- rclone: `webdav` backend, vendor `other`, URL `https://<DOMAIN>/dav`

## Change domain

```bash
nano .env                               # update DOMAIN
./setup.sh                              # rewrites externalUrl and JWT if needed
docker compose up -d --force-recreate
```

`externalUrl` in `data/config.yaml` must match the browser URL exactly, or cookies will not be set.

## Backup, restore, update

```bash
./backup.sh
# backups/data-YYYYmmdd-HHMMSS.tar.gz (config + SQLite, excludes tmp)
# User files are NOT included:
rsync -a --delete files/ user@backup-host:/backup/files/
```

Nightly backup:

```bash
(crontab -l 2>/dev/null; echo "0 3 * * * cd /opt/filemanager && ./backup.sh >> /var/log/filebrowser-backup.log 2>&1") | crontab -
```

Restore:

```bash
docker compose down
tar -xzf backups/data-<timestamp>.tar.gz
sudo chown -R 1000:1000 data files
docker compose up -d
```

Update:

```bash
./backup.sh && docker compose pull && docker compose up -d && docker compose ps
```

## Security notes

- `.env` contains the admin password and JWT signing secret; keep it `chmod 600` and out of version control.
- While `ADMIN_PASSWORD` is set, password changes made in the UI are reverted on restart. Remove it from `.env` and `FILEBROWSER_ADMIN_PASSWORD` from `docker-compose.yml` to make UI-managed passwords persistent.
- Public share links are bearer credentials. Use passwords/expiry and prefer logged-in-only access.
- Only Caddy publishes ports. Keep FileBrowser unexposed and forward only 80/443.
- `trustProxyHeaders: true` assumes traffic always arrives through Caddy.
- Host root and anyone with Docker/SSH access can read all of `files/`, including private user folders.
- Backups are unencrypted and exclude user files; store them on a trusted destination.
- Keep signup disabled (`auth.methods.password.signup: false`) on public servers and consider 2FA.
- The image tag `stable` floats; pin a version tag if reproducibility matters.

## Troubleshooting

| Symptom | What to check |
|---|---|
| 502 from the site | `docker compose logs --tail=100 filebrowser` |
| No certificate | DNS A record, ports 80/443, `docker compose logs caddy` |
| `address already in use` | `ss -ltnp | grep -E ':80|:443'` and stop the conflicting service |
| Uploads fail / zero-byte files | `chown -R 1000:1000 files data`, `df -h` |
| Empty file list | `docker compose exec filebrowser ls /data/users` and `data/config.yaml` |
| Login succeeds then logs out | `externalUrl` must equal the browser URL |
| Everyone logged out after restart | `JWT_SECRET` missing or changed |
| `bad interpreter` on scripts | `sed -i 's/\r$//' *.sh` |

## License

Private project.
