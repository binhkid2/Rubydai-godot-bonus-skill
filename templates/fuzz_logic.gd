extends SceneTree
## A random player with invariants (references/testing.md §2a). Copy to tools/, then ADAPT the actions and the
## invariants to the game's controller and state.
##   godot --headless --path . --script tools/fuzz_logic.gd -- --seeds 10 --steps 2500
## Each seed replays exactly, and every failure names the seed, the step and the action just taken.

## Names a player could type: empty, blank, too long, emoji, markup, a format string.
const NAMES := ["", "   ", "A", "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW", "☕️ Café ñ 漢字", "<b>x</b>", "%d %s {0}", "\n\t"]

var failures: Array[String] = []
var rng := RandomNumberGenerator.new()
var game
var step := 0
var last_action := ""

func _initialize() -> void:
	call_deferred("run")

func arg(name: String, fallback: int) -> int:
	var args := OS.get_cmdline_user_args()
	var at := args.find(name)
	return int(args[at + 1]) if at >= 0 and at + 1 < args.size() else fallback

func check(ok: bool, message: String) -> void:
	if not ok and failures.size() < 60:
		failures.append("seed %d step %d after %s: %s" % [rng.seed, step, last_action, message])

func run() -> void:
	var seeds := arg("--seeds", 10)
	var steps := arg("--steps", 2500)
	for seed in range(1, seeds + 1):
		rng.seed = seed
		game = preload("res://scripts/game_controller.gd").new()  # ADAPT: a new game, saving to disk off
		root.add_child(game)
		game.start("")
		for i in range(steps):
			step = i
			act()
			invariants()
			if failures.size() >= 60:
				break
		game.free()
	for f in failures:
		push_error(f)
	print("FAIL" if not failures.is_empty() else "PASS: %d seeds x %d steps keep every invariant." % [seeds, steps])
	quit(1 if not failures.is_empty() else 0)

func pick(list: Array):
	return list[rng.randi_range(0, list.size() - 1)] if not list.is_empty() else ""

## ADAPT: every player action, with good and bad arguments (unknown ids, negative and huge amounts, NAMES).
func act() -> void:
	match rng.randi_range(0, 5):
		0, 1:
			last_action = "time passes"
			game.advance(rng.randf_range(0.05, 30.0))
		2:
			last_action = "a long time away"
			game.resume(game.clock + pick([60.0, 86400.0, 400.0 * 86400.0]))
		3:
			last_action = "the clock going backwards"
			game.resume(game.clock - pick([5.0, 3600.0, 86400.0]))
		4:
			last_action = "buy"
			game.buy(pick(["sword", "shield", "no_such_thing"]), pick([1, 0, -5, 100000]))
		5:
			last_action = "save and load"
			var before: Dictionary = game.state.to_dict()
			var loaded = game.state.get_script().from_dict(JSON.parse_string(JSON.stringify(before)))
			var difference := first_difference(before, loaded.to_dict(), "")
			check(difference == "", "a save loads back the same: %s" % difference)
			game.state = loaded

func finite(v) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v))

## ADAPT: what must hold after any step: finite and in range, within caps, valid indices, no duplicates.
func invariants() -> void:
	var s = game.state
	check(finite(s.coins) and s.coins >= 0.0, "coins %s" % s.coins)

## Where two saves differ, as a path like items/2/count: 25 -> 0. JSON keeps about 15 digits, so floats get a
## tolerance.
func first_difference(a, b, path: String) -> String:
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		for key in a:
			if not b.has(key):
				return "%s/%s missing" % [path, key]
			var inner := first_difference(a[key], b[key], "%s/%s" % [path, key])
			if inner != "":
				return inner
		for key in b:
			if not a.has(key):
				return "%s/%s added" % [path, key]
		return ""
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size():
			return "%s size %d -> %d" % [path, a.size(), b.size()]
		for i in range(a.size()):
			var inner := first_difference(a[i], b[i], "%s/%d" % [path, i])
			if inner != "":
				return inner
		return ""
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return "" if is_equal_approx(float(a), float(b)) or absf(a - b) <= absf(a) * 1e-12 else "%s: %s -> %s" % [path, a, b]
	return "" if JSON.stringify(a) == JSON.stringify(b) else "%s: %s -> %s" % [path, JSON.stringify(a), JSON.stringify(b)]
