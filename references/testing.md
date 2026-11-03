# Checking a Godot game before the user tries it

"It runs in the editor" isn't done. The checks below go from cheapest to most expensive; do every step that fits the change, then say clearly what was checked, how, and what still has to be tried on a real device.

Everything here works on macOS, Windows and Linux. The commands write the Godot binary as `godot`; see §0 for what that is on each OS.

---

## 0. Running Godot from a terminal

Godot doesn't install a `godot` command. Find the binary once and use its full path (or an alias / a `GODOT` environment variable) in every command:

| OS | Binary | Notes |
|---|---|---|
| macOS | `/Applications/Godot.app/Contents/MacOS/Godot` | Or wherever `Godot.app` lives. |
| Windows | `Godot_v4.x-stable_win64_console.exe` | Use the **`_console`** build, which ships in the same zip. The plain `.exe` detaches from the terminal, so `print()` output and errors never appear and the exit code is lost. |
| Linux | `Godot_v4.x-stable_linux.x86_64` | `chmod +x` it after unzipping. Flatpak/Steam installs need `flatpak run org.godotengine.Godot` or the Steam path. |

- Check with `<binary> --version` before running anything else.
- Shell differences: in PowerShell, quote paths with spaces and run a binary by path with `& "C:\path\Godot_..._console.exe" --headless ...`; redirect both streams with `> build\export.log 2>&1` (works in PowerShell and cmd). `grep` examples below become `Select-String` in PowerShell.
- Write screenshots and logs to a folder inside the project (`shots/`, `build/`) instead of `/tmp`, so the same command works on every OS; keep those folders out of git and out of the import (add a `.gdignore` file).

---

## 1. Scripts load

```sh
godot --headless --path . --import                      # after adding/changing a class_name or new assets
godot --headless --path . --quit-after 120              # run the main scene for 120 frames with autoloads: catches parse and runtime errors
godot --headless --path . --check-only --script res://scripts/x.gd   # lint one file; missing-autoload errors are expected
```

Read every `SCRIPT ERROR` / `Parse Error` line carefully: one parse error stops the whole file from loading, and every node using that file loses all its functions.

---

## 2. Pure rules, run headless

Move the game rules (movement, scoring, levels, solutions) into scripts that don't use nodes, then write validators as `extends SceneTree`:

```sh
godot --headless --path . --script tools/validate_levels.gd
```

A validator should check that every level is solvable, the reference solutions are correct, the data has no duplicate ids, and random content works in every variant; print stats (minimum moves, BFS solution) to spot unintended shortcuts. Exit with a non-zero code on failure.

`--script` mode has **no** autoloads, so validators must not touch scripts that use autoloads.

### 2a. Logic fuzzing: a random player + invariants

