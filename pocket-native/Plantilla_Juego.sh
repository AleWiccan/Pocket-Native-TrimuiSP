#!/bin/sh
# PLANTILLA.sh v3 - nombre del juego - Pocket Native en Trimui Smart Pro (stock OS / JEB+)
# Copiar a SDCARD/Roms/PORTS/ con el nombre que quieras que salga en el menu.
#
# Estructura esperada en la SD:
#   SDCARD/Data/ports/PocketNative/pocket-native      (el runtime, ya con el parche)
#   SDCARD/Data/ports/PocketNative/games/<GAME_ID>/   (title.so, game.3ds, ...)
#   SDCARD/Data/ports/PocketNative/titles/ power.sh ...
# (tambien vale si el kit esta un nivel mas abajo, en .../PocketNative/pocket-native/)
#
# Para otro juego: copia este archivo, cambia GAME_ID (y PROFILE_ID si hace falta).
# Todo lo que se escribe va a la SD: nada en la particion del sistema
# (solo /proc y /sys, que no ocupan disco).
# Salir del juego: FN (boton Menu central) + Start. Tocar FN abre el menu del juego.
# Log: games/<GAME_ID>/data/log.txt (se sobrescribe en cada arranque).

# ---------- LO UNICO QUE HAY QUE CAMBIAR POR JUEGO ----------
GAME_ID="CAMBIAR_ID_16_DIGITOS"       # nombre de la carpeta dentro de games/ (16 digitos hex)
PROFILE_ID="" # id cuyo perfil usar si GAME_ID no tiene; dejar "" si no hace falta
# -------------------------------------------------------------
PORT_NAME="PocketNative"  # nombre de la carpeta en Data/ports/ (cambiar si la tienes con otro nombre)

PORT="$(cd "$(dirname "$0")/../../Data/ports/$PORT_NAME" 2>/dev/null && pwd)"
[ -n "$PORT" ] || exit 1
if [ -d "$PORT/pocket-native" ]; then BASE="$PORT/pocket-native"; else BASE="$PORT"; fi
BIN="$BASE/pocket-native"
GAME="$BASE/games/$GAME_ID"
if [ ! -d "$GAME" ]; then
  echo "[launcher] no existe $GAME (revisa GAME_ID)" > "$PORT/log.txt"
  ls "$BASE/games" >> "$PORT/log.txt" 2>&1
  exit 1
fi
ROM="$GAME/game.3ds"
DATA="$GAME/data"
CONF="$BASE/config"
TMPD="$CONF/tmp"
mkdir -p "$DATA" "$CONF" "$TMPD" "$CONF/data" "$CONF/cache"
LOGF="$DATA/log.txt"
chmod +x "$BIN" "$BASE/power.sh" 2>/dev/null

export LD_LIBRARY_PATH="$BASE/libs:/usr/trimui/lib:/usr/lib:$LD_LIBRARY_PATH"
unset SDL_VIDEODRIVER
# temporales, caches y ajustes en la SD, nunca en la particion del sistema
export HOME="$BASE" TMPDIR="$TMPD"
export XDG_CONFIG_HOME="$CONF" XDG_DATA_HOME="$CONF/data" XDG_CACHE_HOME="$CONF/cache"

echo "[launcher] version 3 - $GAME_ID - $(date)" > "$LOGF"

# Perfil: si el juego no tiene perfil con su propio id (p. ej. un volcado cuyo
# ROM declara 0004000000000000), se copia el del PROFILE_ID.
if [ -n "$PROFILE_ID" ] && [ ! -f "$BASE/titles/$GAME_ID/profile.toml" ] && [ -f "$BASE/titles/$PROFILE_ID/profile.toml" ]; then
  mkdir -p "$BASE/titles/$GAME_ID"
  cp "$BASE/titles/$PROFILE_ID/profile.toml" "$BASE/titles/$GAME_ID/profile.toml"
  echo "[launcher] perfil $PROFILE_ID copiado a $GAME_ID" >> "$LOGF"
fi

# power.sh guarda los governors en /tmp: se usa una copia que los guarda en la SD
sed "s|/tmp/pocket-native-governors|$TMPD/governors|" "$BASE/power.sh" > "$CONF/power_trimui.sh"
chmod +x "$CONF/power_trimui.sh"

