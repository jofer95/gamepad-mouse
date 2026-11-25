# Gamepad Mouse

App de barra de menú para macOS que convierte un control de consola (probado con el DualSense de PS5)
en mouse, scroll y atajos de teclado, para trabajar con las manos abajo y descansadas.

## Instalar

```bash
./scripts/build-app.sh --install
```

Compila, firma con el primer certificado de firma de tu llavero que no esté revocado (así el permiso
de Accesibilidad no se pierde al recompilar), copia la app a `~/Applications` y la abre. Para elegir
otro: `SIGN_IDENTITY=<SHA-1> ./scripts/build-app.sh --install` (los ves con
`security find-identity -v -p codesigning`).

> Si macOS dice *"contains malware"* y la manda a la Papelera, casi seguro se firmó con un
> certificado revocado: macOS trata así cualquier app firmada con uno. El script ya los descarta.

La primera vez:

1. **Accesibilidad:** macOS pide permiso. Ve a *Ajustes del Sistema → Privacidad y seguridad →
   Accesibilidad* y activa **GamepadMouse**. Sin esto la app no puede mover el mouse ni teclear.
   El ícono de la barra de menú muestra ⚠️ mientras falte.
2. **Control:** enciéndelo con el botón PS. Si nunca lo emparejaste: mantén **PS + Create** hasta
   que la luz parpadee y conéctalo en *Ajustes → Bluetooth*. También funciona por cable USB-C.

La barra de luz del control se pone **azul** cuando el mapeo está activo y **naranja** en pausa.

## Temas

Un tema es un mapeo completo de los botones. Vienen dos, y puedes crear los tuyos:

| Control | A · Clásico | B · Clics en botones |
|---|---|---|
| Stick izquierdo | Mover el puntero | Mover el puntero |
| Stick derecho | Scroll | Scroll |
| ✕ | Dictar con Wispr Flow (mantener) | Clic izquierdo |
| ○ | Cerrar ventana (`⌘W`) | Clic izquierdo |
| □ | Modo precisión (mantener) | Clic derecho |
| △ | Enter | Clic derecho |
| Touchpad (clic) | Clic izquierdo | Dictar con Wispr Flow (mantener) |
| Create (izq. del touchpad) | Escape | Cerrar ventana (`⌘W`) |
| Options (der. del touchpad, ≡) | App anterior (`⌘Tab`) | Enter |
| R2 | Clic izquierdo | Sin acción |
| L2 | Clic derecho | Sin acción |
| L1 / R1 | Atrás / Adelante (`⌘[` / `⌘]`) | Atrás / Adelante |
| D-pad ↑ | Flecha arriba (se repite) | Mission Control: todas las ventanas |
| D-pad ↓ | Flecha abajo (se repite) | Ventanas de la app al frente |
| D-pad ← / → | Flechas (se repiten) | Flechas (se repiten) |
| R3 | Clic central | Clic central |
| L3 | Sin acción | Sin acción |
| PS | Pausar / reanudar | Pausar / reanudar |

Los clics se mantienen mientras sostienes el botón, así que también sirven para arrastrar. Dos
pulsaciones rápidas cuentan como doble clic. Dictar mantiene `⇧⌃`, el push-to-talk de Wispr Flow.

Para cambiar de ventana en B: D-pad ↑ abre Mission Control, mueves el puntero a la ventana y haces
clic. Si presionas ↑ otra vez, se cierra sin cambiar.

## Configurar los botones

Menú de la barra → **Configurar botones…** (`⌘,`):

- **Izquierda:** la lista de temas. El seleccionado es el que usa el control. **+** crea un tema
  como copia del seleccionado y **−** lo borra (los predeterminados no se borran, pero
  **Restaurar original** los regresa a como venían).
- **Botones:** cada botón con su acción. Presiona un botón del control y su fila se ilumina, para
  ubicarlo. En **Atajo de teclado** y **Mantener teclas**, haz clic en el atajo y presiona las teclas
  nuevas. Para mantener solo modificadores, como `⇧⌃`, presiónalos y suéltalos.
