# Minecraft 1.20.1 Forge Server — Dokploy + Cloudflare R2

Forge **1.20.1 / 47.4.10**. Sized for **5 GB RAM / 2 cores**. Hourly crash-consistent
backups to **Cloudflare R2**. Mods live in R2 and are pulled on first boot, so you can
add/remove them live from the console.

## Architecture

```
Dokploy (Compose app)
├── mc        : itzg/minecraft-server (Forge 1.20.1)  ── volume mc-data:/data
│                └─ on first boot: rclone copy r2:.../mods → /data/mods
└── backups   : itzg/mc-backup → every 1h:
                save-off → tar (world+playerdata+configs) → gzip → R2 → save-on
```

Why mods are in R2, not git: your `Mods/` is **640 MB** and one jar
(`Souls_Like_Bosses...jar`) is **246 MB**. GitHub hard-rejects any file over **100 MB**,
so they can't be pushed. Keeping code in git and big binaries in R2 is the clean fix —
fast builds, private mods, no LFS fragility.

---

## One-time setup

### 1. Create R2 API credentials
Cloudflare dashboard → **R2** → **Manage R2 API Tokens** → **Create API Token**
→ permission **Object Read & Write** → scope to bucket `minecraftserverbackup`.
Copy the **Access Key ID** and **Secret Access Key**.

Your endpoint is already known:
`https://e3ad2427faef6098ee545bb8b4307217.r2.cloudflarestorage.com`

### 2. Upload your mods to R2 (once)
Install rclone on your PC: https://rclone.org/downloads/ (Windows: `winget install Rclone.Rclone`).

From this repo folder (PowerShell), set env for the session and push the `Mods/` folder:

```powershell
$env:RCLONE_CONFIG_R2_TYPE="s3"
$env:RCLONE_CONFIG_R2_PROVIDER="Cloudflare"
$env:RCLONE_CONFIG_R2_ACCESS_KEY_ID="<your key id>"
$env:RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="<your secret>"
$env:RCLONE_CONFIG_R2_ENDPOINT="https://e3ad2427faef6098ee545bb8b4307217.r2.cloudflarestorage.com"

rclone copy ".\Mods" "r2:minecraftserverbackup/mods" --transfers=4 --progress
```

Verify: `rclone ls r2:minecraftserverbackup/mods` should list ~92 jars.

> The 3 broken mods (see bottom) are auto-deleted after seeding even if uploaded.

### 3. Deploy on Dokploy
1. New **Compose** application → source = this GitHub repo (`docker-compose.yml`).
2. In the app's **Environment** tab, paste the contents of `.env.example` and fill in
   real values (`RCON_PASSWORD`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`).
3. **Deploy.** First boot installs Forge, then pulls mods from R2 (a few minutes).
4. Expose port **25565** in Dokploy (domain or raw TCP port) so players can connect.

Watch logs until you see `Done (xx.xxxs)! For help, type "help"`.

---

## Managing mods from the console

Open the **mc** container terminal in Dokploy (or `docker exec -it mc bash`).
The image ships `rcon-cli` for in-game commands and the mods live in `/data/mods`.

**Add a mod**
```bash
cd /data/mods
curl -L -o SomeMod-1.20.1.jar "https://<direct-download-url>.jar"
# then restart the mc container in Dokploy
```

**Remove a mod**
```bash
rm "/data/mods/BadMod-1.20.1.jar"
# then restart
```

Mods persist in the `mc-data` volume — they are **not** re-seeded on restart (seed only
runs when `/data/mods` is empty). To force a full re-pull from R2, set
`FORCE_MOD_SYNC=true` for one deploy, then back to `false`.

### Chunky (pre-generating chunks)
Chunky runs **in-game**, so use RCON (no restart needed):
```bash
docker exec mc rcon-cli chunky radius 3000
docker exec mc rcon-cli chunky start
docker exec mc rcon-cli chunky progress
docker exec mc rcon-cli chunky pause      # ease CPU when players join
```
On 2 cores, pre-gen is CPU-heavy — run it with few/no players and `chunky pause`
when needed.

---

## Backups

- **Frequency:** hourly (`BACKUP_INTERVAL=1h`), first one 3 min after start.
- **Consistent:** the backup service issues `save-off`/`save-all`/`save-on` over RCON
  so the world isn't backed up mid-write — protects worlds **and player inventories**
  (`world/playerdata`).
- **Small:** mods/libraries/logs/cache are excluded; only world + player data + configs
  are archived and gzipped.
- **Retention:** newest **72** kept on R2 (`PRUNE_BACKUPS_COUNT`, ~3 days). Raise/lower
  in `.env`.
- **Location:** `r2:minecraftserverbackup/world-backups/`.

### Restore a backup
```bash
# 1. list backups on R2
rclone ls r2:minecraftserverbackup/world-backups

# 2. stop the mc container (Dokploy), then on the host pull one in:
docker run --rm -v mc-data:/data -e RCLONE_CONFIG_R2_TYPE=s3 \
  -e RCLONE_CONFIG_R2_PROVIDER=Cloudflare \
  -e RCLONE_CONFIG_R2_ACCESS_KEY_ID=... \
  -e RCLONE_CONFIG_R2_SECRET_ACCESS_KEY=... \
  -e RCLONE_CONFIG_R2_ENDPOINT=https://e3ad2427faef6098ee545bb8b4307217.r2.cloudflarestorage.com \
  itzg/mc-backup bash -c \
  "rclone copy r2:minecraftserverbackup/world-backups/<file>.tgz /tmp && \
   rm -rf /data/world && tar xzf /tmp/<file>.tgz -C /data"

# 3. start the mc container again
```

---

## Tuning for 5 GB / 2 cores

- `MEMORY=3584M` (3.5 GB heap). Leaves room for ~90 mods' metaspace + OS + backup.
  - Seeing OOM kills? Lower to `3072M`. Stable with headroom? Try `4096M`.
- `VIEW_DISTANCE=7`, `SIMULATION_DISTANCE=5` — biggest CPU/RAM levers. Drop to 6/4 if laggy.
- Aikar GC flags are on (`USE_AIKAR_FLAGS=true`).
- This is a heavy modpack (Souls-Like Bosses, Dungeons, BOP, Tan's Huge Trees…). On
  this hardware keep player count modest and pre-gen with Chunky to smooth exploration.

---

## ⚠️ Mods you must fix (wrong version/loader — auto-removed on seed)

| File | Problem |
|------|---------|
| `PlayerAnimationLibNeoforge-1.1.4+mc.1.21.1.jar` | NeoForge + MC **1.21.1**, not Forge 1.20.1 |
| `PotionCore-1.9_for_1.12.2.jar` | MC **1.12.2** |
| `QualityTools-1.0.7_for_1.12.2.jar` | MC **1.12.2** |

**Dependency warning:** `bettercombat` needs a **Player Animation Library**. The one you
have is the wrong build, so it's removed — download the correct
**Player Animation Lib — Forge 1.20.1** jar, upload it to `r2:minecraftserverbackup/mods`,
and re-seed (or drop it into `/data/mods` via console). Otherwise bettercombat may fail
to load.