# --- Mando: el binario solo reconoce nombres con Gamepad/Controller/Joypad y
# el de la Trimui es "TRIMUI Player1". Se le ensena una copia con otro nombre.
BOUND=0
sed 's/TRIMUI Player1/TRIMUI Gamepad/' /proc/bus/input/devices > "$TMPD/pn_devices" 2>/dev/null
if mount --bind "$TMPD/pn_devices" /proc/bus/input/devices 2>>"$LOGF"; then
  BOUND=1
  echo "[launcher] bind de /proc/bus/input/devices OK" >> "$LOGF"
else
  echo "[launcher] bind de /proc/bus/input/devices FALLO" >> "$LOGF"
fi

# --- Opcional: congelar el menu de Trimui mientras se juega (crear el archivo stopui.on en la carpeta PocketNative)
UI=""
if [ -f "$PORT/stopui.on" ]; then
  UI="$(pgrep -x MainUI 2>/dev/null | head -n 1)"
  [ -n "$UI" ] && kill -STOP "$UI" && echo "[launcher] MainUI ($UI) detenido" >> "$LOGF"
fi

# --- CPU: nucleos online, governor performance y frecuencia maxima (el stock la limita a 1,2 GHz)
CPUP=/sys/devices/system/cpu/cpufreq/policy0
OLD_GOV="$(cat $CPUP/scaling_governor 2>/dev/null)"
OLD_MAX="$(cat $CPUP/scaling_max_freq 2>/dev/null)"
OFFLINE=""
for c in /sys/devices/system/cpu/cpu[1-9]/online; do
  [ -f "$c" ] && [ "$(cat "$c")" = 0 ] && { OFFLINE="$OFFLINE $c"; echo 1 > "$c" 2>/dev/null; }
done
echo "performance" > $CPUP/scaling_governor 2>/dev/null
cat $CPUP/cpuinfo_max_freq > $CPUP/scaling_max_freq 2>/dev/null
echo "[launcher] cpu: governor $(cat $CPUP/scaling_governor) max $(cat $CPUP/scaling_max_freq) (antes: $OLD_GOV $OLD_MAX)" >> "$LOGF"

# --- Entorno del motor. KMS=1 falla sin libgbm y cae a /dev/fb0; NULL_WINDOW es para la PowerVR.
export ZAKURO_FAST=1 ZAKURO_KMS=1 ZAKURO_FBDEV_NULL_WINDOW=1
export ZAKURO_DATA="$DATA" ZAKURO_RECOMPILED="$GAME/title.so" ZAKURO_SHADER_MANIFEST="$DATA/shaders.txt"
export POCKET_NATIVE_TITLES="$BASE/titles" POCKET_NATIVE_POWER="$CONF/power_trimui.sh" POCKET_NATIVE_CONFIG="$CONF"
[ -f "$DATA/drops.txt" ] && export ZAKURO_DROP_DRAWS="$(cat "$DATA/drops.txt")"
echo 1 > /proc/sys/debug/exception-trace 2>/dev/null

cd "$GAME" || exit 1
while true; do
  "$BIN" "$ROM" >> "$LOGF" 2>&1
  CODE=$?
  [ "$CODE" -eq 3 ] || break      # codigo 3 = reinicio pedido desde el menu del juego
done
echo "[launcher] codigo de salida: $CODE  (137 = falta de memoria)" >> "$LOGF"
echo "[launcher] memoria libre: $(grep MemAvailable /proc/meminfo)" >> "$LOGF"
if [ "$CODE" != "0" ]; then
  dmesg 2>/dev/null | grep -iE 'pocket|segv|fault|oom|killed|out of memory' | tail -8 >> "$LOGF"
fi

# --- Restaurar
"$CONF/power_trimui.sh" normal 2>/dev/null
[ -n "$OLD_GOV" ] && echo "$OLD_GOV" > $CPUP/scaling_governor 2>/dev/null
[ -n "$OLD_MAX" ] && echo "$OLD_MAX" > $CPUP/scaling_max_freq 2>/dev/null
for c in $OFFLINE; do echo 0 > "$c" 2>/dev/null; done
[ "$BOUND" = 1 ] && umount /proc/bus/input/devices 2>/dev/null
[ -n "$UI" ] && kill -CONT "$UI" 2>/dev/null
exit 0