- **Movimiento:** velocidad y curva del puntero y del scroll, modo precisión, zona muerta y qué stick
  mueve el puntero. Estos ajustes son de todos los temas.

Todo se aplica al momento y se guarda solo. También puedes cambiar de tema desde el menú
**Tema**, o con un botón del control asignado a **Siguiente tema**.

> Al grabar `⇧⌃` en la ventana, Wispr Flow también lo detecta y empieza a dictar. Es normal.

### El archivo de configuración

Todo vive en `~/Library/Application Support/GamepadMouse/config.json` (**Editar archivo JSON…** lo
abre, **Recargar archivo JSON** lo vuelve a leer). Si tiene un error, la app avisa y sigue con la
configuración anterior.

```json
{
  "activeThemeID": "b",
  "settings": { "pointerMaxSpeed": 1600, "pointerCurve": 2.2, "deadzone": 0.12 },
  "themes": [
    {
      "id": "b",
      "name": "B · Clics en botones",
      "buttons": {
        "cross":    { "type": "leftClick" },
        "create":   { "type": "shortcut", "key": "w", "modifiers": ["cmd"] },
        "touchpad": { "type": "holdKey", "modifiers": ["shift", "ctrl"] },
        "dpadUp":   { "type": "shortcut", "key": "up", "repeat": true }
      }
    }
  ]
}
```

- **Botones:** `cross`, `circle`, `square`, `triangle`, `l1`, `r1`, `l2`, `r2`, `l3`, `r3`, `dpadUp`,
  `dpadDown`, `dpadLeft`, `dpadRight`, `options`, `create`, `ps`, `touchpad`. Un botón que falte en un
  tema no hace nada.
- **Acciones (`type`):** `leftClick`, `rightClick`, `middleClick`, `shortcut` (`key` + `modifiers`,
  `repeat` opcional), `holdKey` (mantiene `key` y/o `modifiers`), `precision`, `toggleEnabled`,
  `nextTheme`, `missionControl`, `appWindows`, `none`.
- **Modificadores:** `cmd`, `shift`, `option`, `ctrl`, `fn`.
- **Teclas:** letras, números, `return`, `tab`, `space`, `delete`, `escape`, `up`/`down`/`left`/`right`,
  `home`, `end`, `pageup`, `pagedown`, `f1`–`f12` y signos como `[`, `]`, `,`, `.`, `/`.

## Cómo funciona

- `GameController` (framework de Apple) lee el control; `shouldMonitorBackgroundEvents` hace que
  llegue la entrada aunque la app no esté al frente.
- Un timer a 120 Hz lee sticks y botones, y `CGEvent` publica eventos de mouse, scroll y teclado.
- Los atajos con modificadores mandan también el evento de cada tecla modificadora, para apps que
  escuchan las teclas en sí (como el push-to-talk de Wispr Flow).

| Archivo | Qué hace |
|---|---|
| `Sources/GamepadMouse/Engine.swift` | Bucle de 120 Hz: botones → acciones, sticks → puntero y scroll |
| `Sources/GamepadMouse/InputSynthesizer.swift` | Publica los eventos de mouse, scroll y teclado |
| `Sources/GamepadMouse/SystemActions.swift` | Abre Mission Control y las ventanas de la app |
| `Sources/GamepadMouse/ControllerManager.swift` | Conexión del control, lectura, batería y luz |
| `Sources/GamepadMouse/Config.swift` | Botones, acciones, temas A y B, formato del archivo |
| `Sources/GamepadMouse/ConfigStore.swift` | Config en vivo: cambios de tema y de botones, guardado |
| `Sources/GamepadMouse/SettingsView.swift` | Ventana para configurar botones (SwiftUI) |
| `Sources/GamepadMouse/ShortcutRecorder.swift` | Botón que graba un atajo de teclado |
| `Sources/GamepadMouse/AppDelegate.swift` | Menú de la barra, ventana, permisos, abrir al iniciar sesión |

## Pendiente / ideas

- Probar el Switch 2 Pro Controller (los botones van por posición: `cross` es el de abajo).
- Usar el touchpad del DualSense como trackpad.
- Perfiles por app (otro mapeo cuando estás en el navegador o en la terminal).
