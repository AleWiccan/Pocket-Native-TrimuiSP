# Pocket Native en la Trimui Smart Pro

Guia para ejecutar juegos de Nintendo 3DS recompilados con
[Pocket Native](https://github.com/whovian64/pocket-native) en la **Trimui Smart Pro**
con el firmware stock

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


## Qué incluye este repositorio

| Archivo | Para qué sirve |
|---|---|
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

# copia tu volcado a esta carpeta (pocket-native) y ejecuta el kit del proyecto
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 juego.3ds -Keys aes_keys.txt
```

El kit compila en un contenedor el runtime y el juego recompilado. La primera vez tarda bastante
y descarga varios cientos de MB. Las siguientes reutilizan lo ya compilado.

Otra opción es descargar el kit con interfaz gráfica desde https://github.com/whovian64/pocket-native/releases

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

## Controles

- **FN** (el botón central, Menú) abre el menú del juego al tocarlo.
- **FN + Start** sale del juego.
- El resto del reparto es el de Pocket Native. La Smart Pro no tiene L3/R3.

## Problemas conocidos y consejos

| Síntoma | Qué probar |
|---|---|
| `Killed` / código 137 | Falta de memoria. No ocurrió en las pruebas, pero con juegos más pesados podría hacer falta un swapfile en la SD |
| Parones al cargar shaders | Normal en las primeras sesiones. La caché está en `config/cache/zakuro/gles/`: no la borres |
| El juego no arranca | Revisa `games/<GAME_ID>/data/log.txt` (se sobrescribe en cada arranque) |

Sal siempre con FN + Start, no reiniciando la consola, para que se guarden partida y manifiesto de shaders.

## Créditos y licencias

- [Pocket Native](https://github.com/whovian64/pocket-native), fork de Zakuro, por whovian64 y colaboradores.
  Consulta su `LICENSE`, `CREDITS.md` y `THIRD_PARTY_LICENSES.txt`; el parche es una modificación de ese código.
- Los lanzadores y este README se publican bajo licencia **MIT**, ©AleWiccan.
- Pokémon, Nintendo 3DS y los nombres relacionados son marcas de sus propietarios.
