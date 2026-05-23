# Minecraft 1.20.1 Forge server for Dokploy
# Base: itzg/minecraft-server (the standard MC server image). Java 17 = required by Forge 1.20.1.
FROM itzg/minecraft-server:java17

# rclone is needed to pull the mod set from Cloudflare R2 on first boot.
# (mods are NOT baked into the image / git — they live in R2; see DEPLOY.md)
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends rclone ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Seed script: downloads mods into the data volume on first boot, then hands off to itzg's /start.
COPY --chmod=0755 scripts/seed-mods.sh /seed-mods.sh

ENTRYPOINT ["/seed-mods.sh"]