Normal tests only follow the paths their author thought of. A fuzzer has a "player" press every action at random (buy, sell, switch level/city, reset, mini-games) in any order, with bad arguments (ids that don't exist, negative numbers, huge numbers, empty/long/emoji/`%d` names), makes the clock jump far ahead **and backwards**, and saves and reloads along the way. After **every** step it checks what must always hold:

- money, score and rates are finite (`is_finite`), not negative, and within range (reputation 0..100, stock ≤ capacity, level ≤ cap);
- selected indexes are valid and not duplicated (two shops in the same city), menus aren't empty;
- save → JSON → load gives back exactly the same data (compare key by key; floats within a tolerance of ~1e-12 because JSON keeps about 15 digits; print the path of the first differing key, e.g. `cafes/2/stock/milk: 25 -> 0`);
- messages contain no broken numbers (regex in `silent-bugs-checklist.md` §5).

Use a fixed seed per run (`rng.seed = seed`) so failures reproduce; report a failure with the seed, the step number and the last action. Template: `templates/fuzz_logic.gd`. About 10 seeds × 2500 steps takes a few minutes; run it in the background if it takes longer.

### 2b. Worst-case data for the UI

The most dangerous layout bugs don't show with a normal save, only with long data: every ingredient out at once, custom names at maximum length, a chain spanning all 12 cities, 1e18 money. Write a tool that builds a few scenarios (normal; **worst case**: every text at its longest, every list full, everything out, huge and negative numbers; **maxed**: everything at the top level), then at each screen size (16:9, tall iPhone, iPhone SE, iPad portrait and landscape):

- open **every** panel/popup/info card (take the list from a registry in code, not a hand-typed list, so new panels are checked automatically), and check that the panel is on screen and every visible child control fits within the panel's width;
- redraw the HUD with the audit flag (`silent-bugs-checklist.md` §1.10) and with **every** possible status label (each warning, each ingredient name, each event), and check that text stays inside its card and doesn't overlap;
- play one round of any mini-game that shows data-driven text (an order with a long dish name);
- scan the text of every Label/Button for `nan`, `inf`, `922337203`, unfilled `%d`.

Then **test the test**: temporarily put back the bug you just fixed and confirm the test goes red; print a few debug lines to be sure the scenario really appeared (e.g. the order really has the long dish name), so you don't get a green test that checks nothing. Template: `templates/check_extremes.gd`.

---

## 3. UI tests through the main scene (`--selftest`)

UI tests need autoloads (audio, saving...) and the real scene, so have the main script accept a debug flag after `--` and call the test file:

```gdscript
# scripts/main.gd
func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	if "--selftest" in args:
		# A script error inside an awaited coroutine stops it and the caller hangs forever: set a quit timer.
		get_tree().create_timer(600.0).timeout.connect(func() -> void: get_tree().quit(2))
		var failures: int = await load("res://tools/editor_test.gd").run(self)
		failures += await load("res://tools/check_touch.gd").run(self)
		get_tree().quit(1 if failures else 0)
		return
```

```sh
godot --path . -- --selftest        # prints "ok"/"FAIL" per check, exit code 0 when everything passes
```

- A test file is `extends RefCounted` with `static func run(app: Node) -> int`; it calls the same functions the buttons call, then checks the state (data, which node is open, which row is selected).
- In test mode: don't write the real save, mute audio, speed up animations.
- Every bug found on a device must get a test that catches it (it FAILs on the old code).
- Touch tests: `templates/check_touch.gd` and `touch-input.md`.

---

## 4. Take screenshots and look at them

Have the main script accept a capture flag: build the exact state to look at, wait, save the image, quit.

```gdscript
if shot_path != "":
	await get_tree().create_timer(wait_seconds).timeout     # wait in seconds, not frames
	get_viewport().get_texture().get_image().save_png(shot_path)
	get_tree().quit()
```

```sh
godot --path . -- --shot=shots/a.png --screen=game --level=3 --wait=1.2
godot --path . --resolution 450x975 -- --shot=shots/tall.png     # tall 19.5:9 phone
godot --path . --resolution 600x800 -- --shot=shots/ipad.png     # 3:4 iPad
```

- Run **windowed** (no `--headless`): headless renders nothing.
- **Wait by real time.** A 120 Hz display runs frames twice as fast, so "wait 100 frames" is only 0.8 s and the shot comes too early (stars not lit yet, card not shown yet).
- Have flags to build each state: which screen, which character, load the reference solution, capture after it finishes, capture mid-run, open the hint panel/card...
- Open and look at the images after every UI change. Many bugs (pale colors, boxes instead of text, cards stuck off screen, a play area that's too small) only show in an image.

---

## 5. UI testing on the desktop, not the iOS Simulator; App Store screenshots

**Don't use the iOS Simulator for a Godot game.** The official iOS template only ships an x86_64 Simulator library, recent iOS Simulators on Apple Silicon don't run x86_64 apps, and native plugins (ads, purchases, notifications) are device-only. A self-built Simulator engine runs OpenGL ES on the CPU there: a 3D game takes minutes per frame. The project owner considers it over-engineering. An Android emulator does run Godot, but it adds nothing for UI work over a phone-shaped desktop window and says nothing true about performance.

Split testing like this:

| What | Where |
|---|---|
| UI, layout at each device size, game logic, UI flows, App Store / Play Store screenshots | Desktop (macOS, Windows or Linux): Godot's ▶ button, headless tools, capture tools |
| Performance, heat, FPS, touch and swipe feel, sound, native plugins | Real phone/tablet (`android-export.md`, `ios-export.md`) |

**A phone-shaped ▶ window:** set `display/window/size/window_width_override` and `window_height_override` to iPhone proportions, e.g. 440×956 (the 6.9" iPhone in points). Keep the base viewport size (e.g. 720×1280, stretch `canvas_items` + `expand`) unchanged.

**Safe area on the desktop:** on a desktop OS, `DisplayServer.get_display_safe_area()` is the whole screen, so the HUD hugs the top edge. Give the HUD a static variable that tools can set, e.g. `static var simulated_safe := Vector2(-1, -1)` for the top and bottom insets as fractions of the screen height. When it's ≥ 0, the HUD uses it instead of the real safe area.

**App Store screenshots** (the sizes Apple requires; App Store scales them down for smaller devices):

| Device | Portrait image | Safe area (points) |
|---|---|---|
| iPhone 6.9" | 1320×2868 | top 62, bottom 34, out of 956 |
| iPad 13" (only if the app supports iPad) | 2064×2752 | top 24, bottom 20, out of 1376 |

- An `extends SceneTree` tool, run **windowed**. Set `root.borderless = true`, then `root.size = Vector2i(1320, 2868)`: the OS clips a bordered window to the screen height (measured on macOS: 1924 instead of 2868), while a borderless window keeps the exact size. On Windows and Linux, check the saved image's size; if it's still clipped, render into a `SubViewport` of the target size and save its texture instead. Save `root.get_texture().get_image()`.
- Have existing capture tools accept `--device iphone|ipad` (size + safe area) instead of writing new tools, plus one shell script that runs the whole set into `shots/appstore/<device>/`. Template: `templates/store_shots.gd`.
- **A good-looking state (`--showcase`)** built on demo data:
  - plenty of money, full stock, clean floors, every unlocked item on the menu;
  - whatever city/level the shop is in, its name is shown correctly;
  - no red warnings on the HUD: if a genuinely busy state still warns about missing seats, give the tool a flag that hides warnings instead of changing the game rules;
  - secondary shops in the chain must be healthy too, or they show red dots.
- Look at the images before handing them to the user. Don't use shots that contain debug-only items.

---

## 6. Play all content through the real UI (`--autoplay`)

Load the reference solution of every level × every character into the UI, run at high speed, and check the results. This catches mismatches between the rules and the animation layer (a command that follows the rules but the UI gets stuck, a tween on a freed node...). Filter the output for `ERROR|SCRIPT`, not just "FAIL".

---

## 7. Performance

Run windowed and read `Performance.get_monitor()`:

```gdscript
print("draw calls %d, objects %d, triangles %d" % [
	Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
```

Watch these as you add decoration, characters and effects. Numbers on a desktop are only a lower bound; heat and FPS must be measured on a device.

---

## 8. On a real device

Export and install with the commands in `android-export.md` or `ios-export.md`. Only a device can answer: how swiping and inertia feel, mis-taps, safe areas, sound through the speaker and the silent switch, heat after 10–15 minutes, launch time.

When reporting to the user, separate clearly: what was checked by tests/screenshots, and what still waits for them to try on a device.
