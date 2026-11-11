# Pocket Native en la Trimui Smart Pro

Parche para ejecutar juegos de Nintendo 3DS recompilados con
[Pocket Native](https://github.com/whovian64/pocket-native) en la **Trimui Smart Pro**
con el firmware stock / JEB+, sin usar el runtime oficial de PortMaster.

> **Proyecto no oficial.** No está afiliado ni respaldado por Nintendo, Trimui, Pocket Native ni
> Zakuro. Este repositorio **no contiene ningún juego, volcado, clave ni dato de Nintendo**.
> Necesitas tu propia copia legal del juego, volcada de tu propia consola.

## Estado

| | |
|---|---|
| Consola | Trimui Smart Pro, firmware JEB+ (stock OS), 1 GB de RAM, sin swap |
| Juego probado | **Pokémon X** (un volcado `.cci` ya descifrado) |
| Resultado | Imagen, sonido y mando funcionan. Jugable. |
| Rendimiento | Aceptable. Hay parones por compilación de shaders que bajan a medida que se llena la caché |
| Memoria | En las pruebas, entre unos 170 y 320 MiB de RAM; no hizo falta swap |
| Otros juegos | **Sin probar.** Pocket Native tiene su propia lista de compatibilidad, medida en otras consolas |

Versión base: Pocket Native 0.5.0, commit `178f2b0f4f3444ed8d6af49fe5c130fe3094b598`.

## Qué incluye este repositorio

| Archivo | Para qué sirve |
|---|---|
| `pocket-native-trimui.patch` | Parche para el runtime (`engine/gpu/src/raster/gles/display.rs`) que arregla la salida de imagen en la PowerVR |
| `Plantilla_Juego.sh` | Plantilla: Solo se cambia el ID |

## Requisitos

- Windows con Docker Desktop y PowerShell (también debería valer Linux, no probado).
- Un volcado de tu juego, descifrado, y tu `aes_keys.txt`.
- Git.

## Cómo compilar

En PowerShell:

```powershell
cd "ruta/a/guardar/el/proyecto"
git clone -c core.autocrlf=false https://github.com/whovian64/pocket-native.git
cd pocket-native
git checkout 178f2b0f4f3444ed8d6af49fe5c130fe3094b598
# copia pocket-native-trimui.patch de este repositorio a pocket-native
git apply --whitespace=nowarn ..\pocket-native-trimui.patch

# copia tu volcado a esta carpeta (pocket-native) y ejecuta el kit del proyecto
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 juego.3ds -Keys aes_keys.txt
```

El kit compila en un contenedor el runtime y el juego recompilado. La primera vez tarda bastante
y descarga varios cientos de MB. Las siguientes reutilizan lo ya compilado.

> **Importante:** el parche solo afecta al runtime. Si usas otro kit (por ejemplo uno sin parchear)
> para recompilar el juego, no copies su `pocket-native` a la consola. El juego recompilado y el
> runtime comparten un número de interfaz (ABI 5 en este commit) y deben coincidir.
> No ejecutes `Update Pocket Native` sin guardar antes el parche: no he comprobado cómo trata los
> cambios locales.

## Instalación en la SD

Copia el contenido de la carpeta `pocket-native` que genera el kit en la carpeta build a:

```
SDCARD/Data/ports/PocketNative/
├── pocket-native             (runtime, con el parche)
├── power.sh, titles/, libs/ ...
└── games/<GAME_ID>/          (title.so, game.3ds, ...)
SDCARD/Roms/PORTS/<Nombre del juego>.sh (Plantilla modificada con el GAME_ID del juego)
SDCARD/Imgs/PORTS/<Nombre del juego>.png (Carátula del juego)
```

- `GAME_ID` es el nombre de la carpeta que el kit crea dentro de `games/`. El lanzador copia el
  perfil de ese ID para que se apliquen sus ajustes.
- El nombre de la carpeta `PocketNative` se puede cambiar con la variable `PORT_NAME` del lanzador.
- Para otro juego, copia `Plantilla_Juego.sh` a `Roms/PORTS/` y cambia `GAME_ID` (y `PROFILE_ID` si hace falta).
- La primera vez que se ejecuta un juego en la consola hay que configurar como quieres que se vean las pantalla ya que inicia con una sola pantalla. Esto se hace presionando el botón Menu y en Layout seleccionar el perfil a usar (se recomienda Big top, small beside, Aspect radio: 16:10). Tambien puede que tengas que cambiar D-Pad a D-pad.

## Controles

- **FN** (el botón central, Menú) abre el menú del juego al tocarlo.
- **FN + Start** sale del juego.
- El resto del reparto es el de Pocket Native. La Smart Pro no tiene L3/R3.

## Qué hubo que cambiar y por qué

1. **Imagen.** Sin KMS, el motor dibuja en un búfer fuera de pantalla, así que se oye pero no se ve.
   Con `ZAKURO_KMS=1` falla KMS (no hay `libgbm`/`libdrm`), cae a `/dev/fb0` y le pasa a EGL una
   estructura de ventana pensada para Mali. El EGL de la PowerVR de la consola se cae en
   `eglCreateWindowSurface`. El parche añade la variable `ZAKURO_FBDEV_NULL_WINDOW`, que no pasa
   ventana, y con eso la imagen sale. La causa exacta del fallo es una deducción a partir del
   log y del código.
2. **Mando.** El binario solo reconoce dispositivos cuyo nombre contiene `Gamepad`, `Controller`
   o `Joypad`, y el de la Trimui es `TRIMUI Player1`. El lanzador monta con `mount --bind` una copia
   de `/proc/bus/input/devices` con el nombre cambiado y la desmonta al salir.
3. **CPU.** El sistema limita la CPU a 1,2 GHz (el máximo es 2 GHz) y apaga núcleos. El lanzador
   los activa, pone el governor `performance` y restaura todo al salir.
4. **Partición del sistema.** Es de unos 190 MB y casi sin espacio. El lanzador no escribe en ella:
   temporales, caché y ajustes van a la SD (`TMPDIR` y `XDG_*`), y `power.sh` se usa en una copia que
   guarda su estado en la SD. Solo toca `/proc` y `/sys`, que no ocupan disco.
5. **No hace falta SDL.** El runtime usa `dlopen` de `libEGL`, `libGLESv2` y `libasound`, que ya
   están en la consola, y lee el mando por evdev. Pide como máximo glibc 2.27, así que arranca con
   la 2.33 de la Smart Pro.

## Problemas conocidos y consejos

| Síntoma | Qué probar |
|---|---|
| `Killed` / código 137 | Falta de memoria. No ocurrió en las pruebas, pero con juegos más pesados podría hacer falta un swapfile en la SD |
| Parones al cargar shaders | Normal en las primeras sesiones. La caché está en `config/cache/zakuro/gles/`: no la borres |
| El juego no arranca | Revisa `games/<GAME_ID>/data/log.txt` (se sobrescribe en cada arranque) |

Sal siempre con FN + Start, no reiniciando la consola, para que se guarden partida y manifiesto de shaders.

## Sin verificar

- Solo se ha probado Pokémon X, en una consola con firmware JEB+. Otros firmwares o juegos pueden diferir.
- El parche se ha probado únicamente sobre el commit indicado.
- No se ha medido en detalle la velocidad en fotogramas por segundo ni la temperatura.

## Créditos y licencias

- [Pocket Native](https://github.com/whovian64/pocket-native), fork de Zakuro, por whovian64 y colaboradores.
  Consulta su `LICENSE`, `CREDITS.md` y `THIRD_PARTY_LICENSES.txt`; el parche es una modificación de ese código.
- Los lanzadores y este README se publican bajo licencia **[elige: MIT / otra]**, © [tu nombre].
- Pokémon, Nintendo 3DS y los nombres relacionados son marcas de sus propietarios.
