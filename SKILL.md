---
name: binh-godot-bonus-skill
description: Hard-won checklist for Godot 4 games that ship to phones (iOS/Android) — touch bugs that never show with a mouse (lists that won't swipe because buttons swallow the touch, a sheet that closes right after it opens, a tap that fires after a swipe), Control layout traps (anchors vs offsets, autowrap sizes, reset_size), tweens/coroutines on freed nodes and awaits that hang, mobile rendering (sRGB vertex colors, washed-out tonemapping, SubViewport cameras, 120 Hz heat), fonts missing glyphs, GLB/texture import, iOS export ("No presets found", signing, installing on a device with devicectl), and how to verify with headless validators, a --selftest scene, simulated touch and screenshots. Use whenever working in a Godot project — building UI, ScrollContainers, sheets/popups, 3D scenes, input or gestures, export/deploy to iPhone or Android, or checking work before the user tests on a device — even if the user doesn't ask for a checklist.
---

# Godot mobile bonus skill: touch, layout, coroutines, export, verification

"Runs in the editor" is not "works on a phone". A mouse on a Mac hides every touch bug, and the editor hides export problems. The full guides are in `references/` (written in Vietnamese); read the relevant one before acting, and reuse `templates/` rather than re-deriving them.

| Situation | Read |
|---|---|
| Any ScrollContainer, list, sheet, popup, backdrop, drag, swipe, pinch or "tap does nothing / fires twice" | `references/touch-input.md` |
| Building Controls in code, layout looks collapsed/off-screen, tweens or `await` misbehave, 3D looks pale, text shows boxes, imported assets look wrong | `references/silent-bugs-checklist.md` |
| Export to iPhone/iPad, "No presets found", signing, installing/launching on a device, device heat | `references/ios-export.md` |
| Before saying something works: tests, simulated touch, screenshots, level/content validators, profiling | `references/testing.md` |

Templates (copy into the project, adapt names):
- `templates/touch_scroll.gd` — ScrollContainer that swipes even when the finger lands on a button, with inertia; children call `dragged()` to ignore the release of a swipe.
- `templates/check_touch.gd` — real touch events through `Input.parse_input_event` (tap, drag, canvas→window coordinates) plus example checks.

## Always-on rules (apply without being asked)

**Touch input**
- A phone delivers each touch as an emulated mouse click *and* a touch event. Handle a given gesture through one of them only; Buttons react to the mouse half.
- Every scrollable list must be swipeable when the swipe starts on a child Button/Panel. Either pass touches through (`mouse_filter = PASS` on all content, `scroll_deadzone` ≈ 14) or use `templates/touch_scroll.gd`. A release after a swipe must not press the button or select the row under the finger.
- A backdrop that closes a sheet must arm on its own press and close on its own release, so the tap that opened the sheet can't close it.
- Set `input_devices/pointing/emulate_touch_from_mouse=true` so mouse drags behave like a finger on desktop, and test with simulated touch (`templates/check_touch.gd`), not only the mouse wheel.

**Controls built in code**
- After a node is in the tree, use `set_anchors_and_offsets_preset()`; plain `set_anchors_preset()` keeps the current (often zero) rect.
- Don't call `reset_size()` on anchored controls. Read sizes of autowrapping labels only after layout (`await get_tree().process_frame`, twice for nested containers).
- `remove_child()` before `queue_free()` when rebuilding rows that draw from an external list; guard `_draw()` against stale indices.

**Tweens, timers, coroutines**
- Create tweens on the node they animate (`node.create_tween()`), so freeing the node kills the tween. Lambdas in callbacks must not capture nodes that can be freed first.
- A Timer must be in the tree before `start()`; start loops from `_ready()`, not from a setup call made before `add_child()`.
- A script error inside an awaited coroutine stops it and the caller waits forever: test runners need a watchdog that quits with an error.

**Mobile rendering and platform**
- Vertex/instance colors written as sRGB need `vertex_color_is_srgb = true`. Check colors on a screenshot, not in your head; AgX/strong fog washes out flat-colored scenes.
- Cap `application/run/max_fps=60` (ProMotion runs at 120 Hz and heats the phone); use MSAA 2× on mobile; guard camera math against a zero-size viewport.
- Respect the safe area (top notch, bottom home bar) and `application/config/quit_on_go_back=false` with your own back handling on Android.
- Bundled fonts must contain every glyph you print (`FontFile.has_char`); emoji and symbols like ⏭ ★ are usually missing.

**Export and devices**
- No `export_presets.cfg` means the Export dialog shows "No presets found": create the preset (team ID, bundle ID) before telling the user how to deploy; reload the project if the editor was open.
- Export from the CLI and install with `xcrun devicectl` to prove the build works before handing it over (`references/ios-export.md`).

**Verification**
- Run the project's validators and `--selftest` scene (with autoloads) after changes; take screenshots of every screen you touched and look at them.
- Wait by real time before screenshots (`create_timer`), not frame counts: a 120 Hz Mac runs frames twice as fast.
- `--check-only` reports autoload names as missing; that's expected. New `class_name` files need `godot --headless --path . --import` before other scripts can see them.
- Say what was verified and how; say what still needs a real device (feel of scrolling, heat, sound).

## Keeping this skill current

When a project hits a new device-only bug, add the symptom, cause, fix and the test that catches it to the matching reference here, keeping it generic (no project class names).
