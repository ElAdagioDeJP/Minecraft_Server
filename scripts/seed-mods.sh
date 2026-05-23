#!/usr/bin/env bash
# Seeds /data/mods from Cloudflare R2 on FIRST boot only (empty volume),
# so you can freely add/remove mods from the console afterwards without them
# being overwritten on restart. Set FORCE_MOD_SYNC=true to re-pull anyway.
set -euo pipefail

MODS_DEST="/data/mods"
MODS_SOURCE="${MODS_REMOTE_PATH:-r2:minecraftserverbackup/mods}"

# Mods that are the WRONG Minecraft version / loader and will crash a Forge 1.20.1
# server. They are deleted after seeding. Fix them (correct 1.20.1 Forge jar) and
# re-upload to R2, then run with FORCE_MOD_SYNC=true, or drop them in via console.
BROKEN_MODS=(
  "PlayerAnimationLibNeoforge-1.1.4+mc.1.21.1.jar"   # NeoForge + MC 1.21.1
  "PotionCore-1.9_for_1.12.2.jar"                     # MC 1.12.2
  "QualityTools-1.0.7_for_1.12.2.jar"                 # MC 1.12.2
)

mkdir -p "$MODS_DEST"

is_empty() { [ -z "$(ls -A "$MODS_DEST" 2>/dev/null)" ]; }

if is_empty || [ "${FORCE_MOD_SYNC:-false}" = "true" ]; then
  if [ -n "${RCLONE_CONFIG_R2_ACCESS_KEY_ID:-}" ]; then
    echo "[seed-mods] Pulling mods from ${MODS_SOURCE} -> ${MODS_DEST}"
    rclone copy "$MODS_SOURCE" "$MODS_DEST" \
      --transfers=4 --checkers=8 --fast-list --stats=15s --stats-one-line
    for m in "${BROKEN_MODS[@]}"; do
      if [ -f "$MODS_DEST/$m" ]; then
        echo "[seed-mods] Removing incompatible mod: $m"
        rm -f "$MODS_DEST/$m"
      fi
    done
    echo "[seed-mods] Mod count now: $(ls -1 "$MODS_DEST"/*.jar 2>/dev/null | wc -l)"
  else
    echo "[seed-mods] WARNING: R2 credentials not set; skipping mod seed. /data/mods is empty."
  fi
else
  echo "[seed-mods] /data/mods already populated ($(ls -1 "$MODS_DEST"/*.jar 2>/dev/null | wc -l) jars). Skipping seed."
fi

# Hand off to itzg/minecraft-server's normal startup.
exec /start
