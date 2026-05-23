# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Deployment config (not Java source) for a **Minecraft 1.20.1 Forge 47.4.10** modded server, run via **Dokploy** as a Docker Compose app. It builds on `itzg/minecraft-server` + `itzg/mc-backup`. Target hardware is small: **5 GB RAM / 2 cores**.

## Core architecture (read these together)

Three files form one system; a change in one usually needs a matching change in another:

- **`Dockerfile`** — `FROM itzg/minecraft-server:java17` (Java 17 is required by Forge 1.20.1), adds `rclone`, and sets `ENTRYPOINT` to `scripts/seed-mods.sh`.
- **`scripts/seed-mods.sh`** — runs before the server. On an **empty** `/data/mods` (or `FORCE_MOD_SYNC=true`) it `rclone copy`s the mod set from R2, deletes the hardcoded `BROKEN_MODS`, then `exec /start` (itzg's real entrypoint). The empty-only guard is what lets users add/remove mods live via console without restarts re-overwriting them.
- **`docker-compose.yml`** — two services sharing the `mc-data` volume: `mc` (the server, built from the Dockerfile) and `backups` (`itzg/mc-backup`, reads the volume `:ro`). Both get the same `RCLONE_CONFIG_R2_*` env. The backup service reaches the server over RCON (`RCON_HOST: mc`) to do `save-off`/`save-all`/`save-on` for crash-consistent backups.

**Mods are intentionally not in git.** `Mods/` is ~640 MB with a 246 MB jar — GitHub rejects files >100 MB. Mods live in Cloudflare R2 (`r2:minecraftserverbackup/mods`) and are pulled at first boot. `Mods/` is the local upload source only (gitignored). Do not "fix" this by committing jars or adding Git LFS unless explicitly asked.

## Configuration & secrets

All runtime config is env-driven. `.env` holds real secrets (R2 keys, RCON password) and is **gitignored** — never commit it or echo its values. `.env.example` is the committed template; keep the two in sync when adding a variable. On Dokploy these go in the app's Environment tab, not a file.

## Common operations

There is no build/test/lint step in this repo. Operations happen against the running container:

```bash
# Validate compose locally (requires Docker)
docker compose config -q

# Build + run locally
docker compose up -d --build

# Server console / in-game commands (RCON)
docker exec mc rcon-cli <command>          # e.g. chunky start, op <user>, stop

# Manage mods live (then restart the mc container)
docker exec -it mc bash                     # edit /data/mods, then restart

# Force a full re-pull of mods from R2: set FORCE_MOD_SYNC=true for one deploy, then false
```

## Conventions / gotchas

- `seed-mods.sh` is bash with `set -euo pipefail` and **must** keep `exec /start` as its last line — that hands off to itzg.
- The `BROKEN_MODS` array in `seed-mods.sh` lists wrong-version jars that crash a 1.20.1 Forge server (currently a NeoForge/1.21.1 player-animation lib and two 1.12.2 mods). Keep this list and the table in `DEPLOY.md` / `README.md` in agreement when it changes. Note: `bettercombat` depends on a Player Animation Library, so removing the broken one leaves a dependency gap until a correct Forge 1.20.1 build is supplied.
- Memory: `MEMORY` is the JVM heap and must stay below the container limit so mod metaspace + OS + the backup run fit (default `3584M` on a 5 GB box).
- The README is in Spanish and uses centered HTML/badges by design — markdownlint warnings there are expected, not bugs.
- `DEPLOY.md` is the long-form English runbook (R2 setup, restore procedure, tuning). Keep it consistent with `docker-compose.yml` env names.
