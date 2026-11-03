# Silent-bug checklist for Godot 4 games (mobile)

A "silent bug" is one the editor doesn't report: the game keeps running, but the screen is wrong, an action does nothing, or it only breaks on a phone. Each entry has the symptom, the cause, the fix, and how to catch it before players do.

Touch bugs (swiping, sheets closing themselves, mis-taps) are in `touch-input.md`. Exporting and installing on a device are in `ios-export.md`. How to test is in `testing.md`.

---

## 0. Scripts and classes

| Symptom | Cause and fix |
|---|---|
| `--check-only` reports `Identifier not found: <AutoloadName>` | Expected: this mode doesn't load autoloads. To catch real errors, run the whole project: `godot --headless --path . --quit-after 120`. |
| `Could not find type "X"`, `Identifier "X" not declared` right after adding a file with `class_name X` | The global class cache hasn't updated. Run `godot --headless --path . --import` (or open the editor) once. |
| `Cannot infer the type of "x" variable because the value doesn't have a set type` | `:=` with a value from a `Dictionary`/`Array`/`Variant` (`var n := d.count`). Declare the type explicitly: `var n: int = d.count`. This error stops **the whole file** from loading. |
| `Cannot call non-static function "name_to_tag()" on the class "TextServer"` | Call it through an instance: `TextServerManager.get_primary_interface().name_to_tag("wght")`. |
| `Expected expression for match pattern` | A `match` inside a multi-line lambda passed as an argument. Move the logic out (a `Dictionary` lookup table, or a separate function). |
| A `not x in y` condition behaves unexpectedly | Write `not (x in y)` explicitly. |
| Opening the project reports a script error, but the game still partly "works" | When a script fails to parse, nodes using it have no functions at all. Always read the Output panel; don't judge by the screen alone. |

---

## 1. Controls built in code

**1.1 The whole UI collapses into the top-left corner or has zero width.**
- Cause: calling `set_anchors_preset(PRESET_FULL_RECT)` when the node is *already in the tree*. It changes the anchors but recomputes the offsets to **keep the current rect** (often 0).
- Fix: use `set_anchors_and_offsets_preset()`, then set any custom offsets. Assigning `anchor_*` directly while in the tree has the same problem, so set offsets afterwards.

**1.2 A bottom-anchored card shrinks to its minimum width and gets stuck off screen.**
- Cause: calling `reset_size()` on an anchored control. It sets the size to the minimum size and overwrites the offsets.
- Fix: don't call `reset_size()`. For a card that grows up from the bottom: `anchor_top = anchor_bottom = 1`, `offset_top = offset_bottom = -margin`, `grow_vertical = GROW_DIRECTION_BEGIN`; the height follows the content.

**1.3 A measured height comes out huge (2000+ px) and the layout is shifted by it.**
- Cause: a `Label` with `autowrap` doesn't know its width yet, so it treats every word as its own line.
- Fix: measure after layout: `await get_tree().process_frame` twice (nested containers), then read `size`.

**1.4 A slide/bounce animation runs in the wrong place as soon as something opens.**
- Cause: reading `position`/`size` right after `add_child`, before the container has laid things out.
- Fix: wait one frame; or animate `modulate` and `scale` (set `pivot_offset` once the size is known) instead of the `position` of a container's child.

**1.5 `Out of bounds get index` in `_draw()` after rebuilding a list.**
- Cause: an old row was `queue_free()`d but still draws for one more frame, with an index into the new, shorter list.
- Fix: `remove_child(row)` before `queue_free()`; in `_draw()`, return early if the index is past the end of the list.

**1.6 Text shows boxes.**
- Cause: the bundled font doesn't contain the character (emoji, ⏭, ★, ✓...). A system fallback font exists on one machine and not on another.
- Fix: check `FontFile.has_char(c.unicode_at(0))` for every special character; replace with an SVG icon or plain text. For languages with diacritics, check every accented letter the game can show, including stacked accents (é, ñ, ü, ầ...).
- Variable fonts: use a `FontVariation` with `variation_opentype = {tag("wght"): 700}` to get several weights from one file.

**1.7 The notch / home bar covers buttons.**
- `DisplayServer.get_display_safe_area()` returns screen pixels; convert to canvas units: `safe.position.y * canvas_h / screen_h`. Apply it only when `OS.has_feature("mobile")`.

**1.8 Rounded corners on a 3D view.**
- Put the `SubViewportContainer` inside a `Panel` with a rounded StyleBox and `clip_children = CLIP_CHILDREN_ONLY`.

