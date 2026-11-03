# Touch input in Godot 4 on phones

A desktop mouse hides almost every touch bug. This guide explains how a phone delivers touches to Godot, the three most common bugs, how to fix them, and how to test with simulated touch.

---

## 1. How a phone delivers a touch

- A finger produces `InputEventScreenTouch` (press/release) and `InputEventScreenDrag` (move); each finger has its own `index`.
- `input_devices/pointing/emulate_mouse_from_touch` is on by default: Godot also generates emulated `InputEventMouseButton` / `InputEventMouseMotion`. **The emulated click arrives first, then the touch event itself.** So every touch arrives **twice**.
- `Button` (every `BaseButton`) reacts to the mouse half: a mouse press and release inside the button emits `pressed`.
- Processing order: `_input()` on every node → GUI (`_gui_input` on the control under the finger) → `_unhandled_input()`. So `_input()` sees the release **before** the button emits `pressed`.
- `mouse_filter` (defaults measured on Godot 4.7):
  - `STOP`: receives the event and does **not** pass it to the parent. Default for `Control`, `Button`, `Panel`, **`PanelContainer`**, `ColorRect`, `RichTextLabel`. Cards built from `PanelContainer` inside a list block swipes too.
  - `PASS`: receives it, then passes it to the parent. Default for `VBoxContainer`, `HBoxContainer`, `MarginContainer`, `ScrollContainer`, `TextureRect`, `SubViewportContainer`.
  - `IGNORE`: ignores it; the event falls through to the control below. Default for `Label`.
  - Measured `_input` order for one tap: `MouseButton(press)`, `ScreenTouch(press)`, `MouseButton(release)`, `ScreenTouch(release)`.
- `ScrollContainer` drags with a finger only when `DisplayServer.is_touchscreen_available()`. That is true on a phone; on desktop only when `input_devices/pointing/emulate_touch_from_mouse` is on. The mouse wheel always scrolls, so "it scrolls on desktop" proves nothing.

---

## 2. Three bugs that only show on a real device

### 2.1 A list that won't swipe

**Symptom:** the level list, shop, settings panel, etc. won't swipe up or down. The scrollbar can still be dragged, and the mouse wheel on desktop still scrolls.

**Cause:** the content is buttons/cards with `mouse_filter = STOP`. The finger lands on a button, the button keeps the touch, and the `ScrollContainer` never receives a drag. Only swipes that start in the gaps between buttons scroll.

