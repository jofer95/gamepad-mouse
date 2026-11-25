<div align="center">

# 🎮 Gamepad Mouse

**Use a PlayStation 5 controller as your Mac's mouse, scroll wheel and keyboard shortcuts.**<br>
Work with your hands resting low instead of reaching for the mouse and keyboard all day.

macOS 13+ · Swift · DualSense (PS5) · Menu bar app · English & Español · [MIT License](LICENSE)

[Español](README.es.md) · [Docs site](https://jofer95.github.io/gamepad-mouse/)

<img src="docs/images/settings.png" alt="The Gamepad Mouse settings window: themes on the left, each controller button and its action on the right" width="760">

</div>

## Why

Working with AI agents means a lot of the same moves: dictate a prompt, scroll, click, go back,
close a window, switch apps. Gamepad Mouse puts all of that on a controller you can hold in your lap,
so your wrists and shoulders get a break.

## Features

- 🖱️ **Mouse and scroll on the sticks.** The left stick moves the pointer with an acceleration curve,
  the right stick scrolls both ways. A precision mode slows both down for small targets.
- ⌨️ **Any button, any action.** Left, right and middle click (hold to drag, tap twice to
  double-click), keyboard shortcuts with auto-repeat, held keys for push-to-talk dictation, Mission
  Control and the front app's windows.
- 🎯 **Gyro pointer.** Hold L2 and turn the controller to move the pointer like a laser pointer,
  for fine aiming without touching the sticks.
- 🎨 **Themes.** Three built-in mappings and as many of your own as you like, switched from the menu
  bar or from the controller.
- 👆 **Touchpad as a trackpad.** Slide one finger to move the pointer. Spread or pinch two fingers to
  zoom smoothly, the way a Mac trackpad does.
- 🪟 **A settings window.** Each button's row lights up when you press it, and shortcuts are recorded
  by pressing them.
- 🔋 **The real battery level.** Read straight from the controller, since macOS doesn't report it
  over Bluetooth.
- 🔒 **A lock on the mute button.** Press mute and nothing else does anything until you press it
  again, with a dim white light bar and a buzz to tell you. It can also lock by itself after a while.
- 💡 **Light bar status.** Each theme has its own color, the light breathes red while you dictate,
  turns orange while paused and dim white while locked, and flashes yellow when the battery runs low.
- 🌎 **English and Spanish.** The app follows your Mac's language.

## Requirements

- macOS 13 Ventura or later
- Xcode or the Xcode Command Line Tools (Swift 5.9+)
- A DualSense (PS5) controller, over Bluetooth or USB-C. Other controllers macOS supports should work
  for the sticks and buttons; the touchpad, battery and pinch are DualSense-only.

## Install

```bash
git clone https://github.com/jofer95/gamepad-mouse.git
cd gamepad-mouse
./scripts/build-app.sh --install
```

This builds the app, signs it, copies it to `~/Applications` and opens it. Look for the controller
icon in the menu bar.

### First run

1. **Allow Accessibility.** macOS asks the first time. Turn on **GamepadMouse** in *System Settings →
   Privacy & Security → Accessibility*. Without it the app can't move the pointer or type. The menu
   bar icon shows ⚠️ until it's allowed.
2. **Connect the controller.** Pair it over Bluetooth the first time (below), or plug in a USB-C data
   cable, which needs no pairing.

### Pair a DualSense over Bluetooth

You only do this once. After that, pressing **PS** reconnects it to the Mac.

1. **Turn the controller off.** If any light is on, hold **PS** for about 10 seconds until it goes
   out. If a PS5 is nearby and on, turn it off too, or the controller connects to it instead.
2. **Put it in pairing mode.** Hold **Create** (the small button left of the touchpad) and **PS**
   together for about 3–5 seconds, until the light around the touchpad **blinks quickly, twice at a
   time**. A slow pulse means it's trying to reconnect to its last device, not pairing: let go, turn
   it off and try again.
3. **Connect it on the Mac.** Open *System Settings → Bluetooth*. **DualSense Wireless Controller**
   appears under *Nearby Devices*; click **Connect**. If it doesn't show up within a minute, repeat
   step 2.
4. **Done.** The light bar stays on and the player light under the touchpad lights up. With Gamepad
   Mouse running, the light bar turns the active theme's color (blue, green or purple).

<details>
<summary><b>Pairing problems</b></summary>

- **It doesn't show up in Bluetooth:** pairing mode only lasts about a minute. Hold **Create + PS**
  again and keep *System Settings → Bluetooth* open while it blinks.
- **It was paired before but won't connect:** in *System Settings → Bluetooth*, click ⓘ next to
  the controller, choose **Forget This Device**, and pair it again.
- **You also play on a PS5:** the controller remembers one console or computer at a time. After
  using it on the PS5 (or connecting it there by cable), pair it with the Mac again.
- **No Bluetooth needed:** a USB-C data cable connects it right away, and it charges at the same
  time. The microphone only works over the cable.

</details>

## Themes

A theme is a complete button mapping. Pick one from the menu bar (**Theme**) or in
**Configure Buttons…**. The built-in ones:

| Control | A · Classic | B · Clicks on buttons | C · Touchpad as mouse |
|---|---|---|---|
| Left stick | Pointer | Pointer | Pointer |
| Right stick | Scroll | Scroll | Scroll |
| ✕ Cross | Dictate (hold) | Left click | Left click |
| ○ Circle | Close window `⌘W` | Left click | Left click |
| □ Square | Precision (hold) | Right click | Right click |
| △ Triangle | Return | Right click | Right click |
| Touchpad click | Left click | Dictate (hold) | Dictate (hold) |
| Touchpad slide | — | — | Pointer, pinch to zoom |
| Create | Escape | Close window `⌘W` | Close window `⌘W` |
| Options | Last app `⌘Tab` | Return | Return |
| L1 / R1 | Back / Forward | Back / Forward | Back / Forward |
| L2 | Right click | Gyro pointer (hold) | Gyro pointer (hold) |
| R2 | Left click | — | — |
| D-pad ↑ / ↓ | Arrows | Mission Control / App windows | Mission Control / App windows |
| D-pad ← / → | Arrows | Arrows | Arrows |
| R3 | Middle click | Middle click | Middle click |
| PS | — | — | — |
| 🎙️ Mute | Lock / unlock | Lock / unlock | Lock / unlock |

The mute button always locks and unlocks; it isn't part of a theme. **Dictate** holds `⇧⌃` while the button is down. Set your dictation app's push-to-talk (Wispr Flow,
Superwhisper, …) to that shortcut, or record your own in the settings window. Back and forward send
`⌘[` and `⌘]`.

## Touchpad

With a theme whose touchpad is set to **Moves the pointer, pinch to zoom** (theme C):

- **One finger** moves the pointer. Slide slowly for precision, quickly to cross the screen. Putting
  a finger down never moves the pointer; only sliding does.
- **Two fingers** zoom. Spread to zoom in, pinch to zoom out.
  - **Smooth zoom** (default) sends a real trackpad pinch, so it follows your fingers. It works in
    apps that take trackpad pinches: Safari, Chrome, Preview, Maps, Photos.
  - Turn smooth zoom off to zoom in **steps** with `⌘=` / `⌘-` instead, which works almost everywhere,
    Terminal and VS Code included.
- **Clicking** the touchpad is a separate button you can map to anything.
- **While you dictate** (theme C dictates on the touchpad click), the touchpad doesn't move the
  pointer, so pressing it doesn't nudge the pointer. After you let go, the pointer stays still until
  you lift your finger. The sticks still move it. Turn this off with **Keep the pointer still while
  dictating**.

## Gyro pointer

In themes B and C, hold **L2** and turn the controller: the pointer follows like a laser pointer.
It moves by how fast you turn, so holding the controller still keeps the pointer still, slow turns
aim precisely and quick ones cross the screen. Let go of L2 to move the controller freely; press it
again to pick up where the pointer is, like lifting a mouse off the desk.

In **Configure Buttons… → Movement → Gyro pointer** you can set the sensitivity, choose whether left
and right come from **turning** the controller (like a flashlight) or **tilting** it (like a steering
wheel, handy with it in your lap), and invert either direction. Any button can be a gyro pointer:
pick **Gyro pointer (hold)** as its action.

## Lock

Press the **mute** button (under the PS logo) to lock the controller. Every other button, both sticks
and the touchpad stop doing anything, anything held is let go, the light bar turns dim white and the
controller buzzes once. Press mute again to unlock: two buzzes and the light comes back. You can also
lock from the menu bar (**Lock Controller**, `⌘L` with the menu open).

In **Configure Buttons… → Movement → Lock** you can require holding mute for half a second to unlock,
and make the controller lock by itself after 2 to 30 minutes without use. Both are off by default.

## Light bar

The light bar around the touchpad tells you what the controller is doing without looking at the screen:

| State | Light |
|---|---|
| Theme A active | 🔵 Blue |
| Theme B active | 🟢 Green |
| Theme C active | 🟣 Purple |
| Dictating (a *Hold keys* button held) | 🔴 Red, breathing slowly |
| Paused | 🟠 Orange |
| Locked | ⚪ Dim white |
| Battery low | 🟡 Two yellow flashes once a minute, over the normal color |

Changing themes blinks the light twice and buzzes once. Pick each theme's color with the **Light**
color well next to its name in **Configure Buttons…**; your own themes start with the color of the
theme they were copied from. **Movement → Light bar** has the brightness and turns the dictation
breath and the low-battery flash on or off.

The app sets the light bar straight through the DualSense's HID output report, not through macOS,
whose light can stop reaching the controller and leave it on one color. When you quit the app, the
light stays on its last color until the controller turns off. The five player lights and the mute
button's light are left to macOS.

## Configure

Open the menu bar icon → **Configure Buttons…** (`⌘,`).

- **Themes** on the left. The selected one is live. **+** copies it into a new theme, **−** deletes
  it. Built-in themes can't be deleted, but **Restore original** puts them back the way they shipped.
- **Buttons** tab: every button and its action. Press a controller button and its row lights up. To
  change a shortcut, click it and press the new keys. For modifier-only shortcuts like `⇧⌃`, press
  and release them.
- **Movement** tab: pointer, scroll and touchpad speeds, response curves, precision speed, stick dead
  zone, and which stick moves the pointer. These apply to every theme.

Changes apply right away and save themselves.

<details>
<summary><b>The config file</b></summary>

Everything lives in `~/Library/Application Support/GamepadMouse/config.json`. **Edit JSON File…** in
the menu opens it and **Reload JSON File** reads it again. If the file has an error, the app tells
you and keeps the previous settings.

```json
{
  "activeThemeID": "c",
  "settings": { "pointerMaxSpeed": 1600, "touchpadSpeed": 1.0, "smoothZoom": true },
  "themes": [
    {
      "id": "c",
      "name": "C · Touchpad as mouse",
      "touchpad": "pointer",
      "buttons": {
        "cross":    { "type": "leftClick" },
        "create":   { "type": "shortcut", "key": "w", "modifiers": ["cmd"] },
        "touchpad": { "type": "holdKey", "modifiers": ["shift", "ctrl"] },
        "dpadLeft": { "type": "shortcut", "key": "left", "repeat": true }
      }
    }
  ]
}
```

| | Values |
|---|---|
| Buttons | `cross` `circle` `square` `triangle` `l1` `r1` `l2` `r2` `l3` `r3` `dpadUp` `dpadDown` `dpadLeft` `dpadRight` `options` `create` `ps` `touchpad` |
| Action `type` | `leftClick` `rightClick` `middleClick` `shortcut` (`key`, `modifiers`, optional `repeat`) `holdKey` (`key` and/or `modifiers`) `precision` `gyroPointer` `missionControl` `appWindows` `toggleEnabled` `nextTheme` `none` |
| `touchpad` | `none` or `pointer` |
| Modifiers | `cmd` `shift` `option` `ctrl` `fn` |
| Keys | letters, digits, `return` `tab` `space` `delete` `escape` `up` `down` `left` `right` `home` `end` `pageup` `pagedown` `f1`–`f12`, and `[` `]` `,` `.` `/` `;` `'` `-` `=` `` ` `` `\` |
| Settings | `pointerMaxSpeed` `pointerCurve` `scrollMaxSpeed` `scrollCurve` `invertScrollVertical` `invertScrollHorizontal` `precisionFactor` `deadzone` `pointerStick` (`left`/`right`) `touchpadSpeed` `pinchSensitivity` `smoothZoom` `holdToUnlock` `autoLockMinutes` (0 = never) `gyroSensitivity` `gyroHorizontalAxis` (`yaw`/`roll`) `invertGyroHorizontal` `invertGyroVertical` |

A button left out of a theme does nothing.

</details>

## Language

The app shows in English or Spanish, whichever comes first in *System Settings → General → Language &
Region*. To use a different one only for this app, add it under **Applications** on that same screen.
Themes you rename keep your name in either language.

## Troubleshooting

<details>
<summary><b>macOS says the app "contains malware" and moves it to the Trash</b></summary>

The app was signed with a revoked certificate; macOS treats any app signed with one as malware. The
build script skips revoked certificates, so rebuild with `./scripts/build-app.sh --install`. To choose
a certificate yourself, list them with `security find-identity -v -p codesigning` and run
`SIGN_IDENTITY=<SHA-1> ./scripts/build-app.sh --install`.

</details>

<details>
<summary><b>The controller is connected but nothing moves</b></summary>

- Check that Accessibility is allowed: the menu shows **Accessibility: allowed**.
- Check that it isn't locked (dim white light bar, 🔒 in the menu bar): press **mute**.
- Check that mapping isn't paused (orange light bar, ⏸ in the menu bar): choose **Enabled** in the menu.

</details>

<details>
<summary><b>macOS asks for Accessibility again after every build</b></summary>

The build was signed ad-hoc because no signing certificate was found, and an ad-hoc signature
changes with every build. Install Xcode and sign in with an Apple ID (a free one works), or create a
self-signed code signing certificate in Keychain Access. The script then uses it automatically.

</details>

<details>
<summary><b>Smooth zoom does nothing</b></summary>

Smooth zoom only works in apps that take trackpad pinches, and it relies on undocumented macOS
gesture fields that a macOS update could change. Turn off **Smooth zoom** in **Configure Buttons… →
Touchpad** to zoom in steps with `⌘=` / `⌘-`.

</details>

<details>
<summary><b>Using the controller's microphone</b></summary>

The DualSense microphone only works over a USB-C cable. Plug it in and pick **DualSense Wireless
Controller** as the input in your dictation app or in *System Settings → Sound*.

</details>

## How it works

- Apple's **GameController** framework reads the sticks and buttons.
  `GCController.shouldMonitorBackgroundEvents` keeps input coming while the app isn't in front (a
  menu bar app never is).
- A 120 Hz timer turns that state into **CGEvent** mouse, scroll and keyboard events. Shortcuts with
  modifiers also send each modifier's key event, for apps that watch the modifier keys themselves,
  like push-to-talk.
- **IOKit HID** reads what GameController doesn't expose from the DualSense's own input reports: the
  battery, both touchpad fingers with their touch-down and lift, the mute button, and the gyroscope. It also sets the light bar with the DualSense's own output
  report, since GameController's light can stop reaching the controller. The byte layout matches the
  Linux `hid-playstation` driver.
- **Smooth zoom** posts trackpad magnify gesture events through undocumented CGEvent fields, the same
  approach other macOS input tools use.

| File | What it does |
|---|---|
| `Engine.swift` | The 120 Hz loop: buttons to actions, sticks and touchpad to pointer, scroll and zoom |
| `InputSynthesizer.swift` | Posts mouse, scroll, keyboard and pinch events |
| `ControllerManager.swift` | Controller connection, buttons, sticks, battery text and light bar |
| `DualSenseHID.swift` | Battery, touchpad fingers, mute button and gyroscope from the DualSense HID reports, and its light bar |
| `Config.swift` | Buttons, actions, themes and the config file format |
| `ConfigStore.swift` | The live config: theme and button changes, saving |
| `SettingsView.swift` · `ShortcutRecorder.swift` | The settings window (SwiftUI) and its shortcut recorder |
| `AppDelegate.swift` | Menu bar, settings window, permissions, open at login |
| `SystemActions.swift` · `KeyCodes.swift` · `L10n.swift` | Mission Control, key codes, English and Spanish text |

All sources are in `Sources/GamepadMouse/`.

## Roadmap

- Touchpad gestures and two-finger scroll.
- Adaptive triggers with a physical click point.
- Per-app themes.

## Contributing

Issues and pull requests are welcome. To work on the app:

```bash
swift build                      # compile
./scripts/build-app.sh --install # build, sign, install and relaunch
```

Keep every user-facing string in both languages with `tr("English", "Español")`.

## License

[MIT](LICENSE). Use it, change it, share it.
