---
name: rubydai-godot-bonus-skill
description: Hard-won checklist for Godot 4 phone games (iOS/Android), built on macOS, Windows or Linux — touch bugs that never show with a mouse (lists that won't swipe because buttons keep the touch, a sheet that closes right after it opens, a tap that fires after a swipe), Control layout traps (anchors/offsets, autowrap, reset_size), tweens/coroutines on freed nodes and hanging awaits, mobile rendering (sRGB vertex colors, washed-out tonemapping, 120 Hz heat), missing glyphs, GLB import, Android export (adb, logcat, signing), iOS export (Mac only: "No presets found", signing, devicectl), and verifying with headless validators, a --selftest scene, simulated touch and screenshots at phone sizes on the desktop, including App Store screenshots, never the iOS Simulator. Use whenever working in a Godot project — UI, ScrollContainers, sheets/popups, 3D scenes, input or gestures, export/deploy to iPhone or Android, or checking work before the user tests on a device, even if the user doesn't ask for a checklist.
---

# Godot mobile bonus skill: touch, layout, coroutines, export, verification

"Runs in the editor" is not "works on a phone". A desktop mouse hides every touch bug, and the editor hides export problems. The full guides are in `references/`; read the relevant one before acting, and reuse `templates/` rather than re-deriving them.

Works the same on macOS, Windows and Linux, except iOS export, which needs a Mac with Xcode. Before running Godot from a terminal, find the Godot binary for the current OS (`references/testing.md` §0); the commands here write it as `godot`.

| Situation | Read |
|---|---|
| Any ScrollContainer, list, sheet, popup, backdrop, drag, swipe, pinch, text field / on-screen keyboard, or "tap does nothing / fires twice" | `references/touch-input.md` |
| Building Controls in code, layout looks collapsed/off-screen, tweens or `await` misbehave, 3D looks pale, text shows boxes, imported assets look wrong, a file loads in the editor but not in an export | `references/silent-bugs-checklist.md` |
| Export to Android, installing/launching with `adb`, reading the device log, keystores, Play Store bundles | `references/android-export.md` |
| Export to iPhone/iPad, "No presets found", signing, installing/launching on a device, device heat, AdMob / tracking (ATT) prompt for App Review | `references/ios-export.md` |
| Running Godot from a terminal, before saying something works: tests, simulated touch, screenshots, level/content validators, profiling | `references/testing.md` |
| A panel/sheet suddenly wider than the screen, HUD text running into other text, "nan"/"9223372036854775807" on screen, before any release | `references/silent-bugs-checklist.md` §1.9–1.10, §5 and `references/testing.md` §2a–2b |
| Testing UI at phone/tablet sizes, App Store screenshots, or tempted to use the iOS Simulator | `references/testing.md` §5 |

Templates (copy into the project, adapt names):
- `templates/touch_scroll.gd` — ScrollContainer that swipes even when the finger lands on a button, with inertia; children call `dragged()` to ignore the release of a swipe.
- `templates/check_touch.gd` — real touch events through `Input.parse_input_event` (tap, drag, canvas→window coordinates) plus example checks.
- `templates/check_extremes.gd` — worst-case data (longest names, everything sold out, huge numbers) at every screen size: panels on screen, HUD text inside its card and off other text, no broken numbers.
- `templates/fuzz_logic.gd` — a seeded random player with invariants after every step, including save → load → same.
- `templates/store_shots.gd` — App Store screenshots on the desktop at iPhone 6.9" (1320×2868) / iPad 13" (2064×2752) with a simulated notch and home bar (borderless window, so it may be taller than the screen).

## Always-on rules (apply without being asked)

**Touch input**
- A phone delivers each touch as an emulated mouse click *and* a touch event. Handle a given gesture through one of them only; Buttons react to the mouse half.
- Every scrollable list must be swipeable when the swipe starts on a child Button/Panel. Either pass touches through (`mouse_filter = PASS` on all content, `scroll_deadzone` ≈ 14) or use `templates/touch_scroll.gd`. A release after a swipe must not press the button or select the row under the finger.
- A backdrop that closes a sheet must arm on its own press and close on its own release, so the tap that opened the sheet can't close it.
- Every text field in a sheet: the sheet rises above the on-screen keyboard (`DisplayServer.virtual_keyboard_get_height()`, window pixels) with the field scrolled into view, and a tap outside the field releases its focus; a number pad has no return key (`references/touch-input.md` §2.4).
- Set `input_devices/pointing/emulate_touch_from_mouse=true` so mouse drags behave like a finger on desktop, and test with simulated touch (`templates/check_touch.gd`), not only the mouse wheel.

**Controls built in code**
- After a node is in the tree, use `set_anchors_and_offsets_preset()`; plain `set_anchors_preset()` keeps the current (often zero) rect.
- Don't call `reset_size()` on anchored controls. Read sizes of autowrapping labels only after layout (`await get_tree().process_frame`, twice for nested containers).
- `remove_child()` before `queue_free()` when rebuilding rows that draw from an external list; guard `_draw()` against stale indices.
- A Label whose text comes from data (a joined list, a name the player typed, a big number) must wrap or clip. A one-line Label's minimum width is its whole text, and every container up to the sheet grows with it, so one long day pushes the panel and its buttons off screen. Plain one-line Labels are for short fixed text only.
- Text drawn by hand (`draw_string`) goes through a fit-to-width helper that leaves room for what sits beside it on the same line.
- Number formatters guard `NAN`, `INF` and values past the largest unit before `int()`, which silently overflows to 9223372036854775807.

**Tweens, timers, coroutines**
- Create tweens on the node they animate (`node.create_tween()`), so freeing the node kills the tween. Lambdas in callbacks must not capture nodes that can be freed first.
- A Timer must be in the tree before `start()`; start loops from `_ready()`, not from a setup call made before `add_child()`.
- A script error inside an awaited coroutine stops it and the caller waits forever: test runners need a watchdog that quits with an error.

**Mobile rendering and platform**
- Vertex/instance colors written as sRGB need `vertex_color_is_srgb = true`. Check colors on a screenshot, not in your head; AgX/strong fog washes out flat-colored scenes.
- Cap `application/run/max_fps=60` (ProMotion and many Android phones run at 90–120 Hz and heat up); use MSAA 2× on mobile; guard camera math against a zero-size viewport.
- Respect the safe area (top notch, bottom home bar) and `application/config/quit_on_go_back=false` with your own back handling on Android.
- Bundled fonts must contain every glyph you print (`FontFile.has_char`); emoji and symbols like ⏭ ★ are usually missing.
- `res://` paths must match the file name's exact case. Windows and macOS file systems ignore case, so a wrong case works in the editor there, then fails on Linux and inside exported games (`references/silent-bugs-checklist.md` §4.7).

**Export and devices**
- No `export_presets.cfg` means the Export dialog shows "No presets found": create the preset (package/bundle ID, and the team ID for iOS) before telling the user how to deploy; reload the project if the editor was open.
- Export from the CLI and install with `adb` (Android) or `xcrun devicectl` (iOS, on a Mac) to prove the build works before handing it over (`references/android-export.md`, `references/ios-export.md`).
- A game with ads asks App Tracking Transparency at the first launch, about a second after it's on screen and in front (asked during startup, iOS silently drops the prompt; asked later, after a tutorial or the first ad, App Review never sees it and rejects the app). Ads can still be offered later (`references/ios-export.md` §4.1).

**Where to test (no iOS Simulator, no emulator for UI work)**
- Never use or build anything for the iOS Simulator for a Godot game: the official template's simulator slice is x86_64-only, native plugins are device-only, and a self-built simulator engine runs OpenGL ES on the CPU (minutes per frame in 3D). The owner considers it over-engineering.
- Test UI, layout and game logic on the desktop (any OS): Godot's ▶ with a phone-shaped window override (e.g. 440×956), headless tools, and capture tools at device sizes with a simulated safe area. Take App Store screenshots the same way (`references/testing.md` §5).
- Use a real phone/tablet only for performance, heat, touch feel, sound and native plugins (ads, purchases, notifications).

**Verification**
- Run the project's validators and `--selftest` scene (with autoloads) after changes; take screenshots of every screen you touched and look at them.
- Test with worst-case data, not just the save at hand: every text at its longest, every list full, everything sold out at once, huge and negative numbers, every screen size (`templates/check_extremes.gd`). Logic gets a seeded random player with invariants (`templates/fuzz_logic.gd`). Before a release, run both.
- After writing a test for a bug, put the bug back for a moment and see the test fail; print enough to know the scenario really appeared.
- Wait by real time before screenshots (`create_timer`), not frame counts: a 120 Hz display runs frames twice as fast.
- `--check-only` reports autoload names as missing; that's expected. New `class_name` files need `godot --headless --path . --import` before other scripts can see them.
- Say what was verified and how; say what still needs a real device (feel of scrolling, heat, sound).

## Keeping this skill current

When a project hits a new device-only bug, add the symptom, cause, fix and the test that catches it to the matching reference here, keeping it generic (no project class names).