**Fix A: let touches pass up to the ScrollContainer** (keeps Godot's built-in behavior; good when the content is ordinary Buttons):

```gdscript
scroll.scroll_deadzone = 14   # the finger must move more than 14 px to become a scroll; below that it's still a tap

func pass_touches_to_scroll(node: Node) -> void:
	if node is Control and node.mouse_filter == Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		pass_touches_to_scroll(child)

# Nodes added later (rebuilt rows) must PASS too:
get_tree().node_added.connect(func(n: Node) -> void:
	if content.is_ancestor_of(n): pass_touches_to_scroll(n))
```

Once the finger passes the deadzone, the ScrollContainer tells the button to drop the press, so a swipe doesn't press the button.

**Fix B: the ScrollContainer handles swipes itself** (`templates/touch_scroll.gd`). Use it when rows have their own tap handling (hand-drawn code lines, cells with special hit areas), when swipes must be blocked while an overlay is open (`guard`), or when you want to be sure you don't depend on how buttons handle touches. It:
- catches the swipe in `_input()` if the touch started inside its rect, even on a button;
- disables the built-in drag with a huge `scroll_deadzone` so it doesn't scroll twice;
- adds inertia on release;
- lets children ask `dragged()` on release to ignore the touch that was used for swiping.

```gdscript
b.pressed.connect(func() -> void:
	if scroll.dragged():   # release after a swipe: don't open the level
		return
	open_level(i))
```

### 2.2 A sheet that closes right after it opens

**Symptom:** tapping a button that opens a sheet/card shows it and then it disappears immediately. With a mouse on desktop it works fine.

**Cause:** the button opens the sheet on the *emulated click* (the first half of the touch). Right after, the *touch event* (the second half) arrives and lands on the backdrop of the sheet that just opened. The backdrop hears "release" and closes.

**Fix:** the backdrop listens to only one kind of event (mouse), and closes only when it received both the press and the release itself; ignore taps for the first ~300 ms after opening.

```gdscript
const IGNORE_TAPS_FOR_MS := 300
var opened_at := Time.get_ticks_msec()
var armed := false

func _on_backdrop_input(event: InputEvent) -> void:
	# A touch arrives twice (emulated click, then touch); listening to the click is enough.
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		armed = Time.get_ticks_msec() - opened_at >= IGNORE_TAPS_FOR_MS
	elif armed:
		armed = false
		close()
```

General rule: handle a given gesture through **one** of the two paths (mouse *or* touch), never both, or it runs twice.

### 2.3 A swipe that ends up "tapping" a button or row

**Symptom:** swiping a list and lifting the finger opens the level under the finger, or selects the wrong row.

**Cause:** hand-written tap detection compares the *local* position at press and at release. The content scrolls with the finger, so the local position barely changes and the swipe counts as a tap. A button emits `pressed` if the finger is still inside it on release, and the button has moved along with the finger.

**Fix:** ask the ScrollContainer whether it was dragged (`dragged()` in `touch_scroll.gd`); or compare *global* positions (`get_global_transform() * event.position`); or use fix A from 2.1 (the ScrollContainer tells the button to drop the press).

### 2.4 The on-screen keyboard covers the field and won't go away

**Symptom:** on a device, tapping a `LineEdit` low in a bottom sheet brings up the iOS/Android keyboard on top of the field, so you can't see what you type. Tapping outside the keyboard doesn't dismiss it. A number pad (`KEYBOARD_TYPE_NUMBER`, e.g. a PIN field) has no Return key at all, so the player is stuck and can only escape by closing the sheet. You never see this on desktop because there's no on-screen keyboard.

**Cause:** Godot doesn't push the UI up when the keyboard appears, and the keyboard only hides when the `LineEdit` loses focus. Tapping the background or a label doesn't take focus away from the field.

**Fix** (put it once in the base class of every sheet):
- Every frame, read `DisplayServer.virtual_keyboard_get_height()`. It's in *window* pixels, so convert it to viewport units: multiply by `viewport_height / DisplayServer.window_get_size().y`, then divide by the sheet's scale. When the height is > 0, place the sheet right above the keyboard, shrink it to fit the remaining screen, then `scroll.ensure_control_visible(focused_field)` (deferred, so layout has updated first). When the keyboard hides, put the sheet back.
- In the sheet's `_input()`: a mouse press (emulated touch) outside the focused field's rect (`get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size)`) calls `release_focus()`. Don't call `set_input_as_handled()`: the tap must still do its job (press a button, switch tabs).
- Number fields: once enough characters are typed (e.g. a 6-digit PIN), call `release_focus()` automatically. Text fields: connect `text_submitted` to `release_focus()`.
- Switching tabs or closing the sheet releases focus, otherwise the keyboard stays on screen.

**Testing on desktop:** give the sheet a static variable that fakes the keyboard height (window pixels, `-1` = use the real keyboard). Tap the field with `Input.parse_input_event` (`InputEventScreenTouch`), and **only then** set the fake height, matching the order on a device: if you set it first, the sheet rises before the tap and the tap lands on empty space. Check that the sheet's bottom edge ≤ the keyboard's top edge, the field is inside the sheet, tapping the title removes focus from the field, and removing the keyboard returns the sheet to the bottom. Headless, `window_get_size()` can be 0, so the conversion needs a fallback.

---

## 3. Other gestures

- **Rotate the camera by dragging, zoom with two fingers:** in the `SubViewportContainer`'s `_gui_input`, track fingers by `index`. One finger: `ScreenDrag.relative` changes the angle. Two fingers: the ratio of the distance between them changes the zoom. Add `InputEventMagnifyGesture` (trackpad pinch, reported on macOS) and the mouse wheel for desktop. Call `accept_event()`.
- **Double tap:** two releases less than about 0.32 s apart, with less than 12 px of movement.
- **Tapping or pointing at a 3D object:** `camera.unproject_position(p)` returns coordinates inside the SubViewport; add the `SubViewportContainer`'s global position (when `stretch = true`). Check `camera.is_position_behind(p)` first.
- **An overlay is open:** gestures on the 3D view and swipes on the list below must be blocked. The overlay has a background that takes touches (`STOP`), and handlers in `_input()` need a `guard`.
- **Multi-touch:** follow only the `index` that started the gesture and ignore other fingers.

---

## 4. Testing with simulated touch

`Input.parse_input_event()` goes through the same path as a phone (emulated click, then touch), so it catches all three bugs from section 2. See `templates/check_touch.gd`.

- **Coordinates:** injected events use *window* coordinates. A control's rect is in *canvas* coordinates. Convert with `get_viewport().get_final_transform() * canvas_point` (when the stretch mode is `canvas_items`). Convert a ScreenDrag's `relative` with `basis_xform`.
- **Built-in ScrollContainer when headless:** set `Input.emulate_touch_from_mouse = true` (or enable it in Project Settings) so it drags like on a phone.
- **Wait by real time** (`create_timer`) after a tap that opens a sheet, because the open animation and the tap-ignore window are measured in milliseconds.

Checks worth having for every screen with buttons and lists:

- [ ] Tap every button that opens a sheet/card: the sheet is still open 0.5 s later.
- [ ] Tap the backdrop: the sheet closes. Tap a button inside the sheet: the right action, exactly once.
- [ ] Swipe every list, starting **on a button**: the list scrolls (`scroll_vertical` increases) and the button isn't pressed.
- [ ] After the inertia stops, tap a button in the scrolled list: it still presses.
- [ ] Tap a row: it is selected exactly once (not toggled on and off by the double event).
- [ ] Drag the 3D view: the camera rotates. With an overlay open, it doesn't.

What simulated tests can't replace, and needs a device: how scrolling and inertia feel, mis-taps from a big finger, safe areas (notch, home bar), latency.
