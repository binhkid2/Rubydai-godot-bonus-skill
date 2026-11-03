extends RefCounted
## Simulated taps and swipes that take the same path as on a phone: Input.parse_input_event() produces the
## emulated click first and then the touch event, like iOS/Android. Catches "the list won't swipe", "the sheet
## closes right after it opens" and "a swipe ends in a mis-tap", which a desktop mouse never shows.
##
## Usage: copy to tools/check_touch.gd, rewrite run() for the game's screens, then call it from the main
## scene when the --selftest flag is set (so autoloads are loaded):
##   var failures: int = await load("res://tools/check_touch.gd").run(self)
## Run: godot --path . -- --selftest

static var failures := 0


static func check(name: String, ok: bool, detail := "") -> void:
	print("%s %s %s" % ["ok  " if ok else "FAIL", name, detail])
	failures += int(not ok)


static func run(app: Node) -> int:
	failures = 0
	# The built-in ScrollContainer only drags with a finger on a touchscreen; this makes desktop/headless behave like a phone.
	Input.emulate_touch_from_mouse = true

	# --- Example 1: a button opens a sheet; the sheet must not close itself, tapping the backdrop closes it ---
	# var screen: Control = preload("res://scenes/shop.tscn").instantiate()
	# app.add_child(screen)
	# await wait(app, 0.3)
	# await tap(app, find_button(screen, "Shop").get_global_rect().get_center())
	# await wait(app, 0.5)
	# check("tap the open button: sheet stays open", screen.sheet != null)
	# await tap(app, Vector2(360, 120))            # a point on the backdrop, canvas coordinates
	# await wait(app, 0.4)
	# check("tap the backdrop: sheet closes", screen.sheet == null)

	# --- Example 2: a swipe that starts on a button scrolls the list and doesn't press the button ---
	# var scroll: ScrollContainer = screen.find_child("List", true, false)
	# var button := find_button(scroll, "Buy")
	# var presses := [0]
	# button.pressed.connect(func() -> void: presses[0] += 1)
	# var at := button.get_global_rect().get_center()
	# await drag(app, at, at - Vector2(0, 400))
	# check("swipe on a button scrolls", scroll.scroll_vertical > 100, str(scroll.scroll_vertical))
	# check("swipe doesn't press the button", presses[0] == 0)
	# await settle(app, scroll)
	# await tap(app, find_button(scroll, "Buy").get_global_rect().get_center())
	# check("after inertia stops, a tap still presses", presses[0] == 1)

	print("touch test: %d failure(s)" % failures)
	return failures


# --- Touch events ---

## Canvas coordinates (as from get_global_rect) to window coordinates, through the screen stretch (stretch canvas_items).
static func to_window(app: Node, canvas_point: Vector2) -> Vector2:
	return app.get_viewport().get_final_transform() * canvas_point


static func touch(app: Node, at: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = to_window(app, at)
	e.pressed = pressed
	Input.parse_input_event(e)
	await app.get_tree().process_frame


static func tap(app: Node, at: Vector2) -> void:
	await touch(app, at, true)
	await touch(app, at, false)


## Swipe from `from` to `to` in several steps, one frame per step (with velocity, to exercise inertia).
static func drag(app: Node, from: Vector2, to: Vector2, steps := 12, index := 0) -> void:
	await touch(app, from, true, index)
	var t := app.get_viewport().get_final_transform()
	var last := from
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / steps)
		var e := InputEventScreenDrag.new()
		e.index = index
		e.position = t * point
		e.relative = t.basis_xform(point - last)
		e.velocity = e.relative * 60.0
		Input.parse_input_event(e)
		last = point
		await app.get_tree().process_frame
	await touch(app, to, false, index)


static func wait(app: Node, seconds: float) -> void:
	await app.get_tree().create_timer(seconds).timeout


## Wait until the list stops scrolling from inertia.
static func settle(app: Node, scroll: ScrollContainer) -> void:
	var last := -1
	while scroll.scroll_vertical != last:
		last = scroll.scroll_vertical
		await wait(app, 0.1)


static func find_button(root: Node, text: String) -> Button:
	for b: Button in root.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null
