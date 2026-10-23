extends SceneTree
## Worst-case data at every screen size (references/testing.md §2b). Copy to tools/, then fill in the four
## ADAPT parts: how to load the game, how to dress the save, how to open each panel, and where the HUD is.
##   godot --headless --path . --script tools/check_extremes.gd
## Checks: every panel/popup on screen, every visible control inside its panel's width, HUD text inside a card and
## off other text, no "nan", "inf", overflowed int or unfilled %d anywhere. Prove it works by putting a fixed bug
## back for a moment: it must fail.

## Phone and tablet windows: 16:9, tall iPhone, iPhone SE, iPad portrait and landscape.
const SIZES := [Vector2i(540, 960), Vector2i(390, 844), Vector2i(375, 667), Vector2i(768, 1024), Vector2i(1024, 768)]
const SCENARIOS := ["as_loaded", "worst", "maxed"]
## ADAPT: the script that declares `static var audit` (the HUD's base script).
const HudScript = preload("res://scripts/hud.gd")
## W is the widest letter: a name as wide as the field allows.
const WIDE := "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"

var failures: Array[String] = []
## nan/inf as words, an int that overflowed, an unfilled %d/%s/%.1f, a printed null.
var bad_text := RegEx.create_from_string("(?i)\\b(nan|inf)\\b|922337203|%[-+0-9.]*[dsf]\\b|<null>")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)

func run() -> void:
	# An error inside an awaited step would otherwise leave the run hanging.
	create_timer(600.0).timeout.connect(func(): push_error("timed out"); quit(1))
	check_formats()
	for scenario in SCENARIOS:
		var scene = load("res://scenes/main.tscn").instantiate()  # ADAPT: the game scene, saving turned off
		root.add_child(scene)
		await process_frame
		scene.process_mode = Node.PROCESS_MODE_DISABLED  # a still game: nothing changes between checks
		dress(scene, scenario)
		for size in SIZES:
			root.size = size
			await process_frame
			await process_frame
			var where := "%s %dx%d" % [scenario, size.x, size.y]
			for kind in panel_kinds(scene):
				var panel: Control = open_panel(scene, kind)
				await create_timer(0.3).timeout  # let the slide-in finish; real time, not frames
				check_panel(panel, "%s (%s)" % [kind, where])
				panel.free()
			# ADAPT: the HUD node; draw it with every status text it can show (each warning, each item name).
			# await check_hud(scene.get_node("HUD"), where)
		scene.free()
		await process_frame
	for f in failures:
		push_error(f)
	print("FAIL" if not failures.is_empty() else "PASS: worst-case data fits every screen.")
	quit(1 if not failures.is_empty() else 0)

## ADAPT: every panel the game can open, from its own registry (so a new panel is checked without editing this).
func panel_kinds(scene) -> Array:
	return scene.PANELS.keys()

## ADAPT: open one and return the Control that must stay on screen.
func open_panel(scene, kind: String) -> Control:
	return scene.open_panel(kind)

## ADAPT: "worst" = every text at its longest (WIDE names, every list full, everything sold out at once),
## huge and negative numbers, every unlock; "maxed" = everything at its top level.
func dress(scene, scenario: String) -> void:
	if scenario == "as_loaded":
		return
	var s = scene.game.state
	if scenario == "worst":
		s.player_name = WIDE.left(20)
		s.coins = 9.87e17
	else:
		pass

## Number formatters with values the game can reach, and some it shouldn't.
func check_formats() -> void:
	for v in [0.0, -3.0, 999.0, 1e5, 1e15, 1e21, 1e300, -1e30, INF, -INF, NAN]:
		pass  # ADAPT: for text in [Fmt.compact(v), Fmt.coins(v), Fmt.rate(v)]: check(text.length() <= 12 and bad(text) == "", ...)

func bad(text: String) -> String:
	var found := bad_text.search(text)
	return found.get_string() if found != null else ""

func check_panel(panel: Control, what: String) -> void:
	var bounds := panel.get_viewport().get_visible_rect()
	# Under canvas_items stretching, global rects are in the same units as the visible rect. Multiply by the
	# panel's own scale when the panel scales itself.
	var rect := panel.get_global_rect()
	check(bounds.grow(1.0).encloses(rect), "%s: panel %s leaves the screen %s" % [what, rect, bounds.size])
	for c in panel.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree() or c.size.x <= 0.0:
			continue
		var r: Rect2 = c.get_global_rect()
		check(r.position.x >= rect.position.x - 1.0 and r.end.x <= rect.end.x + 1.0, "%s: %s sticks out" % [what, c.name])
		if c is Label or c is Button or c is LineEdit:
			check(bad(c.text) == "", "%s: '%s' shows %s" % [what, c.text, bad(c.text)])

## The HUD script needs, in text_at()/draw_text() and card()/panel():
##   static var audit = null
##   if audit != null: audit.append({"text": words, "rect": Rect2(at.x, at.y - size * 0.72, width, size * 0.8)})
##   if audit != null: audit.append({"box": rect})
func check_hud(hud, where: String) -> void:
	HudScript.audit = []
	hud.queue_redraw()
	await process_frame
	await process_frame
	var drawn: Array = HudScript.audit
	HudScript.audit = null
	var boxes: Array = drawn.filter(func(d): return d.has("box")).map(func(d): return d.box)
	var texts: Array = drawn.filter(func(d): return d.has("text") and d.text.strip_edges() != "")
	check(not texts.is_empty(), "HUD (%s) drew no text: is the audit hook in place?" % where)
	for i in range(texts.size()):
		var t: Dictionary = texts[i]
		check(boxes.any(func(b: Rect2): return b.grow(2.0).encloses(t.rect)), "HUD (%s): '%s' leaves its card" % [where, t.text])
		check(bad(t.text) == "", "HUD (%s): '%s' shows %s" % [where, t.text, bad(t.text)])
		for j in range(i + 1, texts.size()):
			check(t.rect.intersection(texts[j].rect).get_area() < 6.0, "HUD (%s): '%s' runs into '%s'" % [where, t.text, texts[j].text])
