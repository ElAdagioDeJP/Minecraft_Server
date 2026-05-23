<div align="center">

# 🗡️ Minecraft Server — Forge 1.20.1

### Servidor modded autohospedado con despliegue en **Dokploy**, backups automáticos a **Cloudflare R2** y gestión de mods en vivo

![Minecraft](https://img.shields.io/badge/Minecraft-1.20.1-62B47A?style=for-the-badge&logo=minecraft&logoColor=white)
![Forge](https://img.shields.io/badge/Forge-47.4.10-1E2A3A?style=for-the-badge)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Dokploy](https://img.shields.io/badge/Deploy-Dokploy-7C3AED?style=for-the-badge)
![Cloudflare R2](https://img.shields.io/badge/Backups-Cloudflare%20R2-F38020?style=for-the-badge&logo=cloudflare&logoColor=white)

**RAM:** 5 GB · **CPU:** 2 núcleos · **Mods:** ~92 · **Backups:** cada hora

</div>

---

## 📑 Tabla de contenidos

- [✨ Características](#-características)
- [🏗️ Arquitectura](#️-arquitectura)
- [🚀 Inicio rápido](#-inicio-rápido)
- [🧩 Gestión de mods desde la consola](#-gestión-de-mods-desde-la-consola)
- [💾 Backups y restauración](#-backups-y-restauración)
- [⚙️ Ajuste de rendimiento (5 GB / 2 núcleos)](#️-ajuste-de-rendimiento-5-gb--2-núcleos)
- [🔐 Variables de entorno](#-variables-de-entorno)
- [⚠️ Mods que debes corregir](#️-mods-que-debes-corregir)
- [❓ Solución de problemas](#-solución-de-problemas)
- [📂 Estructura del repo](#-estructura-del-repo)

---

## ✨ Características

| | |
|---|---|
| 🐳 **Despliegue 1-click** | `docker-compose.yml` listo para Dokploy. Forge se instala solo. |
| 🧩 **Mods en la nube** | Tus ~92 mods viven en R2, no en git. Repo ligero, builds rápidos, sin el límite de 100 MB de GitHub. |
| 🔄 **Edición de mods en vivo** | Agrega/quita mods desde la consola sin reconstruir la imagen. |
| ⛏️ **Chunky vía RCON** | Pre-genera chunks sin reiniciar el servidor. |
| 💾 **Backups cada hora** | Consistentes ante caídas (`save-off`/`save-all` por RCON) → mundo **e inventarios** a salvo. |
| 📦 **Backups livianos** | Comprimidos en gzip, sin mods ni librerías. Solo mundo + datos de jugadores + configs. |
| 🧹 **Retención automática** | Conserva los 72 más recientes en R2 (~3 días). |
| ⚡ **Optimizado** | Flags de Aikar + heap y distancias afinadas para 5 GB / 2 núcleos. |

---

## 🏗️ Arquitectura

```
                          ┌─────────────────────────────────────────┐
                          │              Dokploy (Compose)           │
                          │                                          │
   Jugadores ──:25565──►  │  ┌────────────────┐   ┌───────────────┐ │
                          │  │      mc        │   │   backups     │ │
                          │  │ Forge 1.20.1   │◄──┤ itzg/mc-backup│ │
                          │  │ itzg/minecraft │RCON│  cada 1 hora  │ │
                          │  └───────┬────────┘   └──────┬────────┘ │
                          │          │ volumen mc-data    │          │
                          └──────────┼────────────────────┼─────────┘
                                     │ 1er arranque        │ subida
                          pull mods  ▼                     ▼ backup
                          ┌─────────────────────────────────────────┐
                          │            Cloudflare R2 (S3)            │
                          │  /mods           ← tus jars              │
                          │  /world-backups  ← mundo.tgz por hora    │
                          └─────────────────────────────────────────┘
```

**Flujo:**
1. En el **primer arranque**, `scripts/seed-mods.sh` descarga los mods desde `r2:.../mods` hacia `/data/mods` (solo si está vacío → tus ediciones manuales sobreviven a los reinicios).
2. El servicio **backups** cada hora pausa la escritura del mundo por RCON, lo empaqueta, lo comprime y lo sube a `r2:.../world-backups`.

> **¿Por qué los mods van en R2 y no en git?** Tu carpeta `Mods/` pesa **640 MB** y un jar (`Souls_Like_Bosses…jar`) pesa **246 MB**. GitHub **rechaza** cualquier archivo de más de **100 MB**. Solución limpia: código en git, binarios grandes en R2. Builds rápidos, mods privados, sin la fragilidad de Git LFS.

---

## 🚀 Inicio rápido

### Prerrequisitos
- Cuenta de **Cloudflare R2** con el bucket `minecraftserverbackup` creado.
- **Dokploy** instalado en tu VPS (5 GB RAM / 2 núcleos).
- **rclone** en tu PC → https://rclone.org/downloads/ (`winget install Rclone.Rclone`).

### 1️⃣ Crear credenciales R2
Cloudflare → **R2** → **Manage R2 API Tokens** → **Create API Token** → permiso **Object Read & Write** → bucket `minecraftserverbackup`. Copia **Access Key ID** y **Secret Access Key**.

### 2️⃣ Subir los mods a R2 (una sola vez)
Desde la carpeta del repo (PowerShell):

```powershell
$env:RCLONE_CONFIG_R2_TYPE="s3"
$env:RCLONE_CONFIG_R2_PROVIDER="Cloudflare"
$env:RCLONE_CONFIG_R2_ACCESS_KEY_ID="<tu key id>"
$env:RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="<tu secret>"
$env:RCLONE_CONFIG_R2_ENDPOINT="https://e3ad2427faef6098ee545bb8b4307217.r2.cloudflarestorage.com"

rclone copy ".\Mods" "r2:minecraftserverbackup/mods" --transfers=4 --progress
```

Verifica: `rclone ls r2:minecraftserverbackup/mods` (deben aparecer ~92 jars).

### 3️⃣ Configurar `.env`
```bash
cp .env.example .env
```
Edita `.env` y rellena `RCON_PASSWORD` (¡fuerte!), `R2_ACCESS_KEY_ID` y `R2_SECRET_ACCESS_KEY`.

> 🔒 `.env` está en `.gitignore` — **nunca** se sube al repo.

### 4️⃣ Desplegar en Dokploy
1. Nueva app tipo **Compose** → fuente = este repo de GitHub (`docker-compose.yml`).
2. Pestaña **Environment** → pega el contenido de `.env.example` con tus valores reales.
3. **Deploy.** El primer arranque instala Forge y descarga los mods (unos minutos).
4. Expón el puerto **25565** (dominio o puerto TCP).

Listo cuando los logs muestren:
```
Done (xx.xxxs)! For help, type "help"
```

---

## 🧩 Gestión de mods desde la consola

Abre la terminal del contenedor **mc** en Dokploy (o `docker exec -it mc bash`). Los mods están en `/data/mods`.

**➕ Agregar un mod**
```bash
cd /data/mods
curl -L -o NombreMod-1.20.1.jar "https://<url-de-descarga-directa>.jar"
# luego reinicia el contenedor mc en Dokploy
```

**➖ Quitar un mod**
```bash
rm "/data/mods/ModMalo-1.20.1.jar"
# luego reinicia
```

> Los mods persisten en el volumen `mc-data` y **no** se vuelven a descargar al reiniciar (el seed solo corre cuando `/data/mods` está vacío). Para forzar una re-descarga completa desde R2: pon `FORCE_MOD_SYNC=true` en un deploy y luego vuelve a `false`.

### ⛏️ Chunky (pre-generar chunks)
Chunky se controla **en el juego**, así que usa RCON (sin reiniciar):
```bash
docker exec mc rcon-cli chunky radius 3000
docker exec mc rcon-cli chunky start
docker exec mc rcon-cli chunky progress
docker exec mc rcon-cli chunky pause     # libera CPU cuando entren jugadores
```
> Con 2 núcleos la pre-generación es pesada. Córrela con pocos/ningún jugador y usa `chunky pause` cuando haga falta.

---

## 💾 Backups y restauración

| Aspecto | Valor |
|---|---|
| **Frecuencia** | Cada hora (`BACKUP_INTERVAL=1h`), el primero a los 3 min |
| **Consistencia** | `save-off` → `save-all` → tar → `save-on` por RCON (sin corrupción) |
| **Contenido** | Mundo + `playerdata` (inventarios) + configs |
| **Excluye** | mods, librerías, logs, cache (se re-descargan de R2) |
| **Compresión** | gzip |
| **Retención** | 72 más recientes (`PRUNE_BACKUPS_COUNT`, ~3 días) |
| **Destino** | `r2:minecraftserverbackup/world-backups/` |

### 🔁 Restaurar un backup
```bash
# 1. listar backups en R2
rclone ls r2:minecraftserverbackup/world-backups

# 2. detén el contenedor mc en Dokploy, luego en el host:
docker run --rm -v mc-data:/data \
  -e RCLONE_CONFIG_R2_TYPE=s3 \
  -e RCLONE_CONFIG_R2_PROVIDER=Cloudflare \
  -e RCLONE_CONFIG_R2_ACCESS_KEY_ID=... \
  -e RCLONE_CONFIG_R2_SECRET_ACCESS_KEY=... \
  -e RCLONE_CONFIG_R2_ENDPOINT=https://e3ad2427faef6098ee545bb8b4307217.r2.cloudflarestorage.com \
  itzg/mc-backup bash -c \
  "rclone copy r2:minecraftserverbackup/world-backups/<archivo>.tgz /tmp && \
   rm -rf /data/world && tar xzf /tmp/<archivo>.tgz -C /data"

# 3. vuelve a iniciar el contenedor mc
```

---

## ⚙️ Ajuste de rendimiento (5 GB / 2 núcleos)

| Variable | Valor | Notas |
|---|---|---|
| `MEMORY` | `3584M` | Heap 3.5 GB. Deja espacio para metaspace de ~92 mods + OS + backup. ¿OOM? baja a `3072M`. ¿Estable? prueba `4096M`. |
| `VIEW_DISTANCE` | `7` | Mayor palanca de CPU/RAM. Baja a `6` si hay lag. |
| `SIMULATION_DISTANCE` | `5` | Baja a `4` si hay lag. |
| `USE_AIKAR_FLAGS` | `true` | Flags de GC optimizados. |
| `MAX_TICK_TIME` | `120000` | Margen del watchdog para worldgen pesado / Chunky. |

> Es un modpack **pesado** (Souls-Like Bosses, Dungeons, Biomes O' Plenty, Tan's Huge Trees…). En este hardware: pocos jugadores y pre-genera con Chunky para suavizar la exploración.

---

## 🔐 Variables de entorno

Todas viven en `.env` (local/Dokploy, nunca en git). Ver [`.env.example`](.env.example).

| Variable | Descripción |
|---|---|
| `RCON_PASSWORD` | Contraseña de consola RCON (úsala fuerte y única). |
| `MEMORY` | Heap de la JVM. |
| `VIEW_DISTANCE` / `SIMULATION_DISTANCE` | Distancias de render/simulación. |
| `MAX_PLAYERS` | Máximo de jugadores. |
| `R2_ENDPOINT` | `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`. |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` | Credenciales S3 de R2. |
| `MODS_REMOTE_PATH` | Origen de mods en R2 (`r2:bucket/mods`). |
| `BACKUP_DEST_DIR` | Destino de backups (`bucket/ruta`). |
| `PRUNE_BACKUPS_COUNT` | Cuántos backups conservar en R2. |
| `FORCE_MOD_SYNC` | `true` para re-descargar mods en el próximo deploy. |

---

## ⚠️ Mods que debes corregir

Estos jars son de **versión/cargador equivocado** y harían crashear el servidor. El script `seed-mods.sh` los **elimina automáticamente** tras la descarga:

| Archivo | Problema |
|---|---|
| `PlayerAnimationLibNeoforge-1.1.4+mc.1.21.1.jar` | NeoForge + MC **1.21.1** (no Forge 1.20.1) |
| `PotionCore-1.9_for_1.12.2.jar` | MC **1.12.2** |
| `QualityTools-1.0.7_for_1.12.2.jar` | MC **1.12.2** |

> 🔴 **Dependencia rota:** `bettercombat` necesita una **Player Animation Library**. La tuya es la build equivocada (se elimina), así que descarga la correcta **Player Animation Lib — Forge 1.20.1**, súbela a `r2:minecraftserverbackup/mods` y re-haz el seed (o suéltala en `/data/mods` por consola). Si no, bettercombat puede no cargar.

---

## ❓ Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `/data/mods` vacío tras el deploy | No subiste los mods a R2 o faltan credenciales | Haz el [paso 2](#2️⃣-subir-los-mods-a-r2-una-sola-vez); revisa `R2_*` en `.env`. |
| El contenedor muere con `OOMKilled` | Heap demasiado alto | Baja `MEMORY` a `3072M`. |
| Crash al iniciar por un mod | Mod incompatible 1.20.1 | Quítalo de `/data/mods` y reinicia; revisa los logs. |
| No se generan backups | RCON mal configurado | Verifica que `RCON_PASSWORD` sea igual en ambos servicios. |
| Mods no se actualizan al reiniciar | Comportamiento esperado (seed solo si vacío) | Usa `FORCE_MOD_SYNC=true` un deploy. |
| Lag / TPS bajo | Hardware ajustado + modpack pesado | Baja `VIEW_DISTANCE`/`SIMULATION_DISTANCE`, menos jugadores. |

---

## 📂 Estructura del repo

```
.
├── Dockerfile             # imagen del servidor (itzg + rclone + seed)
├── docker-compose.yml     # servicios mc + backups (para Dokploy)
├── scripts/
│   └── seed-mods.sh       # descarga mods de R2 en el 1er arranque
├── .env.example           # plantilla de configuración
├── .env                   # tus secretos (gitignored)
├── .gitignore             # ignora .env, Mods/, datos del runtime
├── .dockerignore          # contexto de build limpio
├── DEPLOY.md              # guía de despliegue detallada
└── README.md              # este archivo
```

> 📌 La carpeta `Mods/` se mantiene **local** (gitignored). Es la fuente para subir a R2 una vez; no se versiona ni se hornea en la imagen.

---

<div align="center">

**Hecho para correr fluido en hardware modesto.** 🟢

Construido sobre [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server) · [itzg/docker-mc-backup](https://github.com/itzg/docker-mc-backup)

</div>