**1.9 One day the whole panel gets wider and spills off screen (price buttons, the Close button cut off).**
- Cause: a `Label` that does **not** wrap shows text that depends on data: a joined list ("Out of Coffee Beans, Flour, Matcha, Cocoa and Berries"), a name the player typed (a dish, a shop), a big number. A Label's minimum size is its whole line of text; HBox → card → ScrollContainer → panel all grow to their children's minimum size, so **the whole panel** gets wider. Forcing `panel.size` every frame doesn't help, because Godot won't go below the minimum size. With normal data nothing shows; the bug only appears on the day the data is long (5 ingredients run out at once), i.e. after release.
- Fix: every Label with data-driven text inside a horizontal row must wrap (`autowrap_mode = AUTOWRAP_WORD_SMART`, `size_flags_horizontal = EXPAND_FILL`, with a `custom_minimum_size.x` so it isn't measured as one word per line) or clip (`clip_text = true` / `text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS`). Make a builder function (e.g. `UiKit.heading()`) that every heading uses; plain one-line Labels are for short fixed text only.
- Catch it: a worst-case data test (`testing.md` §2b): set names to the maximum length using the widest letter (`W`), run out of everything at once, unlock every city/item, set a huge amount of money, then open every panel at every screen size and check that the panel stays on screen and every child control fits within the panel's width. Test the test: temporarily remove the fix and the test must fail.

**1.10 Hand-drawn text (`draw_string`) spills out of its card or overlaps other text.**
- Cause: a HUD drawn with `draw_string` has no container limiting it. Long text on the left ("OUT OF MOON MARSHMALLOWS ›") runs into right-aligned text ("Clean 100%") on the same bar; a huge amount of money runs into the income line.
- Fix: all data-driven text goes through a helper that trims it to the available width (measure with `font.get_string_size()`, drop characters, then add "..."). Available width = card − margins − the fixed text beside it (arrow, right-hand number).
- Catch it: have the text- and card-drawing helpers record their rectangles when a test sets a `static var audit` flag (in release this costs only one `null` comparison). The test redraws the HUD with every label that can appear and checks that each text sits inside a card and no text intersects another. Measure text boxes by the glyphs (from the baseline up about 0.72 × font size), not ascent + descent, or two stacked lines get falsely reported as overlapping.

---

## 2. Tweens, timers, coroutines

**2.1 `Lambda capture at index 0 was freed`, `Invalid assignment ... on a base object of type 'Nil'`.**
- Cause: the tween was created on one node (the screen's `create_tween()`) but animates another node that has been freed (screen rebuilt, card closed).
- Fix: create the tween on the node being animated: `gem.create_tween()`. When the node goes, the tween goes with it.

**2.2 An animation loop stands still, and the log says `Unable to start the timer because it's not inside the scene tree`.**
- Cause: `Timer.start()` before the node is in the tree (called from a setup function before `add_child`).
- Fix: start loops in `_ready()`. Wait with a `Timer` child of the node (if the node is freed, the coroutine simply never resumes, with no error) instead of `get_tree().create_timer()` when the node can be freed midway.

**2.3 A test or a level hangs forever.**
- Cause: a script error inside an awaited coroutine stops it, and whoever awaits it never resumes. Or it `await`s a signal that no code path emits (e.g. the Stop button doesn't emit the signal the run loop is waiting for).
- Fix: every stop path emits the awaited signal; test runners have a watchdog: `get_tree().create_timer(600).timeout.connect(func(): get_tree().quit(2))`.

**2.4 An old effect plays over the new state** (the character still does a victory jump after a reset).
- Fix: a generation counter: increment it on every reset; the coroutine keeps the value it started with and exits when it differs.

**2.5 Calling a function that contains `await` without `await`ing it.** The function runs until its first `await`, then returns immediately; the rest runs on a later frame. Reading state right after the call reads the old state. Conversely, `await`ing a function that never suspends returns immediately in the same frame.

---

## 3. 3D and rendering on mobile

**3.1 Pale colors, grey grass, grey ground.**
- Cause 1: vertex / instance colors (`SurfaceTool.set_color`, `MultiMesh.set_instance_color`) are written in sRGB but the material treats them as linear. Fix: `material.vertex_color_is_srgb = true` (with `vertex_color_use_as_albedo = true`).
- Cause 2: the AgX tonemapper + fog + high ambient light washes out flat-colored scenes. Try Filmic, lower `fog_density`, `adjustment_saturation` around 1.1–1.2. Always compare screenshots; don't guess.

**3.2 `Basis ... must be normalized` spammed in the log right after opening.**
- Cause: camera math runs while the 3D view still has size 0 (division by zero → infinity/NaN).
- Fix: return early if `size.x <= 1 or size.y <= 1`.

**3.3 The island/play area is too small or hidden behind the UI.**
- Frame the camera by projecting the 8 corners of the bounding box (`AABB`) through the camera and binary-searching the smallest distance at which all corners fit inside the part of the view **not covered by UI** (minus the top/bottom margins), then move the camera along its up axis so the center sits in the middle of what's left. A bounding sphere is too conservative for long maps.

**3.4 Several 3D views (title screen, preview cards) show each other's objects.** Set `SubViewport.own_world_3d = true`.

**3.5 A procedural mesh is missing faces or lit backwards.** Godot treats faces whose vertices go **clockwise** (seen from outside) as front faces. Pass normals explicitly and flip the vertex order yourself when `(b - a).cross(c - a).dot(normal) > 0`.

**3.6 Glow doesn't show.** Glow only picks up what's brighter than `glow_hdr_threshold`; glowing objects need enough emission (energy around 1 or more).

**3.7 The Mobile renderer:** no SSAO/SSR/SDFGI (bake AO into textures); MSAA 2× on phones; `SHADOW_ORTHOGONAL` directional shadows are enough for small scenes; `CPUParticles` are safer than GPU particles on weak devices; batch ground/decoration with `MultiMeshInstance3D` to cut draw calls.

**3.8 The phone gets hot.** ProMotion screens run at 120 Hz: set `application/run/max_fps=60`. Measure draw calls and triangles with `Performance.get_monitor(RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` / `RENDER_TOTAL_PRIMITIVES_IN_FRAME` in a windowed run (headless returns 0).

---

## 4. Assets

**4.1 Replacing a GLB but the textures stay old.** The importer extracts embedded textures as PNGs next to the GLB and doesn't overwrite them if the PNGs already exist. Delete the extracted PNGs (keep the `.import` files), then `godot --headless --path . --import`; compare md5 sums to be sure they were re-extracted.

**4.2 Animations from a GLB don't loop.** Set `animation.loop_mode` in code after loading (or in Advanced Import Settings) for looping clips (Idle, Run...).

**4.3 Blurry SVG icons.** An SVG is imported at the file's own `width/height`. Draw it at twice the display size, in white, then tint it with `icon_*_color` / `modulate`.

**4.4 Looping music clicks at the seam.** `AudioStreamWAV.loop_mode = LOOP_FORWARD`, `loop_end = int(get_length() * mix_rate)` (in frames). When synthesizing music yourself, fold the tail of the last note back into the start of the buffer so the seam is continuous.

**4.5 Tests/screenshots make sound.** Mute when `DisplayServer.get_name() == "headless"` or a test flag is set.

**4.6 Editing character models in Blender.** It runs headless (`blender --background file.blend --python script.py`), and EEVEE can render in background mode. Judge faces from **the game's camera angle** (often looking down 25–40°), not just head-on: the outer corners of the eyes and the eyebrows sit deep in the head, so from above they look slanted, and protruding details (eyebrows) hide the eyes.

**4.7 A file loads in the editor but not on Linux or in the exported game.**
- Cause: a `res://` path whose case doesn't match the file name (`res://Art/Player.png` for `art/player.png`). Windows and macOS file systems ignore case, so the editor finds the file; Linux and the exported `.pck` don't, and `load()` returns `null` there.
- Fix: write paths with the exact case, and keep file and folder names lowercase (`snake_case`) so there's nothing to get wrong. Rename a file through Godot's FileSystem dock so references are updated.
- Catch it: export once and run the exported game, or run the project on Linux/CI; a validator can walk every `res://` string in scripts and scenes and compare it to `DirAccess` listings with exact case.

**4.8 Line endings and paths across machines.** A team that mixes Windows with macOS/Linux should add a `.gitattributes` (`* text=auto`, and `*.sh text eol=lf` for shell scripts) so Git doesn't flip every line ending. In GDScript, build paths with `path_join()` and `/`, never `\`; `res://` and `user://` use `/` on every OS.

---

## 5. Platform and data

- **Android Back button:** `application/config/quit_on_go_back=false` and handle `NOTIFICATION_WM_GO_BACK_REQUEST` (level → list → quit).
- **Aspect ratios:** stretch `canvas_items` + aspect `expand`; try a tall 19.5:9 phone and a 3:4 iPad with `--resolution 450x975` and `--resolution 600x800`.
- **Vibration:** `Input.vibrate_handheld(ms)`; Android needs the VIBRATE permission in the export.
- **Formatting extreme numbers:** `int()` of a number > 9.2e18, of `INF` or of `NAN` gives `9223372036854775807` / `-9223372036854775808` with no error, so "1.2Qi" becomes "9223372036854775807Qi", "pays back in 9223372036854775807 days", "+nan/s". Formatters (short numbers, money, rates, durations) must guard `is_nan()`, infinity and values past the largest unit ("999Qi+", "999+ days") before calling `int()`. Catch it: call each formatter with `0, -0, a negative number, 1e21, 1e300, INF, -INF, NAN` and check the result is short and contains no `nan`/`inf`/`922337203`.
- **Unfilled text on screen:** a raw `"%d"` / `"%s"` template, or `<null>`. A test should scan the text of every Label/Button/toast with the regex `(?i)\b(nan|inf)\b|922337203|%[-+0-9.]*[dsf]\b|<null>`, after removing names the player typed (a player can type "%d").
- **Saving progress:** `ConfigFile` in `user://`, keyed by **stable ids** (not level numbers, which shift when a level is inserted), with a version number so old incompatible saves can be dropped. Strip internal keys (e.g. `_line`) before saving.
- **Programming-puzzle levels or random content:** keep the rules in plain code (no nodes) so they run headless; the UI only replays the trace the rules produce, so visuals never drift from the rules. Cap steps/iterations to stop infinite loops. For random content, check the solution on **every** variant.
